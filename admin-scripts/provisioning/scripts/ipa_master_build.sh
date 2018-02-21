#!/bin/bash

dns_forwarder=
ipa_admin_password=
ipa_master_hostname=
foreman_hostname=
domain=
priv_vpc_cidr=
verbose=0
 
show_help() {
    echo "Usage: $0 [option...] " >&2
    echo
    echo "   --dns_forwarder            DNS forwarder "
    echo "   --ipa_admin_password       Desired IPA admin password "
    echo "   --ipa_master_hostname      Desired IPA master hostname "
    echo "   --foreman_hostname         Foreman hostname for CNAME creation "
    echo "   --domain                   Desired IPA domain "
    echo "   --priv_vpc_cidr            Network CIDR of private VPC "
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
         --priv_vpc_cidr)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 priv_vpc_cidr=$2
                 shift
             else
                 printf 'ERROR: "--priv_vpc_cidr" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --priv_vpc_cidr=?*)
             priv_vpc_cidr=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --priv_vpc_cidr=)         # Handle the case of an empty --priv_vpc_cidr=
             printf 'ERROR: "--priv_vpc_cidr" requires a non-empty option argument.\n' >&2
             exit 1
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
         --foreman_hostname)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 foreman_hostname=$2
                 shift
             else
                 printf 'ERROR: "--foreman_hostname" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --foreman_hostname=?*)
             foreman_hostname=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --foreman_hostname=)         # Handle the case of an empty --foreman_hostname=
             printf 'ERROR: "--foreman_hostname" requires a non-empty option argument.\n' >&2
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
elif [ ! $foreman_hostname ]; then
    echo "foreman_hostname is a required option."
    exit 1
elif [ ! $domain ]; then
    echo "domain is a required option."
    exit 1
elif [ ! $priv_vpc_cidr ]; then
    echo "priv_vpc_cidr is a required option."
    exit 1
fi


## Derived variables
realm=$(echo $domain | tr '[:lower:]' '[:upper:]')
domain_prefix=$(echo $domain | cut -f1 -d.)
domain_suffix=$(echo $domain | cut -f2 -d.)
realm_prefix=$(echo $realm | cut -f1 -d.)
realm_suffix=$(echo $realm | cut -f2 -d.)
IPADDR=`/usr/bin/curl -s http://169.254.169.254/latest/meta-data/local-ipv4`
rz3=$(echo $IPADDR | cut -f1 -d.)
rz2=$(echo $IPADDR | cut -f2 -d.)
rz1=$(echo $IPADDR | cut -f3 -d.)
pz3=$(echo $priv_vpc_cidr | cut -f1 -d.)
pz2=$(echo $priv_vpc_cidr | cut -f2 -d.)
ptr=$(echo $IPADDR | cut -f4 -d.)


## Install IPA Master
/usr/sbin/ipa-server-install -a $ipa_admin_password --hostname=${ipa_master_hostname}.${domain} \
-n $domain -p $ipa_admin_password -r $realm --forwarder=$dns_forwarder --setup-dns --ip-address $IPADDR -U 

## Create reverse zones and ptr record
echo $ipa_admin_password | kinit admin
ipa dnszone-add ${rz1}.${rz2}.${rz3}.in-addr.arpa. --allow-sync-ptr=true --dynamic-update=true
ipa dnszone-add ${pz2}.${pz3}.in-addr.arpa. --allow-sync-ptr=true --dynamic-update=true
ipa dnszone-mod $domain --allow-sync-ptr=True
ipa dnsrecord-add ${rz1}.${rz2}.${rz3}.in-addr.arpa. $ptr --ptr-hostname=${ipa_master_hostname}.${domain}.  

## Create puppet and puppet-ca CNAMEs
ipa dnsrecord-add $domain puppet --cname-hostname=${foreman_hostname}.${domain}.
ipa dnsrecord-add $domain puppet-ca --cname-hostname=${foreman_hostname}.${domain}.

## Create sudoers
ipa sudorule-add god-mode --desc="God mode on all servers as all users" --cmdcat=all --hostcat=all --runasusercat=all --runasgroupcat=all
ipa sudorule-add-user god-mode --groups=admins
ipa sudorule-add-option god-mode --sudooption='!authenticate'
ipa sudorule-add-option god-mode --sudooption='!requiretty'

## Create service_accounts group and adjust policy to not expire passwords
ipa group_add service_accounts
ipa pwpolicy-add service_accounts --priority=100 --maxlife=10000

## Create jenkins user and add to service_acounts group. Also "hard" set password
ipa user-add jenkins --first=Jenkins --last="Jenkins Orchestration Service Account" \
--cn="Jenkins Orchestration Service Account" --displayname="Jenkins Orchestration Service Account" \
--initials=JR --gecos="Jenkins Orchestration Service Account" --shell=/bin/sh --homedir=/tmp
ipa  group-add-member service_accounts --users=jenkins
ldappasswd  -D 'cn=directory manager' -w $ipa_admin_password -s Sigma-Jenkins2017 -S uid=jenkins,cn=users,cn=accounts,dc=${domain_prefix},dc=${domain_suffix}

## Create openfire user and add to service_acounts group. Also "hard" set password
ipa user-add openfire --first=Open --last=Fire \
--cn="Open Fire Service Account" --displayname="Open Fire Service Account" \
--initials=OF --gecos="Open Fire Service Account" --shell=/bin/sh --homedir=/home/openfire
ipa  group-add-member service_accounts --users=openfire
ldappasswd  -D 'cn=directory manager' -w $ipa_admin_password -s Sigma-OpenFire2017 -S uid=openfire,cn=users,cn=accounts,dc=${domain_prefix},dc=${domain_suffix}

## Create rundeck_orch user and add to service_acounts group. Also "hard" set password
ipa user-add rundeck_orch --first=RunDeck --last=Orchestration \
--cn="RunDeck Orchestration Service Account" --displayname="RunDeck Orchestration Service Account" \
--initials=RO --gecos="RunDeck Orchestration Service Account" --shell=/bin/sh --homedir=/tmp
ipa  group-add-member service_accounts --users=rundeck_orch
ldappasswd  -D 'cn=directory manager' -w $ipa_admin_password -s Sigma-RunDeck2017 -S uid=rundeck_orch,cn=users,cn=accounts,dc=${domain_prefix},dc=${domain_suffix}

## Create readonly user and add to service_acounts group. Also "hard" set password
ipa user-add readonly --first=Read --last=Only \
--cn="Read Only Service Account" --displayname="Read Only Service Account" \
--initials=RO --gecos="Read Only Service Account" --shell=/bin/sh --homedir=/tmp
ipa  group-add-member service_accounts --users=readonly
ldappasswd  -D 'cn=directory manager' -w $ipa_admin_password -s RomeoOscar2017 -S uid=readonly,cn=users,cn=accounts,dc=${domain_prefix},dc=${domain_suffix}

## Set up audit logging and accesslog rotation  
cat << EOF > /root/logs.ldif
dn: cn=config
changetype: modify
replace: nsslapd-accesslog-logging-enabled
nsslapd-accesslog-logging-enabled: on
-
replace: nsslapd-auditlog-logging-enabled
nsslapd-auditlog-logging-enabled: on
-
replace: nsslapd-auditfaillog-logging-enabled
nsslapd-auditfaillog-logging-enabled: on
-
replace: nsslapd-accesslog-level
nsslapd-accesslog-level: 256
-
replace: nsslapd-accesslog-logbuffering
nsslapd-accesslog-logbuffering: on
-
replace: nsslapd-accesslog-logrotationtime
nsslapd-accesslog-logrotationtime: 1
-
replace: nsslapd-accesslog-logrotationtimeunit
nsslapd-accesslog-logrotationtimeunit: day
-
replace: nsslapd-accesslog-maxlogsize
nsslapd-accesslog-maxlogsize: 500
-
replace: nsslapd-accesslog-maxlogsperdir
nsslapd-accesslog-maxlogsperdir: 100
-
replace: nsslapd-accesslog-logexpirationtime
nsslapd-accesslog-logexpirationtime: 3
-
replace: nsslapd-accesslog-logexpirationtimeunit
nsslapd-accesslog-logexpirationtimeunit: month
-
replace: nsslapd-accesslog-logmaxdiskspace
nsslapd-accesslog-logmaxdiskspace: 20000
-
replace: nsslapd-accesslog-logminfreediskspace
nsslapd-accesslog-logminfreediskspace: 500
EOF
/bin/ldapmodify -h localhost -D 'cn=directory manager' -w $ipa_admin_password -f /root/logs.ldif 
rm /root/logs.ldif

## Set up rsyslog to add dirsrv files
cat << EOF > /etc/rsyslog.d/dirsrv.conf
module(load="imfile" PollingInterval="2")


input(type="imfile"
       File="/var/log/dirsrv/slapd-${realm_prefix}-${realm_suffix}/access"
       Tag="dirsrv"
       StateFile="statedirsrv"
       Facility="local0")
 
 input(type="imfile"
       File="/var/log/dirsrv/slapd-${realm_prefix}-${realm_suffix}/errors"
       Tag="dirsrv"
       StateFile="statedirsrverr"
       Severity="error"
       Facility="local0")

 input(type="imfile"
       File="/var/log/dirsrv/slapd-${realm_prefix}-${realm_suffix}/audit"
       Tag="dirsrv"
       StateFile="statedirsrvaud"
       Facility="local0")
EOF
## Restart rsyslog
/sbin/systemctl restart rsyslog
