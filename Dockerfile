FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

ARG wsjtz_version=2.0.20
ARG hamlib_version=4.7.2

# ── 1. Build & packaging dependencies ────────────────────────────────────────
RUN apt-get update && \
    apt-get -y install --no-install-recommends \
    tzdata wget curl git ca-certificates file patchelf desktop-file-utils \
    cmake ninja-build autoconf automake libtool g++ build-essential gfortran binutils pkg-config \
    libboost-log-dev libboost-thread-dev libboost-filesystem-dev libboost-regex-dev \
    libusb-1.0-0-dev libudev-dev libreadline-dev portaudio19-dev \
    qtbase5-dev qt5-qmake qttools5-dev qttools5-dev-tools \
    libqt5serialport5-dev qtmultimedia5-dev libqt5multimedia5-plugins \
    libqt5sql5-sqlite libqt5websockets5-dev libqt5svg5-dev \
    libfftw3-dev texinfo asciidoctor \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Hamlib (static build to isolated prefix) ──────────────────────────────
WORKDIR /build/hamlib/src
RUN git clone --depth 1 --branch ${hamlib_version} https://github.com/Hamlib/Hamlib.git . && \
    ./bootstrap

WORKDIR /build/hamlib/build
RUN ../src/configure \
    --prefix=/build/hamlib-prefix \
    --disable-shared \
    --enable-static \
    --without-cxx-binding \
    --disable-winradio \
    CFLAGS="-g -O2 -fPIC -fdata-sections -ffunction-sections" \
    LDFLAGS="-Wl,--gc-sections" && \
    make -j $(nproc --all) && \
    make install-strip

# ── 3. WSJT-Z source (from GitHub) ───────────────────────────────────────────
WORKDIR /build/wsjtz
RUN git clone --depth 1 --branch v${wsjtz_version} https://github.com/sq9fve/wsjt-z.git src

# ── 4. Build & install WSJT-Z into AppDir ────────────────────────────────────
WORKDIR /build/wsjtz/build
RUN cmake -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_PREFIX_PATH=/build/hamlib-prefix \
    -DWSJT_SKIP_MANPAGES=ON \
    -DWSJT_GENERATE_DOCS=OFF \
    -DCMAKE_INSTALL_PREFIX=/build/wsjtz.AppDir/usr \
    -Wno-dev \
    ../src && \
    cmake --build . -j $(nproc --all) && \
    cmake --install .

# ── 5. Prepare AppDir & linuxdeploy tooling ──────────────────────────────────
COPY ./src/entrypoint.sh /
COPY ./src/wsjtz.desktop /build/wsjtz.AppDir/usr/share/applications/wsjtz.desktop

# Remove upstream wsjtx.desktop so linuxdeploy uses wsjtz.desktop unambiguously
RUN rm -f /build/wsjtz.AppDir/usr/share/applications/wsjtx.desktop \
          /build/wsjtz.AppDir/usr/share/applications/message_aggregator.desktop

WORKDIR /build
ENV LINUXDEPLOY_TAG="1-alpha-20251107-1"
ENV LINUXDEPLOY_SHA256="c20cd71e3a4e3b80c3483cef793cda3f4e990aca14014d23c544ca3ce1270b4d"

RUN curl -fsSL -o linuxdeploy-x86_64.AppImage \
      "https://github.com/linuxdeploy/linuxdeploy/releases/download/${LINUXDEPLOY_TAG}/linuxdeploy-x86_64.AppImage" && \
    echo "${LINUXDEPLOY_SHA256}  linuxdeploy-x86_64.AppImage" | sha256sum -c - && \
    curl -fsSL -o linuxdeploy-plugin-qt-x86_64.AppImage \
      "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage" && \
    chmod +x linuxdeploy-x86_64.AppImage linuxdeploy-plugin-qt-x86_64.AppImage && \
    ./linuxdeploy-x86_64.AppImage --appimage-extract >/dev/null && mv squashfs-root /opt/linuxdeploy && \
    ./linuxdeploy-plugin-qt-x86_64.AppImage --appimage-extract >/dev/null && mv squashfs-root /opt/linuxdeploy-plugin-qt && \
    ln -sf /opt/linuxdeploy/AppRun /usr/local/bin/linuxdeploy && \
    ln -sf /opt/linuxdeploy-plugin-qt/AppRun /usr/local/bin/linuxdeploy-plugin-qt && \
    rm -f linuxdeploy-x86_64.AppImage linuxdeploy-plugin-qt-x86_64.AppImage

# ── 6. Bundle Qt, libraries & build AppImage ─────────────────────────────────
WORKDIR /build
ENV LDAI_OUTPUT="wsjtz-x86_64.AppImage"
ENV EXTRA_PLATFORM_PLUGINS="libqoffscreen.so"

# Deploy libGL.so.1 so the AppImage runs even on headless CI runners without X11/OpenGL installed
RUN linuxdeploy \
    --appdir /build/wsjtz.AppDir \
    --library /usr/lib/x86_64-linux-gnu/libGL.so.1 \
    --library /usr/lib/x86_64-linux-gnu/libGLX.so.0 \
    --library /usr/lib/x86_64-linux-gnu/libGLdispatch.so.0 \
    --plugin qt \
    --output appimage \
    --desktop-file /build/wsjtz.AppDir/usr/share/applications/wsjtz.desktop \
    --icon-file /build/wsjtz.AppDir/usr/share/pixmaps/wsjtx_icon.png

# ── 7. Smoke-test the produced AppImage ──────────────────────────────────────
RUN test -f /build/wsjtz-x86_64.AppImage && \
    chmod +x /build/wsjtz-x86_64.AppImage && \
    /build/wsjtz-x86_64.AppImage --appimage-extract >/dev/null && \
    test -x squashfs-root/usr/bin/wsjtx && \
    test -x squashfs-root/usr/bin/jt9 && \
    test -x squashfs-root/usr/bin/wsprd && \
    test -x squashfs-root/usr/bin/wsjtx_app_version && \
    test -f squashfs-root/usr/bin/ALLCALL7.TXT && \
    test -f squashfs-root/usr/bin/qt.conf && \
    test -f squashfs-root/wsjtz.desktop && \
    test -f squashfs-root/wsjtx_icon.png && \
    ls squashfs-root/usr/plugins/audio/*.so | grep -q "libqtaudio_alsa.so" && \
    ls squashfs-root/usr/plugins/audio/*.so | grep -q "libqtmedia_pulse.so" && \
    ./squashfs-root/usr/bin/wsjtx_app_version --version && \
    ./squashfs-root/usr/bin/jt9 -h >/dev/null && \
    (timeout 3 env QT_QPA_PLATFORM=offscreen ./squashfs-root/AppRun || [ $? -eq 124 ]) && \
    rm -rf squashfs-root

CMD [ "/bin/bash" ]
ENTRYPOINT [ "/entrypoint.sh" ]
