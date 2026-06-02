# Contributing

This repository is a [Homebrew tap](https://docs.brew.sh/Taps) that distributes the
[Aspire CLI](https://aspire.dev/) cask. The cask file (`Casks/a/aspire.rb`) is
**generated** from
[`eng/homebrew/aspire.rb.template`](https://github.com/microsoft/aspire/blob/main/eng/homebrew/aspire.rb.template)
in [`microsoft/aspire`](https://github.com/microsoft/aspire) and is published here
automatically by the Aspire release pipeline.

## Where to file issues and pull requests

Almost everything you might want to change lives in
[`microsoft/aspire`](https://github.com/microsoft/aspire), not here:

- **Bugs in the Aspire CLI itself** — file an issue in
  [`microsoft/aspire`](https://github.com/microsoft/aspire/issues).
- **Changes to how the cask is built** (URLs, SHA handling, install logic,
  post-install steps) — edit
  [`eng/homebrew/aspire.rb.template`](https://github.com/microsoft/aspire/blob/main/eng/homebrew/aspire.rb.template)
  in `microsoft/aspire` and open a PR there. Edits to `Casks/a/aspire.rb` in this
  repo will be overwritten by the next release.
- **Changes to the release/publish pipeline** that pushes new cask versions into this
  tap — also in `microsoft/aspire`.

Pull requests directly against this repo are accepted for things that are genuinely
local to the tap, such as fixes to `README.md`, `SECURITY.md`, `SUPPORT.md`, this file,
or `.gitignore`. For anything else, please open the PR in `microsoft/aspire` instead so
the change survives the next generated publish.

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
