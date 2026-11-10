# frozen_string_literal: true

require "json"
# macOS system Ruby needs this require even though Homebrew's Ruby does not.
require "pathname" # rubocop:disable Lint/RedundantRequireStatement
require "timeout"
require "uri"

module ValidationDiagnostics
  TEXT_LIMIT = 128 * 1024
  ASSETS_LIMIT = 2 * 1024 * 1024
  ENTRY_LIMIT = 1024
  FILE_LIMIT = 16

  def self.destination(work, destination)
    path = File.join(File.realpath(File.dirname(File.expand_path(destination))), File.basename(destination))
    root = File.realpath(work)
    if path == root || path.start_with?("#{root}/")
      raise ArgumentError, "diagnostics directory must be outside the validation workspace"
    end
    raise ArgumentError, "diagnostics directory must not already exist" if File.exist?(path) || File.symlink?(path)

    path
  end

  def self.redact(text)
    text = text.encode("UTF-8", invalid: :replace, undef: :replace)
    ENV.sort_by { |_, value| -value.length }.each do |key, value|
      next unless key.match?(/token|secret|password|credential|key|connection_?string/i)
      next if value.empty?

      text = text.gsub(value, "[REDACTED]")
    end
    text = text.gsub(%r{https?://[^\s"'<>]+}i) do |url|
      uri = URI.parse(url)
      uri.user = nil
      uri.password = nil
      uri.query = nil
      uri.fragment = nil
      uri.to_s
    rescue URI::InvalidURIError
      "[REDACTED URL]"
    end
    text = text.gsub(/((?:authorization|proxy-authorization)\s*[:=]\s*)[^\r\n]+/i, '\1[REDACTED]')
    text = text.gsub(
      /(["']?(?:[\w.-]*(?:password|passwd|token|secret|credential|key|connection[_-]?string)|sig)
        ["']?\s*[:=]\s*)(?:"[^"]*"|'[^']*'|[^\s,;]+)/ix,
      '\1[REDACTED]',
    )
    text = text.gsub(
      /\b(?:gh[pousr]_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+|
        eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)\b/x,
      "[REDACTED]",
    )
    text.gsub(%r{\e\[[0-?]*[ -/]*[@-~]}, "")
  end

  def self.write(destination, name, text)
    # Redact before limiting so truncation cannot split a recognizable secret.
    safe = redact(text)
    safe = safe.byteslice(0, TEXT_LIMIT).force_encoding("UTF-8").scrub("")
    File.write(File.join(destination, name), safe, mode: "wx", perm: 0600)
  end

  def self.write_summary(destination, summaries)
    truncated = false
    while JSON.generate(summaries).bytesize > TEXT_LIMIT - 1024
      summaries.pop
      truncated = true
    end
    summaries << { "diagnostic" => "Summary truncated to fit retention limit" } if truncated
    File.write(File.join(destination, "nuget-summary.json"), JSON.generate(summaries), mode: "wx", perm: 0600)
  end

  def self.read_regular(path, limit, tail: false)
    return unless File.lstat(path).file?

    File.open(path, File::RDONLY | File::NOFOLLOW | File::NONBLOCK) do |file|
      next unless file.stat.file?
      next if !tail && file.size > limit

      truncated = tail && file.size > limit
      file.seek(-limit, IO::SEEK_END) if truncated
      text = file.read(limit) || +""
      # Never retain a partial first line that may start midway through a secret.
      text = text.sub(/\A[^\n]*(?:\n|\z)/, "") if truncated
      text.force_encoding("UTF-8").scrub
    end
  end

  def self.assets_files(work)
    root = File.join(work, "smoke")
    pending = [root]
    entries = 0
    files = []
    until pending.empty? || entries >= ENTRY_LIMIT || files.length >= FILE_LIMIT
      directory = pending.shift
      next unless File.lstat(directory).directory?

      Dir.each_child(directory) do |name|
        entries += 1
        break if entries > ENTRY_LIMIT

        path = File.join(directory, name)
        stat = File.lstat(path)
        next if stat.symlink?

        if stat.directory?
          pending << path
        elsif name == "project.assets.json" && File.basename(directory) == "obj" && stat.file?
          files << path
          break if files.length >= FILE_LIMIT
        end
      end
    end
    files
  rescue Errno::ENOENT
    files
  end

  def self.collect(work, output)
    Timeout.timeout(5) do
      output = destination(work, output)
      Dir.mkdir(output, 0700)
      %w[smoke-command.log cli-new.log cli-restore.log failed-checks.log load.err].each do |name|
        path = File.join(work, name)
        next unless File.exist?(path)

        text = read_regular(path, TEXT_LIMIT, tail: true)
        write(output, name, text) if text
      end
      summaries = assets_files(work).map do |path|
        text = read_regular(path, ASSETS_LIMIT)
        if text.nil?
          { "file"       => redact(Pathname.new(path).relative_path_from(Pathname.new(work)).to_s),
            "diagnostic" => "Skipped non-regular or oversized assets file" }
        else
          data = JSON.parse(text)
          errors = Array(data["logs"]).select { |entry| entry["level"].to_s.casecmp("error").zero? }
          errors = errors.first(10).map do |entry|
            { "code" => redact(entry["code"].to_s)[0, 128], "message" => redact(entry["message"].to_s)[0, 512] }
          end
          sources = data.dig("project", "restore", "sources").to_h.keys.first(10)
          { "file"    => redact(Pathname.new(path).relative_path_from(Pathname.new(work)).to_s),
            "errors"  => errors,
            "sources" => sources.map { |source| redact(feed_identity(source))[0, 256] } }
        end
      rescue JSON::ParserError, TypeError, NoMethodError
        { "diagnostic" => "Could not parse an assets summary" }
      end
      write_summary(output, summaries)
      warn "Retained failure diagnostics in #{output}"
    end
  end

  def self.feed_identity(source)
    uri = URI.parse(source)
    return "[local or unrecognized feed]" unless %w[http https].include?(uri.scheme)
    return "[local or unrecognized feed]" unless uri.host

    uri.user = nil
    uri.password = nil
    uri.query = nil
    uri.fragment = nil
    uri.to_s
  rescue URI::InvalidURIError
    "[unrecognized feed]"
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    if ARGV.first == "--check-directory"
      puts ValidationDiagnostics.destination(ARGV.fetch(1), ARGV.fetch(2))
    else
      ValidationDiagnostics.collect(ARGV.fetch(0), ARGV.fetch(1))
    end
  rescue => e
    # Do not echo exception messages, which can contain raw JSON or credentials.
    if ARGV.first == "--check-directory"
      warn "Error: --diagnostics-dir must be new, outside the workspace, with an existing parent directory."
    else
      warn "Warning: diagnostics collection failed (#{e.class})."
    end
    exit 1
  end
end
