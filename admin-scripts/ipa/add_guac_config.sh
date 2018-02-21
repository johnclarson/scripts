#!/bin/bash

domain=$(domainname)
domain_prefix=$(echo $domain | cut -f1 -d.)
domain_suffix=$(echo $domain | cut -f2 -d.)
read -p  "Enter username for access: " user 
desktop_default="c-sandbox-${user}.${domain_prefix}.${domain_suffix}"
read -p  "Enter FQDN of desktop [$desktop_default]: "  desktop 
desktop="${desktop:-$desktop_default}"
echo "dn: cn=${user}_rdp,cn=groups,cn=accounts,dc=${domain_prefix},dc=${domain_suffix}
objectClass: guacConfigGroup
objectClass: groupOfNames
objectClass: ipausergroup
objectClass: nestedgroup
objectClass: ipaobject
cn: ${user}_rdp
guacConfigProtocol: rdp
guacConfigParameter: hostname=${desktop}
guacConfigParameter: port=3389
member: uid=${user},cn=users,cn=accounts,dc=${domain_prefix},dc=${domain_suffix}" > /tmp/${user}_rdp.ldif

echo -n "Enter password for IPA LDAP Directory Manager: " 
read -s dmpassword
echo
ldapadd -ZZ -x -D "cn=Directory Manager" -w $dmpassword -H ldap://localhost -f /tmp/${user}_rdp.ldif
rm /tmp/${user}_rdp.ldif

