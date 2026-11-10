#!/usr/bin/env bash
# Shared lifecycle functions, also exercised without a macOS installation.
# Validator-owned paths and lifecycle state are supplied by the caller.
# shellcheck disable=SC2154

run_smoke_command() {
  local statuses
  # The command's status is deliberately recovered from PIPESTATUS below.
  # shellcheck disable=SC2312
  if "$@" 2>&1 | tee "${work}/smoke-command.log"
  then
    return 0
  else
    statuses=("${PIPESTATUS[@]}")
    if [[ "${statuses[0]}" -ne 0 ]]
    then
      return "${statuses[0]}"
    fi
    return "${statuses[1]}"
  fi
}

collect_failure_diagnostics() {
  local collector watchdog result=0
  ruby "${script_dir}/collect-validation-diagnostics.rb" "${work}" "${diagnostics_dir}" &
  collector=$!
  # A separate watchdog bounds even a stuck collector before cleanup proceeds.
  ruby -e 'sleep 10; Process.kill("KILL", Integer(ARGV.fetch(0))) rescue Errno::ESRCH' "${collector}" &
  watchdog=$!
  wait "${collector}" || result=$?
  kill "${watchdog}" 2>/dev/null || true
  wait "${watchdog}" 2>/dev/null || true
  if [[ "${result}" -ne 0 ]]
  then
    echo "Warning: failure diagnostics could not be fully collected (exit ${result})." >&2
  fi
}

cleanup_validation() {
  local status=$?
  trap - EXIT
  if [[ "${status}" -ne 0 && -n "${diagnostics_dir}" ]]
  then
    collect_failure_diagnostics
  fi
  if [[ "${install_attempted}" == true ]]
  then
    if ! "${brew_command}" uninstall --cask "${reference}"
    then
      echo "Error: cleanup uninstall failed in isolated prefix ${prefix}." >&2
      if [[ "${status}" -eq 0 ]]; then status=1; fi
    fi
  fi
  if ! rm -rf -- "${work}"
  then
    echo "Error: could not remove validation directory ${work}." >&2
    if [[ "${status}" -eq 0 ]]; then status=1; fi
  fi
  exit "${status}"
}
