# frozen_string_literal: true

cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.6.0"
  sha256 arm:   "f2dae5ce572f24095cbaba8e9b94fb874aa59c130906defcc5a61dcb37738093",
         intel: "9d7f08b935b8b156da87121dc1222225f04e4488a560f38ad450d5ae12e4e04b"

  url "https://github.com/microsoft/aspire/releases/download/v#{version}/aspire-cli-osx-#{arch}-#{version}.tar.gz",
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
  postflight_steps do
    write_file ".aspire-install.json", "{\"source\":\"brew\"}\n"
  end

  zap trash: "~/.aspire"
end
