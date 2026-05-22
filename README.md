# JaMaK Release Channel

This repository hosts the JaMaK Windows installer, fallback installer stubs, and update manifests.

JaMaK itself remains local-first: the installer downloads the core app zip, installs into the current user's profile by default, adds an embedded Python runtime if needed, and lets the app download AI models and runtime engines on demand.

## Install

Download `JaMaKSetup.exe` from the latest GitHub release and run it.

The installer lets users choose the install location, optionally create a desktop shortcut, create Start Menu shortcuts, and uninstall JaMaK from Windows Apps/Programs. It does not require administrator rights by default.

Default install location:

```text
%LOCALAPPDATA%\Programs\JaMaK
```

Fallback script stubs are also available in this repository:

- `JaMaKSetup.cmd`
- `JaMaKSetup.ps1`

Release assets are attached to GitHub releases. The current manifest files are:

- `latest.json`
- `release-manifest.json`

The core app package intentionally excludes local model weights, downloaded engines, uploads, generated outputs, and job memory.
