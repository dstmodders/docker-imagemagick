FROM alpine:3.19.1

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG IMAGEMAGICK_VERSION="6.9.13-22"
ENV IMAGEMAGICK_VERSION="${IMAGEMAGICK_VERSION}"

# hadolint ignore=DL3003
RUN addgroup -g 1000 imagemagick \
  && adduser -u 1000 -G imagemagick -s /bin/sh -D --no-create-home imagemagick \
  && apk add --no-cache \
    libgcc='13.2.1_git20231014-r0' \
    libgomp='13.2.1_git20231014-r0' \
    libstdc++='13.2.1_git20231014-r0' \
    libzip-dev='1.10.1-r0' \
    # Perl
    perl='5.38.5-r0' \
    # Fonts
    font-dejavu='2.37-r5' \
    fontconfig='2.14.2-r4' \
    freetype='2.13.2-r0' \
    # JPEG
    libjpeg-turbo='3.0.1-r0' \
    # PNG
    libpng='1.6.44-r0' \
    # TIFF
    tiff='4.6.0-r0' \
    # WebP
    libwebp='1.3.2-r0' \
    libwebpdemux='1.3.2-r0' \
    libwebpmux='1.3.2-r0' \
  && apk add --no-cache --virtual .imagemagick-deps \
    cmake='3.27.8-r0' \
    g++='13.2.1_git20231014-r0' \
    git='2.43.7-r0' \
    libc-dev='0.7.2-r5' \
    make='4.4.1-r2' \
    # Perl
    perl-dev='5.38.5-r0' \
    # Fonts
    fontconfig-dev='2.14.2-r4' \
    freetype-dev='2.13.2-r0' \
    # JPEG
    libjpeg-turbo-dev='3.0.1-r0' \
    # PNG
    libpng-dev='1.6.44-r0' \
    # TIFF
    tiff-dev='4.6.0-r0' \
    # WebP
    libwebp-dev='1.3.2-r0' \
  # ImageMagick
  && git clone "https://github.com/ImageMagick/ImageMagick$([ "$(printf '%s' "${IMAGEMAGICK_VERSION}" | cut -c 1)" -eq '6' ] && echo '6').git" /tmp/ImageMagick/ \
  && cd /tmp/ImageMagick/ \
  && git checkout "${IMAGEMAGICK_VERSION}" \
  && ./configure --with-perl --with-png \
  && make \
  && make install \
  && ldconfig /usr/local/lib/ \
  # clean
  && apk del .imagemagick-deps \
  && rm -rf /tmp/* \
  # smoke test
  && identify -version

USER imagemagick
WORKDIR /data/
