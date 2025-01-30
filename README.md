# docker-imagemagick

[![Debian Size]](https://hub.docker.com/r/dstmodders/imagemagick)
[![Alpine Size]](https://hub.docker.com/r/dstmodders/imagemagick)
[![CI]](https://github.com/dstmodders/docker-imagemagick/actions/workflows/ci.yml)
[![Build]](https://github.com/dstmodders/docker-imagemagick/actions/workflows/build.yml)

![ImageMagick Logo](./logo.png)

## Supported tags and respective `Dockerfile` links

- [`7.1.1-40-alpine`, `7.1.1-40`, `alpine`, `latest`](https://github.com/dstmodders/docker-imagemagick/blob/b7a7ecd1671b71d59ece4ccf4e51fa23b939b8a6/latest/alpine/Dockerfile)
- [`7.1.1-40-debian`, `debian`](https://github.com/dstmodders/docker-imagemagick/blob/b7a7ecd1671b71d59ece4ccf4e51fa23b939b8a6/latest/debian/Dockerfile)
- [`legacy-6.9.13-18-alpine`, `legacy-6.9.13-18`, `legacy-alpine`, `legacy-latest`, `legacy`](https://github.com/dstmodders/docker-imagemagick/blob/b7a7ecd1671b71d59ece4ccf4e51fa23b939b8a6/legacy/alpine/Dockerfile)
- [`legacy-6.9.13-18-debian`, `legacy-debian`](https://github.com/dstmodders/docker-imagemagick/blob/b7a7ecd1671b71d59ece4ccf4e51fa23b939b8a6/legacy/debian/Dockerfile)

## Overview

[Docker] images for both the latest and legacy [ImageMagick] versions.

They are meant to be used as the base for other [Docker] images, much like how
we use them in use them in our own endeavors such as [dstmodders/docker-ktools].
However, you can use them directly as well.

- [Usage](#usage)
- [Supported environment variables](#supported-environment-variables)
- [Supported build arguments](#supported-build-arguments)
- [Supported architectures](#supported-architectures)
- [Build](#build)

## Usage

For the latest [ImageMagick 7]:

```shell
$ docker pull dstmodders/imagemagick:latest
# or
$ docker pull ghcr.io/dstmodders/imagemagick:latest
```

For the latest legacy [ImageMagick 6]:

```shell
$ docker pull dstmodders/imagemagick:legacy
# or
$ docker pull ghcr.io/dstmodders/imagemagick:legacy
```

See [tags] for a list of all available versions.

#### Shell/Bash (Linux & macOS)

```shell
$ docker run --rm -v "$(pwd):/data/" dstmodders/imagemagick magick input.gif -negate output.gif
```

#### CMD (Windows)

```cmd
> docker run --rm -v "%CD%:/data/" dstmodders/imagemagick magick input.gif -negate output.gif
```

#### PowerShell (Windows)

```powershell
PS:\> docker run --rm -v "${PWD}:/data/" dstmodders/imagemagick magick input.gif -negate output.gif
```

## Supported environment variables

| Name                  | Image                  | Value                       | Description           |
| --------------------- | ---------------------- | --------------------------- | --------------------- |
| `IMAGEMAGICK_VERSION` | `latest`<br />`legacy` | `7.1.1-40`<br />`6.9.13-19` | [ImageMagick] version |

## Supported build arguments

| Name                  | Image                  | Default                     | Description                |
| --------------------- | ---------------------- | --------------------------- | -------------------------- |
| `IMAGEMAGICK_VERSION` | `latest`<br />`legacy` | `7.1.1-40`<br />`6.9.13-19` | Sets [ImageMagick] version |

## Supported architectures

| Image    | Architecture(s)                                           |
| -------- | --------------------------------------------------------- |
| `latest` | `linux/amd64`, `linux/386`, `linux/arm64`, `linux/arm/v7` |
| `legacy` | `linux/amd64`, `linux/386`, `linux/arm64`, `linux/arm/v7` |

## Build

To build images locally:

```shell
$ docker build --tag='dstmodders/imagemagick:alpine' ./latest/alpine/
$ docker build --tag='dstmodders/imagemagick:debian' ./latest/debian/
$ docker build --tag='dstmodders/imagemagick:legacy-alpine' ./legacy/alpine/
$ docker build --tag='dstmodders/imagemagick:legacy-debian' ./legacy/debian/
```

Respectively, to build multi-platform images using [buildx]:

```shell
$ docker buildx build --platform='linux/amd64,linux/386,linux/arm64,linux/arm/v7' --tag='dstmodders/imagemagick:alpine' ./latest/alpine/
$ docker buildx build --platform='linux/amd64,linux/386,linux/arm64,linux/arm/v7' --tag='dstmodders/imagemagick:debian' ./latest/debian/
$ docker buildx build --platform='linux/amd64,linux/386,linux/arm64,linux/arm/v7' --tag='dstmodders/imagemagick:legacy-alpine' ./legacy/alpine/
$ docker buildx build --platform='linux/amd64,linux/386,linux/arm64,linux/arm/v7' --tag='dstmodders/imagemagick:legacy-debian' ./legacy/debian/
```

## License

Released under the [MIT License](https://opensource.org/licenses/MIT).

[alpine size]: https://img.shields.io/docker/image-size/dstmodders/imagemagick/alpine?label=alpine%20size&logo=docker
[build]: https://img.shields.io/github/actions/workflow/status/dstmodders/docker-imagemagick/build.yml?branch=main&label=build&logo=github
[buildx]: https://github.com/docker/buildx
[ci]: https://img.shields.io/github/actions/workflow/status/dstmodders/docker-imagemagick/ci.yml?branch=main&label=ci&logo=github
[debian size]: https://img.shields.io/docker/image-size/dstmodders/imagemagick/debian?label=debian%20size&logo=docker
[docker]: https://www.docker.com/
[dstmodders/docker-ktools]: https://github.com/dstmodders/docker-ktools
[imagemagick 6]: https://imagemagick.org/
[imagemagick 7]: https://legacy.imagemagick.org/
[imagemagick]: https://imagemagick.org/
[tags]: https://hub.docker.com/r/dstmodders/imagemagick/tags
