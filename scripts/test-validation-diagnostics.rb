# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "json"
require "open3"
require "securerandom"
require "shellwords"

class ValidationDiagnosticsTest < Minitest::Test
  SCRIPT_DIR = File.expand_path(__dir__).freeze

  def setup
    @root = File.expand_path("../.diagnostics-test-#{Process.pid}-#{SecureRandom.hex(4)}", SCRIPT_DIR)
    @output = File.join(@root, "diagnostics")
    @tools = File.join(@root, "tools")
    FileUtils.mkdir_p(@tools)
    File.write(File.join(@root, "cask.rb"), "cask \"aspire\" do\n  version \"1.2.3\"\nend\n")
    File.write(
      File.join(@root, "metadata.json"),
      JSON.generate(
        "casks" => [{
          "version"    => "1.2.3",
          "url"        => "https://github.com/microsoft/aspire/releases/download/v1.2.3/aspire-cli-osx-arm64-1.2.3.tar.gz",
          "sha256"     => "a" * 64,
          "variations" => {
            "sequoia" => {
              "url"    => "https://github.com/microsoft/aspire/releases/download/v1.2.3/aspire-cli-osx-x64-1.2.3.tar.gz",
              "sha256" => "b" * 64,
            },
          },
        }],
      ),
    )
    File.binwrite(File.join(@root, "trace"),
                  "\e[36mAuthorization:\e[0m Bearer raw-canary\r\n\xff\nrestore failed NU1105\n".b)
    File.write(
      File.join(@root, "assets"),
      JSON.pretty_generate(
        "version" => 3,
        "targets" => { "net10.0" => { "Example/1.0" => { "type" => "package" } } },
        "project" => { "restore" => { "sources" => {
          "https://url-user-canary:url-pass-canary@example.com/feed?token=url-query-canary" => {},
        } } },
        "logs"    => [{ "level" => "Error", "code" => "NU1105",
                     "message" => "Password=\"quoted-canary with spaces\"; invalid version" }],
      ),
    )
    write_tool("uname", "echo Darwin")
    write_tool("dotnet", "echo 10.0.100")
    write_tool("sudo", "exit 1")
    write_tool("codesign", "exit 0")
    write_tool("curl", <<~BASH)
      while [[ "$1" != --output ]]; do shift; done
      cp "${TEST_ROOT}/cask.rb" "$2"
    BASH
    write_tool("git", <<~BASH)
      if [[ "$*" == *https://github.com/Homebrew/brew.git* ]]
      then
        prefix="${@: -1}"
        mkdir -p "$prefix/bin" "$prefix/Library/Taps/homebrew/homebrew-core/.git"
        cp "${TEST_ROOT}/tools/brew" "$prefix/bin/brew"
        printf '%s\\n' "$(dirname "$prefix")" >"${TEST_ROOT}/workspace"
      elif [[ "$*" == *checkout* ]]
      then
        :
      else
        exec #{Shellwords.escape(`command -v git`.strip)} "$@"
      fi
    BASH
    write_tool("brew", <<~'BASH')
      prefix="$(cd "$(dirname "$0")/.." && pwd)"
      case "$1" in
        --repository) printf '%s\n' "${TEST_ROOT}/source" ;;
        --prefix) printf '%s\n' "$prefix" ;;
        --version) echo "Homebrew fixture" ;;
        info) cat "${TEST_ROOT}/metadata.json" ;;
        ruby)
          shift
          args=()
          for arg in "$@"; do [[ "$arg" == -- ]] || args+=("$arg"); done
          exec ruby "${args[@]}"
          ;;
        install)
          mkdir -p "$prefix/Caskroom/aspire/1.2.3"
          cp "${TEST_ROOT}/tools/aspire" "$prefix/Caskroom/aspire/1.2.3/aspire"
          printf '{"source":"brew"}\n' >"$prefix/Caskroom/aspire/1.2.3/.aspire-install.json"
          ln -s "$prefix/Caskroom/aspire/1.2.3/aspire" "$prefix/bin/aspire"
          ;;
        uninstall)
          printf 'uninstall\n' >>"${TEST_ROOT}/cleanup"
          rm -rf "$prefix/Caskroom/aspire/1.2.3" "$prefix/bin/aspire"
          exit "${TEST_UNINSTALL_STATUS:-0}"
          ;;
        trust|style|readall|audit|fetch|cask-ci) : ;;
        *) echo "Unexpected brew command: $*" >&2; exit 99 ;;
      esac
    BASH
    write_tool("aspire", <<~'BASH')
      if [[ "$1" == --version ]]; then echo 1.2.3; exit 0; fi
      [[ "$1" == --log-level && "$2" == trace && "$3" == --log-file ]] || exit 98
      log="$4"
      action="$5"
      printf '%s\n' "$log" >>"${TEST_ROOT}/trace-paths"
      cp "${TEST_ROOT}/trace" "$log"
      if [[ "$action" == new ]]
      then
        mkdir -p "SmokeApp.AppHost/obj" "SmokeApp.Api Service/obj"
        cp "${TEST_ROOT}/assets" "SmokeApp.AppHost/obj/project.assets.json"
        printf '{"logs":[]}\n' >"SmokeApp.Api Service/obj/project.assets.json"
        printf 'not diagnostic\n' >"SmokeApp.AppHost/obj/cache"
        exit "${TEST_NEW_STATUS:-0}"
      elif [[ "$action" == restore ]]
      then
        [[ "${TEST_BAD_JSON:-false}" != true ]] || printf '{"broken":"failure-canary"' >"SmokeApp.AppHost/obj/project.assets.json"
        if [[ "${TEST_COPY_FAILURE:-false}" == true ]]
        then
          mkdir -p "$TEST_DIAGNOSTICS/smoke/SmokeApp.AppHost/obj"
          ln -s "${TEST_ROOT}/missing-copy-parent/assets" \
            "$TEST_DIAGNOSTICS/smoke/SmokeApp.AppHost/obj/project.assets.json"
        fi
        [[ "${TEST_TERMINATE:-false}" != true ]] || kill -TERM "$PPID"
        exit "${TEST_RESTORE_STATUS:-6}"
      else
        exit 97
      fi
    BASH
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_writes_trace_logs_directly_to_requested_directory
    _, stderr, status = validate

    assert_equal 6, status.exitstatus, stderr
    assert_equal %w[cli-new.log cli-restore.log].map { |name| File.join(@output, name) },
                 File.readlines(File.join(@root, "trace-paths"), chomp: true)
    %w[cli-new.log cli-restore.log].each do |name|
      assert_equal File.binread(File.join(@root, "trace")), File.binread(File.join(@output, name))
    end
    assert_cleaned_up
  end

  def test_diagnostics_directory_is_owner_only_with_permissive_caller_umask
    _, stderr, status = Open3.capture3(
      test_environment, "bash", "-c", 'umask 000; exec bash "$@"', "validate-cask",
      File.join(SCRIPT_DIR, "validate-cask.sh"), "--cask-file", File.join(@root, "cask.rb"),
      "--diagnostics-dir", @output
    )

    assert_equal 6, status.exitstatus, stderr
    assert_equal 0700, File.stat(@output).mode & 0777
    assert_equal File.binread(File.join(@root, "trace")), File.binread(File.join(@output, "cli-restore.log"))
    assert_cleaned_up
  end

  def test_failure_retains_byte_exact_assets_with_project_relative_paths
    _, stderr, status = validate

    assert_equal 6, status.exitstatus, stderr
    assert_equal ["cli-new.log", "cli-restore.log", "smoke/SmokeApp.Api Service/obj/project.assets.json",
                  "smoke/SmokeApp.AppHost/obj/project.assets.json"],
                 Dir.glob("#{@output}/**/*").select { |path| File.file?(path) }
                    .map { |path| path.delete_prefix("#{@output}/") }.sort
    assert_equal File.binread(File.join(@root, "assets")),
                 File.binread(File.join(@output, "smoke/SmokeApp.AppHost/obj/project.assets.json"))
    assert_equal "{\"logs\":[]}\n",
                 File.binread(File.join(@output, "smoke/SmokeApp.Api Service/obj/project.assets.json"))
    assert_cleaned_up
  end

  def test_copy_failure_preserves_exit_six_and_still_cleans_workspace
    _, stderr, status = validate({ "TEST_COPY_FAILURE" => "true" })

    assert_equal 6, status.exitstatus, stderr
    assert_match(/cp: /, stderr)
    assert_match(/Warning: failure assets could not be fully copied/, stderr)
    assert_equal File.join(@root, "missing-copy-parent/assets"),
                 File.readlink(File.join(@output, "smoke/SmokeApp.AppHost/obj/project.assets.json"))
    %w[cli-new.log cli-restore.log].each do |name|
      assert_equal File.binread(File.join(@root, "trace")), File.binread(File.join(@output, name))
    end
    assert_cleaned_up
  end

  def test_success_keeps_direct_logs_without_copying_assets
    _, stderr, status = validate({ "TEST_RESTORE_STATUS" => "0" })

    assert_equal 0, status.exitstatus, stderr
    assert_equal %w[cli-new.log cli-restore.log], Dir.children(@output).sort
    %w[cli-new.log cli-restore.log].each do |name|
      assert_equal File.binread(File.join(@root, "trace")), File.binread(File.join(@output, name))
    end
    assert_cleaned_up
  end

  def test_failure_without_diagnostics_removes_logs_with_workspace
    _, stderr, status = validate({}, diagnostics: false)

    assert_equal 6, status.exitstatus, stderr
    refute File.exist?(@output)
    workspace = File.read(File.join(@root, "workspace")).strip
    assert_equal %w[cli-new.log cli-restore.log].map { |name| File.join(workspace, name) },
                 File.readlines(File.join(@root, "trace-paths"), chomp: true)
    assert_cleaned_up
  end

  def test_scaffold_failure_preserves_status_even_when_uninstall_fails
    _, stderr, status = validate({ "TEST_NEW_STATUS" => "37", "TEST_UNINSTALL_STATUS" => "72" })

    assert_equal 37, status.exitstatus, stderr
    assert_match(/cleanup uninstall failed/, stderr)
    assert_equal ["cli-new.log", "smoke/SmokeApp.Api Service/obj/project.assets.json",
                  "smoke/SmokeApp.AppHost/obj/project.assets.json"],
                 Dir.glob("#{@output}/**/*").select { |path| File.file?(path) }
                    .map { |path| path.delete_prefix("#{@output}/") }.sort
    assert_cleaned_up
  end

  def test_retains_incomplete_assets_without_parsing_or_changing_bytes
    _, stderr, status = validate({ "TEST_BAD_JSON" => "true" })

    assert_equal 6, status.exitstatus, stderr
    assert_equal '{"broken":"failure-canary"',
                 File.binread(File.join(@output, "smoke/SmokeApp.AppHost/obj/project.assets.json"))
    assert_cleaned_up
  end

  def test_termination_preserves_status_and_cleans_workspace
    _, stderr, status = validate({ "TEST_TERMINATE" => "true" })

    assert_equal 143, status.exitstatus, stderr
    assert_equal File.binread(File.join(@root, "assets")),
                 File.binread(File.join(@output, "smoke/SmokeApp.AppHost/obj/project.assets.json"))
    assert_cleaned_up
  end

  def test_rejects_directory_inside_workspace_including_symlink_alias
    # Predict the shell's workspace at the brew --repository boundary, before
    # creation, so the real directory guard also sees a symlinked parent.
    %w[direct alias].each do |kind|
      write_tool("brew", <<~BASH)
        work="$TEST_WORKSPACE"
        if [[ "#{kind}" == alias ]]; then ln -s "$work" "${TEST_ROOT}/alias"; work="${TEST_ROOT}/alias"; fi
        printf '%s\\n' "$TEST_WORKSPACE" >"${TEST_ROOT}/inside"
        echo "${TEST_ROOT}/source"
      BASH
      _, stderr, status = Open3.capture3(
        test_environment,
        "bash", "-c", <<~BASH
          RANDOM=123
          TEST_RANDOM="$RANDOM"
          RANDOM=123
          export TEST_WORKSPACE="#{File.dirname(SCRIPT_DIR)}/.aspire-tap-validation.$$.$TEST_RANDOM"
          source "#{SCRIPT_DIR}/validate-cask.sh" --diagnostics-dir \
            "#{(kind == "alias") ? "#{@root}/alias" : "$TEST_WORKSPACE"}/diagnostics"
        BASH
      )
      assert_equal 1, status.exitstatus, stderr
      assert_match(/outside.*workspace/, stderr)
      refute File.exist?(File.join(@root, "workspace")), "validation must stop before cloning Homebrew"
      refute File.exist?(File.read(File.join(@root, "inside")).strip), "rejected workspace must be removed"
    end
  end

  def test_rejects_existing_file_directory_and_dangling_symlink_without_changes
    File.write(@output, "existing file")
    _, stderr, status = validate

    assert_equal 1, status.exitstatus, stderr
    assert_equal "existing file", File.read(@output)
    File.unlink(@output)

    FileUtils.mkdir_p(@output)
    File.write(File.join(@output, "keep"), "existing directory")
    existing_mode = File.stat(@output).mode & 0777
    _, stderr, status = validate

    assert_equal 1, status.exitstatus, stderr
    assert_equal existing_mode, File.stat(@output).mode & 0777
    assert_equal ["keep"], Dir.children(@output)
    assert_equal "existing directory", File.read(File.join(@output, "keep"))
    FileUtils.remove_entry(@output)

    File.symlink(File.join(@root, "missing"), @output)
    _, stderr, status = validate

    assert_equal 1, status.exitstatus, stderr
    assert_equal File.join(@root, "missing"), File.readlink(@output)
    refute File.exist?(File.join(@root, "workspace"))
  end

  def test_rejects_nonexistent_parent_before_cloning_homebrew
    @output = File.join(@root, "missing", "diagnostics")
    _, stderr, status = validate

    assert_equal 1, status.exitstatus, stderr
    assert_match(/existing parent directory/, stderr)
    refute File.exist?(File.join(@root, "missing"))
    refute File.exist?(File.join(@root, "workspace"))
  end

  private

  def write_tool(name, body)
    path = File.join(@tools, name)
    File.write(path, "#!/usr/bin/env bash\nset -euo pipefail\n#{body}\n")
    FileUtils.chmod(0700, path)
  end

  def test_environment
    {
      "PATH" => "#{@tools}:#{ENV.fetch("PATH")}",
      "TEST_ROOT" => @root, "TEST_DIAGNOSTICS" => @output,
      "CI" => nil, "HOMEBREW_VALIDATION_REF" => "7.0.9"
    }
  end

  def validate(environment = {}, diagnostics: true)
    args = ["bash", File.join(SCRIPT_DIR, "validate-cask.sh"), "--cask-file", File.join(@root, "cask.rb")]
    args += ["--diagnostics-dir", @output] if diagnostics
    Open3.capture3(test_environment.merge(environment), *args)
  end

  def assert_cleaned_up
    assert_equal "uninstall\n", File.read(File.join(@root, "cleanup"))
    refute File.exist?(File.read(File.join(@root, "workspace")).strip), "validation workspace survived cleanup"
  end
end
