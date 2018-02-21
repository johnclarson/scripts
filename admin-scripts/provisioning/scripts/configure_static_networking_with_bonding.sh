#!/usr/bin/env bash


# Configure static network interface
systemctl disable NetworkManager
systemctl stop NetworkManager
primary_interface=$( netstat -rn | grep "^\s*0.0.0.0" | awk '{ print $8 }' )
primary_gateway=$( netstat -rn | grep "^\s*0.0.0.0" | awk '{ print $2 }' )
primary_ip=$( ip addr show | grep inet | grep "${primary_interface}" | awk '{ print $2 }' | awk -F '/' '{ print $1 }' )
primary_netmask=$( ifconfig | grep "inet ${primary_ip}" | awk '{ print $4 }' )
fqdn=$( hostname -f )

cat << EOF > /etc/hostname
${fqdn}
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-${primary_interface}
DEVICE="${primary_interface}"
TYPE="Ethernet"
BOOTPROTO="static"
NM_CONTROLLED="no"
ONBOOT="yes"
USERCTL="no"
MASTER="bond0"
SLAVE="yes"
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-bond0
DEVICE="bond0"
ONBOOT="yes"
BRIDGE="br0"
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-br0
DEVICE="br0"
TYPE="bridge"
BOOTPROTO="static"
ONBOOT=yes
PEERDNS=yes
PEERROUTES=yes
DEFROUTE=yes
IPADDR="${primary_ip}"
NETMASK="${primary_netmask}"
GATEWAY="${primary_gateway}"
STP="off"
DELAY="0"
EOF

cat << EOF > /etc/modprobe.d/bond0.conf
alias bond0 bonding
options bond0 miimon=100 mode=4 lacp_rate=1 xmit_hash_policy=layer3+4
EOF

systemctl restart network


