# Keep CLOUDSDK_CONFIG / GOOGLE_APPLICATION_CREDENTIALS in sync with $BYTA_PROFILE.
# `byta` (function) is the per-command explicit override; this is the ambient default.
#
# Triggered on any change to BYTA_PROFILE (e.g. direnv doing `set -gx BYTA_PROFILE ...`),
# and also applied once at load below to cover a value inherited at shell startup.
function __byta_apply_profile --on-variable BYTA_PROFILE --description "Sync gcloud config/ADC env with \$BYTA_PROFILE"
    if not set -q BYTA_PROFILE[1]; or test -z "$BYTA_PROFILE"
        set -e CLOUDSDK_CONFIG
        set -e GOOGLE_APPLICATION_CREDENTIALS
        return
    end

    set -q XDG_CONFIG_HOME; or set -l XDG_CONFIG_HOME $HOME/.config
    set -gx CLOUDSDK_CONFIG $XDG_CONFIG_HOME/byta/$BYTA_PROFILE
    set -gx GOOGLE_APPLICATION_CREDENTIALS $CLOUDSDK_CONFIG/application_default_credentials.json
end

# Apply for a value already present in the environment when this shell starts;
# --on-variable does not fire for inherited variables.
__byta_apply_profile
