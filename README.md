# byta.fish

A small fish plugin to assist in context switching between GCP profiles.

## Installation

oh-my-fish:

```sh
omf install https://github.com/pablofgaeta/byta.fish
```

fisher:

```sh
fisher install pablofgaeta/byta.fish
```

## Quickstart

For long-term projects, configure `BYTA_PROFILE` to be set in your shell (e.g. via [`direnv`](https://direnv.net/)).

For running one-off commands in a different context, use `byta run <profile> -- <cmd> ...`.

For running a few commands in a different context, use `byta shell <profile>` and exit when finished to return to the parent shell.

Example usage:

```fish
# Set an ambient profile for the whole session
set -gx BYTA_PROFILE cymbal

# Authenticate with "cymbal", the active profile
gcloud auth login

# List GCS blobs in a path with a different profile
byta run other -- gcloud storage ls gs://<path>

# List profiles; a `*` marks the active one, "cymbal"
byta list

# Drop into a sub-shell scoped to a profile; `exit` to return
byta shell other

# All scoped to the "other" profile
gcloud auth login
gcloud auth application-default login
gcloud config set project other-project

# Return to parent shell with "cymbal" profile active
exit

# Delete a profile you no longer need (prompts for confirmation)
byta delete cymbal
byta delete other
```

## Usage

This plugin has two modes:

- **Automatic context switching**:
  - When the `BYTA_PROFILE` variable is set, an isolated directory for `gcloud` and ADC credentials are configured.
  - When `BYTA_PROFILE` is unset, the dependent GCP environment variables are unset to prevent accidental leakage.
- **Explicit context switching**:
  - Run a command with an explicit context using: `byta run [<profile>] -- [...CMD]`
  - Run a sub-shell with an explicit context using: `byta shell <profile>`

Commands:

| Command                     | Aliases        | Description                                                                                       |
| --------------------------- | -------------- | ------------------------------------------------------------------------------------------------ |
| `byta list`                 | `ls`           | List available profiles. A `*` marks the active profile.                        |
| `byta delete <profile>`     | `rm`           | Delete a profile's config directory (prompts for confirmation).                                  |
| `byta run [<profile>] -- …` |                | Run a command under `<profile>`, scoped to that command. Defaults to `$BYTA_PROFILE` if omitted.  |
| `byta shell [<profile>]`    |                | Start an interactive sub-shell under `<profile>`. Defaults to `$BYTA_PROFILE` if omitted.         |
| `byta help`                 | `-h`, `--help` | Show usage.                                                                                       |

Profiles live in `$XDG_CONFIG_HOME/byta/<profile>` (default `~/.config/byta/<profile>`), used as the `gcloud` config directory (`CLOUDSDK_CONFIG`) with ADC stored at `application_default_credentials.json` inside it.

## Motivation

The `gcloud` CLI offers configuration management via `gcloud config configurations`, but there are several limitations:

1. There can only be one active configuration at a time. Parallel development is impossible without manually modifying environment variables.
1. Switching configurations is cumbersome and error-prone. It often requires this sequence of commands:

   ```sh
   # Activate the configuration globally
   gcloud config configurations activate <name>
   # Interactive user authentication for gcloud CLI
   gcloud auth login
   # Interactive user authentication for ADC
   gcloud auth application-default login
   # Update quota project to match the new configuration
   gcloud auth application-default set-quota-project <project>
   ```

1. Switching profiles is slow due to the need to re-authenticate and validate the new configuration.

The plugin essentially just automates running `CLOUDSDK_CONFIG=<path> GOOGLE_APPLICATION_CREDENTIALS=<path> <cmd> ...`,
but offers a simple interface for different common scenarios and automatic context switching.
