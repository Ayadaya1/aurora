
%include %{_sourcedir}/defines.inc

%global __provides_exclude_from ^%{_datadir}/%{name}/lib/.*$
%global __requires_exclude %{_flutter_excludes}

Name: %{orgName}.%{appName}%{?flavor}
Summary: %{summary}
Version: %{appVersion}
Release: 1
License: %{license}
Source0: %{name}-%{version}.tar.zst

%requires
%dnl Place to add custom BuildRequires.

%global webview_launcher %{_libexecdir}/%{name}/%{name}.webview-subprocess
%global cryptopro_checker %{_libexecdir}/%{name}/ru.auroraos.webview-cryptopro-checker

%description
%{summary}.

%prep
%autosetup

%build
%cmake -GNinja \
       -DCMAKE_BUILD_TYPE=%{_flutter_build_type} \
       -DPSDK_VERSION=%{_flutter_psdk_version} \
       -DPSDK_MAJOR=%{_flutter_psdk_major} \
       -DWEBVIEW_SUBPROCESS_LAUNCHER_INSTALL_PATH=%{webview_launcher} \
       -DFLUTTER_PROJECT_NAME=%{name} \
       -DFLUTTER_ORG_NAME=%{orgName}
%ninja_build

%install
%ninja_install
mkdir -p %{buildroot}%{_libexecdir}/%{name}
mv %{buildroot}%{_bindir}/%{name}.webview-subprocess %{buildroot}%{webview_launcher}
mv %{buildroot}%{_libexecdir}/ru.auroraos.webview-cryptopro-checker %{buildroot}%{cryptopro_checker}
chmod +x %{buildroot}%{webview_launcher} %{buildroot}%{cryptopro_checker}

%files
%{_bindir}/%{name}
%{_datadir}/%{name}/*
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png

%{webview_launcher}
%{cryptopro_checker}
