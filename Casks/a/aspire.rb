cask "aspire" do
  arch arm: "arm64", intel: "x64"

  version "13.6.2"
  sha256 arm:   "86e2a1a8541129f95eb32b9c77b7dbcbeda5df6cedfa1b2afd3f5560bb780dce",
         intel: "bbe0ad6b877c788bc77f2dd393554ee0518af5dca3be35c02cf75d9f70c52a8a"

  url "https://github.com/microsoft/aspire/releases/download/v#{version}/aspire-cli-osx-#{arch}-#{version}.tar.gz"
  name "Aspire CLI"
  desc "CLI for building observable, production-ready distributed applications"
  homepage "https://aspire.dev/"

  # livecheck drives upstream Homebrew/homebrew-cask's autobump detection —
  # see eng/homebrew/README.md "Submission: upstream autobump".
  livecheck do
    url :url
    strategy :github_latest
  end

  # Aspire CLI is distributed for macOS only via Homebrew cask. Without this,
  # brew test-bot --only-tap-syntax tries to evaluate the cask on Linux too —
  # the arch hash above has no Linux keys, so the cask becomes invalid and the
  # syntax job fails (see Homebrew/homebrew-cask CI: "Invalid cask (Linux on
  # ...)"). See https://docs.brew.sh/Cask-Cookbook#depends_on for the cross-
  # platform / single-platform conventions.
  depends_on :macos

  binary "aspire"

  # The sidecar tells the CLI which install channel placed this binary, so
  # behaviors like self-update can route through `brew` instead of overwriting
  # the cask payload. See docs/specs/install-routes.md.
  postflight_steps do
    write_file ".aspire-install.json", "{\"source\":\"brew\"}\n", base: :staged_path
  end

  # Empty by design. `~/.aspire/` is shared user state across all Aspire CLI
  # install channels (brew cask, winget, dotnet-tool, script install). A brew
  # uninstall must not delete it — that would corrupt a parallel install from
  # another channel. The stanza is present (not omitted) so the
  # Homebrew/homebrew-cask triage workflow does not apply the `missing-zap`
  # label — see Homebrew/homebrew-cask/.github/workflows/triage.yml
  # (`missing_content: zap .+\n`).
  zap trash: []
end
