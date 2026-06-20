cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.4.6"
  sha256 arm:   "a8c844cca68dc313f313a486ce1f7bbed64070c6717957cbe23653c1b7e33e96",
         intel: "5d2719f19794a9074a5fb0c03986e8ae68cc80192af7004bb955b05ea196d575"

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
