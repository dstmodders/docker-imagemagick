FROM alpine:3.19.1

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG IMAGEMAGICK_VERSION="6.9.13-13"
ENV IMAGEMAGICK_VERSION="${IMAGEMAGICK_VERSION}"

# hadolint ignore=DL3003
RUN addgroup -g 1000 imagemagick \
  && adduser -u 1000 -G imagemagick -s /bin/sh -D --no-create-home imagemagick \
  && apk add --no-cache \
    libgcc='13.2.1_git20231014-r0' \
    libgomp='13.2.1_git20231014-r0' \
    libpng-dev='1.6.40-r0' \
    libstdc++='13.2.1_git20231014-r0' \
    libzip-dev='1.10.1-r0' \
  && apk add --no-cache --virtual .imagemagick-deps \
    cmake='3.27.8-r0' \
    g++='13.2.1_git20231014-r0' \
    git='2.43.4-r0' \
    libc-dev='0.7.2-r5' \
    make='4.4.1-r2' \
  # ImageMagick
  && git clone "https://github.com/ImageMagick/ImageMagick$([ "$(printf '%s' "${IMAGEMAGICK_VERSION}" | cut -c 1)" -eq '6' ] && echo '6').git" /tmp/ImageMagick/ \
  && cd /tmp/ImageMagick/ \
  && git checkout "${IMAGEMAGICK_VERSION}" \
  && ./configure --with-png \
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
