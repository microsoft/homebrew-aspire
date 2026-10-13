# frozen_string_literal: true

cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.6.1"
  sha256 arm:   "23f4946aae59ad55bd9c651ab617ec127b02bedc5fa1c1f38c850d7e6843340b",
         intel: "9950ab666edf0d7dd92c4e162c2e2aaeb2117a4160fa7f97fb6414f82e3a648e"

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
    write_file ".aspire-install.json", "{\"source\":\"brew\"}\n", base: :staged_path
  end

  zap trash: []
end
