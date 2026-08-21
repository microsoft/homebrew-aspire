cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.5.1"
  sha256 arm:   "af08edeca8cd00723e08e172efd8725b11badad4a56b7b675e0c148789e0795e",
         intel: "0cf6e86c74a7abec014bb25d9db4ee60c76f4bfe45250c0960f81d29380e96b3"

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
