# JaMaK Release Channel

This repository hosts the lightweight JaMaK installer stubs and update manifests.

JaMaK itself remains local-first: the installer downloads the core app zip, installs into the current user's profile, adds an embedded Python runtime if needed, and lets the app download AI models and runtime engines on demand.

## Install

Download `JaMaKSetup.cmd` from this repository and run it. It does not require administrator rights by default.

Default install location:

```text
%LOCALAPPDATA%\Programs\JaMaK
```

Release assets are attached to GitHub releases. The current manifest files are:

- `latest.json`
- `release-manifest.json`

The core app package intentionally excludes local model weights, downloaded engines, uploads, generated outputs, and job memory.
