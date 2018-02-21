#!/usr/bin/env bash

#################################################################################################
# Populate Foreman with Hammer CLI commands
#################################################################################################
# Configure hammer CA certificate and test hammer
# hap=$( grep "admin_password. value:" /var/log/foreman-installer/foreman.log | sed -e 's/^.*value: "//' -e 's/"$//' )
hap=SigmaTown2016
domain="sigma.dsci"
realm="SIGMA.DSCI"
subdomain="p1"
dns1="172.26.254.98"
network="172.26.0.0"
netmask="255.255.0.0"
gateway="172.26.0.1"
bind_dn="dc=sigma,dc=dsci"
os_major="7"
os_minor="4"
os_increment="1708"
os_title="CentOS Linux ${os_major}.${os_minor}.${os_increment}"
fqdn=$( hostname -f )

if [ ! -f /root/.hammer/certs/foreman.${subdomain}.${domain}_443.pem ]; then
  hammer -p ${hap} --fetch-ca-cert https://foreman.${subdomain}.${domain}/
fi

hammer -p ${hap} auth-source ldap create --name FreeIPA --server-type posix --host ipa.${subdomain}.${domain} --port 389 --base-dn "${bind_dn}" --groups-base "${bind_dn}"

hammer -p ${hap} environment create --name ${subdomain}
hammer -p ${hap} domain create --description  "${subdomain}.${domain} - Physical Island 1" --name ${subdomain}.${domain}
hammer -p ${hap} domain create --description  "${domain} - Platform Global Environment" --name ${domain}

#hammer -p ${hap} proxy create --name "${fqdn}" --url https://${fqdn}:8443
hammer -p ${hap} proxy update --name "${fqdn}"
hammer -p ${hap} proxy refresh-features --name "${fqdn}"
proxy_id=$( hammer -p ${hap} --output json proxy info --name "${fqdn}" | jq .Id )

hammer -p ${hap} subnet create --name ${subdomain}Net --boot-mode Static --dns-primary ${dns1} --domains ${subdomain}.${domain} --network ${network} --mask ${netmask} --gateway ${gateway} --tftp-id ${proxy_id}

hammer -p ${hap} realm create --name ${realm} --realm-type "FreeIPA" --realm-proxy-id ${proxy_id}

hammer -p ${hap} global-parameter set --name custom_search_domains --value "${subdomain}.${domain}, ${domain}" --hidden-value false
hammer -p ${hap} global-parameter set --name disable-firewall --value true --hidden-value false
hammer -p ${hap} global-parameter set --name enable_bare_metal --value false  --hidden-value false
hammer -p ${hap} global-parameter set --name enable_ec2 --value true --hidden-value false
hammer -p ${hap} global-parameter set --name enable-epel --value false --hidden-value false
hammer -p ${hap} global-parameter set --name enable-puppetlabs-pc1-repo --value true  --hidden-value false
hammer -p ${hap} global-parameter set --name freeipa_mkhomedir --value false --hidden-value false
hammer -p ${hap} global-parameter set --name freeipa_opts --value "--request-cert --no-dns-sshfp --enable-dns-updates" --hidden-value false
hammer -p ${hap} global-parameter set --name freeipa_register_host --value true --hidden-value false
hammer -p ${hap} global-parameter set --name graphical_environment --value false --hidden-value false
hammer -p ${hap} global-parameter set --name install_yum_updates --value true --hidden-value false
hammer -p ${hap} global-parameter set --name ntp-server --value "ipa.${subdomain}.${domain}" --hidden-value false
hammer -p ${hap} global-parameter set --name puppet_ca_server --value "puppet" --hidden-value false
hammer -p ${hap} global-parameter set --name puppet_server --value puppet --hidden-value false
hammer -p ${hap} global-parameter set --name selinux-mode --value disabled --hidden-value false
hammer -p ${hap} global-parameter set --name sigma_basdn --value "${bind_dn}" --hidden-value false
hammer -p ${hap} global-parameter set --name sigma_tld --value "${domain}" --hidden-value false
hammer -p ${hap} global-parameter set --name time-zone --value UTC --hidden-value false
hammer -p ${hap} global-parameter set --name yum_host --value "sigma-yum.s3.amazonaws.com"  --hidden-value false

hammer -p ${hap} medium create --name "Sigma CentOS ${os_major}" --os-family Redhat --path http://tftp.${subdomain}.${domain}/CentOS-${os_major}-x86_64-Everything-${os_increment} 

foreman-rake templates:sync repo="https://gitlab.${domain}/sigma/foreman-templates.git" prefix="Sigma - "
hammer -p ${hap} partition-table update --name "Sigma - kickstart-gpt" --os-family "Redhat"

hammer -p ${hap} os create --name CentOS${os_major} --major ${os_major} --minor ${os_minor}.${os_increment} --description "${os_title}" --family "Redhat" --password-hash SHA256 --architectures x86_64  --media "Sigma CentOS ${os_major}" --partition-tables "Sigma - kickstart-gpt" --provisioning-templates "Sigma - kickstart","Sigma - kickstart pxelinux","Sigma - kickstart finish"
os_id=$( hammer -p ${hap} --output json os info --title "${os_title}" | jq .Id )
f_id=$( hammer -p ${hap} --output json template info --name "Sigma - kickstart finish" | jq .Id )
k_id=$( hammer -p ${hap} --output json template info --name "Sigma - kickstart" | jq .Id )
p_id=$( hammer -p ${hap} --output json template info --name "Sigma - kickstart pxelinux" | jq .Id )
hammer -p ${hap} os set-default-template --id ${os_id} --config-template-id ${f_id}
hammer -p ${hap} os set-default-template --id ${os_id} --config-template-id ${k_id}
hammer -p ${hap} os set-default-template --id ${os_id} --config-template-id ${p_id}

hammer -p ${hap} hostgroup create --architecture "x86_64" --ask-root-pass false --domain "${subdomain}.${domain}" --environment "${subdomain}" --medium "Sigma CentOS ${os_major}" --name "${subdomain}" --operatingsystem "${os_title}" --partition-table "Sigma - kickstart-gpt" --puppet-ca-proxy "${fqdn}" --puppet-proxy "${fqdn}" --pxe-loader "PXELinux BIOS" --root-pass "${hap}" --subnet "${subdomain}Net" --realm "${realm}"

hammer -p ${hap} hostgroup set-parameter --hostgroup "${subdomain}" --name "enable_bare_metal" --value "true" --hidden-value false
hammer -p ${hap} hostgroup set-parameter --hostgroup "${subdomain}" --name "enable_ec2" --value "false" --hidden-value false
hammer -p ${hap} hostgroup set-parameter --hostgroup "${subdomain}" --name "freeipa_mkhomedir" --value "true" --hidden-value false
hammer -p ${hap} hostgroup set-parameter --hostgroup "${subdomain}" --name "freeipa_opts" --value "--request-cert --no-dns-sshfp" --hidden-value false
hammer -p ${hap} hostgroup set-parameter --hostgroup "${subdomain}" --name "puppet_environment" --value "${subdomain}" --hidden-value false
hammer -p ${hap} hostgroup set-parameter --hostgroup "${subdomain}" --name puppet_ca_server --value "${fqdn}" --hidden-value false
hammer -p ${hap} hostgroup set-parameter --hostgroup "${subdomain}" --name puppet_server --value "${fqdn}" --hidden-value false
hammer -p ${hap} hostgroup set-parameter --hostgroup "${subdomain}" --name "sigma_subdomain" --value "${subdomain}." --hidden-value false
hammer -p ${hap} hostgroup set-parameter --hostgroup "${subdomain}" --name "yum_host" --value "yum.${subdomain}.${domain}" --hidden-value false

hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "bootstrap_server" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "build_server" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "cloudera_management_service" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "cloudera_manager" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "core_fileserver" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "dto_server" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "hypervisor_server" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "identity_server" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "large_application_optimized" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "large_application_optimized" --name "hadoop_node" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "logging_server" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "mesos_master" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "mesos_slave" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "mysql_database_server" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "nexus_server" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "orchestration_server" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "postgresql_database_server" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "provisioning_server" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "remote_desktop_gateway" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "repo_server" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "sandbox_desktop" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "small_application_optimized" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "small_application_optimized" --name "hadoop_node" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "small_storage_data_optimized" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "small_storage_data_optimized" --name "hadoop_node" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "use_case_remote_desktop_gateway" --pxe-loader "PXELinux BIOS"
hammer -p ${hap} hostgroup create --parent "${subdomain}" --name "zookeeper_server" --pxe-loader "PXELinux BIOS"


hammer -p ${hap} hostgroup set-parameter --hostgroup "cloudera_manager" --name "cloudera_mgr_db_password" --value "cloudera" --hidden-value false
hammer -p ${hap} hostgroup set-parameter --hostgroup "remote_desktop_gateway" --name "guacamole_db_password" --value "guacamole" --hidden-value false
hammer -p ${hap} hostgroup set-parameter --hostgroup "sandbox_desktop" --name "freeipa_mkhomedir" --value "true" --hidden-value false
hammer -p ${hap} hostgroup set-parameter --hostgroup "sandbox_desktop" --name "graphical_environment" --value "true" --hidden-value false


#################################################################################################
# Extras
#################################################################################################
#hammer -p ${hap} compute-resource create --name "p-hyper-20.${subdomain}.${domain}" --provider "Libvirt" --url "qemu+ssh://kvm-manager@p-hyper-20.${subdomain}.${domain}/system"
#hammer -p ${hap} compute-resource image create --compute-resource "p-hyper-20.${subdomain}.${domain}" --name "v-base-20171122_01" --operatingsystem "${os_title}" --username "root" --uuid "/data/kvm/images/v-base-20171122_01.qcow2"  --architecture "x86_64" --user-data "false"
#hammer -p ${hap} compute-resource image create --compute-resource "p-hyper-20.${subdomain}.${domain}" --name "v-base-20171128_01" --operatingsystem "${os_title}" --username "root" --uuid "/data/kvm/images/v-base-20171128_01.qcow2"  --architecture "x86_64" --user-data "true"

