FROM alpine:3.22.2

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG BUILD_CPUS
ARG IMAGEMAGICK_VERSION="7.1.1-47"
ENV IMAGEMAGICK_VERSION="${IMAGEMAGICK_VERSION}"

# hadolint ignore=DL3003
RUN addgroup -g 1000 imagemagick \
  && adduser -u 1000 -G imagemagick -s /bin/sh -D --no-create-home imagemagick \
  && apk add --no-cache \
    libgcc='14.2.0-r6' \
    libgomp='14.2.0-r6' \
    libstdc++='14.2.0-r6' \
    libzip-dev='1.11.4-r0' \
    # Perl
    perl='5.40.3-r0' \
    # Fonts
    font-dejavu='2.37-r6' \
    fontconfig='2.15.0-r3' \
    freetype='2.13.3-r0' \
    # JPEG
    libjpeg-turbo='3.1.0-r0' \
    # PNG
    libpng='1.6.47-r0' \
    # TIFF
    tiff='4.7.1-r0' \
    # WebP
    libwebp='1.5.0-r0' \
    libwebpdemux='1.5.0-r0' \
    libwebpmux='1.5.0-r0' \
  && apk add --no-cache --virtual .imagemagick-deps \
    build-base='0.5-r3' \
    cmake='3.31.7-r1' \
    g++='14.2.0-r6' \
    git='2.49.1-r0' \
    make='4.4.1-r3' \
    musl-dev='1.2.5-r10' \
    # Perl
    perl-dev='5.40.3-r0' \
    # Fonts
    fontconfig-dev='2.15.0-r3' \
    freetype-dev='2.13.3-r0' \
    # JPEG
    libjpeg-turbo-dev='3.1.0-r0' \
    # PNG
    libpng-dev='1.6.47-r0' \
    # TIFF
    tiff-dev='4.7.1-r0' \
    # WebP
    libwebp-dev='1.5.0-r0' \
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
