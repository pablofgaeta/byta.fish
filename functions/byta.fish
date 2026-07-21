function byta --description "Manage and run commands under byta gcloud config/ADC profiles"
    if not set -q argv[1]
        __byta_usage >&2
        return 1
    end

    set -l cmd $argv[1]
    set -e argv[1]

    switch $cmd
        case list ls
            __byta_list $argv
        case delete rm
            __byta_delete $argv
        case run
            __byta_run $argv
        case shell
            __byta_shell $argv
        case -h --help help
            __byta_usage
        case '*'
            echo "byta: unknown subcommand '$cmd'" >&2
            __byta_usage >&2
            return 1
    end
end

function __byta_usage --description "Print byta usage"
    echo "usage: byta <command>"
    echo
    echo "commands:"
    echo "  list                    list available profiles (* marks \$BYTA_PROFILE)"
    echo "  delete <profile>        delete a profile's config directory"
    echo "  run [<profile>] -- ...  run a command under <profile> (defaults to \$BYTA_PROFILE)"
    echo "  shell [<profile>]       start an interactive shell under <profile> (defaults to \$BYTA_PROFILE)"
end

function __byta_base --description "Print the byta profiles base directory"
    set -q XDG_CONFIG_HOME; or set -l XDG_CONFIG_HOME $HOME/.config
    echo $XDG_CONFIG_HOME/byta
end

function __byta_list --description "List byta profiles"
    set -l base (__byta_base)
    if not test -d $base
        echo "byta: no profiles ($base does not exist)" >&2
        return 0
    end

    set -l found 0
    for dir in $base/*/
        test -d $dir; or continue
        set found 1
        set -l name (path basename $dir)
        if test "$name" = "$BYTA_PROFILE"
            echo "* $name"
        else
            echo "  $name"
        end
    end

    if test $found -eq 0
        echo "byta: no profiles in $base" >&2
    end
end

function __byta_delete --description "Delete a byta profile"
    if not set -q argv[1]
        echo "byta: delete requires a profile name" >&2
        return 1
    end
    if set -q argv[2]
        echo "byta: delete takes a single profile name" >&2
        return 1
    end

    set -l profile $argv[1]
    set -l dir (__byta_base)/$profile

    if not test -d $dir
        echo "byta: no such profile '$profile'" >&2
        return 1
    end

    read -l -P "byta: delete profile '$profile' ($dir)? [y/N] " confirm
    switch $confirm
        case y Y yes Yes YES
            rm -rf $dir
            echo "byta: deleted '$profile'"
        case '*'
            echo "byta: aborted"
            return 1
    end
end

function __byta_run --description "Run a command under a byta profile"
    set -l idx (contains -i -- -- $argv)
    if test -z "$idx"
        echo "byta: run requires '--' before the command (byta run [<profile>] -- cmd ...)" >&2
        return 1
    end

    set -l pre
    if test $idx -gt 1
        set pre $argv[1..(math $idx - 1)]
    end
    set -l cmd $argv[(math $idx + 1)..-1]

    set -l profile $BYTA_PROFILE
    if test (count $pre) -gt 1
        echo "byta: too many arguments before '--'" >&2
        return 1
    else if test (count $pre) -eq 1
        set profile $pre[1]
    end

    if test -z "$profile"
        echo "byta: no profile set (pass <profile> or export \$BYTA_PROFILE)" >&2
        return 1
    end
    if not set -q cmd[1]
        echo "byta: no command given for profile '$profile'" >&2
        return 1
    end

    set -q XDG_CONFIG_HOME; or set -l XDG_CONFIG_HOME $HOME/.config
    set -lx CLOUDSDK_CONFIG $XDG_CONFIG_HOME/byta/$profile
    set -lx GOOGLE_APPLICATION_CREDENTIALS $CLOUDSDK_CONFIG/application_default_credentials.json

    $cmd
end

function __byta_shell --description "Start an interactive shell under a byta profile"
    if set -q argv[2]
        echo "byta: shell takes a single profile name" >&2
        return 1
    end

    set -l profile $BYTA_PROFILE
    if set -q argv[1]
        set profile $argv[1]
    end

    if test -z "$profile"
        echo "byta: no profile set (pass <profile> or export \$BYTA_PROFILE)" >&2
        return 1
    end

    set -q XDG_CONFIG_HOME; or set -l XDG_CONFIG_HOME $HOME/.config
    set -lx CLOUDSDK_CONFIG $XDG_CONFIG_HOME/byta/$profile
    set -lx GOOGLE_APPLICATION_CREDENTIALS $CLOUDSDK_CONFIG/application_default_credentials.json
    set -lx BYTA_PROFILE $profile
    set -lx BYTA_SHELL $profile

    set -l shell $SHELL
    test -n "$shell"; or set shell fish

    $shell
end
