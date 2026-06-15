# frozen_string_literal: true

cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.4.4"
  sha256 arm:   "cef5583ee9f88943a5a6dc1a1c6e7f6ca1886d53888fdc0f3ca7903b4c7edd8d",
         intel: "318d7167406be8a0df8e6b9a26e356e3c937ae33a507cb36ef5548d3b21da752"

  url "https://github.com/microsoft/aspire/releases/download/v#{version}-release/microsoft-aspire-cli-osx-#{arch}-#{version}.tgz",
      verified: "github.com/microsoft/aspire/"
  name "Aspire CLI"
  desc "CLI for building observable, production-ready distributed applications"
  homepage "https://aspire.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on :macos

  binary "aspire"

  # Lets the Aspire CLI identify the install source without path heuristics.
  postflight do
    File.write("#{staged_path}/.aspire-install.json", %Q({"source":"brew"}\n))
  end

  zap trash: "~/.aspire"
end
