# frozen_string_literal: true

cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.5.4"
  sha256 arm:   "641e1eaec4ef0575acbedbadc7d7b36094b278dc37ebf9ddb5bebf18927c3409",
         intel: "65faf9da2dcd579e619f8301b90c2a8432a49a368c75ea39d204aa66869787da"

  url "https://github.com/microsoft/aspire/releases/download/v#{version}/aspire-cli-osx-#{arch}-#{version}.tar.gz"
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
