FROM debian:bookworm-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG IMAGEMAGICK_VERSION="7.1.1-30"
ENV IMAGEMAGICK_VERSION="${IMAGEMAGICK_VERSION}"

# hadolint ignore=DL3003
RUN groupadd --gid 1000 imagemagick \
  && useradd --uid 1000 --gid imagemagick --shell /bin/bash --create-home imagemagick \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential='12.9' \
    ca-certificates='20230311' \
    git='1:2.39.2-1.1' \
    libgomp1='12.2.0-14' \
    libpng-dev='1.6.39-2' \
    libzip-dev='1.7.3-1+b1' \
    pkg-config='1.8.1-1' \
  # ImageMagick
  && git clone "https://github.com/ImageMagick/ImageMagick$([[ "${IMAGEMAGICK_VERSION}" =~ ^6 ]] && echo '6').git" /tmp/ImageMagick/ \
  && cd /tmp/ImageMagick/ \
  && git checkout "${IMAGEMAGICK_VERSION}" \
  && ./configure --with-png \
  && make \
  && make install \
  && ldconfig /usr/local/lib/ \
  # clean
  && apt-get remove -y \
    build-essential \
    ca-certificates \
    git \
    pkg-config \
  && apt-get clean \
  && apt-get autoremove -y \
  && rm -Rf \
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
