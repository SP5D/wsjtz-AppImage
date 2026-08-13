# wsjtz-AppImage

AppImage of **WSJT-Z** – a fork of WSJT-X with automation features (Auto-CQ, Auto-Call, DXCC filtering, PSK Reporter integration, and more).

Produced AppImage should work like a charm, but there is no guarantee.  
WSJT-Z (and WSJT-X) are surprisingly hard to pack into AppImage with all(!) dependencies.  
Tests have shown that I have provided enough libs for any real desktop, but feel free to lead me out of that error!

## Install

Just download and run the AppImage.

### Arch Linux
This AppImage is available in AUR repository as `wsjtz-appimage`.  
You can use your favorite helper, e.g.:  
```
paru -S wsjtz-appimage
```

### Linux (in general)
```
wget https://github.com/SP5D/wsjtz-AppImage/releases/latest/download/wsjtz-x86_64.AppImage -O /usr/bin/wsjtz-appimage
chmod 755 /usr/bin/wsjtz-appimage
```

## Build

Clone the repo and build with **podman** (recommended) or docker:

```bash
# Using podman-compose (recommended)
podman compose build
podman compose up

# Using docker
docker compose build
docker compose up
```

The AppImage will appear in the `./release/` directory.

### Updating to a new WSJT-Z version

Edit `compose.yaml` and change `wsjtz_version` to the desired release tag (without the `v` prefix).  
Available tags: https://github.com/sq9fve/wsjt-z/releases

## WSJT-Z source
https://github.com/sq9fve/wsjt-z  
*(Previously hosted on SourceForge; moved to GitHub in May 2026.)*

## Versioning
For simplicity, the AppImage release version matches the upstream WSJT-Z version.
