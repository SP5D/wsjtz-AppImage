FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

ARG wsjtz_version
ARG wsjtz_sum

# do not touch - needed to handle redirections in my short checksum verification
SHELL ["/bin/bash", "-c"]

RUN apt-get update && \
    dpkg --configure -a && \
    apt-get -y install \
    tzdata wget git unzip \
    cmake autoconf automake libtool g++ build-essential gfortran binutils \
    libboost-all-dev libusb-1.0-0-dev libudev-dev \
    qtbase5-dev qttools5-dev libqt5serialport5-dev qtmultimedia5-dev \
    libfftw3-dev 

# Hamlib
WORKDIR /build/hamlib/src
RUN git clone --depth 1 --branch integration git://git.code.sf.net/u/bsomervi/hamlib . && \
    ./bootstrap

# Hamlib
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

# WSJT-Z
WORKDIR /build/wsjtz
# COPY ./src/wsjtz-2.5.4-1.22.zip .  # Since sf is IMHO less reliable than github, I've created backup. Just in case.
RUN wget https://sourceforge.net/projects/wsjt-z/files/Source/wsjtz-${wsjtz_version}.zip && \
    diff <(sha256sum wsjtz-${wsjtz_version}.zip | cut -d " " -f 1) <(echo ${wsjtz_sum}) || exit && \
    unzip wsjtz-${wsjtz_version}.zip && \
    mv wsjtx src

WORKDIR /build/wsjtz/build
RUN  cmake \
    -D CMAKE_PREFIX_PATH=/build/hamlib \
    -DWSJT_SKIP_MANPAGES=ON \
    -DWSJT_GENERATE_DOCS=OFF \
    -D CMAKE_INSTALL_PREFIX=/build/wsjtz.AppDir/usr \
    ../src && \
    cmake --build . -j $(nproc --all) && \
    cmake --build . --target install

RUN apt-get -y install python3 python3-setuptools python3-pip wget fakeroot gnupg2 libglib2.0-bin file \
    desktop-file-utils libgdk-pixbuf2.0-dev librsvg2-dev libyaml-dev zsync gtk-update-icon-cache strace elfutils

WORKDIR /tmp
RUN wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage && \
    chmod +x /tmp/appimagetool-x86_64.AppImage && \
    cd /opt && /tmp/appimagetool-x86_64.AppImage --appimage-extract && \
    mv squashfs-root appimage-tool.AppDir && \
    ln -s /opt/appimage-tool.AppDir/AppRun /usr/bin/appimagetool && \
    rm /tmp/appimagetool-x86_64.AppImage

COPY ./src/entrypoint.sh /

WORKDIR /build/wsjtz.AppDir/
RUN cp usr/share/pixmaps/wsjtx_icon.png .

COPY ./src/AppRun .
COPY ./src/wsjtz.desktop .

ENV libs_to_copy="libboost|libicui18n|libicuuc|libicudata|libusb|libfftw3|libx11|libgfortran|libdouble|libquad|libQt5SerialPort|libQt5PrintSupport"

WORKDIR /build/wsjtz.AppDir/usr/lib
RUN ldconfig -p | grep -E -i "$libs_to_copy" | grep -o '\W/[^ ]*' | xargs -n 1 -I {} cp {} .

# AppImage build
WORKDIR /build/
RUN appimagetool wsjtz.AppDir --comp xz


CMD [ "/bin/bash" ]
ENTRYPOINT [ "/entrypoint.sh" ]
