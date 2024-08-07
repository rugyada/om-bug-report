Summary:	%{distribution} bug helper
Name:		om-bug-report
Version:	0.1
Release:	1
License:	GPLv3+
Group:		System/Base
Url:		%{disturl}
Source0:	%{name}.sh
BuildArch:	noarch
%rename omv-bug-report
%rename omdv-bug-report
Requires:	/bin/sh
Requires:	coreutils
Requires:	systemd
Requires:	system-release
Requires:	pciutils
Requires:	usbutils
Requires:	dmidecode
Requires:	systemd-coredump
Requires:	setup
Suggests:	zstd

%description
A simple tool to gather system information to ease bug resolve.

%prep

%build

%install
mkdir -p %{buildroot}%{_bindir}
install -c -m755 %{SOURCE0} %{buildroot}%{_bindir}/%{name}
ln -sf %{_bindir}/%{name} %{buildroot}%{_bindir}/%{name}.sh

# (tpg) keep comapt with old name
ln -sf %{_bindir}/%{name} %{buildroot}%{_bindir}/omv-bug-report.sh
ln -sf %{_bindir}/%{name} %{buildroot}%{_bindir}/omv-bug-report

%files
%{_bindir}/*
