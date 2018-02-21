#!/bin/bash

: <<DOCUMENTATION

######################################################################
##             Rundeck Resource Generation Script                   ##
######################################################################
This script queries Foreman (via Hambone) for a list of currently known
hosts, pings them to determine if they are up or not, and then replaces
the current Rundeck resource configuration file with the list of hosts.

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
OPT_ARGS['c']="20"
OPT_ARGS['f']=false
OPT_ARGS['o']="/etc/rundeck/resources.xml"
OPT_ARGS['q']=false
OPT_ARGS['t']="/tmp/new_resources_${timestamp}.xml"
OPT_ARGS['v']=false

## Define the script usage method
usage( ) {
    cat << EOM
    Usage:  $0

        Required Parameters:

        Optional Parameters:
          -h         Help. You're lookin' at it.

          -c         Change Threshold (%). (default: ${OPT_ARGS['c']})
          -f         Force Output. (default: ${OPT_ARGS['f']})
          -o         Output File. (default: ${OPT_ARGS['o']})
          -q         Quiet mode. Print less stuff.
          -t         Temp File. (default: ${OPT_ARGS['t']})
          -v         Verbose output. Print more stuff.


EOM
    exit 1
}

## Double colon following argument used for required parameters
EXPECTED_ARGS=":cfho:qt:v"
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
        ## Change Threshold
        c)
          OPT_ARGS['c']=${OPTARG}
          ;;
        ## Force Output
        f)
          OPT_ARGS['f']=true
          ;;
        ## Output File
        o)
          OPT_ARGS['o']=${OPTARG}
          ;;
        ## Quiet
        q)
          OPT_ARGS['q']=true
          ;;
        ## Temp File
        t)
          OPT_ARGS['t']=${OPTARG}
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
## Define script processing functions
##
check_root( ) {
    if (( $( id -u ) != 0 )); then
        error "Sorry, you must be root to run this command. Exiting..."
        exit 1
    fi
}

get_resource_prefix( ) {
    echo -e "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\n<project>"
}

get_resource_node( ) {
    host_json=$1
    host_id=$( echo "${host_json}" | jq -r .id )
    host_name=$( echo "${host_json}" | jq -r .name )
    host_ip=$( host ${host_name} | awk '{print $4}' )
    host_hostgroup=$( echo "${host_json}" | jq -r .hostgroup_name )
    host_environment=$( echo "${host_json}" | jq -r .environment_name )
    active_tag="active"
    timeout 1 bash -c "echo -n > /dev/tcp/${host_ip}/22"
    rcp=$?
    if [ ! "${rcp}" == "0" ]; then
        active_tag="inactive"
    fi
    re='^[0-9]+.[0-9]+.[0-9]+.[0-9]+$'
    if  [[ $host_ip =~ $re ]]; then
        echo -e "<node name=\"${host_name}\" description=\"${host_ip}\" tags=\"${active_tag},${host_hostgroup},${host_environment}\" hostname=\"${host_name}\" username=\"rundeck_orch\"/>"
    fi
}

get_resource_suffix( ) {
    echo -e "</project>"
}

check_host_count( ) {
    new_count=$( cat ${OPT_ARGS['t']} | grep "node name=" | wc -l )
    orig_count=$( cat ${OPT_ARGS['o']} | grep "node name=" | wc -l )
    # ensure the orig count is at least 1 to avoid 'divide by zero' errors
    if [ "${orig_count}" == "0" ]; then orig_count=1; fi
    change_ratio=$( echo "scale = 10; 1 - ${new_count} / ${orig_count}" | bc | awk ' { if($1>=0) { print int($1*100) } else {print int($1*-100) }}' )
    echo -e "New Hosts: ${new_count}\tOrig Hosts: ${orig_count}\tRatio: ${change_ratio}"
    # Check if the ratio is larger than the threshold
    if [ "${change_ratio}" -gt "${OPT_ARGS['c']}" ]; then
       # Check if the force flag has been set
       if ! ${OPT_ARGS['f']}; then
           return 1
       fi
    fi
}

write_new_resources_file( ) {
    sudo cp ${OPT_ARGS['t']} ${OPT_ARGS['o']}
}


######################################################################
## Define script functions
##
if ! ${OPT_ARGS['q']}; then
    cat << EOM

######################################################################
## ${script} Configuration
##         this:                ${this}
##         bin:                 ${bin}
##         script:              ${script}
##         timestamp:           ${timestamp}
##         fqdn:                ${fqdn}
##
##         change_threshold:    ${OPT_ARGS['c']}
##         force_output:        ${OPT_ARGS['f']}
##         output_file:         ${OPT_ARGS['o']}
##         quiet_mode:          ${OPT_ARGS['q']}
##         tmp_file:            ${OPT_ARGS['t']}
##         verbose_mode:        ${OPT_ARGS['v']}
##

EOM
fi

######################################################################
## Script processing logic
##
#check_root
prefix=$( get_resource_prefix )
log "${prefix}" 2
echo "${prefix}" > ${OPT_ARGS['t']}
for host_json in $( /opt/hambone/hambone foreman -R -p hosts -a 'per_page:100' -k 'id,name,ip,hostgroup_name,environment_name' -r ); do
    host_xml=$( get_resource_node "${host_json}" )
    log "${host_xml}" 2
    echo "${host_xml}" >> ${OPT_ARGS['t']}
done
suffix=$( get_resource_suffix )
log "${suffix}" 2
echo "${suffix}" >> ${OPT_ARGS['t']}

if ! check_host_count; then
    error "Looks like there is more than a 20% change in the number of hosts.  You must supply a '-f' flag to force the update to occur."
    exit 1
fi
write_new_resources_file

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
