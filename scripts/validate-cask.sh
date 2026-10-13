#!/usr/bin/env bash
# Validate the checked-out cask against its release template and Homebrew gates,
# then smoke-test the released CLI in an isolated prefix and clean it up.
# --checks-only runs structural checks without installing the CLI.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cask_file="${script_dir}/../Casks/a/aspire.rb"
checks_only=false
while [[ $# -gt 0 ]]
do
  case "$1" in
    --cask-file)
      [[ $# -ge 2 ]] || {
        echo "Error: --cask-file requires a path." >&2
        exit 1
      }
      cask_file="$2"
      shift 2
      ;;
    --checks-only)
      checks_only=true
      shift
      ;;
    *)
      echo "Usage: bash $0 [--cask-file PATH] [--checks-only]" >&2
      exit 1
      ;;
  esac
done
host_os="$(uname -s)"
[[ "${host_os}" == Darwin ]] || {
  echo "Error: macOS is required." >&2
  exit 1
}
[[ -f "${cask_file}" ]] || {
  echo "Error: cask not found: ${cask_file}" >&2
  exit 1
}
command -v brew >/dev/null || {
  echo "Error: Homebrew is required." >&2
  exit 1
}

validation_ref="${HOMEBREW_VALIDATION_REF:-7.0.9}"
[[ "${validation_ref}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || "${validation_ref}" =~ ^[0-9a-fA-F]{40}$ ]] || {
  echo "Error: HOMEBREW_VALIDATION_REF must be a semantic version tag or 40-character commit SHA." >&2
  exit 1
}
source_repository="$(brew --repository)"
work="${script_dir}/../.aspire-tap-validation.$$.${RANDOM}"
mkdir "${work}"
prefix="${work}/homebrew"
brew_command="${prefix}/bin/brew"
reference="validation/aspire/aspire"
install_attempted=false
export HOME="${work}/home" DOTNET_CLI_HOME="${work}/home"
export XDG_CONFIG_HOME="${work}/home/.config"
export NUGET_PACKAGES="${work}/nuget"
mkdir -p "${HOME}"

cleanup() {
  local status=$?
  trap - EXIT
  if [[ "${install_attempted}" == true ]]
  then
    if ! "${brew_command}" uninstall --cask "${reference}"
    then
      echo "Error: cleanup uninstall failed in isolated prefix ${prefix}." >&2
      status=1
    fi
  fi
  if ! rm -rf -- "${work}"
  then
    echo "Error: could not remove validation directory ${work}." >&2
    status=1
  fi
  exit "${status}"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# A separate brew executable determines a separate prefix; fetch the chosen
# version only into that prefix, never into the caller's Homebrew installation.
git --no-pager clone --quiet --filter=blob:none \
  https://github.com/Homebrew/brew.git "${prefix}"
git --no-pager -C "${prefix}" checkout --quiet --detach "${validation_ref}"
if [[ -d "${source_repository}/Library/Taps/homebrew/homebrew-core/.git" ]]
then
  mkdir -p "${prefix}/Library/Taps/homebrew"
  git --no-pager clone --quiet --shared \
    "${source_repository}/Library/Taps/homebrew/homebrew-core" \
    "${prefix}/Library/Taps/homebrew/homebrew-core"
fi
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_INSTALL_FROM_API=1
export HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1
export HOMEBREW_TEMP="${work}/downloads" HOMEBREW_CACHE="${work}/cache"
export HOMEBREW_LOGS="${work}/logs"
mkdir -p "${HOMEBREW_TEMP}" "${HOMEBREW_CACHE}" "${HOMEBREW_LOGS}"
actual_prefix="$("${brew_command}" --prefix)"
[[ "${actual_prefix}" -ef "${prefix}" ]] || {
  echo "Error: Homebrew prefix is not isolated." >&2
  exit 1
}
echo "Isolated Homebrew prefix: ${actual_prefix}"
"${brew_command}" --version
if [[ ! -d "${prefix}/Library/Taps/homebrew/homebrew-core/.git" ]]
then
  "${brew_command}" tap --force homebrew/core
fi

tap_root="${prefix}/Library/Taps/validation/homebrew-aspire"
# Reuse this checkout's history without creating a commit or updating the
# original repository.
mkdir -p "$(dirname "${tap_root}")"
git --no-pager clone --quiet --shared "${script_dir}/.." "${tap_root}"
cp "${cask_file}" "${tap_root}/Casks/a/aspire.rb"
cp "${script_dir}/check-cask-consistency.rb" \
  "${script_dir}/test-cask-consistency.rb" \
  "${script_dir}/validate-cask.sh" "${tap_root}/scripts/"
cp "${script_dir}/../.github/workflows/validate-tap.yml" "${tap_root}/.github/workflows/"
cp "${script_dir}/../CONTRIBUTING.md" "${tap_root}/CONTRIBUTING.md"
tap_files=(
  "${tap_root}/Casks/a/aspire.rb"
  "${tap_root}/scripts/check-cask-consistency.rb"
  "${tap_root}/scripts/test-cask-consistency.rb"
  "${tap_root}/scripts/validate-cask.sh"
  "${tap_root}/.github/workflows/validate-tap.yml"
  "${tap_root}/CONTRIBUTING.md"
)
mkdir -p "${work}/tap-before"
for index in "${!tap_files[@]}"
do
  cp "${tap_files[index]}" "${work}/tap-before/${index}"
done
"${brew_command}" trust --tap homebrew/core
"${brew_command}" trust --tap validation/aspire

failed=false
run_check() {
  local name="$1"
  shift
  echo "Checking ${name}..."
  if "$@" >"${work}/check.out" 2>"${work}/check.err"
  then
    :
  else
    echo "Error: ${name} failed." >&2
    failed=true
  fi
  cat "${work}/check.out" "${work}/check.err"
  if grep -Ei 'deprecated|deprecation' "${work}/check.err"
  then
    echo "Error: ${name} reported a deprecation." >&2
    failed=true
  fi
}

# Keep JSON separate from diagnostics so a successful load cannot hide a
# deprecation, and report drift even when another structural check fails.
echo "Loading checked-out cask..."
if ! "${brew_command}" info --cask --json=v2 --variations "${reference}" >"${work}/cask.json" 2>"${work}/load.err"
then
  cat "${work}/load.err" >&2
  echo "Error: cask loading failed." >&2
  exit 1
fi
cat "${work}/load.err"
if grep -Ei 'deprecated|deprecation' "${work}/load.err"
then
  echo "Error: cask loading reported a deprecation." >&2
  failed=true
fi
version="$("${brew_command}" ruby -rjson -e 'print JSON.parse(File.read(ARGV.fetch(0))).fetch("casks").fetch(0).fetch("version")' -- "${work}/cask.json")"
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][a-zA-Z0-9.-]+)?$ ]] || {
  echo "Error: invalid cask release version: ${version}" >&2
  exit 1
}
curl --fail --silent --show-error --location --retry 3 \
  "https://raw.githubusercontent.com/microsoft/aspire/v${version}/eng/homebrew/aspire.rb.template" \
  --output "${work}/release.template"
run_check "release-template consistency" "${brew_command}" ruby \
  "${script_dir}/check-cask-consistency.rb" -- "${tap_root}/Casks/a/aspire.rb" "${work}/cask.json" "${work}/release.template"
run_check "Homebrew style (no auto-fix)" "${brew_command}" style --cask "${reference}"
run_check "Homebrew tap-wide style" "${brew_command}" style validation/aspire
run_check "Homebrew all-platform syntax" env -u HOMEBREW_SORBET_RECURSIVE \
  "${brew_command}" readall --aliases --os=all --arch=all validation/aspire
run_check "Homebrew tap audit" env -u HOMEBREW_SORBET_RECURSIVE \
  "${brew_command}" audit --except=installed --tap=validation/aspire
for index in "${!tap_files[@]}"
do
  if ! cmp -s "${tap_files[index]}" "${work}/tap-before/${index}"
  then
    echo "Error: Homebrew style modified ${tap_files[index]} in the isolated tap." >&2
    failed=true
  fi
done
run_check "both macOS archive checksums" "${brew_command}" fetch --cask --retry --arch=all "${reference}"
run_check "Homebrew audit" "${brew_command}" audit --cask --online "${reference}"
[[ "${failed}" == false ]] || {
  echo "Error: cask checks failed; installation was not attempted." >&2
  exit 1
}
if [[ "${checks_only}" == true ]]
then
  echo "Structural checks passed; install/uninstall explicitly omitted (--checks-only)."
  exit 0
fi

# Keep CLI first-run state separate too. Never use PATH to resolve Aspire.
export ASPIRE_CLI_TELEMETRY_OPTOUT=1
command -v dotnet >/dev/null || {
  echo "Error: .NET SDK is required for new/restore smoke validation." >&2
  exit 1
}
dotnet --version
env CI=1 GITHUB_ENV="${work}/ci.env" GITHUB_OUTPUT="${work}/ci.out" \
  "${brew_command}" cask-ci info "${reference}"
snapshot_available=true
if ! sudo -n true 2>/dev/null
then
  if [[ -n "${CI:-}" ]]
  then
    echo "Error: Homebrew snapshot/check requires passwordless sudo in CI." >&2
    exit 1
  fi
  echo "Warning: skipping Homebrew snapshot/check locally: passwordless sudo is unavailable." >&2
  snapshot_available=false
fi
if [[ "${snapshot_available}" == true ]]
then
  env CI=1 GITHUB_ENV="${work}/snapshot.env" "${brew_command}" cask-ci snapshot
  HOMEBREW_SNAPSHOT_BEFORE="$(sed -n 's/^HOMEBREW_SNAPSHOT_BEFORE=//p' "${work}/snapshot.env")"
  [[ -n "${HOMEBREW_SNAPSHOT_BEFORE}" ]] || {
    echo "Error: Homebrew snapshot was not produced." >&2
    exit 1
  }
  export HOMEBREW_SNAPSHOT_BEFORE
fi
install_attempted=true
"${brew_command}" install --cask --require-sha "${reference}"
binary="${prefix}/Caskroom/aspire/${version}/aspire"
sidecar="${prefix}/Caskroom/aspire/${version}/.aspire-install.json"
link="${prefix}/bin/aspire"
[[ -x "${binary}" && -L "${link}" && "${link}" -ef "${binary}" ]] || {
  echo "Error: installed binary/link missing or points outside the cask payload." >&2
  exit 1
}
echo "Checking installed Aspire version..."
if ! installed_version="$("${link}" --version)"
then
  echo "Error: installed Aspire failed to report its version." >&2
  xattr -l "${binary}" >&2 || true
  exit 1
fi
echo "Installed CLI version: ${installed_version}"
[[ "${installed_version%%+*}" == "${version}" ]] || {
  echo "Error: expected CLI version ${version}, got ${installed_version}." >&2
  exit 1
}
"${brew_command}" ruby -rjson -e \
  'abort "Error: missing brew install source" unless JSON.parse(File.read(ARGV.fetch(0))).fetch("source") == "brew"' \
  -- "${sidecar}"
if codesign --verify -R=notarized --check-notarization --verbose=4 "${binary}"
then
  :
else
  signing_status=$?
  echo "Error: notarization verification failed (exit ${signing_status})." >&2
  codesign --display --verbose=4 "${binary}" >&2 ||
    echo "Error: could not display the installed binary's signature." >&2
  codesign --verify --strict --verbose=4 "${binary}" >&2 ||
    echo "Error: installed binary signature integrity verification failed." >&2
  xattr -l "${binary}" >&2 ||
    echo "Error: could not read the installed binary's extended attributes." >&2
  /usr/bin/log show --last 2m --style compact --info --debug \
    --predicate '(process == "codesign" OR process == "syspolicyd") AND (eventMessage CONTAINS[c] "notar" OR eventMessage CONTAINS[c] "ticket")' >&2 ||
    echo "Error: could not read recent notarization-ticket diagnostics." >&2
  exit "${signing_status}"
fi
mkdir -p "${work}/smoke"
(
  cd "${work}/smoke"
  "${link}" --log-level trace new aspire-starter --name SmokeApp --output . \
    --non-interactive --nologo --suppress-agent-init
  "${link}" --log-level trace restore --non-interactive --nologo
)
"${brew_command}" uninstall --cask "${reference}"
install_attempted=false
[[ ! -e "${link}" && ! -L "${link}" && ! -e "${binary}" && ! -e "${sidecar}" && ! -d "${prefix}/Caskroom/aspire/${version}" ]] || {
  echo "Error: cask binary, sidecar or link survived uninstall." >&2
  exit 1
}
if [[ "${snapshot_available}" == true ]]
then
  CI=1 "${brew_command}" cask-ci check "${reference}"
fi
echo "Install, version, brew sidecar, notarization, new/restore and uninstall cleanup checks passed."
