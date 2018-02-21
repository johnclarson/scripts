#!/bin/bash

: <<DOCUMENTATION

######################################################################
##                    IPA Host Cert Script
######################################################################
This script generates IPA Service certificates and attempts to satisfy
all prerequisists (ie: registered host, registered service, etc).

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
OPT_ARGS['q']=false
OPT_ARGS['v']=false
OPT_ARGS['c']=/root/host_certs
OPT_ARGS['t']=HTTP

## Define the script usage method
usage( ) {
    cat << EOM
    Usage:  $0

        Required Parameters:
          -H         Host. FQDN of IPA service. (ie: foo.example.com)
          -r         Realm. IPA realm associated with the service cert. (ie: EXAMPLE.COM)

        Optional Parameters:
          -c         Certificate Directory. (default: ${OPT_ARGS['c']})
          -h         Help. You're lookin' at it.
          -q         Quiet Mode. Print less stuff.
          -t         Type. IPA service type. (default: ${OPT_ARGS['t']})
          -v         Verbose Output. Print more stuff.


EOM
    exit 1
}

## Double colon following argument used for required parameters
EXPECTED_ARGS=":H::hqr::v:c::t::"
OPT_REQUIRED_NUM=$( echo -n ${EXPECTED_ARGS} | ( grep -o :: || true ) | wc -l )
GETOPT_ARGS=$( echo -n ${EXPECTED_ARGS} | sed -e 's/::/:/g' )

## Process arguments
while getopts "${GETOPT_ARGS}" opt; do
    case "${opt}" in
        ## Host
        H)
          OPT_ARGS['H']=${OPTARG}
          ;;
        ## Realm
        r)
          OPT_ARGS['r']=${OPTARG}
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
        c)
          OPT_ARGS['c']=${OPTARG}
          ;;
        t)
          OPT_ARGS['t']=${OPTARG}
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
if [ ! ${OPT_ARGS['H']+isset} ]; then error "Sorry, you must specify a valid FQDN for the '-H' option."; usage; fi
if [ ! ${OPT_ARGS['r']+isset} ]; then error "Sorry, you must specify a value for the '-r' option."; usage; fi


######################################################################
## Define script processing functions
##
check_root( ) {
    if (( $( id -u ) != 0 )); then
        error "Sorry, you must be root to run this command. Exiting..."
        exit 1
    fi
}

## Ensure the user has a valid kerberos identity
check_kerberos_tickets( ) {
    log "Checking kerberos credentials..." 2
    if ! klist > /dev/null 2>&1; then
        error "Please initialize privileged kerberos credentials via kinit prior to running this script."
        exit 1
    fi
}

## Make the host certificate directory if it has not already been created
ensure_cert_dir( ) {
    log "Creating host certificate directory..." 2
    if [ ! -d ${OPT_ARGS['c']} ]; then
        mkdir -p ${OPT_ARGS['c']}
    fi
}

## Add the host to IPA if it has not already been added
ensure_host_in_ipa( ) {
    log "Checking for existing host in IPA..." 2
    if ! ipa host-show ${OPT_ARGS['H']} > /dev/null 2>&1; then
        log "Attempting to add the host '${OPT_ARGS['H']}' to IPA..."
        if ! ipa host-add --force ${OPT_ARGS['H']}; then
            error "Sorry. Unable to add the host to IPA. Aborting."
            exit 1
        fi
    fi
}

## Add the service to IPA and register this host as an authorized host if it has not already been done
ensure_service_in_ipa( ) {
    log "Checking for existing service in IPA..." 2
    if ! ipa service-show ${OPT_ARGS['t']}/${OPT_ARGS['H']} > /dev/null 2>&1; then
        log "Attempting to add the service ${OPT_ARGS['t']}/${OPT_ARGS['H']}..."
        if ! ipa service-add --force ${OPT_ARGS['t']}/${OPT_ARGS['H']}; then
            error "Sorry. Unable to add the service to IPA. Aborting."
            exit 1
        fi
        log "Attempting to authorize this host to request the service certificate..."
        if ! ipa service-add-host --hosts=`hostname` ${OPT_ARGS['t']}/${OPT_ARGS['H']}; then
            error "Unable to authorize this host to request the certificate. Aborting."
            exit 1
        fi
    fi
}

## Request the certificate from CertMonger if it has not already been requested
generate_service_cert( ) {
    log "Checking for existing service certificate in IPA..." 2
    if ! ipa-getcert list | grep "${OPT_ARGS['t']}/${OPT_ARGS['H']}" > /dev/null 2>&1; then
        log "Attempting to request service certificate for ${OPT_ARGS['t']}/${OPT_ARGS['H']} from CertMonger..."
        ipa-getcert request -K ${OPT_ARGS['t']}/${OPT_ARGS['H']} -N CN=${OPT_ARGS['H']},O=${OPT_ARGS['r']} -g 2048 -k ${OPT_ARGS['c']}/${OPT_ARGS['H']}.key -f ${OPT_ARGS['c']}/${OPT_ARGS['H']}.crt
        log "...sleeping..."
        sleep 4
        log "Verifying certificate was created and signed via CertMonger..."
        if ! ipa-getcert list | grep "${OPT_ARGS['t']}/${OPT_ARGS['H']}" > /dev/null 2>&1; then
            error "Unable to detect a valid certificate generation from CertMonger. Aborting"
            exit 1
        fi
    fi
}

## Print generated certificate information
output_summary_info( ) {
    cert_info=$( ipa-getcert list )
    echo -e "\n\nCertificate Information from 'ipa-getcert list' command:"
    echo -e "${cert_info}"
    echo -e "\n\nYou may want to consider stop CertMonger from tracking for this certificate with the following command:\n\tipa-getcert stop-tracking -k ${OPT_ARGS['c']}/${OPT_ARGS['H']}.key -f ${OPT_ARGS['c']}/${OPT_ARGS['H']}.crt\n\nThe certificate can be renewed manually with the following command:\n\tipa-getcert resubmit -f ${OPT_ARGS['c']}/${OPT_ARGS['H']}.crt\n\n"
    echo -e "\n\nService certificate generation complete. Please lookin output directory ${OPT_ARGS['c']}..."
}

######################################################################
## Define script functions
##
if ! ${OPT_ARGS['q']}; then
    cat << EOM

######################################################################
## ${script} Configuration
##         this:           ${this}
##         bin:            ${bin}
##         script:         ${script}
##         timestamp:      ${timestamp}
##         fqdn:           ${fqdn}
##
##         cert dir:       ${OPT_ARGS['c']}
##         host:           ${OPT_ARGS['H']}
##         realm:          ${OPT_ARGS['r']}
##         type:           ${OPT_ARGS['t']}
##

EOM
fi

######################################################################
## Script processing logic
##
check_kerberos_tickets
ensure_cert_dir
ensure_host_in_ipa
ensure_service_in_ipa
generate_service_cert


######################################################################
## That's a wrap, folks!
##
if ${OPT_ARGS['v']}; then
    output_summary_info
    cat << EOM

##
## Finished!
##


EOM
fi


exit 0
