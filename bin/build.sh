#!/bin/bash
#
# Script to build docker-imagemagick images locally.
#
# Usage:
#   ./bin/build.sh [options] [image_set]
#
# Options:
#   -b, --build-cpus <n>    Set the number of CPUs to use for parallel builds.
#                           Also respects the BUILD_CPUS environment variable.
#   -h, --help              Show this help message and exit.
#
# Image Sets:
#   all (default)           Builds all 'latest' and 'legacy' images.
#   latest                  Builds the latest ImageMagick 7 images (alpine, debian).
#   legacy                  Builds the legacy ImageMagick 6 images (alpine, debian).
#

set -euo pipefail


IMAGE_NAME="dstmodders/imagemagick"

declare -A LATEST_IMAGES=(
    ["latest/alpine"]="alpine latest"
    ["latest/debian"]="debian"
)

declare -A LEGACY_IMAGES=(
    ["legacy/alpine"]="legacy-alpine legacy"
    ["legacy/debian"]="legacy-debian"
)


BUILD_CPUS=""
BUILD_SET="all"

show_help() {
    grep ^# "$0"
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -b|--build-cpus)
            if [ -n "$2" ] && ! [[ "$2" =~ ^- ]]; then
                BUILD_CPUS="$2"
                shift
            else
                echo "Error: Argument for $1 is missing or invalid." >&2
                exit 1
            fi
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            show_help
            exit 1
            ;;
        *)
            if [ -z "$BUILD_SET" ] || [ "$BUILD_SET" == "all" ]; then
                BUILD_SET="$1"
            else
                echo "Error: Too many image sets specified (found '$BUILD_SET' and '$1')." >&2
                exit 1
            fi
            ;;
    esac
    shift
done

if [[ "$BUILD_SET" != "all" && "$BUILD_SET" != "latest" && "$BUILD_SET" != "legacy" ]]; then
    echo "Error: Invalid image set specified: '$BUILD_SET'. Must be 'all', 'latest', or 'legacy'." >&2
    exit 1
fi

if [ -z "$BUILD_CPUS" ] && [ -n "${BUILD_CPUS:-}" ]; then
    BUILD_CPUS="${BUILD_CPUS}"
fi

BUILDX_AVAILABLE=0
if docker buildx version >/dev/null 2>&1; then
    BUILDX_AVAILABLE=1
fi

build_image() {
    local context_path="$1"
    local tags="$2"

    local BUILD_CMD=""
    local PLATFORM_ARG=""
    local BUILD_ARG=""

    if [ -n "$BUILD_CPUS" ]; then
        BUILD_ARG="--build-arg BUILD_CPUS=${BUILD_CPUS}"
        echo "--> Building with BUILD_CPUS=${BUILD_CPUS}"
    fi

    if [ "$BUILDX_AVAILABLE" -eq 1 ]; then
        BUILD_CMD="docker buildx build --load"
        PLATFORM_ARG=""
        echo "--> Using 'docker buildx' for single-platform build."

        # Uncomment for production multi-platform builds
        # BUILD_CMD="docker buildx build --push" 
        # PLATFORM_ARG="--platform=linux/amd64,linux/arm64"
        # echo "--> Using 'docker buildx' for multi-platform build."

    else
        BUILD_CMD="docker build"
        echo "--> Using standard 'docker build'. Consider installing 'docker buildx' for multi-platform support."
    fi

    local TAG_ARGS=""
    for tag in $tags; do
        TAG_ARGS="${TAG_ARGS} -t ${IMAGE_NAME}:${tag}"
    done

    echo ""
    echo "======================================================================"
    echo "🚀 Building image(s) for context: **${context_path}** with tags: **${tags}**"
    echo "======================================================================"
    
    ${BUILD_CMD} ${PLATFORM_ARG} ${TAG_ARGS} ${BUILD_ARG} "${context_path}"
}


echo "Starting Docker Image build for '${BUILD_SET}' set(s)..."

if [ "$BUILD_SET" == "all" ] || [ "$BUILD_SET" == "latest" ]; then
    echo "### Starting 'latest' ImageMagick 7 images build ###"
    for context in "${!LATEST_IMAGES[@]}"; do
        tags="${LATEST_IMAGES[${context}]}"
        build_image "${context}" "${tags}"
    done
fi

if [ "$BUILD_SET" == "all" ] || [ "$BUILD_SET" == "legacy" ]; then
    echo "### Starting 'legacy' ImageMagick 6 images build ###"
    for context in "${!LEGACY_IMAGES[@]}"; do
        tags="${LEGACY_IMAGES[${context}]}"
        build_image "${context}" "${tags}"
    done
fi

echo ""
echo "Build process complete."