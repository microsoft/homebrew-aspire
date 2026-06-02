# Aspire CLI Homebrew tap

Official Microsoft-owned Homebrew tap that distributes the
[Aspire CLI](https://aspire.dev/) for macOS.

## Install

```bash
brew install --cask microsoft/aspire/aspire
```

That single command taps `microsoft/homebrew-aspire`, downloads the
signed Aspire CLI macOS archive from the matching GitHub release on
`microsoft/aspire`, and symlinks the `aspire` binary into your
Homebrew prefix.

## Upgrade

```bash
brew upgrade --cask microsoft/aspire/aspire
```

## Uninstall

```bash
brew uninstall --cask microsoft/aspire/aspire
brew untap microsoft/aspire
```

## What this tap ships

`Casks/a/aspire.rb` pins the latest stable Aspire CLI release published
at [`microsoft/aspire` releases](https://github.com/microsoft/aspire/releases).
The cask points at the per-arch `aspire-cli-osx-arm64-<version>.tar.gz`
and `aspire-cli-osx-x64-<version>.tar.gz` archives from that release,
with SHA256 hashes verified at install time.

The cask is generated from
[`eng/homebrew/aspire.rb.template`](https://github.com/microsoft/aspire/blob/main/eng/homebrew/aspire.rb.template)
in the `microsoft/aspire` repo and is published here as part of the
Aspire release pipeline.

## Relationship to `Homebrew/homebrew-cask`

The same cask is also being submitted to
[`Homebrew/homebrew-cask`](https://github.com/Homebrew/homebrew-cask),
which means `brew install --cask aspire` (no tap prefix) will work
once that submission lands. This tap exists as the
canonical Microsoft-owned distribution channel and as a fallback path
that stays available even when upstream review is pending.

## Reporting issues

File issues against the CLI or the cask in
[`microsoft/aspire`](https://github.com/microsoft/aspire/issues),
not against this tap. The tap repo only carries the generated cask;
all CLI code, the cask template, and the release pipeline live in
`microsoft/aspire`.
