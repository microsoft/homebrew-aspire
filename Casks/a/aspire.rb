cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.4.3"
  sha256 arm:   "fcc5516aa148933cee8b842e4d808947393c88d930e534ebb722661ebd50a98a",
         intel: "ffd5d0b92e01440954fc2a4bc3a53fc67db6e83c64986fec8e07fd1f714ed31a"

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
