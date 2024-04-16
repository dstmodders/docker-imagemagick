# docker-imagemagick

[![Debian Size]](https://hub.docker.com/r/dstmodders/imagemagick)
[![Alpine Size]](https://hub.docker.com/r/dstmodders/imagemagick)
[![CI]](https://github.com/dstmodders/docker-imagemagick/actions/workflows/ci.yml)
[![Build]](https://github.com/dstmodders/docker-imagemagick/actions/workflows/build.yml)

![ImageMagick Logo](./logo.png)

## Supported tags and respective `Dockerfile` links

- [`7.1.1-30-alpine`, `7.1.1-30`, `alpine`, `latest`](https://github.com/dstmodders/docker-imagemagick/blob/9940b72eff39dd45b8e8bf9e606bbe9111ecc666/latest/alpine/Dockerfile)
- [`7.1.1-30-debian`, `debian`](https://github.com/dstmodders/docker-imagemagick/blob/9940b72eff39dd45b8e8bf9e606bbe9111ecc666/latest/debian/Dockerfile)
- [`legacy-6.9.13-8-alpine`, `legacy-6.9.13-8`, `legacy-alpine`, `legacy-latest`, `legacy`](https://github.com/dstmodders/docker-imagemagick/blob/9940b72eff39dd45b8e8bf9e606bbe9111ecc666/legacy/alpine/Dockerfile)
- [`legacy-6.9.13-8-debian`, `legacy-debian`](https://github.com/dstmodders/docker-imagemagick/blob/9940b72eff39dd45b8e8bf9e606bbe9111ecc666/legacy/debian/Dockerfile)

## Overview

[Docker] images for both the latest and legacy [ImageMagick] versions.

They are meant to be used as the base for other [Docker] images, much like how
we use them in use them in our own endeavors such as [dstmodders/docker-ktools].
However, you can use them directly as well.

- [Environment variables](#environment-variables)
- [Usage](#usage)
- [Build](#build)

## Environment variables

| Name                  | Value      | Description           |
| --------------------- | ---------- | --------------------- |
| `IMAGEMAGICK_VERSION` | `7.1.1-30` | [ImageMagick] version |

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

## Build

To build images locally:

```shell
$ docker build ./latest/alpine/ --tag='dstmodders/imagemagick:alpine'
$ docker build ./latest/debian/ --tag='dstmodders/imagemagick:debian'
$ docker build ./legacy/alpine/ --tag='dstmodders/imagemagick:legacy-alpine'
$ docker build ./legacy/debian/ --tag='dstmodders/imagemagick:legacy-debian'
```

To build images locally using [buildx] to target multiple platforms, ensure that
your builder is running. If you are using [QEMU] emulation, you may also need to
enable [qemu-user-static].

In overall, to create your builder and enable [QEMU] emulation:

```shell
$ docker buildx create --name mybuilder --use --bootstrap
$ docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

Respectively, to build multi-platform images locally:

```shell
$ docker buildx build ./latest/alpine/ --platform='linux/amd64,linux/386,linux/arm64,linux/arm/v7' --tag='dstmodders/imagemagick:alpine'
$ docker buildx build ./latest/debian/ --platform='linux/amd64,linux/386,linux/arm64,linux/arm/v7' --tag='dstmodders/imagemagick:debian'
$ docker buildx build ./legacy/alpine/ --platform='linux/amd64,linux/386,linux/arm64,linux/arm/v7' --tag='dstmodders/imagemagick:legacy-alpine'
$ docker buildx build ./legacy/debian/ --platform='linux/amd64,linux/386,linux/arm64,linux/arm/v7' --tag='dstmodders/imagemagick:legacy-debian'
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
[qemu-user-static]: https://github.com/multiarch/qemu-user-static
[qemu]: https://www.qemu.org/
[tags]: https://hub.docker.com/r/dstmodders/imagemagick/tags
