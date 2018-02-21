Name: ami-builder		
Version: 0.0.12
Release:	1%{?dist}
Summary: A utility that manages AMI builds for Sigma	

Group: Applications/Internet		
BuildRoot: %{_tmppath}/%{name}-root
License: GPL	
URL: http://sigma.dsci		
Source0: %{name}-%{version}.tar.gz	
BuildArch: noarch
Requires: fabric python2-boto libyaml

%description
A utility that manages AMI builds for Sigma


%prep
%setup -q


%build


%install
rm -rf ${RPM_BUILD_ROOT}
mkdir -p ${RPM_BUILD_ROOT}/usr/bin
mkdir -p ${RPM_BUILD_ROOT}/etc/ami-builder/configs
mkdir -p ${RPM_BUILD_ROOT}/etc/ami-builder/commands
mkdir -p ${RPM_BUILD_ROOT}/etc/ami-builder/keys
install -m 755 ami-builder ${RPM_BUILD_ROOT}%{_bindir}
install -m 755 configs/example.yaml ${RPM_BUILD_ROOT}/etc/ami-builder/configs

%clean
rm -rf ${RPM_BUILD_ROOT}

%files
%defattr(-,root,root)
%attr(755,root,root) %{_bindir}/ami-builder
%attr(700,root,root) /etc/ami-builder/keys
%attr(755,root,root) /etc/ami-builder/configs
%attr(644,root,root) /etc/ami-builder/configs/example.yaml
%attr(755,root,root) /etc/ami-builder/commands



%changelog
* Fri Jan 26 2018 Unknown name 0.0.12-1
- added switches to not process disk creation and to not run scripts
  (segfault@sigma.dsci)

* Mon Jan 08 2018 Unknown name 0.0.11-1
- jl:changed timeout higher to account for latency, added update define
  (root@c-repo-1.sigma.dsci)

* Mon Nov 06 2017 Unknown name 0.0.10-1
- adding new packages to all ami templates (segfault@sigma.dsci)

* Tue May 30 2017 John Larson <segfault@sigma.dsci> 0.0.9-1
- added 1 15 second between EC2 launch and describe instance because it errors
  out occasionally (segfault@sigma.dsci)

* Tue May 30 2017 John Larson <segfault@sigma.dsci> 0.0.8-1
- added region config element to yaml files (segfault@sigma.dsci)

* Tue May 30 2017 John Larson <segfault@sigma.dsci> 0.0.7-1
- Added checks to make sure arrays exist before attempting to process
  (segfault@sigma.dsci)
- Removing pem from git because it shouldnt be there (segfault@sigma.dsci)

* Fri May 26 2017 John Larson <segfault@sigma.dsci> 0.0.6-1
- Another typo (segfault@sigma.dsci)

* Fri May 26 2017 John Larson <segfault@sigma.dsci> 0.0.5-1
- Typo (segfault@sigma.dsci)

* Fri May 26 2017 John Larson <segfault@sigma.dsci> 0.0.4-1
- Added RPM build root to example config (segfault@sigma.dsci)

* Fri May 26 2017 John Larson <segfault@sigma.dsci> 0.0.3-1
- Added directory structure and an example yaml file for rpm build
  (segfault@sigma.dsci)

* Fri May 26 2017 John Larson <segfault@sigma.dsci> 0.0.2-1
- new package built with tito


