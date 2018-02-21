#!/bin/bash

dbpassword=
ipa_admin_password=
ipa_master_hostname=
ipa_master_ip=
ipa_slave_ip=
mysqlurl=
foreman_hostname=
domain=
aws_resource_name=
aws_region=
build_bucket=
project_code=
pub_subnet_a_cidr=
pub_subnet_b_cidr=
priv_subnet_a_cidr=
priv_subnet_b_cidr=
yum_host=
verbose=0

show_help() {
    echo "Usage: $0 [option...] " >&2
    echo
    echo "   --priv_subnet_a_cidr       Private subnet A network CIDR "
    echo "   --priv_subnet_b_cidr       Private subnet B network CIDR "
    echo "   --pub_subnet_a_cidr        Public subnet A network CIDR "
    echo "   --pub_subnet_b_cidr        Public subnet B network CIDR "
    echo "   --dbpassword               Password for foreman UI and database "
    echo "   --ipa_admin_password       Password for the IPA admin user "
    echo "   --mysqlurl                 Hostname or endpoint for mysql server "
    echo "   --foreman_hostname         Hostname for the Foreman server "
    echo "   --domain                   IPA domain name "
    echo "   --ipa_master_ip            IP address of IPA master "
    echo "   --ipa_master_hostname      Hostname of IPA master "
    echo "   --ipa_slave_ip             IP address of IPA slave "
    echo "   --aws_resource_name        Desired name of AWS resource in Foreman "
    echo "   --aws_region               AWS region where the Foreman server is "
    echo "   --build_bucket             AWS S3 bucket where build content is "
    echo "   --project_code             Name of git projects tarball in build_bucket "
    echo "   --yum_host                 Name of host where yum repos are stored "
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
         --priv_subnet_a_cidr)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 priv_subnet_a_cidr=$2
                 shift
             else
                 printf 'ERROR: "--priv_subnet_a_cidr" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --priv_subnet_a_cidr=?*)
             priv_subnet_a_cidr=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --priv_subnet_a_cidr=)         # Handle the case of an empty --priv_subnet_a_cidr=
             printf 'ERROR: "--priv_subnet_a_cidr" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --priv_subnet_b_cidr)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 priv_subnet_b_cidr=$2
                 shift
             else
                 printf 'ERROR: "--priv_subnet_b_cidr" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --priv_subnet_b_cidr=?*)
             priv_subnet_b_cidr=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --priv_subnet_b_cidr=)         # Handle the case of an empty --priv_subnet_b_cidr=
             printf 'ERROR: "--priv_subnet_b_cidr" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --pub_subnet_b_cidr)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 pub_subnet_b_cidr=$2
                 shift
             else
                 printf 'ERROR: "--pub_subnet_b_cidr" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --pub_subnet_b_cidr=?*)
             pub_subnet_b_cidr=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --pub_subnet_b_cidr=)         # Handle the case of an empty --pub_subnet_b_cidr=
             printf 'ERROR: "--pub_subnet_b_cidr" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --pub_subnet_a_cidr)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 pub_subnet_a_cidr=$2
                 shift
             else
                 printf 'ERROR: "--pub_subnet_a_cidr" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --pub_subnet_a_cidr=?*)
             pub_subnet_a_cidr=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --pub_subnet_a_cidr=)         # Handle the case of an empty --pub_subnet_a_cidr=
             printf 'ERROR: "--pub_subnet_a_cidr" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --dbpassword)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 dbpassword=$2
                 shift
             else
                 printf 'ERROR: "--dbpassword" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --dbpassword=?*)
             dbpassword=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --dbpassword=)         # Handle the case of an empty --dbpassword=
             printf 'ERROR: "--dbpassword" requires a non-empty option argument.\n' >&2
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
         --mysqlurl)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 mysqlurl=$2
                 shift
             else
                 printf 'ERROR: "--mysqlurl" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --mysqlurl=?*)
             mysqlurl=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --mysqlurl=)         # Handle the case of an empty --mysqlurl=
             printf 'ERROR: "--mysqlurl" requires a non-empty option argument.\n' >&2
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
         --ipa_slave_ip)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 ipa_slave_ip=$2
                 shift
             else
                 printf 'ERROR: "--ipa_slave_ip" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --ipa_slave_ip=?*)
             ipa_slave_ip=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --ipa_slave_ip=)         # Handle the case of an empty --ipa_slave_ip=
             printf 'ERROR: "--ipa_slave_ip" requires a non-empty option argument.\n' >&2
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
         --aws_resource_name)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 aws_resource_name=$2
                 shift
             else
                 printf 'ERROR: "--aws_resource_name" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --aws_resource_name=?*)
             aws_resource_name=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --aws_resource_name=)         # Handle the case of an empty --aws_resource_name=
             printf 'ERROR: "--aws_resource_name" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --aws_region)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 aws_region=$2
                 shift
             else
                 printf 'ERROR: "--aws_region" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --aws_region=?*)
             aws_region=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --aws_region=)         # Handle the case of an empty --aws_region=
             printf 'ERROR: "--aws_region" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --build_bucket)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 build_bucket=$2
                 shift
             else
                 printf 'ERROR: "--build_bucket" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --build_bucket=?*)
             build_bucket=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --build_bucket=)         # Handle the case of an empty --build_bucket=
             printf 'ERROR: "--build_bucket" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --project_code)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 project_code=$2
                 shift
             else
                 printf 'ERROR: "--project_code" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --project_code=?*)
             project_code=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --project_code=)         # Handle the case of an empty --project_code=
             printf 'ERROR: "--project_code" requires a non-empty option argument.\n' >&2
             exit 1
             ;;
         --yum_host)       # Takes an option argument, ensuring it has been specified.
             if [ -n "$2" ]; then
                 yum_host=$2
                 shift
             else
                 printf 'ERROR: "--yum_host" requires a non-empty option argument.\n' >&2
                 exit 1
             fi
             ;;
         --yum_host=?*)
             yum_host=${1#*=} # Delete everything up to "=" and assign the remainder.
             ;;
         --yum_host=)         # Handle the case of an empty --yum_host=
             printf 'ERROR: "--yum_host" requires a non-empty option argument.\n' >&2
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
if [ ! $dbpassword ]; then
    echo "dbpassword is a required option."
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
elif [ ! $ipa_slave_ip ]; then
    echo "ipa_slave_ip is a required option."
    exit 1
elif [ ! $mysqlurl ]; then
    echo "mysqlurl is a required option."
    exit 1
elif [ ! $yum_host ]; then
    echo "yum_host is a required option."
    exit 1
elif [ ! $foreman_hostname ]; then
    echo "foreman_hostname is a required option."
    exit 1
elif [ ! $domain ]; then
    echo "domain is a required option."
    exit 1
elif [ ! $aws_resource_name ]; then
    echo "aws_resource_name is a required option."
    exit 1
elif [ ! $aws_region ]; then
    echo "aws_region is a required option."
    exit 1
elif [ ! $build_bucket ]; then
    echo "build_bucket is a required option."
    exit 1
elif [ ! $project_code ]; then
    echo "project_code is a required option."
    exit 1
elif [ ! $pub_subnet_a_cidr ]; then
    echo "pub_subnet_a_cidr is a required option."
    exit 1
elif [ ! $pub_subnet_b_cidr ]; then
    echo "pub_subnet_b_cidr is a required option."
    exit 1
elif [ ! $priv_subnet_b_cidr ]; then
    echo "priv_subnet_b_cidr is a required option."
    exit 1
elif [ ! $priv_subnet_a_cidr ]; then
    echo "priv_subnet_a_cidr is a required option."
    exit 1
fi


## Derived variables
realm=$(echo $domain | tr '[:lower:]' '[:upper:]')
domain_prefix=$(echo $domain | cut -f1 -d.)
domain_suffix=$(echo $domain | cut -f2 -d.)


# Install foreman with installer
foreman-installer --foreman-configure-epel-repo=false --foreman-configure-scl-repo=false --puppet-dns-alt-names=puppet-ca,puppet-ca.${domain},puppet,puppet.${domain}

## Perform database configurations
sed -i 's/postgresql/mysql2/' /etc/foreman/database.yml
sed -i "s|password.*|password: $dbpassword|" /etc/foreman/database.yml
echo "  host: $mysqlurl" >> /etc/foreman/database.yml
echo "  port: 3306" >> /etc/foreman/database.yml

## Migrate database
su -s /bin/bash -c 'cd /usr/share/foreman && tfm-rake db:migrate RAILS_ENV=production' foreman

## Seed database
su -s /bin/bash -c 'cd /usr/share/foreman && tfm-rake db:seed RAILS_ENV=production' foreman

## Restart httpd
service httpd restart

## Reset admin password
su -s /bin/bash -c "cd /usr/share/foreman && tfm-rake permissions:reset password=$dbpassword RAILS_ENV=production" foreman

## Add proxy to mysql
mysql -u foreman --password=$dbpassword -h $mysqlurl foreman -e "insert into smart_proxies (id,name,url) values ('1','local','https://$foreman_hostname.$domain:8443');"

## Fix DNS in prep for IPA client install
rm /etc/resolv.conf
echo "domain $domain" >> /etc/resolv.conf
echo "nameserver $ipa_master_ip" >> /etc/resolv.conf

## Install IPA Client
ipa-client-install -p admin -w $ipa_admin_password --enable-dns-updates --server=$ipa_master_hostname.$domain --domain $domain --no-dns-sshfp -U --force

## Configure IPA Realm
rm /etc/foreman-proxy/settings.d/realm.yml
cat << EOF > /etc/foreman-proxy/settings.d/realm.yml
---
:enabled: true
:realm_provider: freeipa
:realm_keytab: /etc/foreman-proxy/freeipa.keytab
:realm_principal: realm-proxy@${realm}
:freeipa_remove_dns: true
EOF

## Configure realm Proxy
cd /etc/foreman-proxy && echo $ipa_admin_password | foreman-prepare-realm admin realm-proxy
chown foreman-proxy /etc/foreman-proxy/freeipa.keytab
chmod 600 /etc/foreman-proxy/freeipa.keytab
cp /etc/ipa/ca.crt /etc/pki/ca-trust/source/anchors/ipa.crt
update-ca-trust enable
update-ca-trust

## Fix EC2 plugin to use instance role
sed -i 's/:aws_access_key_id => user, :aws_secret_access_key => password/:use_iam_profile => true/g' /usr/share/foreman/app/models/compute_resources/foreman/model/ec2.rb
service httpd restart

## Fix Fog where appropriate
if [ $aws_region = "us-iso-east-1" ]
then
    /bin/sed -i 's/us-east-1/us-iso-east-1/g' /opt/theforeman/tfm/root/usr/share/gems/gems/fog-aws*/lib/fog/aws/compute.rb
    /bin/sed -i 's/amazonaws.com/c2s.ic.gov/g' /opt/theforeman/tfm/root/usr/share/gems/gems/fog-aws*/lib/fog/aws/compute.rb
    /bin/sed -i 's/iam.amazonaws.com/iam.us-iso-east-1.c2s.ic.gov/g' /opt/theforeman/tfm/root/usr/share/gems/gems/fog-aws*/lib/fog/aws/iam.rb
    /bin/sed -i 's/us-east-1/us-iso-east-1/g' /opt/theforeman/tfm/root/usr/share/gems/gems/fog-aws*/lib/fog/aws.rb

    ## Disable SSL verify in excon
    /bin/sed -i 's/ssl_context = OpenSSL::SSL::SSLContext.new/ssl_context = OpenSSL::SSL::SSLContext.new\n      params[:ssl_verify_peer] = false/g' /opt/theforeman/tfm/root/usr/share/gems/gems/excon-*/lib/excon/ssl_socket.rb

fi

## Add AWS Compute Resource
HOME=/root /bin/hammer -u admin -p $dbpassword  compute-resource create --name $aws_resource_name --url $aws_region --provider EC2 --user null --password null
service httpd restart

## Update and refresh proxy
HOME=/root /bin/hammer -u admin -p $dbpassword proxy update --id=1
HOME=/root /bin/hammer -u admin -p $dbpassword proxy refresh-features --id 1

## Download and install puppet code
newenv=production_${domain_prefix}_${domain_suffix}
rm -rf /etc/puppetlabs/code/*
/bin/aws s3 cp --region $aws_region s3://$build_bucket/$project_code /tmp
/bin/tar zxf /tmp/$project_code -C /tmp
/bin/mkdir -p /etc/puppetlabs/code/environments/${newenv}
/bin/mkdir -p /data/puppetlabs/binaries
/bin/rsync -a /tmp/projects/puppet/ -C /etc/puppetlabs/code/environments/${newenv}
/bin/chown -R root:root /etc/puppetlabs/code
/bin/rm -rf /tmp/$project_code
/bin/rm -rf /tmp/projects

## Fix Fileserver configuration for binaries
cat << EOF >> /etc/puppetlabs/puppet/fileserver.conf
[binaries]
  path /data/puppetlabs/binaries
  allow *
EOF

## Copy generic hiera.yaml file from local puppet
/bin/cp /etc/puppetlabs/code/environments/${newenv}/modules/sigma/puppet/files/etc/puppet/hiera.yaml /etc/puppetlabs/puppet/hiera.yaml

## Set up domain specific enviroment
/bin/cp /etc/puppetlabs/code/environments/${newenv}/templates/environment.yaml  /etc/puppetlabs/code/environments/${newenv}/hieradata/environments/${newenv}.yaml
sed -i "s|IPAMASTER|$ipa_master_ip|g" /etc/puppetlabs/code/environments/${newenv}/hieradata/environments/${newenv}.yaml
sed -i "s|IPASLAVE|$ipa_slave_ip|g" /etc/puppetlabs/code/environments/${newenv}/hieradata/environments/${newenv}.yaml
sed -i "s|PROVHOST|$foreman_hostname|g" /etc/puppetlabs/code/environments/${newenv}/hieradata/environments/${newenv}.yaml
mkdir /facts
echo "$newenv" > /facts/puppet_environment.fact
echo "provisioning_server" > /facts/puppet_role.fact
echo "$domain" > /facts/sigma_tld.fact
echo "*.${domain}" >> /etc/puppetlabs/puppet/autosign.conf

## Run puppet
/opt/puppetlabs/bin/puppet agent -t || true

## Create new environment in Foreman and update host
HOME=/root /bin/hammer -u admin -p $dbpassword environment create --name $newenv
HOME=/root /bin/hammer -u admin -p $dbpassword host update --environment $newenv --id 1

## Rsync yaml stuff and restart server and client
/bin/rsync -av /opt/puppetlabs/server/data/puppetserver/yaml/ /opt/puppetlabs/puppet/cache/yaml/
/sbin/service puppetserver restart
/opt/puppetlabs/bin/puppet agent -t || true

## Add realm to Foreman
/bin/mysql -u foreman --password=$dbpassword -h $mysqlurl foreman -e "insert into realms (id,name,realm_type,realm_proxy_id) values ('1','$realm','FreeIPA','1');"
/sbin/service foreman-proxy restart
HOME=/root /bin/hammer -u admin -p $dbpassword proxy update --id=1
HOME=/root /bin/hammer -u admin -p $dbpassword proxy refresh-features --id 1


## Add subnets
pubanm=$(ipcalc -m $pub_subnet_a_cidr | cut -f2 -d=)
pubbnm=$(ipcalc -m $pub_subnet_b_cidr | cut -f2 -d=)
prvanm=$(ipcalc -m $priv_subnet_a_cidr | cut -f2 -d=)
prvbnm=$(ipcalc -m $priv_subnet_b_cidr | cut -f2 -d=)

HOME=/root /bin/hammer -u admin -p $dbpassword subnet create --name public-a --network $pub_subnet_a_cidr --domains $domain --mask $pubanm
HOME=/root /bin/hammer -u admin -p $dbpassword subnet create --name public-b --network $pub_subnet_b_cidr --domains $domain --mask $pubbnm
HOME=/root /bin/hammer -u admin -p $dbpassword subnet create --name private-a --network $priv_subnet_a_cidr --domains $domain --mask $prvanm
HOME=/root /bin/hammer -u admin -p $dbpassword subnet create --name private-b --network $priv_subnet_b_cidr --domains $domain --mask $prvbnm

## Add globals
lines=$(cat /etc/puppetlabs/code/environments/${newenv}/templates/foreman_global_variables)
for line in $lines; do
  KEY=$(echo $line | cut -f1 -d:);
  VALUE=$(echo $line | cut -f2 -d:);
  HOME=/root /bin/hammer -u admin -p $dbpassword global-parameter set --name $KEY --value $VALUE
done
HOME=/root /bin/hammer -u admin -p $dbpassword global-parameter set --name sigma_tld --value $domain
HOME=/root /bin/hammer -u admin -p $dbpassword global-parameter set --name sigma_basedn --value dc=$domain_prefix,dc=$domain_suffix
HOME=/root /bin/hammer -u admin -p $dbpassword global-parameter set --name yum_host --value $yum_host

