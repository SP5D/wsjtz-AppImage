#!/usr/bin/env bash
set -euo pipefail

APPIMAGE="${1:-./release/wsjtz-x86_64.AppImage}"

if [ ! -f "$APPIMAGE" ]; then
    echo "ERROR: AppImage not found at: $APPIMAGE"
    echo "Run 'podman compose build && podman compose up' first."
    exit 1
fi

APPIMAGE="$(readlink -f "$APPIMAGE")"
echo "=== [1/5] Checking file attributes: $APPIMAGE ==="
ls -lh "$APPIMAGE"
file "$APPIMAGE"
sha256sum "$APPIMAGE"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT
cd "$WORKDIR"

echo "=== [2/5] Testing AUR PKGBUILD compatibility (icon & desktop extraction) ==="
"$APPIMAGE" --appimage-extract wsjtx_icon.png >/dev/null
"$APPIMAGE" --appimage-extract wsjtz.desktop >/dev/null
test -f squashfs-root/wsjtx_icon.png && echo "  [OK] wsjtx_icon.png present in AppDir root"
test -f squashfs-root/wsjtz.desktop && echo "  [OK] wsjtz.desktop present in AppDir root"
rm -rf squashfs-root

echo "=== [3/5] Extracting full payload and checking bundled files & plugins ==="
"$APPIMAGE" --appimage-extract >/dev/null
for bin in wsjtx jt9 wsprd ft8code message_aggregator udp_daemon rigctl-wsjtx rigctld-wsjtx rigctlcom-wsjtx; do
    test -x "squashfs-root/usr/bin/$bin" && echo "  [OK] Binary executable: usr/bin/$bin"
done

for data in usr/bin/ALLCALL7.TXT usr/bin/qt.conf usr/share/wsjtx/cty.dat usr/share/wsjtx/USState.db usr/share/wsjtx/JPLEPH; do
    test -f "squashfs-root/$data" && echo "  [OK] Data file present: $data"
done

for plugin in audio/libqtaudio_alsa.so audio/libqtmedia_pulse.so platforms/libqxcb.so sqldrivers/libqsqlite.so; do
    test -f "squashfs-root/usr/plugins/$plugin" && echo "  [OK] Qt5 plugin bundled: usr/plugins/$plugin"
done

echo "=== [4/5] Checking dynamic linking (no missing libraries) ==="
MISSING_LIBS="$(ldd squashfs-root/usr/bin/wsjtx squashfs-root/usr/bin/jt9 squashfs-root/usr/plugins/platforms/libqxcb.so squashfs-root/usr/plugins/audio/*.so | grep "not found" || true)"
if [ -n "$MISSING_LIBS" ]; then
    echo "  [FAIL] Missing shared libraries detected:"
    echo "$MISSING_LIBS"
    exit 1
fi
echo "  [OK] All shared library dependencies (via \$ORIGIN/../lib RUNPATH) are satisfied"

echo "=== [5/5] Testing execution (version check, offscreen GUI startup & jt9 decoder) ==="
VERSION_OUT="$(./squashfs-root/usr/bin/wsjtx_app_version --version 2>&1)"
echo "  [OK] wsjtx_app_version --version: $VERSION_OUT"
./squashfs-root/usr/bin/jt9 -h >/dev/null
echo "  [OK] jt9 decoder help executed cleanly"
if timeout 3 env QT_QPA_PLATFORM=offscreen "$APPIMAGE" --appimage-extract-and-run >/dev/null 2>&1; then
    echo "  [OK] GUI started and exited cleanly"
elif [ $? -eq 124 ]; then
    echo "  [OK] GUI started and stayed alive for 3s without crashing (no realloc/Qt collision!)"
else
    echo "  [FAIL] GUI crashed on startup!"
    exit 1
fi

echo ""
echo "ALL TESTS PASSED SUCCESSFULLY!"
