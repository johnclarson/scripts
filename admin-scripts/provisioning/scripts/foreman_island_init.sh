#!/usr/bin/env bash

set -e 

domain=$1
realm=$2
top_domain=$( echo "${realm}" | tr '[:upper:]' '[:lower:]' )
fqdn=$( hostname -f )

if [ "${domain}" == "" ]; then
    echo "Oops.  Please supply the DOMAIN (ie: p1.sigma.dsci) as the first argument to this script."
    echo "Oops.  Please supply the REALM (ie: SIGMA.DSCI) as the second argument to this script."
    exit 1
fi

if [ "${realm}" == "" ]; then
    echo "Oops.  Please supply the REALM (ie: SIGMA.DSCI) as the second argument to this script."
    exit 1
fi

if [ ! -f /root/foreman.${domain}.key ]; then
    echo "NOTE:  You must copy the foreman.${domain}.{crt,key} from c-ipa-1 to /root/ prior to running this script."
    exit 1
fi

if [ ! -f /root/freeipa.keytab ]; then
    echo "NOTE:  You must copy the /etc/foreman-proxy/freeipa.keytab from c-prov-1 to /root/ prior to running this script."
    exit 1
fi

if ! rpm -qa | grep foreman-installer >/dev/null 2>&1; then
    yum install foreman-installer
fi

## Add IPA DNS Records
kinit -kt /root/freeipa.keytab realm-proxy@${realm}
ipa dnsrecord-add ${domain}. foreman --cname-hostname=${fqdn}.
ipa dnsrecord-add ${domain}. puppet --cname-hostname=${fqdn}.
ipa dnsrecord-add ${domain}. puppet-ca --cname-hostname=${fqdn}.

## Run the foreman installer
foreman-installer \
  --foreman-configure-epel-repo=false \
  --foreman-configure-scl-repo=false \
  --puppet-dns-alt-names=puppet-ca,puppet-ca.${domain},puppet,puppet.${domain} \
  --enable-foreman-plugin-discovery \
  --enable-foreman-plugin-hooks \
  --enable-foreman-compute-libvirt \
  --enable-foreman-plugin-templates \

## Configure Hammer
mkdir -p /root/.hammer/
cat << EOF > /root/.hammer/cli_config.yml
---

:foreman:
 :host: 'https://foreman.${domain}/'
 :username: 'admin'

EOF

## Configure IPA Realm
rm -f /etc/foreman-proxy/settings.d/realm.yml
cat << EOF > /etc/foreman-proxy/settings.d/realm.yml
--- 
:enabled: true
:realm_provider: freeipa
:realm_keytab: /etc/foreman-proxy/freeipa.keytab
:realm_principal: realm-proxy@${realm}
:freeipa_remove_dns: true

EOF
cat << EOF > /etc/foreman-proxy/settings.d/realm_freeipa.yml
---

:keytab_path: /etc/foreman-proxy/freeipa.keytab
:principal: realm-proxy@${realm}
:ipa_config: /etc/ipa/default.conf
:remove_dns: true

EOF

## Configure realm Proxy
rsync -av /root/freeipa.keytab /etc/foreman-proxy/
chown foreman-proxy /etc/foreman-proxy/freeipa.keytab
chmod 600 /etc/foreman-proxy/freeipa.keytab
cp /etc/ipa/ca.crt /etc/pki/ca-trust/source/anchors/ipa.crt
cat /etc/ipa/ca.crt >> /etc/puppetlabs/puppet/ssl/certs/ca.pem
update-ca-trust enable
update-ca-trust
systemctl restart foreman-proxy

chown root:root /root/foreman.${domain}.{crt,key}
chmod 0644 /root/foreman.${domain}.{crt,key}
rsync -av /root/foreman.${domain}.crt /etc/pki/tls/certs/
rsync -av /root/foreman.${domain}.key /etc/pki/tls/private/
sed -i -e "s/SSLCertificateFile.*/SSLCertificateFile      \/etc\/pki\/tls\/certs\/foreman.${domain}.crt/" /etc/httpd/conf.d/05-foreman-ssl.conf
sed -i -e "s/SSLCertificateKeyFile.*/SSLCertificateKeyFile   \/etc\/pki\/tls\/private\/foreman.${domain}.key/" /etc/httpd/conf.d/05-foreman-ssl.conf
sed -i -e "s/SSLCertificateChainFile.*/SSLCertificateChainFile \/etc\/ipa\/ca.crt/" /etc/httpd/conf.d/05-foreman-ssl.conf
systemctl restart httpd

## Configure Puppet Server
sed -i -e "s/^:url:.*$/:url: \"https:\/\/foreman.${domain}\"/" /etc/puppetlabs/puppet/foreman.yaml
sed -i -e "s/^:ssl_ca:.*$/:ssl_ca: \"/etc/puppetlabs/puppet/ssl/certs/ca.pem\"/" /etc/puppetlabs/puppet/foreman.yaml
cat << EOF > /etc/puppetlabs/puppet/hiera.yaml
---
:backends:
  - yaml
:hierarchy:
  - "nodes/%{::trusted.certname}"
  - "island/%{::puppet_island}"
  - "roles/%{::puppet_role}"
  - "environments/%{::puppet_environment}"
  - common
:yaml:
  :datadir:  /etc/puppetlabs/code/environments/%{::environment}/hieradata
  :merge_behavior:  deeper

EOF
cat << EOF > /etc/puppetlabs/puppet/fileserver.conf
[binaries]
  path /data/puppetlabs/binaries
  allow *

EOF
cat << EOF > /etc/puppetlabs/puppet/autosign.conf
*.${domain}
EOF

systemctl restart puppetserver


