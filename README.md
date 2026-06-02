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

## Reporting security issues

**Do not report security vulnerabilities through public GitHub issues.**
See [SECURITY.md](./SECURITY.md) for the security reporting process.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for how to contribute and the
Contributor License Agreement, and [SUPPORT.md](./SUPPORT.md) for where
to get help.

## Code of Conduct

This project has adopted the
[Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the
[Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any
additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or
services. Authorized use of Microsoft trademarks or logos is subject to
and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project
must not cause confusion or imply Microsoft sponsorship. Any use of
third-party trademarks or logos are subject to those third-party's policies.
