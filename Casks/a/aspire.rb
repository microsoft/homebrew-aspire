cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.5.3"
  sha256 arm:   "6eb3622513082a32c6b1e2c8cc9f8137dbfdf57c78b72df15a6f9ad674646b65",
         intel: "daeaf04d52cc05e84de624cf727a0d19d595bd8a6855cae2af619f3ddd8b0eba"

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
