FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

ARG wsjtz_version

# ── 1. Build dependencies ────────────────────────────────────────────────────
RUN apt-get update && \
    dpkg --configure -a && \
    apt-get -y install --no-install-recommends \
    tzdata wget git ca-certificates \
    cmake autoconf automake libtool g++ build-essential gfortran binutils pkg-config \
    libboost-all-dev libusb-1.0-0-dev libudev-dev \
    qtbase5-dev qttools5-dev libqt5serialport5-dev qtmultimedia5-dev \
    libqt5sql5-sqlite libqt5websockets5-dev \
    libfftw3-dev \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Hamlib (static build) ──────────────────────────────────────────────────
WORKDIR /build/hamlib/src
RUN git clone --depth 1 --branch Hamlib-4.7 https://github.com/Hamlib/Hamlib.git . && \
    ./bootstrap

WORKDIR /build/hamlib/build
RUN ../src/configure \
    --prefix=/build/wsjtz.AppDir/usr \
    --disable-shared \
    --enable-static \
    --without-cxx-binding \
    --disable-winradio \
    CFLAGS="-g -O2 -fdata-sections -ffunction-sections" \
    LDFLAGS="-Wl,--gc-sections" && \
    make -j $(nproc --all) && \
    make install-strip

# ── 3. WSJT-Z source (from GitHub) ──────────────────────────────────────────
WORKDIR /build/wsjtz
RUN git clone --depth 1 --branch v${wsjtz_version} https://github.com/sq9fve/wsjt-z.git src

# ── 4. Build WSJT-Z ─────────────────────────────────────────────────────────
WORKDIR /build/wsjtz/build
RUN cmake \
    -DCMAKE_PREFIX_PATH=/build/wsjtz.AppDir/usr \
    -DWSJT_SKIP_MANPAGES=ON \
    -DWSJT_GENERATE_DOCS=OFF \
    -DCMAKE_INSTALL_PREFIX=/build/wsjtz.AppDir/usr \
    ../src && \
    cmake --build . -j $(nproc --all) && \
    cmake --build . --target install

# ── 5. AppImage tooling ─────────────────────────────────────────────────────
RUN apt-get update && apt-get -y install --no-install-recommends \
    python3 python3-setuptools wget fakeroot gnupg2 libglib2.0-bin file \
    desktop-file-utils libgdk-pixbuf2.0-dev librsvg2-dev libyaml-dev \
    zsync gtk-update-icon-cache strace elfutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage && \
    chmod +x /tmp/appimagetool-x86_64.AppImage && \
    cd /opt && /tmp/appimagetool-x86_64.AppImage --appimage-extract && \
    mv squashfs-root appimage-tool.AppDir && \
    ln -s /opt/appimage-tool.AppDir/AppRun /usr/bin/appimagetool && \
    rm /tmp/appimagetool-x86_64.AppImage

# ── 6. Assemble AppDir ──────────────────────────────────────────────────────
COPY ./src/entrypoint.sh /

WORKDIR /build/wsjtz.AppDir/
RUN cp usr/share/pixmaps/wsjtx_icon.png .

COPY ./src/AppRun .
COPY ./src/wsjtz.desktop .

ENV libs_to_copy="libboost|libicui18n|libicuuc|libicudata|libusb|libfftw3|libx11|libgfortran|libdouble|libquad|libQt5Core|libQt5Gui|libQt5Widgets|libQt5SerialPort|libQt5PrintSupport|libQt5Sql|libQt5WebSockets|libQt5Network|libQt5Multimedia|libQt5DBus|libQt5XcbQpa|libQt5Svg|libgomp|libxcb"

WORKDIR /build/wsjtz.AppDir/usr/lib
RUN ldconfig -p | grep -E -i "$libs_to_copy" | grep -o '\W/[^ ]*' | xargs -n 1 -I {} cp {} .

# Qt platform plugins (critical for AppImage portability)
RUN mkdir -p /build/wsjtz.AppDir/usr/plugins/platforms && \
    cp /usr/lib/x86_64-linux-gnu/qt5/plugins/platforms/libqxcb.so \
       /build/wsjtz.AppDir/usr/plugins/platforms/ 2>/dev/null || \
    cp /usr/lib/qt5/plugins/platforms/libqxcb.so \
       /build/wsjtz.AppDir/usr/plugins/platforms/ 2>/dev/null || true
RUN mkdir -p /build/wsjtz.AppDir/usr/plugins/sqldrivers && \
    cp /usr/lib/x86_64-linux-gnu/qt5/plugins/sqldrivers/libqsqlite.so \
       /build/wsjtz.AppDir/usr/plugins/sqldrivers/ 2>/dev/null || \
    cp /usr/lib/qt5/plugins/sqldrivers/libqsqlite.so \
       /build/wsjtz.AppDir/usr/plugins/sqldrivers/ 2>/dev/null || true

# ── 7. Build AppImage ───────────────────────────────────────────────────────
WORKDIR /build/
RUN appimagetool wsjtz.AppDir --comp xz

CMD [ "/bin/bash" ]
ENTRYPOINT [ "/entrypoint.sh" ]
