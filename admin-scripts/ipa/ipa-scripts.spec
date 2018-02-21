Name:          ipa-scripts
Version:       0.1
Release:       1%{?dist}
Summary:       A collection of scripts used to manage IPA resources in Sigma

Group:         Applications/Internet
BuildRoot:     %{_tmppath}/%{name}-tito
License:       GPL
URL:           http://sigma.dsci
Source0:       https://gitlab/api/v3/projects/sigma%2Fadmin-scripts/repository/archive.tgz?sha=%{name}-%{version}-%{release}
BuildArch:     noarch
Requires:      bash
Requires:      ipa-admintools
Requires:      openldap-clients

%description
###############################################################################
Part of a collection of scripts that support Sigma DevOps. This package
installs IPA-specific scripts for working with the IPA command line interface
and LDAP daemon.


%prep
%setup -q -n ipa-scripts-%{version}


%build


%install
rm -rf ${RPM_BUILD_ROOT}
%{__mkdir_p} ${RPM_BUILD_ROOT}/root/ipa-scripts/
#install -m 0750 -d ${RPM_BUILD_ROOT}/root/ipa-scripts/
install -m 0750 ./* ${RPM_BUILD_ROOT}/root/ipa-scripts/
# install -m 0750 backup_ipa_ldap.sh ${RPM_BUILD_ROOT}/root/ipa-scripts/backup_ipa_ldap.sh

%clean
rm -rf ${RPM_BUILD_ROOT}

%files
%defattr(-,root,root)
%dir /root/ipa-scripts/
%attr(750,root,root) /root/ipa-scripts/*

%changelog
* Fri May 19 2017 Dan L <daniel.lindorf@gmail.com> 0.1-1
- new ipa-scripts package built with tito



