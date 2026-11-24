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

## Build & Local Verification

Clone the repo and build with **podman** (recommended) or docker:

```bash
# Using podman-compose (recommended)
podman compose build
podman compose up

# Or using docker
docker compose build
docker compose up
```

The AppImage will appear in `./release/wsjtz-x86_64.AppImage`.

### Testing the AppImage locally before releasing

Every build already runs an internal smoke test inside the container (`Dockerfile` step 7).  
To verify the produced `./release/wsjtz-x86_64.AppImage` on your host machine (checks AUR `PKGBUILD` icon/desktop extraction, bundled Qt5 audio/platform plugins, `qt.conf`, dynamic linking via `ldd`, `jt9` decoder, and headless GUI startup):

```bash
./test-appimage.sh ./release/wsjtz-x86_64.AppImage
```

### Safe Release Workflow (GitHub Actions & Branches)

The repository includes `.github/workflows/build.yml` which runs the exact same Docker build and `./test-appimage.sh` verification on GitHub Actions:
1. **Test on a branch or PR (no public release created):**
   Push changes to any branch (`main`, `fix/*`, `feat/*`, `test/*`) or trigger the workflow manually (**Actions → Build & Verify WSJT-Z AppImage → Run workflow** with `create_release = false`). GitHub Actions will build, verify, and upload the AppImage as a downloadable workflow artifact without creating a public release.
2. **Publish an official Release:**
   Once verified, either push a version tag (`git tag v2.0.20 && git push origin v2.0.20`) or trigger **Run workflow** with `create_release = true`.

### Updating to a new WSJT-Z version

Edit `compose.yaml` and change `wsjtz_version` to the desired release tag (without the `v` prefix).  
Available tags: https://github.com/sq9fve/wsjt-z/releases

## WSJT-Z source
https://github.com/sq9fve/wsjt-z  
*(Previously hosted on SourceForge; moved to GitHub in May 2026.)*

## Versioning
For simplicity, the AppImage release version matches the upstream WSJT-Z version.
