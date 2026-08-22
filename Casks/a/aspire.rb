# frozen_string_literal: true

cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.5.2"
  sha256 arm:   "32ee8a224a52cd79b1174839b41939eaf2ce0090dcd62d37ab9f0b4897e5260e",
         intel: "89f0a7453c2859d467233d01f12caf61e73fb9bbe14360837e7efacdeb06ed5a"

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
  postflight do
    File.write("#{staged_path}/.aspire-install.json", %Q({"source":"brew"}\n))
  end

  zap trash: "~/.aspire"
end
