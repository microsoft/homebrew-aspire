# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "collect-validation-diagnostics"

class ValidationDiagnosticsTest < Minitest::Test
  SCRIPT_DIR = File.expand_path(__dir__).freeze
  FAILURE = "NU1105: 'auto' is not a valid version string"
  LIFECYCLE = <<~'BASH'
    set -euo pipefail
    script_dir="$1"
    work="$2"
    diagnostics_dir="$3"
    prefix="${work}/homebrew"
    brew_command="$4"
    reference=validation/aspire/aspire
    install_attempted=true
    source "${script_dir}/validation-support.sh"
    trap cleanup_validation EXIT
    run_smoke_command bash -c 'printf "%s\n" "$1"; exit "$2"' -- "$5" "$6"
  BASH

  def setup
    @root = Dir.mktmpdir("validation-diagnostics")
    @work = File.join(@root, "work")
    @output = File.join(@root, "diagnostics")
    FileUtils.mkdir_p(@work)
    @brew = File.join(@root, "brew")
    File.write(@brew, <<~BASH)
      #!/usr/bin/env bash
      printf '%s\\n' "$*" >"#{@root}/uninstall"
      exit "${UNINSTALL_STATUS:-0}"
    BASH
    FileUtils.chmod(0700, @brew)
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def run_lifecycle(status: 42, output: FAILURE, env: {})
    Open3.capture3(env, "bash", "-c", LIFECYCLE, "--", SCRIPT_DIR, @work, @output, @brew, output, status.to_s)
  end

  def write_assets(data = {})
    directory = File.join(@work, "smoke", "SmokeApp.AppHost", "obj")
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, "project.assets.json"), JSON.generate(data))
  end

  def test_failure_survives_cleanup_with_underlying_nuget_error
    write_assets("logs"    => [{ "level" => "Error", "code" => "NU1105", "message" => FAILURE }],
                 "project" => { "restore" => { "sources" => { "https://api.nuget.org/v3/index.json" => {} } } })
    File.write(File.join(@work, "cli-new.log"), "dotnet restore: #{FAILURE}\n")
    stdout, stderr, status = run_lifecycle
    assert_equal 42, status.exitstatus, stderr
    assert_includes stdout, FAILURE
    refute File.exist?(@work)
    assert_equal "uninstall --cask validation/aspire/aspire\n", File.read(File.join(@root, "uninstall"))
    assert_includes File.read(File.join(@output, "smoke-command.log")), FAILURE
    assert_includes File.read(File.join(@output, "cli-new.log")), FAILURE
    summary = JSON.parse(File.read(File.join(@output, "nuget-summary.json"))).fetch(0)
    assert_equal "NU1105", summary.fetch("errors").fetch(0).fetch("code")
    assert_equal ["https://api.nuget.org/v3/index.json"], summary.fetch("sources")
  end

  def test_empty_load_stderr_does_not_abort_failure_diagnostics
    File.write(File.join(@work, "load.err"), "")
    File.write(File.join(@work, "failed-checks.log"), "audit failed: env-canary\n")
    write_assets("logs" => [{ "level" => "Error", "code" => "NU1105", "message" => FAILURE }])
    _, stderr, status = run_lifecycle(env: { "TEST_SECRET" => "env-canary" })
    assert_equal 42, status.exitstatus
    refute File.exist?(@work)
    assert_equal "uninstall --cask validation/aspire/aspire\n", File.read(File.join(@root, "uninstall"))
    refute_includes stderr, "diagnostics collection failed"
    refute_includes stderr, "could not be fully collected"
    assert_empty File.read(File.join(@output, "load.err"))
    assert_equal "audit failed: [REDACTED]\n", File.read(File.join(@output, "failed-checks.log"))
    summary = JSON.parse(File.read(File.join(@output, "nuget-summary.json"))).fetch(0)
    assert_equal "NU1105", summary.fetch("errors").fetch(0).fetch("code")
    assert_equal FAILURE, summary.fetch("errors").fetch(0).fetch("message")
  end

  def test_validator_entrypoint_retains_setup_failure_and_removes_workspace
    tools = File.join(@root, "tools")
    FileUtils.mkdir_p(tools)
    { "uname" => "echo Darwin",
      "brew"  => "echo '#{@root}/source'",
      "git"   => "printf '%s\\n' \"${@: -1}\" >'#{@root}/prefix'; exit 37" }.each do |name, body|
      path = File.join(tools, name)
      File.write(path, "#!/usr/bin/env bash\n#{body}\n")
      FileUtils.chmod(0700, path)
    end
    _, stderr, status = Open3.capture3(
      { "PATH" => "#{tools}:#{ENV.fetch("PATH")}" },
      "bash", File.join(SCRIPT_DIR, "validate-cask.sh"), "--diagnostics-dir", @output
    )
    assert_equal 37, status.exitstatus, stderr
    refute File.exist?(File.dirname(File.read(File.join(@root, "prefix")).strip))
    assert_equal [], JSON.parse(File.read(File.join(@output, "nuget-summary.json")))
  end

  def test_redacts_credentials_and_excludes_configs_caches_and_other_assets_data
    text = <<~TEXT
      #{FAILURE}
      Authorization: Bearer bearer-canary
      Password="password-canary"
      api_key=key-canary
      https://user-canary:pass-canary@feed.example/v3/index.json?sig=query-canary#fragment-canary
      env-canary ghp_githubcanary
    TEXT
    FileUtils.mkdir_p(File.join(@work, "home", ".nuget"))
    File.write(File.join(@work, "home", ".nuget", "NuGet.Config"), "config-canary")
    File.write(File.join(@work, "cache"), "cache-canary")
    File.write(File.join(@work, "cli-restore.log"), text)
    write_assets("logs"      => [
                   { "level" => "Error", "code" => "NU1105", "message" => text, "extra" => "extra-canary" },
                   { "level" => "Warning", "message" => "warning-canary" },
                 ],
                 "libraries" => { "library-canary" => {} },
                 "project"   => { "restore" => { "sources" => {
                   "https://user:pass@feed.example/v3/index.json?token=source-canary#fragment" => {},
                   "/private/local-canary"                                                     => {},
                 } } })
    _, stderr, status = run_lifecycle(output: text, env: { "TEST_SECRET" => "env-canary" })
    assert_equal 42, status.exitstatus, stderr
    retained = Dir.children(@output).map { |name| File.read(File.join(@output, name)) }.join
    refute_match(/canary/, retained)
    assert_includes retained, FAILURE
    summary = JSON.parse(File.read(File.join(@output, "nuget-summary.json"))).fetch(0)
    assert_equal ["https://feed.example/v3/index.json", "[local or unrecognized feed]"], summary.fetch("sources")
    assert_equal %w[cli-restore.log nuget-summary.json smoke-command.log], Dir.children(@output).sort
  end

  def test_collection_and_uninstall_failures_do_not_replace_original_exit
    File.write(@output, "existing file")
    _, stderr, status = run_lifecycle(env: { "UNINSTALL_STATUS" => "9" })
    assert_equal 42, status.exitstatus
    assert_includes stderr, "could not be fully collected"
    assert_includes stderr, "cleanup uninstall failed"
    refute File.exist?(@work)
    assert File.exist?(File.join(@root, "uninstall"))
    assert_equal "existing file", File.read(@output)
  end

  def test_success_creates_no_diagnostics_and_cleanup_failure_still_fails
    _, _, status = run_lifecycle(status: 0)
    assert status.success?
    refute File.exist?(@output)
    refute File.exist?(@work)
    FileUtils.mkdir_p(@work)
    _, _, status = run_lifecycle(status: 0, env: { "UNINSTALL_STATUS" => "9" })
    assert_equal 1, status.exitstatus
  end

  def test_optional_diagnostics_can_be_disabled
    @output = ""
    _, _, status = run_lifecycle
    assert_equal 42, status.exitstatus
    refute File.exist?(@work)
  end

  def test_rejects_workspace_and_symlinked_destination
    assert_raises(ArgumentError) { ValidationDiagnostics.destination(@work, File.join(@work, "diagnostics")) }
    File.symlink(@work, File.join(@root, "alias"))
    assert_raises(ArgumentError) do
      ValidationDiagnostics.destination(@work, File.join(@root, "alias", "diagnostics"))
    end
    File.symlink(File.join(@root, "missing"), @output)
    assert_raises(ArgumentError) { ValidationDiagnostics.destination(@work, @output) }
  end

  def test_bounds_artifacts_and_does_not_follow_log_or_project_symlinks
    File.write(File.join(@work, "cli-new.log"), "#{"x" * 200_000}\n#{FAILURE}\n")
    File.symlink("/dev/zero", File.join(@work, "cli-restore.log"))
    FileUtils.mkdir_p(File.join(@work, "smoke"))
    File.symlink(@root, File.join(@work, "smoke", "outside"))
    ValidationDiagnostics.collect(@work, @output)
    assert_operator File.size(File.join(@output, "cli-new.log")), :<=, ValidationDiagnostics::TEXT_LIMIT
    assert_includes File.read(File.join(@output, "cli-new.log")), FAILURE
    refute File.exist?(File.join(@output, "cli-restore.log"))
    assert_equal [], JSON.parse(File.read(File.join(@output, "nuget-summary.json")))
  end

  def test_file_count_and_multibyte_output_respect_limits
    20.times do |index|
      directory = File.join(@work, "smoke", "project-#{index}", "obj")
      FileUtils.mkdir_p(directory)
      File.write(File.join(directory, "project.assets.json"), "{}")
    end
    assert_equal ValidationDiagnostics::FILE_LIMIT, ValidationDiagnostics.assets_files(@work).length
    ValidationDiagnostics.write(@work, "multibyte.log", "\u20ac" * ValidationDiagnostics::TEXT_LIMIT)
    retained = File.read(File.join(@work, "multibyte.log"), encoding: "UTF-8")
    assert_operator retained.bytesize, :<=, ValidationDiagnostics::TEXT_LIMIT
    assert retained.valid_encoding?
  end

  def test_oversized_and_malformed_assets_are_reported_without_raw_contents
    write_assets
    path = File.join(@work, "smoke", "SmokeApp.AppHost", "obj", "project.assets.json")
    File.write(path, "secret-canary" * 200_000)
    ValidationDiagnostics.collect(@work, @output)
    summary = File.read(File.join(@output, "nuget-summary.json"))
    assert_includes summary, "oversized"
    refute_includes summary, "canary"
    FileUtils.remove_entry(@output)
    File.write(path, '{"broken": "secret-canary"')
    ValidationDiagnostics.collect(@work, @output)
    summary = File.read(File.join(@output, "nuget-summary.json"))
    assert_includes summary, "Could not parse"
    refute_includes summary, "canary"
  end

  def test_summary_is_valid_json_even_when_retention_limit_is_reached
    summaries = Array.new(16) { { "errors" => [{ "message" => "x" * 100_000 }] } }
    ValidationDiagnostics.write_summary(@work, summaries)
    path = File.join(@work, "nuget-summary.json")
    assert_operator File.size(path), :<=, ValidationDiagnostics::TEXT_LIMIT
    assert_includes JSON.parse(File.read(path)).last.fetch("diagnostic"), "truncated"
  end

  def test_watchdog_allows_cleanup_after_a_stuck_collector
    fake_scripts = File.join(@root, "scripts")
    FileUtils.mkdir_p(fake_scripts)
    FileUtils.cp(File.join(SCRIPT_DIR, "validation-support.sh"), fake_scripts)
    File.write(File.join(fake_scripts, "collect-validation-diagnostics.rb"), "sleep 60\n")
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    _, stderr, status = Open3.capture3("bash", "-c", LIFECYCLE, "--", fake_scripts, @work, @output, @brew, FAILURE,
                                       "42")
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert_equal 42, status.exitstatus
    assert_includes stderr, "could not be fully collected"
    assert_operator elapsed, :<, 20
    refute File.exist?(@work)
    assert File.exist?(File.join(@root, "uninstall"))
  end
end
