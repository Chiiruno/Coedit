<p align="center">
  <img src="https://github.com/BBasile/Coedit/raw/master/logo/coedit.png?raw=true" width="15%" height="15%" alt="CE"/>
</p>

Coedit is an IDE for the [D programming language](https://dlang.org), its compilers, tools and libraries.

[![](https://bbasile.github.io/Coedit/img/coedit_kde4_thumb.png)](https://bbasile.github.io/Coedit/img/coedit_kde4.png)

**Overview**
---
- available for _Linux_, _FreeBSD_ or _Windows_.
- supports all the D compilers (DMD-GDC-LDC).
- supports the DUB projects (JSON or SDL) and also Coedit own project format.
- support the DUB scripts (aka _single file packages_) and Coedit own script format (aka _runnable modules_).
- full [D Completion Daemon](https://github.com/dlang-community/DCD) integration (completion, ddoc display, call tips, jump to declaration, rename identifier).
- Dynamic [D-Scanner](https://github.com/dlang-community/D-Scanner) linting with results displayed in the editor gutter.
- single click to compile and to _unittest_ a module and optionally display tests coverage.
- advanced editor with D2 syntax highlighter, folds, regions, identifier markup, macros, sync-edit, etc.
- edition helpers: comment blocks, local identifier renaming, brace auto-closing, ddoc templates, etc.
- GDB gui under linux.
- Tree of symbols in the current module.
- static libraries manager that supports auto-registration from local DUB projects, from online DUB packages or from Coedit custom project format.
- todo list based on the _todo comments_ located in a project or in the current source.
- user-defined tools powered by a string interpolation system.
- integrated file browser, dfmt interface, search & replace, [discover more in the manual](https://bbasile.github.io/Coedit/).

**Project information**
---

- latest release: version 3.6.6, Sat 31 Mar 2018.
- licensed under the terms of the Boost software license.
- Development can be supported with [Paypal donations](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=AQDJVC39PJF7J).

**Download version 3.6.6**
---
Download the zipped binaries or the zip that contains the setup program for you platform:

- :package: [setup program for Linux 64 bit](https://github.com/BBasile/Coedit/releases/download/v3.6.6/coedit.3.6.6.linux64.setup.zip)
- :package: [binaries for Linux 64 bit](https://github.com/BBasile/Coedit/releases/download/v3.6.6/coedit.3.6.6.linux64.zip)
- :package: [setup program for Windows 32/64 bit](https://github.com/BBasile/Coedit/releases/download/v3.6.6/coedit.3.6.6.win32.setup.zip)
- :package: [binaries for Windows 32/64 bit](https://github.com/BBasile/Coedit/releases/download/v3.6.6/coedit.3.6.6.win32.zip)
- :package: [rpm for Linux 64 bit](https://github.com/BBasile/Coedit/releases/download/v3.6.6/coedit-3.6.6-0.x86_64.rpm)
- :package: [deb for Linux 64 bit](https://github.com/BBasile/Coedit/releases/download/v3.6.6/coedit-3.6.6.amd64.deb)

The _zip_ archives allow to move freely the files.
The _setup.zip_ archives contains a command line program that installs to predefined locations so that the software can be run without additional intervention.
The _deb_ and the _rpm_ packages are for those who prefer the official setup system for their linux systems.
Linux i386 version must be [built manually](https://bbasile.github.io/Coedit/build.html).

[**See this page**](https://bbasile.github.io/Coedit/setup.html) for more information about the setup.

There is also 3rd part packages, maintained by volunteers, but the available versions are not guaranteed to be the latest:

- :package: [port for FreeBSD](https://www.freshports.org/editors/coedit/)
- :package: [AUR package for ArchLinux](https://aur.archlinux.org/packages/coedit-bin/)

**Build**
---

Follow the procedure described [**here**](https://bbasile.github.io/Coedit/build.html).
