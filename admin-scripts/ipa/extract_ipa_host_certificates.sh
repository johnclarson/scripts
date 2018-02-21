#!/bin/bash

: <<DOCUMENTATION

######################################################################
##                    Script Template                               ##
######################################################################
This script extracts CA and host certs matching the fqdn of the
running host into locally accessible .pem and .jks formats.

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

## Define script constants
passwd_file="/tmp/.crt_pwd"
nssdb_path="/tmp/ipa_nssdb_clone"
nssdb_pwdfile="${nssdb_path}/pwdfile.txt"
sudo="/usr/bin/sudo"

set -e
set -u
set -o pipefail

IFS=$'\n\t'

scratch=$( mktemp -d -t scratch.tmp.XXXXXXXXXX )

function finish {
    rm -Rf "${scratch}"
    ## Put any custom cleanup code here
    ## ...
    ${sudo} rm -Rf ${nssdb_path}
    ${sudo} rm -f ${passwd_file}
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
OPT_ARGS['d']=/etc/ipa/nssdb
OPT_ARGS['o']=/etc/pki/tls
OPT_ARGS['p']=password

## Define the script usage method
usage( ) {
    cat << EOM
    Usage:  $0

        Required Parameters:

        Optional Parameters:
          -d         NSS DB path. (default: ${OPT_ARGS['d']})
          -h         Help. You're lookin' at it.
          -o         Output path. (default: ${OPT_ARGS['o']})
          -p         Certificate Password. (default: ${OPT_ARGS['p']})
          -q         Quiet mode. Print less stuff.
          -v         Verbose output. Print more stuff.


EOM
    exit 1
}

## Double colon following argument used for required parameters
EXPECTED_ARGS=":d:ho:p:qv"
OPT_REQUIRED_NUM=$( echo -n ${EXPECTED_ARGS} | ( grep -o :: || true ) | wc -l )
GETOPT_ARGS=$( echo -n ${EXPECTED_ARGS} | sed -e 's/::/:/g' )

## Process arguments
while getopts "${GETOPT_ARGS}" opt; do
    case "${opt}" in
        ## NSS DB Path
        d)
          OPT_ARGS['d']=${OPTARG}
          ;;
        ## Help
        h)
          sed --silent -e '/DOCUMENTATION$/,/^DOCUMENTATION$/p' "$0" | sed -e '/DOCUMENTATION$/d' | sed -e 's/^/  /'
          usage
          ;;
        ## Output Directory
        o)
          OPT_ARGS['o']=${OPTARG}
          ;;
        ## Certificate Password
        p)
          OPT_ARGS['p']=${OPTARG}
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

## Define script variables based upon user inputs
cert_passwd=${OPT_ARGS['p']}
out="${OPT_ARGS['o']}"
out_certs="${OPT_ARGS['o']}/certs"
out_jks="${OPT_ARGS['o']}/jks"
out_private="${OPT_ARGS['o']}/private"
nssdb_origin="${OPT_ARGS['d']}"


######################################################################
## Define script processing functions
##
check_root( ) {
    if (( $( id -u ) == 0 )); then
        sudo=""
    fi
}

check_sudo( ) {
    if (( $( id -u ) != 0 )); then
        if ! ${sudo} whoami > /dev/null 2>&1; then
            error "I'm not root and I cannot sudo so I'm basically crippled and cannot run.  Try again after leveling up your character..."
            exit 1
        fi
    fi
}

check_keytool( ) {
    keytool_bin=/usr/java/default/bin/keytool
    if ! test -f ${keytool_bin}; then keytool_bin=$( which keytool || echo "" ); fi
    if ! test -x ${keytool_bin} > /dev/null 2>&1; then
        error "Cannot locate 'keytool'.  Please install and run this awesome script again!"
        exit 1
    fi
}

initialize( ) {
    log "cloning IPA NSS DB from ${nssdb_origin}..."
    if [ -d ${nssdb_path}/ ]; then
        rm -Rf ${nssdb_path}/
    fi
    ${sudo} rsync -a ${nssdb_origin}/ ${nssdb_path}/
    log "creating output file paths at ${out}..."
    ${sudo} mkdir -p ${out}
    ${sudo} mkdir -p ${out_certs}
    ${sudo} mkdir -p ${out_jks}
    ${sudo} mkdir -p ${out_private}
}

extract_ca_cert( ) {
    log "extracting IPA CA certificate..."
    ipa_ca_cert_name=$( ${sudo} certutil -L -d ${nssdb_path} | grep CA | sed -e "s/^\s*//" -e "s/CA    .*$/CA/" )
    log "\tIPA CA Cert Name: '${ipa_ca_cert_name}'"
    ${sudo} bash -c "certutil -L -d ${nssdb_path} -a -n '${ipa_ca_cert_name}' > ${out_certs}/ipa-ca.crt"
}

generate_certificates( ) {
    # create certificate password file
    ${sudo} echo "${cert_passwd}" > ${passwd_file}

    # extract .p12
    ${sudo} pk12util -o ${out_private}/ipa-host.p12 -n "Local IPA host" -d ${nssdb_path} -k ${nssdb_pwdfile} -w ${passwd_file}

    # convert .p12 to .pem
    ${sudo} openssl pkcs12 -in ${out_private}/ipa-host.p12 -out ${out_private}/ipa-host.pem -nodes -passin file:${passwd_file}

    # extract private key from .pem
    ${sudo} bash -c "cat ${out_private}/ipa-host.pem | sed -n '/-----BEGIN PRIVATE KEY-----/,/-----END PRIVATE KEY-----/p' > ${out_private}/ipa-host.key"

    # extract public key from .pem
    ${sudo} bash -c "cat ${out_private}/ipa-host.pem | sed -n '/CN=${fqdn}/,/-----END CERTIFICATE-----/p' > ${out_certs}/ipa-host.crt"

    # convert .p12 to .jks
    ${sudo} ${keytool_bin} -importkeystore -srckeystore ${out_private}/ipa-host.p12 -srcstoretype PKCS12 -destkeystore ${out_jks}/ipa-certs.jks -deststoretype JKS -srcstorepass password -deststorepass password -srcalias "Local IPA host" -destalias "local ipa host" -srckeypass "${cert_passwd}" -destkeypass "${cert_passwd}" -noprompt

    # convert IPA CA trustchain to .jks
    ${sudo} ${keytool_bin} -importcert -alias "ipa trustchain" -file ${out_certs}/ipa-ca.crt -keypass "${cert_passwd}" -keystore ${out_jks}/ipa-certs.jks -storepass "${cert_passwd}" -noprompt

}

notes( ) {
    # convert .pem to .p12
    openssl pkcs12 -export -out ${out_private}/ipa-host.p12 -inkey ${out_private}/ipa-host.key -in ${out_certs}/ipa-host.crt
}

cleanup( ) {
    log "cleaning up..."
    log "\nFinished."
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
##         NSS DB:         ${nssdb_origin}
##         Output Path:    ${out}
##         Temp NSS DB:    ${nssdb_path}
##

EOM
fi

######################################################################
## Script processing logic
##
check_root
check_sudo
check_keytool
initialize

extract_ca_cert
generate_certificates

cleanup

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
