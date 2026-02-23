# typed: false
# frozen_string_literal: true

class Aspire < Formula
  desc "CLI for building production-ready distributed apps with .NET Aspire"
  homepage "https://learn.microsoft.com/dotnet/aspire"
  version "13.2.0-preview.1.26123.7"
  license "MIT"

  on_macos do
    if Hardware::CPU.arm?
      url "https://ci.dot.net/public/aspire/13.2.0-preview.1.26123.7/aspire-cli-osx-arm64-13.2.0-preview.1.26123.7.tar.gz"
      sha256 "126b87b7346bfcf3e287a65dca9bb2497ea472ae314101a087a86e4b77e19a36"
    elsif Hardware::CPU.intel?
      url "https://ci.dot.net/public/aspire/13.2.0-preview.1.26123.7/aspire-cli-osx-x64-13.2.0-preview.1.26123.7.tar.gz"
      sha256 "c4e58d33755395f9a43dc9ac667b0bcb393dd7684a7a45455ebfe1c3dcbe3d82"
    end
  end

  def install
    libexec.install Dir["*"]
    bin.install_symlink libexec/"aspire"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/aspire --version")
  end
end
