#!/bin/bash

: <<DOCUMENTATION

######################################################################
##                    Script Template                               ##
######################################################################
This script will backup the slapd data directory of an IPA server into
LDIF format.

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
#ldapsearch=$( which ldapsearch ) || echo "unable to locate 'ldapsearch'. Aborting." && exit 1
ldapsearch=$( which ldapsearch )

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
OPT_ARGS['q']=false
OPT_ARGS['v']=false
OPT_ARGS['b']=/opt/slapd/backup
OPT_ARGS['f']="(|(ObjectClass=posixgroup)(ObjectClass=posixaccount))"
ldap_protocol='ldap'
ldap_host='localhost'
ldap_port='389'

## Define the script usage method
usage( ) {
    cat << EOM
    Usage:  $0

        Required Parameters:

        Optional Parameters:
          -b         Backup Destination. (default: ${OPT_ARGS['b']})
          -f         LDAP Filter. (default: ${OPT_ARGS['f']})
          -h         Help. You're lookin' at it.
          -q         Quiet mode. Print less stuff.
          -v         Verbose output. Print more stuff.


EOM
    exit 1
}

## Double colon following argument used for required parameters
EXPECTED_ARGS=":b:f:hqv"
OPT_REQUIRED_NUM=$( echo -n ${EXPECTED_ARGS} | ( grep -o :: || true ) | wc -l )
GETOPT_ARGS=$( echo -n ${EXPECTED_ARGS} | sed -e 's/::/:/g' )

## Process arguments
while getopts "${GETOPT_ARGS}" opt; do
    case "${opt}" in
        ## Backup Destination
        b)
          OPT_ARGS['b']=${OPTARG}
          ;;
        ## LDAP Filter
        f)
          OPT_ARGS['f']=${OPTARG}
          ;;
        ## Help
        h)
          sed --silent -e '/DOCUMENTATION$/,/^DOCUMENTATION$/p' "$0" | sed -e '/DOCUMENTATION$/d' | sed -e 's/^/  /'
          usage
          ;;
        ## Quiet
        q)
          OPT_ARGS['q']=true
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

## Initialize script variables
backup_file="${OPT_ARGS['b']}/${ldap_host}_${timestamp}.ldif"
ldap_url="${ldap_protocol}://${ldap_host}:${ldap_port}"

######################################################################
## Define script processing functions
##
check_root( ) {
    if (( $( id -u ) != 0 )); then
        error "Sorry, you must be root to run this command. Exiting..."
        exit 1
    fi
}

initialize_backup_path( ) {
    mkdir -p ${OPT_ARGS['b']}
}

dump_ldap_users_and_groups( ) {
    ${ldapsearch} -x -L -H ${ldap_url} "${OPT_ARGS['f']}" > ${backup_file}
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
##         ldap url:          ${ldap_url}
##         ldap filter:       ${OPT_ARGS['f']}
##         backup file:       ${backup_file}

EOM
fi

######################################################################
## Script processing logic
##
check_root
initialize_backup_path
dump_ldap_users_and_groups


######################################################################
## That's a wrap, folks!
##
if ${OPT_ARGS['v']}; then
    cat << EOM

##
## Finished!
##

EOM
fi


exit 0
