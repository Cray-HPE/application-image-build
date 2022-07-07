%global commit @COMMIT@
%global shortcommit %(c=%{commit}; echo ${c:0:7})

Name:           ceph-ansible
Version:        @VERSION@
Release:        @RELEASE@%{?dist}
Summary:        Ansible playbooks for Ceph
# Some files have been copied from Ansible (GPLv3+). For example:
#  library/ceph_facts
#  plugins/actions/config_template.py
#  roles/ceph-common/plugins/actions/config_template.py
License:        ASL 2.0 and GPLv3+
URL:            https://github.com/ceph/ceph-ansible
Source0:        %{name}-%{version}-%{shortcommit}.tar.gz
Obsoletes:      ceph-iscsi-ansible <= 1.5

BuildArch:      noarch

BuildRequires: ansible >= 2.8
Requires: ansible >= 2.8

%if 0%{?rhel} == 7
BuildRequires: python2-devel
Requires: python2-netaddr
%else
BuildRequires: python3-devel
Requires: python3-netaddr
%endif

%description
Ansible playbooks for Ceph

%prep
%autosetup -p1

%build

%install
mkdir -p %{buildroot}%{_datarootdir}/ceph-ansible

for f in ansible.cfg *.yml *.sample group_vars roles library plugins infrastructure-playbooks; do
  cp -a $f %{buildroot}%{_datarootdir}/ceph-ansible
done

pushd %{buildroot}%{_datarootdir}/ceph-ansible
  # These untested playbooks are too unstable for users.
  rm -r infrastructure-playbooks/untested-by-ci
  %if ! 0%{?fedora} && ! 0%{?centos}
    # remove ability to install ceph community version
    rm roles/ceph-common/tasks/installs/redhat_{community,dev}_repository.yml
    # Ship only the Red Hat Ceph Storage config (overwrite upstream settings)
    cp group_vars/rhcs.yml.sample group_vars/all.yml.sample
  %endif
popd

%check
# Borrowed from upstream's .travis.yml:
ansible-playbook -i dummy-ansible-hosts test.yml --syntax-check

%files
%doc README.rst
%license LICENSE
%{_datarootdir}/ceph-ansible

%changelog
