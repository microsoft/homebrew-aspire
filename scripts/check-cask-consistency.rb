# frozen_string_literal: true

require "json"
require "ripper"

module CaskConsistency
  def self.tokens(source)
    Ripper.lex(source).each_with_object([]) do |(_, type, text, _), tokens|
      tokens << [type, text] unless [:on_sp, :on_nl, :on_ignored_nl, :on_comment].include?(type)
    end
  end

  def self.render(template, metadata)
    version = metadata.fetch("version")
    raise ArgumentError, "Invalid release version: #{version.inspect}" unless version.match?(/\A\d+\.\d+\.\d+(?:[-.][a-zA-Z0-9.-]+)?\z/)

    replacements = { "VERSION" => version }
    variants = [metadata] + metadata.fetch("variations", {}).values.map { |value| metadata.merge(value) }
    { "ARM64" => "arm64", "X64" => "x64" }.each do |key, arch|
      url = "https://github.com/microsoft/aspire/releases/download/v#{version}/aspire-cli-osx-#{arch}-#{version}.tar.gz"
      hashes = variants.each_with_object([]) do |variant, results|
        results << variant["sha256"] if variant["url"] == url && variant["sha256"]
      end.uniq
      if hashes.length != 1 || !hashes.first.match?(/\A[0-9a-f]{64}\z/)
        raise ArgumentError, "Missing or conflicting macOS #{arch} SHA256 in Homebrew metadata"
      end

      replacements["SHA256_OSX_#{key}"] = hashes.first
    end
    template.gsub(/\$\{([^}]+)\}/) do
      replacements.fetch(Regexp.last_match(1)) do |key|
        raise ArgumentError, "Unknown release-template placeholder: #{key}"
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  abort "Usage: ruby #{$PROGRAM_NAME} CASK METADATA_JSON TEMPLATE" if ARGV.length != 3
  cask_path, metadata_path, template_path = ARGV
  metadata = JSON.parse(File.read(metadata_path)).fetch("casks").fetch(0)
  expected = CaskConsistency.tokens(CaskConsistency.render(File.read(template_path), metadata))
  actual = CaskConsistency.tokens(File.read(cask_path))
  if actual != expected
    warn "Release-template drift: #{cask_path} does not match microsoft/aspire v#{metadata.fetch("version")}."
    warn "Comparison ignores Ruby comments, whitespace and line breaks, but preserves strings and DSL arguments."
    warn "Expected: #{expected.map(&:last).join(" ")}"
    warn "Actual:   #{actual.map(&:last).join(" ")}"
    exit 1
  end
  puts "Cask matches release template (ignoring comments and layout)."
end
