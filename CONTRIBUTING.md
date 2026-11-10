# Contributing

This repository is a [Homebrew tap](https://docs.brew.sh/Taps) that distributes the
[Aspire CLI](https://aspire.dev/) cask. The cask file (`Casks/a/aspire.rb`) is
**generated** from
[`eng/homebrew/aspire.rb.template`](https://github.com/microsoft/aspire/blob/main/eng/homebrew/aspire.rb.template)
in [`microsoft/aspire`](https://github.com/microsoft/aspire) and is published here
automatically by the Aspire release pipeline.

## Where to file issues and pull requests

Please file issues and submit contributions in
[`microsoft/aspire`](https://github.com/microsoft/aspire), not directly in this tap.

The Aspire build and release pipeline generates the cask and sends updates to
this repository. For cask changes (URLs, checksums, install steps or zap targets),
edit
[`eng/homebrew/aspire.rb.template`](https://github.com/microsoft/aspire/blob/main/eng/homebrew/aspire.rb.template)
and open the pull request in `microsoft/aspire`. Direct edits to
`Casks/a/aspire.rb` here will be overwritten by a generated update.

## Pull request validation

The [validation workflow](.github/workflows/validate-tap.yml) checks the shipped
cask on macOS Arm64 and Intel with Homebrew 7.0.9.
It checks release-template consistency, syntax/style, archive checksums and
online audit, then tests installation, notarization, scaffold/restore and cleanup.

To run the [checks](scripts/validate-cask.sh) locally on macOS with Homebrew and
a .NET 10 SDK:

```bash
ruby scripts/test-cask-consistency.rb
ruby scripts/test-validation-diagnostics.rb
bash scripts/validate-cask.sh --diagnostics-dir /tmp/aspire-validation-diagnostics
```

Validation uses a temporary Homebrew prefix and does not replace an existing
Aspire installation.

The optional `--diagnostics-dir` must name a **new directory** whose parent exists,
outside the temporary validation workspace. On failure, the validator collects
diagnostics there before uninstalling and removing its workspace. The original
failure status is preserved even if collection or cleanup fails. Successful runs
do not create the diagnostics directory.

Retention is restricted to smoke-command output, the two explicitly selected CLI
trace logs, failed structural-check output, cask-loading stderr, and a summary of
NuGet error entries and feed identities from the smoke project's
`obj/project.assets.json` files. It does not copy HOME, caches, NuGet configuration,
or whole assets files. Each text artifact is limited to 128 KiB; assets discovery
is limited to 1,024 entries and 16 files of at most 2 MiB each. Collection has a
5-second budget and an independent 10-second watchdog.
Environment values named like secrets, common credential assignments, authorization
headers, and URL userinfo/query/fragment components are redacted. Redaction is
best-effort: inspect logs before sharing, and do not pass secrets as arbitrary
unlabelled command output or URL path segments. CI uploads these failure artifacts
separately for each architecture with seven-day retention.

## Contributor License Agreement

This project welcomes contributions and suggestions. Most contributions require you to
agree to a Contributor License Agreement (CLA) declaring that you have the right to,
and actually do, grant us the rights to use your contribution. For details, visit
<https://cla.opensource.microsoft.com>.

When you submit a pull request, a CLA bot will automatically determine whether you need
to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply
follow the instructions provided by the bot. You will only need to do this once across
all repos using our CLA.

## Code of Conduct

This project has adopted the
[Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the
[Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional
questions or comments.
