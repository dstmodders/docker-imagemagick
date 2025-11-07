FROM debian:trixie-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG BUILD_CPUS
ARG IMAGEMAGICK_VERSION="6.9.13-27"
ENV IMAGEMAGICK_VERSION="${IMAGEMAGICK_VERSION}"

# hadolint ignore=DL3003
RUN groupadd --gid 1000 imagemagick \
  && useradd --uid 1000 --gid imagemagick --shell /bin/bash --no-create-home imagemagick \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential='12.12' \
    ca-certificates='20250419' \
    git='1:2.47.3-0+deb13u1' \
    libgomp1='14.2.0-19' \
    libzip-dev='1.11.3-2' \
    pkg-config='1.8.1-4' \
    # Perl
    libperl-dev='5.40.1-6' \
    libperl5.40='5.40.1-6' \
    # Fonts
    fonts-dejavu='2.37-8' \
    libfontconfig1-dev='2.15.0-2.3' \
    libfontconfig1='2.15.0-2.3' \
    libfreetype-dev='2.13.3+dfsg-1' \
    libfreetype6='2.13.3+dfsg-1' \
    # JPEG
    libjpeg62-turbo-dev='1:2.1.5-4' \
    libjpeg62-turbo='1:2.1.5-4' \
    # PNG
    libpng-dev='1.6.48-1' \
    libpng16-16t64='1.6.48-1' \
    # TIFF \
    libtiff-dev='4.7.0-3+deb13u1' \
    libtiff6='4.7.0-3+deb13u1' \
    # WebP \
    libwebp-dev='1.5.0-0.1' \
    libwebp7='1.5.0-0.1' \
    libwebpdemux2='1.5.0-0.1' \
    libwebpmux3='1.5.0-0.1' \
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
  && apt-get remove -y \
    build-essential \
    ca-certificates \
    git \
    pkg-config \
    # Perl
    libperl-dev \
    # Fonts
    libfontconfig1-dev \
    libfreetype6-dev \
    # JPEG
    libjpeg62-turbo-dev \
    # PNG
    libpng-dev \
    # TIFF
    libtiff-dev \
    # WebP
    libwebp-dev \
  && apt-get clean \
  && apt-get autoremove -y \
  && rm -rf \
    /etc/ca-certificates.conf \
    /etc/ssl/ \
    /etc/wgetrc \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/log/alternatives.log \
    /var/log/apt/ \
    /var/log/dpkg.log \
  # smoke test
  && identify -version

USER imagemagick
WORKDIR /data/
