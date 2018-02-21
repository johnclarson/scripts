#!/bin/bash

: <<DOCUMENTATION

######################################################################
##               Gitlab Backup Script                               ##
######################################################################
This script backs up the gitlab database, repositories, and all meta-
data necessary to restore on a different server.

DOCUMENTATION

######################################################################
## Iniitalize the environment
##
this="${BASH_SOURCE-$0}"
bin=$( cd -P -- "$( dirname -- "${this}" )" && pwd -P )
script="$( basename -- "${this}" )"
this="${bin}/${script}"
timestamp="$( date +%Y%m%d_%H%M%S )"
fqdn="$( hostname -f )"

set -e
set -u
set -o pipefail

IFS=$'\n\t'

scratch=$( mktemp -d -t scratch.tmp.XXXXXXXXXX )

function finish {
    rm -Rf "${scratch}"
    ## Put any custom cleanup code here
    ## ...
}
trap finish EXIT


######################################################################
## Define script utility functions
##
error( ) {
    msg=$@
    echo -e "\n##\n##  ERROR: ${msg}\n##\n" >&2
}
log( ) {
    msg=$1
    if [ ${2+isset} ]; then
        vvv=$2
    else
        vvv=1
    fi
    if ! ${OPT_ARGS['q']}; then
        if [ "${vvv}" -le "1" -o "${OPT_ARGS['v']}" == "true" ]; then
            echo -e "${msg}"
        fi
    fi
}


######################################################################
## Process command line arguments
##
declare -A OPT_ARGS
set +u

## Set default values
OPT_ARGS['d']=/home/backups/gitlab
OPT_ARGS['l']=/var/opt/gitlab/backups
OPT_ARGS['q']=false
OPT_ARGS['r']=bosshog
OPT_ARGS['v']=false

## Define the script usage method
usage( ) {
    cat << EOM
    Usage:  $0

        Required Parameters:

        Optional Parameters:
          -d         Remote Destination. Full file path on remote machine. (default: ${OPT_ARGS['d']})
          -h         Help. You're lookin' at it.
          -l         Local Backup Folder. (default: ${OPT_ARGS['l']})
          -q         Quiet mode. Print less stuff.
          -r         Remote Server. (default: ${OPT_ARGS['r']})
          -v         Verbose output. Print more stuff.


EOM
    exit 1
}

## Double colon following argument used for required parameters
EXPECTED_ARGS=":hqr:v"
OPT_REQUIRED_NUM=$( echo -n ${EXPECTED_ARGS} | ( grep -o :: || true ) | wc -l )
GETOPT_ARGS=$( echo -n ${EXPECTED_ARGS} | sed -e 's/::/:/g' )

## Process arguments
while getopts "${GETOPT_ARGS}" opt; do
    case "${opt}" in
        ## Help
        h)
          sed --silent -e '/DOCUMENTATION$/,/^DOCUMENTATION$/p' "$0" | sed -e '/DOCUMENTATION$/d' | sed -e 's/^/  /'
          usage
          ;;
        ## Quiet
        q)
          OPT_ARGS['q']=true
          ;;
        ## Remote Server
        r)
          OPT_ARGS['r']=${OPTARG}
          ;;
        ## Verbose
        v)
          OPT_ARGS['v']=true
          ;;
        \?)
          error "Invalid option specified: -${OPTARG}"
          usage
          ;;
        :)
          error "Option '-${OPTARG}' requires an argument."
          usage
          ;;
    esac
done
set -u
if [ "${#OPT_ARGS[@]}" -lt "${OPT_REQUIRED_NUM}" ]; then
    usage
fi

## Check if required arguments have valid values
#if [ ! ${OPT_ARGS['x']+isset} ]; then error "Sorry, you must specify ...... for the '-x' option."; usage; fi


######################################################################
## Define script functions
##
check_root( ) {
    if (( $( id -u ) != 0 )); then
        error "Sorry, you must be root to run this command. Exiting..."
        exit 1
    fi
}

backup_gitlab( ) {
    log "Backing up GitLab instance..." 2
    gitlab-rake gitlab:backup:create SKIP=registry,builds,artifacts
}

sync_to_remote( ) {
    log "Syncing GitLab backup directory to ${OPT_ARGS['r']}..." 2
    rsync -av ${OPT_ARGS['l']}/ ${OPT_ARGS['r']}:${OPT_ARGS['d']}/
}



######################################################################
## Define script functions
##
if ! ${OPT_ARGS['q']}; then
    cat << EOM

######################################################################
## ${script} Configuration
##         this:              ${this}
##         bin:               ${bin}
##         script:            ${script}
##         timestamp:         ${timestamp}
##         fqdn:              ${fqdn}
##
##         Remote Server:     ${OPT_ARGS['r']}
##         Local Directory:   ${OPT_ARGS['l']}
##         Remote Directory:  ${OPT_ARGS['d']}
##

EOM
fi

######################################################################
## Script processing logic
##
check_root
backup_gitlab
sync_to_remote


if ${OPT_ARGS['v']}; then
    cat << EOM

##
## Finished!
##

EOM
fi


exit 0
