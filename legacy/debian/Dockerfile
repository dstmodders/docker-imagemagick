FROM debian:bookworm-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG BUILD_CPUS
ARG IMAGEMAGICK_VERSION="6.9.13-22"
ENV IMAGEMAGICK_VERSION="${IMAGEMAGICK_VERSION}"

# hadolint ignore=DL3003
RUN groupadd --gid 1000 imagemagick \
  && useradd --uid 1000 --gid imagemagick --shell /bin/bash --no-create-home imagemagick \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential='12.9' \
    ca-certificates='20230311+deb12u1' \
    git='1:2.39.5-0+deb12u2' \
    libgomp1='12.2.0-14+deb12u1' \
    libzip-dev='1.7.3-1+b1' \
    pkg-config='1.8.1-1' \
    # Perl
    libperl-dev='5.36.0-7+deb12u3' \
    libperl5.36='5.36.0-7+deb12u3' \
    # Fonts
    fonts-dejavu='2.37-6' \
    libfontconfig1-dev='2.14.1-4' \
    libfontconfig1='2.14.1-4' \
    libfreetype6-dev='2.12.1+dfsg-5+deb12u4' \
    libfreetype6='2.12.1+dfsg-5+deb12u4' \
    # JPEG
    libjpeg62-turbo-dev='1:2.1.5-2' \
    libjpeg62-turbo='1:2.1.5-2' \
    # PNG
    libpng-dev='1.6.39-2' \
    libpng16-16='1.6.39-2' \
    # TIFF \
    libtiff-dev='4.5.0-6+deb12u3' \
    libtiff6='4.5.0-6+deb12u3' \
    # WebP \
    libwebp-dev='1.2.4-0.2+deb12u1' \
    libwebp7='1.2.4-0.2+deb12u1' \
    libwebpdemux2='1.2.4-0.2+deb12u1' \
    libwebpmux3='1.2.4-0.2+deb12u1' \
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
