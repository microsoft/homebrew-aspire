cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.5.0"
  sha256 arm:   "a51b9686996b179a066a8651ef57e3db82621e3abafc8ae8b2fd61f663c025e5",
         intel: "47facdec75d143e3ba651d6c99bcb1aca6452b7ac6ab916a3441eec5dac9d7d1"

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
