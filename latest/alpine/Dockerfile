FROM alpine:3.24.1

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG BUILD_CPUS
ARG IMAGEMAGICK_VERSION="7.1.2-9"
ENV IMAGEMAGICK_VERSION="${IMAGEMAGICK_VERSION}"

# hadolint ignore=DL3003
RUN addgroup -g 1000 imagemagick \
  && adduser -u 1000 -G imagemagick -s /bin/sh -D --no-create-home imagemagick \
  && apk add --no-cache \
    libgcc='15.2.0-r5' \
    libgomp='15.2.0-r5' \
    libstdc++='15.2.0-r5' \
    libzip-dev='1.11.4-r2' \
    # Perl
    perl='5.42.2-r0' \
    # Fonts
    font-dejavu='2.37-r6' \
    fontconfig='2.17.1-r1' \
    freetype='2.14.3-r0' \
    # JPEG
    libjpeg-turbo='3.1.3-r0' \
    # PNG
    libpng='1.6.58-r1' \
    # TIFF
    tiff='4.7.1-r0' \
    # WebP
    libwebp='1.6.0-r0' \
    libwebpdemux='1.6.0-r0' \
    libwebpmux='1.6.0-r0' \
  && apk add --no-cache --virtual .imagemagick-deps \
    build-base='0.5-r4' \
    cmake='4.2.3-r0' \
    g++='15.2.0-r5' \
    git='2.54.0-r0' \
    make='4.4.1-r4' \
    musl-dev='1.2.6-r2' \
    # Perl
    perl-dev='5.42.2-r0' \
    # Fonts
    fontconfig-dev='2.17.1-r1' \
    freetype-dev='2.14.3-r0' \
    # JPEG
    libjpeg-turbo-dev='3.1.3-r0' \
    # PNG
    libpng-dev='1.6.58-r1' \
    # TIFF
    tiff-dev='4.7.1-r0' \
    # WebP
    libwebp-dev='1.6.0-r0' \
  # ImageMagick
  && git clone -b "${IMAGEMAGICK_VERSION}" --depth 1 \
    "https://github.com/ImageMagick/ImageMagick$([ "$(printf '%s' "${IMAGEMAGICK_VERSION}" | cut -c 1)" -eq '6' ] && echo '6').git" \
    /tmp/ImageMagick/ \
  && cd /tmp/ImageMagick/ \
  && ./configure --with-perl --with-png \
  && : "${BUILD_CPUS:=$(( $(nproc) > 1 ? $(nproc) / 2 : 1 ))}" \
  && echo "BUILD_CPUS=${BUILD_CPUS}" \
  && echo "make -j${BUILD_CPUS}" \
  && make -j"${BUILD_CPUS}" \
  && make install \
  && ldconfig /usr/local/lib/ \
  # clean
  && apk del .imagemagick-deps \
  && rm -rf /tmp/* \
  # smoke test
  && identify -version

USER imagemagick
WORKDIR /data/
