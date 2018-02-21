#!/bin/bash

dns_forwarder=
ipa_admin_password=
ipa_master_hostname=
ipa_master_ip=
domain=
verbose=0

show_help() {
    echo "Usage: $0 [option...] " >&2
    echo
    echo "   --dns_forwarder            DNS forwarder "
    echo "   --ipa_admin_password       Desired IPA admin password "
    echo "   --ipa_master_hostname      Desired IPA master hostname "
    echo "   --ipa_master_ip            Desired IPA master IP address "
    echo "   --domain                   Desired IPA domain "
    echo
    echo "All options are REQUIRED!! "
    exit 1
}


while :; do
     case $1 in
         -h|-\?|--help)   # Call a "show_help" function to display a synopsis, then exit.
             show_help
             exit
             ;;
         --dns_forwarder)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 dns_forwarder=$2
                 shift
             else
                 printf 'ERROR: "--dns_forwarder" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --dns_forwarder=?*)
             dns_forwarder=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --dns_forwarder=)         # Handle the case of an empty --dns_forwarder=
             printf 'ERROR: "--dns_forwarder" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --ipa_admin_password)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 ipa_admin_password=$2
                 shift
             else
                 printf 'ERROR: "--ipa_admin_password" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --ipa_admin_password=?*)
             ipa_admin_password=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --ipa_admin_password=)         # Handle the case of an empty --ipa_admin_password=
             printf 'ERROR: "--ipa_admin_password" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --domain)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 domain=$2
                 shift
             else
                 printf 'ERROR: "--domain" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --domain=?*)
             domain=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --domain=)         # Handle the case of an empty --domain=
             printf 'ERROR: "--foreman_hostname" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --ipa_master_hostname)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 ipa_master_hostname=$2
                 shift
             else
                 printf 'ERROR: "--ipa_master_hostname" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --ipa_master_hostname=?*)
             ipa_master_hostname=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --ipa_master_hostname=)         # Handle the case of an empty --ipa_master_hostname=
             printf 'ERROR: "--ipa_master_hostname" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --ipa_master_ip)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 ipa_master_ip=$2
                 shift
             else
                 printf 'ERROR: "--ipa_master_ip" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --ipa_master_ip=?*)
             ipa_master_ip=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --ipa_master_ip=)         # Handle the case of an empty --ipa_master_ip=
             printf 'ERROR: "--ipa_master_ip" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         -v|--verbose)
             verbose=$((verbose + 1)) # Each -v argument adds 1 to verbosity.
             ;;
         --)              # End of all options.
             shift
             break
             ;;
         -?*)
             printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
             ;;
         *)               # Default case: If no more options then break out of the loop.
             break
     esac
 
     shift
done

# Check for required variables
if [ ! $dns_forwarder ]; then
    echo "dns_forwarder is a required option."
    exit 1
elif [ ! $ipa_admin_password ]; then
    echo "ipa_admin_password is a required option."
    exit 1
elif [ ! $ipa_master_hostname ]; then
    echo "ipa_master_hostname is a required option."
    exit 1
elif [ ! $ipa_master_ip ]; then
    echo "ipa_master_ip is a required option."
    exit 1
elif [ ! $domain ]; then
    echo "domain is a required option."
    exit 1
fi


## Derived variables
realm=$(echo $domain | tr '[:lower:]' '[:upper:]')

## Fix DNS info
rm /etc/resolv.conf
echo "search $domain" >> /etc/resolv.conf
echo "nameserver $ipa_master_ip" >> /etc/resolv.conf

## Install IPA client
rm /etc/ipa/ca.crt
ipa-client-install -p admin -w $ipa_admin_password --enable-dns-updates --no-dns-sshfp --server=${ipa_master_hostname}.${domain} \
--domain=$domain --realm=$realm -U --force

## Install IPA replica
/usr/sbin/ipa-replica-install --setup-ca --setup-dns --no-host-dns --forwarder=$dns_forwarder -w $ipa_admin_password \
--skip-conncheck

