cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.4.5"
  sha256 arm:   "b8700cf7147e2cc670bbf3a9bdaf25549baae5d5fe97de88fe4ebed6a3e29716",
         intel: "f25dcb6a4c813936ea1deb23ecdbcc9f1b032a2fedc15fbe12d702508c5d209f"

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
