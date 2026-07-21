# Fishtape tests for the byta plugin.
#
# Run locally:
#   fisher install jorgebucaran/fishtape   # once
#   fishtape tests/*.fish
#
# Each fishtape file runs in its own shell, so we can freely mutate the global
# environment here without affecting the caller or other test files.

# Locate the repo root (works whether sourced by fishtape or run from root).
set -l repo (path resolve (status dirname)/..)
test -f $repo/functions/byta.fish; or set repo $PWD

# --- Isolated, throwaway environment -----------------------------------------
set -gx XDG_CONFIG_HOME (mktemp -d)
mkdir -p $XDG_CONFIG_HOME/byta/alpha $XDG_CONFIG_HOME/byta/beta

# Make sure nothing ambient leaks into the assertions.
set -e BYTA_PROFILE
set -e CLOUDSDK_CONFIG
set -e GOOGLE_APPLICATION_CREDENTIALS

# A fake $SHELL that reports the environment it was launched with, so we can
# exercise `byta shell` without a real interactive session. Fields are joined
# with "|": BYTA_PROFILE|CLOUDSDK_CONFIG|GOOGLE_APPLICATION_CREDENTIALS|BYTA_SHELL
set -gx FAKE_SHELL $XDG_CONFIG_HOME/fake-shell
printf '#!/bin/sh\nprintf "%%s|%%s|%%s|%%s" "$BYTA_PROFILE" "$CLOUDSDK_CONFIG" "$GOOGLE_APPLICATION_CREDENTIALS" "$BYTA_SHELL"\n' >$FAKE_SHELL
chmod +x $FAKE_SHELL

# Load the code under test.
source $repo/functions/byta.fish
source $repo/conf.d/byta.fish

# =============================================================================
# dispatch / usage
# =============================================================================

@test "no subcommand exits non-zero" (byta >/dev/null 2>&1) $status -ne 0
@test "unknown subcommand exits non-zero" (byta frobnicate >/dev/null 2>&1) $status -ne 0
@test "--help exits zero" (byta --help >/dev/null 2>&1) $status -eq 0
@test "help mentions the run command" (byta --help 2>&1 | string match -q '*run*') $status -eq 0
@test "help mentions the shell command" (byta --help 2>&1 | string match -q '*shell*') $status -eq 0

# =============================================================================
# byta list
# =============================================================================

set -gx BYTA_PROFILE beta
set -l list_out (byta list)
set -e BYTA_PROFILE

@test "list shows every profile" (count $list_out) -eq 2
@test "list marks the active profile with an asterisk" (string match -qr '^\* beta$' -- $list_out) $status -eq 0
@test "list does not mark inactive profiles" (string match -qr '^  alpha$' -- $list_out) $status -eq 0
@test "list exits zero when a base dir with no profiles exists" (rm -rf $XDG_CONFIG_HOME/byta/alpha $XDG_CONFIG_HOME/byta/beta; byta list >/dev/null 2>&1) $status -eq 0

# restore the profiles removed by the previous test
mkdir -p $XDG_CONFIG_HOME/byta/alpha $XDG_CONFIG_HOME/byta/beta

# =============================================================================
# byta run
# =============================================================================

@test "run returns the command's exit status on success" (byta run alpha -- true >/dev/null 2>&1) $status -eq 0
@test "run propagates a nonzero exit status" (byta run alpha -- sh -c 'exit 42' >/dev/null 2>&1) $status -eq 42

set -l run_cfg (byta run alpha -- sh -c 'printf %s "$CLOUDSDK_CONFIG"')
@test "run sets CLOUDSDK_CONFIG for the command" "$run_cfg" = "$XDG_CONFIG_HOME/byta/alpha"

set -l run_adc (byta run alpha -- sh -c 'printf %s "$GOOGLE_APPLICATION_CREDENTIALS"')
@test "run sets GOOGLE_APPLICATION_CREDENTIALS for the command" "$run_adc" = "$XDG_CONFIG_HOME/byta/alpha/application_default_credentials.json"

set -gx BYTA_PROFILE beta
set -l run_fallback (byta run -- sh -c 'printf %s "$CLOUDSDK_CONFIG"')
set -e BYTA_PROFILE
@test "run falls back to \$BYTA_PROFILE when no profile is given" "$run_fallback" = "$XDG_CONFIG_HOME/byta/beta"

@test "run without -- exits non-zero" (byta run alpha echo hi >/dev/null 2>&1) $status -ne 0
@test "run without a profile or \$BYTA_PROFILE exits non-zero" (byta run -- true >/dev/null 2>&1) $status -ne 0
@test "run without a command exits non-zero" (byta run alpha -- >/dev/null 2>&1) $status -ne 0

byta run alpha -- true >/dev/null 2>&1
@test "run does not leak CLOUDSDK_CONFIG into the parent shell" (set -q CLOUDSDK_CONFIG) $status -ne 0

# =============================================================================
# byta shell
# =============================================================================

set -gx SHELL $FAKE_SHELL

set -l shell_parts (string split '|' -- (byta shell alpha))
@test "shell exports BYTA_PROFILE into the sub-shell" "$shell_parts[1]" = alpha
@test "shell sets CLOUDSDK_CONFIG in the sub-shell" "$shell_parts[2]" = "$XDG_CONFIG_HOME/byta/alpha"
@test "shell sets GOOGLE_APPLICATION_CREDENTIALS in the sub-shell" "$shell_parts[3]" = "$XDG_CONFIG_HOME/byta/alpha/application_default_credentials.json"
@test "shell sets the BYTA_SHELL marker in the sub-shell" "$shell_parts[4]" = alpha

set -gx BYTA_PROFILE beta
set -l shell_fallback (string split '|' -- (byta shell))
set -e BYTA_PROFILE
@test "shell falls back to \$BYTA_PROFILE when no profile is given" "$shell_fallback[1]" = beta

@test "shell without a profile or \$BYTA_PROFILE exits non-zero" (byta shell >/dev/null 2>&1) $status -ne 0
@test "shell with too many arguments exits non-zero" (byta shell a b >/dev/null 2>&1) $status -ne 0

byta shell alpha >/dev/null 2>&1
@test "shell does not leak BYTA_SHELL into the parent shell" (set -q BYTA_SHELL) $status -ne 0
@test "shell does not leak BYTA_PROFILE into the parent shell" (set -q BYTA_PROFILE) $status -ne 0

# =============================================================================
# conf.d hook: __byta_apply_profile (ambient context switching)
# =============================================================================

set -gx BYTA_PROFILE gamma
@test "hook derives CLOUDSDK_CONFIG from \$BYTA_PROFILE" "$CLOUDSDK_CONFIG" = "$XDG_CONFIG_HOME/byta/gamma"
@test "hook derives GOOGLE_APPLICATION_CREDENTIALS from \$BYTA_PROFILE" "$GOOGLE_APPLICATION_CREDENTIALS" = "$XDG_CONFIG_HOME/byta/gamma/application_default_credentials.json"

set -e BYTA_PROFILE
@test "hook clears CLOUDSDK_CONFIG when \$BYTA_PROFILE is unset" (set -q CLOUDSDK_CONFIG) $status -ne 0
@test "hook clears GOOGLE_APPLICATION_CREDENTIALS when \$BYTA_PROFILE is unset" (set -q GOOGLE_APPLICATION_CREDENTIALS) $status -ne 0

# --- cleanup -----------------------------------------------------------------
rm -rf $XDG_CONFIG_HOME
