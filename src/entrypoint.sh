#!/usr/bin/bash
set -e
chmod 0755 /build/wsjtz-x86_64.AppImage
cp /build/wsjtz-x86_64.AppImage /release/
chmod 0755 /release/wsjtz-x86_64.AppImage || true
