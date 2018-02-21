Name: sync-repos		
Version: 6.1.45
Release:	1%{?dist}
Summary: A utility that manages yum repos for Sigma	

Group: Applications/Internet		
BuildRoot: %{_tmppath}/%{name}-root
License: GPL	
URL: http://sigma.dsci		
Source0: %{name}-%{version}.tar.gz	
BuildArch: noarch
Requires: bash awscli

%description
A collection of scripts that support Sigma DevOps


%prep
%setup -q


%build


%install
rm -rf ${RPM_BUILD_ROOT}
mkdir -p ${RPM_BUILD_ROOT}/usr/bin
mkdir -p ${RPM_BUILD_ROOT}/etc/sysconfig/reposync
install -m 755 scripts/sync_repos.sh ${RPM_BUILD_ROOT}%{_bindir}
install -m 644 configs/reposync.conf ${RPM_BUILD_ROOT}/etc/sysconfig/reposync
install -m 644 configs/dto_repo.conf ${RPM_BUILD_ROOT}/etc/sysconfig/reposync
install -m 644 configs/dto_export_buckets.conf ${RPM_BUILD_ROOT}/etc/sysconfig/reposync

%clean
rm -rf ${RPM_BUILD_ROOT}

%files
%defattr(-,root,root)
%attr(755,root,root) %{_bindir}/sync_repos.sh
%attr(644,root,root) /etc/sysconfig/reposync/reposync.conf
%attr(644,root,root) /etc/sysconfig/reposync/dto_repo.conf
%attr(644,root,root) /etc/sysconfig/reposync/dto_export_buckets.conf



%changelog
* Wed Jan 17 2018 Unknown name 6.1.45-1
- jl:added CUDA repo for GPU machines (root@c-repo-1.sigma.dsci)

* Mon Jan 15 2018 Unknown name 6.1.44-1
- jl:changed how createrepos are performed as previous method was inconsistent
  (root@c-repo-1.sigma.dsci)

* Thu Dec 07 2017 Unknown name 6.1.43-1
- jl:added log processing and fixed a typo where a slash in a bucket name was
  causing issues (segfault@sigma.dsci)

* Tue Dec 05 2017 Unknown name 6.1.42-1
- jl:adding sclo repos to configuration for upload (segfault@sigma.dsci)

* Tue Dec 05 2017 Unknown name 6.1.41-1
- jl:adding epel and centos repos to configuration for upload
  (segfault@sigma.dsci)

* Tue Dec 05 2017 Unknown name 6.1.40-1
- jl:missed a bracket (segfault@sigma.dsci)

* Fri Nov 17 2017 Unknown name 6.1.39-1
- jl:Adding sync to S3 from local data (segfault@sigma.dsci)

* Mon Nov 06 2017 Unknown name 6.1.38-1
- added S3 sync of snapshots (segfault@sigma.dsci)
- jl:removed sigma-up dto export bucket (segfault@sigma.dsci)

* Thu Oct 26 2017 Unknown name 6.1.37-1
- changed yum amd yum snapshots default locations (segfault@sigma.dsci)

* Tue Oct 24 2017 Unknown name 6.1.36-1
- jl:added --download-metadata to reposync to get comps.xml file/s;changed
  regexp for dto tarball extraction (root@c-repo-1.sigma.dsci)

* Tue Oct 24 2017 Unknown name 6.1.35-1
- jl:added new config file for dto export buckets; added aws options to handle
  endpoint_urls (root@c-repo-1.sigma.dsci)

* Wed Oct 18 2017 Unknown name 6.1.34-1
- jl:added new variable for snapshot directory and cleaned up comments
  (root@c-repo-1.sigma.dsci)
- jl:changed import function to deal with time machine repo servers, added new
  variable (root@c-repo-1.sigma.dsci)

* Tue Aug 08 2017 Unknown name 6.1.33-1
- added sclo-rh and sclo-sclo repos (segfault@sigma.dsci)

* Tue Aug 01 2017 Unknown name 6.1.32-1
- added --region args for ALL aws cli commands (segfault@sigma.dsci)

* Fri Jul 21 2017 Unknown name 6.1.31-1
- jl: Made bucket_region a variable that can be changed on the command line
  (segfault@sigma.dsci)

* Fri Jul 21 2017 Unknown name 6.1.30-1
- jl: Added sigma-elrepo to dto config (segfault@sigma.dsci)

* Fri Jul 21 2017 Unknown name 6.1.29-1
- jl: check for existence of add and remove directives in import *before*
  processing (segfault@sigma.dsci)

* Thu Jul 20 2017 Unknown name 6.1.28-1
- updated spec with new config file. (root@c-repo-1.sigma.dsci)

* Thu Jul 20 2017 Unknown name 6.1.27-1
- Added new config file for DTO repos. Previously, new repos were not being
  processed for DTO. (segfault@sigma.dsci)

* Wed Jul 19 2017 Unknown name 6.1.26-1
- added foreman 1.14 and 1.15 with plugins to config (segfault@sigma.dsci)

* Wed Jul 19 2017 Unknown name 6.1.25-1
- 
Added foreman 1.14 and 1.15 to config. jl

* Tue Jun 13 2017 John Larson <segfault@sigma.dsci> 6.1.24-1
- changed elrepo URL (segfault@sigma.dsci)

* Tue Jun 13 2017 Unknown name 6.1.23-1
- typo in elrepo definition (segfault@sigma.dsci)

* Mon Jun 12 2017 Unknown name 6.1.22-1
- Adding Elrepo source for DRBD rpms (segfault@sigma.dsci)

* Thu May 25 2017 Unknown name 6.1.21-1
- jl: added yum pid check and yum clean all as puppet runs interfere with the
  reposyncs (root@c-repo-1.sigma.dsci)

* Thu May 25 2017 Unknown name 6.1.20-1
- jl: Added a yum clean all and a removal of repodata directory for reposync
  (root@c-repo-1.sigma.dsci)

* Thu May 25 2017 Unknown name 6.1.19-1
- jl: added conditional for s3 sync (root@c-repo-1.sigma.dsci)

* Wed May 24 2017 John Larson
Added sigma to grep line to prevent main from being processed
- 

* Wed May 24 2017 John Larson
Changed sync destination and location of conf file
- 

* Wed May 24 2017 Unknown name 6.1.18-1
- jl:changed root directory from /data/yum to /data/sync_repo
  (root@c-repo-1.sigma.dsci)

* Wed May 24 2017 John Larson
- jl: Removed all custom tarball operations. Export function will manage local
  repos now (root@c-repo-1.sigma.dsci)

* Mon May 22 2017 Unknown name 6.1.14-1
- jl:Added sigma to grep for repos...for sure this time
  (root@c-repo-1.sigma.dsci)

* Mon May 22 2017 Unknown name 6.1.13-1
- jl: added sigma to grep for repos to exclude main (root@c-repo-1.sigma.dsci)

* Mon May 22 2017 Unknown name 6.1.12-1
- 

* Mon May 22 2017 Unknown name 6.1.11-1
- jl:typo in reposync.external.repo (root@c-repo-1.sigma.dsci)

* Mon May 22 2017 Unknown name 6.1.10-1
- jl:typos in spec file (root@c-repo-1.sigma.dsci)

* Mon May 22 2017 Unknown name 6.1.9-1
- 

* Mon May 22 2017 Unknown name 6.1.8-1
- jl: Added new conf file for yum and a directory for configured repos.
  Existing config was allowing /etc/yum.repos.d to get parsed and added to the
  sync operation. (root@c-repo-1.sigma.dsci)

* Mon May 22 2017 Unknown name 6.1.7-1
- jl:Added top section to repo config to prevent duplication
  (root@c-repo-1.sigma.dsci)

* Mon May 22 2017 Unknown name 6.1.6-1
- jl:changed reposync config file location (root@c-repo-1.sigma.dsci)

* Thu May 18 2017 john Larson
Test
- 

* Thu May 18 2017 John Larson

test of versioning function
- 

* Wed May 17 2017 John Larson
- new package built with tito

* Tue May 16 2017 John Larson
Added awscli to requires
- 

* Tue May 16 2017 Unknown name 6.1.2-1
- 

* Tue May 16 2017 John Larson
Trying to get tagger to update version not release
- 

* Tue May 16 2017 John Larson <segfault@sigma.dsci> 5.1-1
- 

* Tue May 16 2017 John Larson <segfault@sigma.dsci> 4.1-1
- 

* Tue May 16 2017 John Larson <segfault@sigma.dsci> 3.1-1
- 

* Tue May 16 2017 John Larson <segfault@sigma.dsci> 2.1-1
- 

* Tue May 16 2017 Unknown name 6.1-1
- new package built with tito

* Tue May 16 2017 John Larson <segfault@sigma.dsci>
- Initial spec

