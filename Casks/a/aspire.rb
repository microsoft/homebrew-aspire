cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.4.1"
  sha256 arm:   "0b4e41d1b47d282cc5aacea37b3caedb54ee1a09309a3b0e54b5389a8717f333",
         intel: "915c73aba56ccc54bae193fefe5852131ac0511c1e609062c1879b027b618deb"

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
