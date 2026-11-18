# frozen_string_literal: true

# Exercise the comparator's Ruby parsing and release-metadata substitution.
# These standard-library tests need neither Homebrew nor downloaded archives.
require "minitest/autorun"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "check-cask-consistency"

class CaskConsistencyTest < Minitest::Test
  def test_comments_and_layout_do_not_count_as_drift
    original = "cask \"aspire\" do\n  zap trash: []\nend\n"
    formatted = "# frozen_string_literal: true\ncask \"aspire\" do\n\n zap  trash: [] # shared state\nend\n"
    assert CaskConsistency.matches?(original, formatted)
  end

  def test_install_and_uninstall_changes_count_as_drift
    original = 'write_file ".aspire-install.json", "{}", base: :staged_path'
    refute_equal CaskConsistency.tokens(original),
                 CaskConsistency.tokens('write_file ".aspire-install.json", "{}"')
    refute_equal CaskConsistency.tokens("zap trash: []"),
                 CaskConsistency.tokens('zap trash: "~/.aspire"')
  end

  def test_block_comments_do_not_count_as_drift
    original = "cask \"aspire\" do\n  zap trash: []\nend\n"
    documented = "=begin\nShared user state is retained.\n=end\n#{original}"
    assert CaskConsistency.matches?(original, documented)
  end

  def test_block_comment_markers_in_strings_remain_significant
    original = "desc \"=begin\nAspire CLI\n=end\"\n"
    changed = "desc \"=begin\nDifferent CLI\n=end\"\n"
    refute_equal CaskConsistency.tokens(original), CaskConsistency.tokens(changed)
  end

  def test_statement_terminating_newline_counts_as_drift
    refute CaskConsistency.matches?("binary \"aspire\"\n", "binary\n\"aspire\"\n")
  end

  def test_continuations_and_trailing_comments_do_not_count_as_drift
    original = "binary \"aspire\"\n"
    continued = "binary \\\n  \"aspire\" # installed command\n\n"
    assert CaskConsistency.matches?(original, continued)
    assert CaskConsistency.matches?(original, 'binary "aspire"')
  end

  def test_literal_spelling_remains_significant
    refute CaskConsistency.matches?('binary "aspire"', "binary 'aspire'")
    refute CaskConsistency.matches?('desc "Aspire CLI"', 'desc "Aspire  CLI"')
  end

  def test_entry_point_accepts_redundant_powershell_heredoc_quotes
    expected = <<~RUBY
      generated_script "aspire-completion.ps1", content: <<~'POWERSHELL'
        #requires -Version 7.0
        & {
            $completionScript = aspire completions script pwsh | Out-String
            if ($LASTEXITCODE -ne 0) {
                throw 'Aspire could not generate PowerShell completions.'
            }
            Invoke-Expression $completionScript
        }
      POWERSHELL
    RUBY
    actual = expected.sub("<<~'POWERSHELL'", "<<~POWERSHELL")
    assert_entry_point(expected, actual, matches: true)
    assert_entry_point(actual, expected, matches: true)
  end

  def test_entry_point_accepts_plain_heredoc_quote_forms
    quotes = ["'", '"']
    ["<<", "<<-", "<<~"].each do |operator|
      quotes.each do |quote|
        expected = "content = #{operator}#{quote}TEXT#{quote}\nplain text\nTEXT\n"
        actual = "content = #{operator}TEXT\nplain text\nTEXT\n"
        assert_entry_point(expected, actual, matches: true)
      end
    end
    assert_entry_point("content = <<~'TEXT'\nTEXT\n", "content = <<~TEXT\nTEXT\n", matches: true)
  end

  def test_entry_point_preserves_heredoc_escape_and_interpolation_semantics
    delimiters = ["TEXT", '"TEXT"']
    [
      'line\nnext',
      'two\\\\slashes',
      "continued\\\nline",
      "\#{version}",
      '#@version',
      '#$version',
      '\#{version}',
    ].each do |body|
      expected = "content = <<~'TEXT'\n#{body}\nTEXT\n"
      delimiters.each do |delimiter|
        actual = "content = <<~#{delimiter}\n#{body}\nTEXT\n"
        assert_entry_point(expected, actual, matches: false)
        assert_entry_point(actual, expected, matches: false)
      end
    end
  end

  def test_entry_point_preserves_heredoc_body_operator_and_command_changes
    expected = "content = <<~'TEXT'\n  plain\nTEXT\n"
    [
      "content = <<~TEXT\n  changed\nTEXT\n",
      "content = <<-TEXT\n  plain\nTEXT\n",
      "content = <<~`TEXT`\n  plain\nTEXT\n",
    ].each do |actual|
      assert_entry_point(expected, actual, matches: false)
    end
  end

  def test_entry_point_tracks_multiple_and_nested_heredocs
    expected = <<~'RUBY'
      contents = [<<~'TEXT', <<~'TEXT']
        plain
      TEXT
        literal\nescape
      TEXT
      nested = <<~OUTER
        #{<<~'INNER'}
          plain
        INNER
      OUTER
    RUBY
    actual = expected.sub("<<~'TEXT'", "<<~TEXT").sub("<<~'INNER'", "<<~INNER")
    assert_entry_point(expected, actual, matches: true)
    assert_entry_point(expected, actual.sub("<<~'TEXT'", "<<~TEXT"), matches: false)
    expected = <<~'RUBY'
      contents = [<<~'TEXT', <<~'TEXT']
        literal\nescape
      TEXT
        plain
      TEXT
    RUBY
    actual = expected.sub("<<~'TEXT', <<~'TEXT'", "<<~'TEXT', <<~TEXT")
    assert_entry_point(expected, actual, matches: true)
  end

  def test_invalid_ruby_is_an_error
    invalid = 'cask "aspire" do'
    valid = 'binary "aspire"'
    [[invalid, valid], [valid, invalid], [invalid, invalid]].each do |expected, actual|
      error = assert_raises(ArgumentError) { CaskConsistency.matches?(expected, actual) }
      assert_match "Invalid Ruby syntax", error.message
    end
  end

  def test_deprecated_url_metadata_counts_as_drift
    refute_equal CaskConsistency.tokens('url "https://example.com/archive"'),
                 CaskConsistency.tokens('url "https://example.com/archive", verified: "example.com/"')
  end

  def test_string_contents_are_not_normalized
    refute_equal CaskConsistency.tokens('desc "Aspire CLI"'),
                 CaskConsistency.tokens('desc "Aspire  CLI"')
  end

  def test_renders_both_architectures_from_homebrew_metadata
    arm = "a" * 64
    intel = "b" * 64
    metadata = {
      "version"    => "13.6.1",
      "url"        => archive_url("arm64"),
      "sha256"     => arm,
      "variations" => {
        "sequoia"     => { "url" => archive_url("x64"), "sha256" => intel },
        "arm64_linux" => { "sha256" => nil },
      },
    }
    template = "${VERSION} ${SHA256_OSX_ARM64} ${SHA256_OSX_X64}"
    assert_equal "13.6.1 #{arm} #{intel}", CaskConsistency.render(template, metadata)
    metadata["url"] = archive_url("x64")
    metadata["sha256"] = intel
    metadata["variations"] = {
      "arm64_sequoia" => { "url" => archive_url("arm64"), "sha256" => arm },
    }
    assert_equal "13.6.1 #{arm} #{intel}", CaskConsistency.render(template, metadata)
  end

  def test_missing_architecture_is_an_error
    metadata = { "version" => "13.6.1", "url" => archive_url("arm64"), "sha256" => "a" * 64 }
    assert_raises(ArgumentError) { CaskConsistency.render("${VERSION}", metadata) }
  end

  def test_unknown_template_placeholder_is_an_error
    metadata = {
      "version" => "13.6.1", "url" => archive_url("arm64"), "sha256" => "a" * 64,
      "variations" => { "sequoia" => { "url" => archive_url("x64"), "sha256" => "b" * 64 } }
    }
    assert_raises(ArgumentError) { CaskConsistency.render("${UNKNOWN}", metadata) }
  end

  private

  def assert_entry_point(expected, actual, matches:)
    Dir.mktmpdir("cask-consistency-test") do |directory|
      cask, metadata, template = ["cask.rb", "metadata.json", "release.template"].map do |name|
        File.join(directory, name)
      end
      File.write(cask, actual)
      File.write(template, expected)
      File.write(metadata, JSON.generate("casks" => [{
        "version" => "13.6.1", "url" => archive_url("arm64"), "sha256" => "a" * 64,
        "variations" => { "sequoia" => { "url" => archive_url("x64"), "sha256" => "b" * 64 } }
      }]))
      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby, File.expand_path("check-cask-consistency.rb", __dir__), cask, metadata, template
      )
      assert_equal(matches ? 0 : 1, status.exitstatus, "#{expected.inspect}\n#{actual.inspect}\n#{stdout}#{stderr}")
      if matches
        assert_match "Cask matches release template", stdout
        assert_empty stderr
      else
        assert_match "Release-template drift", stderr
      end
    end
  end

  def archive_url(arch)
    "https://github.com/microsoft/aspire/releases/download/v13.6.1/aspire-cli-osx-#{arch}-13.6.1.tar.gz"
  end
end
