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
or `.gitignore`, and tap-local validation scripts and workflows. For anything else,
please open the PR in `microsoft/aspire` instead so
the change survives the next generated publish.

## Pull request validation

The `Validate Homebrew tap` workflow runs **only on pull requests**, on macOS 15
Arm64 and Intel runners with both Homebrew 7.0.9 (stable) and a pinned
[Homebrew development commit](https://github.com/Homebrew/brew/tree/eb56e2b1f748e63d02be18a7660eec4e4cf32af1).
It validates the actual checked-out `Casks/a/aspire.rb`, not a freshly generated
replacement:

- Loads the cask and fails on reported Homebrew deprecations.
- Compares it with the template from the matching `microsoft/aspire` release tag.
  Version and both architecture checksums are substituted from Homebrew metadata.
  Ruby comments, whitespace and line breaks are ignored; string contents and DSL
  arguments (including install steps and zap targets) must match.
- Runs `brew style` without auto-fixing and `brew audit --cask --online`.
- Runs `brew test-bot --only-tap-syntax`, including `readall` across all OS and
  architecture combinations, and fetches both macOS archives with checksum checks.
- Installs the released archive, checks the exact CLI version and the
  `{"source":"brew"}` sidecar beside the payload, verifies notarization, and
  exercises `aspire new` and `aspire restore` with a .NET 10 SDK.
- Uninstalls and checks that the payload, sidecar and binary link are removed,
  then uses Homebrew's before/after snapshot check for leftover apps and services.

Each run fetches its pinned Homebrew ref into a unique repository-local prefix
with its own tap, cache and download directory. The installed Homebrew is used
only to locate an optional existing `homebrew-core` checkout. Validation invokes
only the isolated prefix's Aspire binary and uses a separate home for CLI state.
It does not replace or uninstall any existing Aspire installation, and never
uses `--zap`. Cleanup runs on failure too. Both architectures are installed in
CI; a local run exercises the host architecture.
The isolated prefix clones or taps the official `homebrew/core` tap if needed,
then trusts it to obtain Homebrew's style tools; its trust settings cannot
modify the caller's Homebrew configuration. The validator copies the checked-out
scripts, workflow and contribution guide into the cloned tap so tap-wide style
checks see local changes. It rejects any style command that changes that
isolated copy.
Network access is required for the tagged template, Homebrew tooling and release
archive. These checks neither repair the cask nor change the release pipeline.

On macOS with Homebrew and a .NET 10 SDK installed:

```bash
ruby scripts/test-cask-consistency.rb
bash scripts/validate-cask.sh
```

Use `--cask-file /absolute/path/to/aspire.rb` to validate a separate candidate.
Use `--checks-only` to omit installation explicitly; this is not full validation
and is not used in CI. Structural failures are reported before installation.
Local validation defaults to Homebrew 7.0.9; set `HOMEBREW_VALIDATION_REF`
to a semantic-version tag or 40-character commit SHA to use a different version
in the isolated prefix. Homebrew's `cask-ci snapshot` needs passwordless `sudo`
to inspect launchd services: local runs report an explicit warning and omit
snapshot/check if unavailable, while CI fails instead of silently skipping it.
Template drift must be reconciled with the upstream release template rather than
hidden by automatic style fixes or weaker checks.

### Coverage compared with upstream validation

The tap combines the applicable checks from
[`Homebrew/homebrew-cask` CI](https://github.com/Homebrew/homebrew-cask/blob/31cca0997fd2bcebfeb82b3314d228952a9efd4c/.github/workflows/ci.yml)
and Aspire's
[`validate-cask-artifact.sh`](https://github.com/microsoft/aspire/blob/266483abe1a335e371672fba0eba32dfa542fd02/eng/homebrew/validate-cask-artifact.sh),
[`homebrew-validate-release.yml`](https://github.com/microsoft/aspire/blob/266483abe1a335e371672fba0eba32dfa542fd02/.github/workflows/homebrew-validate-release.yml)
and
[`prepare-installer-artifacts.yml`](https://github.com/microsoft/aspire/blob/266483abe1a335e371672fba0eba32dfa542fd02/.github/workflows/prepare-installer-artifacts.yml).
Homebrew helper behavior was checked at
[`Homebrew/brew` eb56e2b](https://github.com/Homebrew/brew/tree/eb56e2b1f748e63d02be18a7660eec4e4cf32af1/Library/Homebrew).

| Check | Tap coverage / deliberate difference |
| --- | --- |
| Syntax and style | Homebrew tap-syntax checks and explicit non-mutating cask style; no `--fix` copy-back. |
| Live release audit | `--online`, as for an existing upstream cask; `--new` is for first submissions, not this published cask. |
| Fetch and integrity | Both architecture archives fetched and SHA256-checked on every runner. |
| Install and uninstall | Real released archive, with CLI version, sidecar and path cleanup assertions added. |
| Signing | Explicit notarization check; Homebrew's signing audit is restricted to the official cask tap. |
| Installed CLI smoke | Scaffold a starter and restore it, using published packages rather than build-artifact overrides. |
| Apps/services left behind | Homebrew `cask-ci snapshot` / `check`, without machine-wide cleanup. |
| Architecture coverage | Arm64 and Intel both execute locally on matching CI runners; downloading both is not execution coverage. |
| Current tap vs release template | Additional drift and deprecation gates absent from generated-artifact validation. |

Homebrew's conflict/dependency removal and `--force --zap` pre-cleanup are not
copied: an isolated prefix starts empty and must not alter the developer's
installations or shared state. Its advisory missing-zap scan is not a gate here:
the release template intentionally retains shared Aspire user state. Aspire's
prepublication archive rewriting and same-build NuGet overrides test unpublished
builds, not this live-release tap, so the validator preserves the checked-out
release URLs. No new-cask submission, publishing or production cleanup runs.
Homebrew's stable-brew syntax job is a compatibility lane; this workflow exercises
both stable and pinned development Homebrew on each architecture without modifying
the runner's installed Homebrew.

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
