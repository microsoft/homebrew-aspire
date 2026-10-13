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
cask on macOS Arm64 and Intel with stable and pinned-development Homebrew.
It checks release-template consistency, syntax/style, archive checksums and
online audit, then tests installation, notarization, scaffold/restore and cleanup.

To run the [checks](scripts/validate-cask.sh) locally on macOS with Homebrew and
a .NET 10 SDK:

```bash
ruby scripts/test-cask-consistency.rb
bash scripts/validate-cask.sh
```

Validation uses a temporary Homebrew prefix and does not replace an existing
Aspire installation.

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
