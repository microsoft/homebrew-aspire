cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.4.2"
  sha256 arm:   "166b4b1a6662c78095e5431debc133c6eb4dd88d0477125a2d8578f045baae9d",
         intel: "0b33db7244a1ff6c414ba604b447d4110ae13ea433f5efeaf3afe0b6fde02684"

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
