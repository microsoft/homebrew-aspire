# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "collect-validation-diagnostics"

class ValidationDiagnosticsTest < Minitest::Test
  SCRIPT_DIR = File.expand_path(__dir__).freeze
  FAILURE = "NU1105: 'auto' is not a valid version string"

  def setup
    @root = Dir.mktmpdir("validation-diagnostics")
    @work = File.join(@root, "work")
    @output = File.join(@root, "diagnostics")
    FileUtils.mkdir_p(@work)
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def write_assets(data)
    directory = File.join(@work, "smoke", "SmokeApp.AppHost", "obj")
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, "project.assets.json"), JSON.generate(data))
  end

  def test_collects_redacted_trace_and_restore_errors_without_other_data
    File.write(File.join(@work, "cli-restore.log"), "error MSB4181\nAuthorization: Bearer bearer-canary\n")
    write_assets("logs"      => [
                   { "level" => "Error", "code" => "NU1105", "message" => FAILURE, "extra" => "extra-canary" },
                   { "level" => "Warning", "message" => "warning-canary" },
                 ],
                 "libraries" => { "library-canary" => {} })
    File.write(File.join(@work, "cache"), "cache-canary")
    ValidationDiagnostics.collect(@work, @output)

    assert_equal %w[cli-restore.log nuget-summary.json], Dir.children(@output).sort
    retained = Dir.children(@output).map { |name| File.read(File.join(@output, name)) }.join
    refute_match(/canary/, retained)
    assert_includes retained, "error MSB4181"
    error = JSON.parse(File.read(File.join(@output, "nuget-summary.json"))).fetch(0).fetch("errors").fetch(0)
    assert_equal({ "code" => "NU1105", "message" => FAILURE }, error)
  end

  def test_validator_collects_before_removing_workspace_and_preserves_failure
    tools = File.join(@root, "tools")
    FileUtils.mkdir_p(tools)
    { "uname" => "echo Darwin",
      "brew"  => "echo '#{@root}/source'",
      "git"   => <<~BASH }.each do |name, body|
        work="$(dirname "${@: -1}")"
        mkdir -p "$work/smoke/SmokeApp.AppHost/obj"
        printf 'trace before cleanup\\n' >"$work/cli-restore.log"
        printf '%s\\n' '{"logs":[{"level":"Error","code":"NU1105","message":"invalid version"}]}' >"$work/smoke/SmokeApp.AppHost/obj/project.assets.json"
        printf '%s\\n' "$work" >'#{@root}/workspace'
        exit 37
      BASH
      path = File.join(tools, name)
      File.write(path, "#!/usr/bin/env bash\n#{body}\n")
      FileUtils.chmod(0700, path)
    end
    _, stderr, status = Open3.capture3(
      { "PATH" => "#{tools}:#{ENV.fetch("PATH")}" },
      "bash", File.join(SCRIPT_DIR, "validate-cask.sh"), "--diagnostics-dir", @output
    )
    assert_equal 37, status.exitstatus, stderr
    refute File.exist?(File.read(File.join(@root, "workspace")).strip)
    assert_includes File.read(File.join(@output, "cli-restore.log")), "trace before cleanup"
    error = JSON.parse(File.read(File.join(@output, "nuget-summary.json"))).fetch(0).fetch("errors").fetch(0)
    assert_equal "NU1105", error.fetch("code")
  end

  def test_rejects_destinations_inside_workspace_or_that_already_exist
    assert_raises(ArgumentError) { ValidationDiagnostics.destination(@work, File.join(@work, "diagnostics")) }
    File.symlink(@work, File.join(@root, "alias"))
    assert_raises(ArgumentError) do
      ValidationDiagnostics.destination(@work, File.join(@root, "alias", "diagnostics"))
    end
    File.write(@output, "existing file")
    assert_raises(ArgumentError) { ValidationDiagnostics.collect(@work, @output) }
    assert_equal "existing file", File.read(@output)
  end

  def test_redacts_sensitive_environment_values_and_url_credentials
    old_secret = ENV.fetch("DIAGNOSTIC_TEST_SECRET", nil)
    ENV["DIAGNOSTIC_TEST_SECRET"] = "env-canary"
    File.write(File.join(@work, "cli-new.log"),
               "env-canary https://user-canary:pass-canary@example.com/feed?token=query-canary\n")
    ValidationDiagnostics.collect(@work, @output)
    refute_match(/canary/, File.read(File.join(@output, "cli-new.log")))
  ensure
    old_secret ? ENV["DIAGNOSTIC_TEST_SECRET"] = old_secret : ENV.delete("DIAGNOSTIC_TEST_SECRET")
  end

  def assert_retained_redactions(cases)
    %w[cli-new.log cli-restore.log].each do |name|
      File.write(File.join(@work, name), cases.map(&:first).join)
    end
    write_assets("logs" => cases.map do |input, _|
      { "level" => "Error", "code" => "NU1105", "message" => input }
    end)
    ValidationDiagnostics.collect(@work, @output)

    %w[cli-new.log cli-restore.log].each do |name|
      retained = File.read(File.join(@output, name))
      assert_equal cases.map(&:last).join, retained
      refute_match(/canary/, retained)
    end
    summary = JSON.parse(File.read(File.join(@output, "nuget-summary.json")))
    messages = summary.fetch(0).fetch("errors").map { |error| error.fetch("message") }
    assert_equal cases.map(&:last), messages
    refute_match(/canary/, messages.join)
  end

  def test_removes_ansi_sequences_before_redacting_retained_credentials
    assert_retained_redactions([
      ["\e[36mPassword:\e[0m ansi-canary\n", "Password: [REDACTED]\n"],
      ["\e[32mProxy-Authorization:\e[0m Bearer ansi-proxy-canary\n", "Proxy-Authorization: [REDACTED]\n"],
    ])
  end

  def test_redacts_quoted_and_plain_authorization_without_crossing_lines
    assert_retained_redactions([
      ["{\"Authorization\":\"Bearer opaque-canary\"}\n", "{\"Authorization\":[REDACTED]\n"],
      ["{\"Proxy-Authorization\":\"Basic proxy-canary\"}\n", "{\"Proxy-Authorization\":[REDACTED]\n"],
      ["'Authorization': 'Bearer single-canary'\n", "'Authorization': [REDACTED]\n"],
      ["'Proxy-Authorization' = 'Basic single-proxy-canary'\n", "'Proxy-Authorization' = [REDACTED]\n"],
      ["aUtHoRiZaTiOn: Bearer plain-canary\n", "aUtHoRiZaTiOn: [REDACTED]\n"],
      ["pRoXy-AuThOrIzAtIoN=Basic plain-proxy-canary\r\n", "pRoXy-AuThOrIzAtIoN=[REDACTED]\r\n"],
      ["\"Authorization\":\r\nnext-line-marker\n", "\"Authorization\":\r\nnext-line-marker\n"],
      ["Proxy-Authorization:\nnext-line-marker\n", "Proxy-Authorization:\nnext-line-marker\n"],
      ["Authorization\r\n=next-line-marker\n", "Authorization\r\n=next-line-marker\n"],
    ])
  end

  def test_redacts_space_containing_credentials_to_delimiters_or_line_end
    assert_retained_redactions([
      ["Password=first-canary second-canary;\n", "Password=[REDACTED];\n"],
      ["Password=ambiguous-canary followed by diagnostic prose\n", "Password=[REDACTED]\n"],
      ["Password=\"quoted-canary with spaces\";Host=example\n", "Password=[REDACTED];Host=example\n"],
      ["Password='single-canary with spaces',Host=example\r\n", "Password=[REDACTED],Host=example\r\n"],
      ["Password=\nnext-line-marker\n", "Password=\nnext-line-marker\n"],
      ["Password:\r\nnext-line-marker\r\n", "Password:\r\nnext-line-marker\r\n"],
      ["Password\r\n=next-line-marker\n", "Password\r\n=next-line-marker\n"],
      ["Password=cr-canary words\rnext-line-marker\r", "Password=[REDACTED]\rnext-line-marker\r"],
      ["Password=lf-canary words\nnext-line-marker\n", "Password=[REDACTED]\nnext-line-marker\n"],
      ["Password=comma-canary words,Host=example;\n", "Password=[REDACTED],Host=example;\n"],
    ])
  end

  def test_reports_malformed_assets_without_retaining_contents
    write_assets({})
    path = File.join(@work, "smoke", "SmokeApp.AppHost", "obj", "project.assets.json")
    File.write(path, '{"broken": "secret-canary"')
    ValidationDiagnostics.collect(@work, @output)
    summary = File.read(File.join(@output, "nuget-summary.json"))
    assert_includes summary, "Could not parse"
    refute_includes summary, "canary"
  end

  def test_bounds_and_skips_symlinked_or_oversized_inputs
    File.write(File.join(@work, "cli-new.log"), "#{"x" * 200_000}\n#{FAILURE}\n")
    File.symlink("/dev/zero", File.join(@work, "cli-restore.log"))
    write_assets({})
    path = File.join(@work, "smoke", "SmokeApp.AppHost", "obj", "project.assets.json")
    File.write(path, "secret-canary" * 200_000)
    ValidationDiagnostics.collect(@work, @output)
    assert_operator File.size(File.join(@output, "cli-new.log")), :<=, ValidationDiagnostics::TEXT_LIMIT
    assert_includes File.read(File.join(@output, "cli-new.log")), FAILURE
    refute File.exist?(File.join(@output, "cli-restore.log"))
    summary = File.read(File.join(@output, "nuget-summary.json"))
    assert_includes summary, "oversized"
    refute_includes summary, "canary"
  end
end
