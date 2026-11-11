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
diagnostics_parent="$(mktemp -d)"
bash scripts/validate-cask.sh --diagnostics-dir "$diagnostics_parent/aspire-validation-diagnostics"
```

Validation uses a temporary Homebrew prefix and does not replace an existing
Aspire installation.

The optional `--diagnostics-dir` must name a **new directory** whose parent exists,
outside the temporary validation workspace. The validator creates it with
owner-only access (0700), independent of the caller's umask, and rejects existing
paths without changing their permissions. The CLI writes raw trace logs
(`cli-new.log` and `cli-restore.log`) **directly** to that directory. Each log
exists only if its corresponding CLI command ran; an earlier failure may leave
one or neither log. Logs already written to the diagnostics directory remain
available even if the exit handler cannot run. On failure, the exit handler
attempts to copy each smoke project's `obj/project.assets.json`, unchanged,
preserving project-relative paths under `smoke/`. Copying can fail and leave
partial diagnostics. No assets are copied on success.

These diagnostics are **unredacted** and may contain sensitive data. The public
tap validation workflow does **not** upload diagnostics artifacts. Internal
consumers, including Aspire pipelines, control whether to retain or upload the
raw diagnostics and must restrict access appropriately. Inspect diagnostics
before sharing and delete them when no longer needed.

Without `--diagnostics-dir`, logs are written inside the disposable workspace
and no diagnostics are retained. When the exit handler runs, it attempts to
uninstall the isolated CLI and remove the workspace on success, failure and
handled interrupts. Forced termination such as SIGKILL prevents the handler
from running, so neither failure-asset copying nor cleanup can occur through
that handler. The handler preserves the original validation failure status
even if copying assets or cleanup fails; a copy failure reports a warning.

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
