#!/usr/bin/env bash
#
# Build images locally.
#
# Usage:
#   build.sh [flags] <image set>
#
# Flags:
#   -b, --build-cpus <number>   set the number of CPUs to use for parallel builds
#   -p, --progress <string>     set type of progress output ("auto", "plain", "tty", "rawjson") (default "auto")
#   -h, --help                  help for build.sh
#
# Image Sets:
#   all (default)   build all images (latest and legacy)
#   latest          build the latest ImageMagick 7 images
#   legacy          build the legacy ImageMagick 6 images
#
set -euo pipefail

# define constants
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME='dstmodders/imagemagick'
BUILDX_AVAILABLE=0

declare -A LATEST_IMAGES=(
  ['latest/alpine']='alpine latest'
  ['latest/debian']='debian'
)

declare -A LEGACY_IMAGES=(
  ['legacy/alpine']='legacy-alpine legacy'
  ['legacy/debian']='legacy-debian'
)

if docker buildx version >/dev/null 2>&1; then
  BUILDX_AVAILABLE=1
fi

readonly BASE_DIR
readonly BUILDX_AVAILABLE
readonly IMAGE_NAME
readonly LATEST_IMAGES
readonly LEGACY_IMAGES

# define flags
FLAG_BUILD_CPUS=''
FLAG_PROGRESS=''

# define build set
BUILD_SET='all'

usage() {
  awk '
    NR==1 && /^#!/ { next }         # skip shebang
    /^#/ {                          # collect comment lines
      sub(/^# ?/, "")
      buf = buf ? buf ORS $0 : $0
      next
    }
    buf { exit }                    # stop after first non-comment
    END {
      if (buf) {
        sub(/[[:space:]]+$/, "", buf)  # trim trailing whitespace
        print buf
      }
    }
  ' "$0"
}

print_bold() {
  local value="$1"
  local output="${2:-1}"

  if [ "${DISABLE_COLORS:-0}" = '1' ] || ! [ -t 1 ]; then
    printf '%s' "${value}" >&"${output}"
  else
    printf "$(tput bold)%s$(tput sgr0)" "${value}" >&"${output}"
  fi
}

print_bold_color() {
  local color="$1"
  local value="$2"
  local output="${3:-1}"

  if [ "${DISABLE_COLORS:-0}" = '1' ] || ! [ -t 1 ]; then
    printf '%s' "${value}" >&"${output}"
  else
    printf "$(tput bold)$(tput setaf "${color}")%s$(tput sgr0)" "${value}" >&"${output}"
  fi
}

print_error() {
  print_bold_color 1 "error: $1" 2
  echo '' >&2
}

set_flag_build_cpus() {
  local value="$1"

  if [ -n "${value}" ] && [[ "${value}" =~ ^[0-9]+$ ]]; then
    FLAG_BUILD_CPUS="${value}"
    readonly FLAG_BUILD_CPUS
    return 0
  else
    # shellcheck disable=SC2016
    print_error 'flag `--build-cpus` value should be a number'
    exit 1
  fi
}

set_flag_progress() {
  local value="$1"

  if [ -n "${value}" ] && [[ "${value}" =~ ^([0-9]+|auto|plain|tty|rawjson)$ ]]; then
    FLAG_PROGRESS="${value}"
    readonly FLAG_PROGRESS
    return 0
  else
    # shellcheck disable=SC2016
    print_error 'flag `--progress` value should be one of: "auto", "plain", "tty", "rawjson"'
    exit 1
  fi
}

build_image() {
  local context_path="$1"
  local tags="$2"

  local build_arg=""
  local build_cmd=""
  local platform_arg=""
  local progress_arg=""

  printf 'Building image(s) for context: %s\n\n' "${context_path}"

  if [ "${BUILDX_AVAILABLE}" -eq 1 ]; then
    build_cmd='docker buildx build --load'
    platform_arg=''
    # shellcheck disable=SC2016
    echo '--> Using `docker buildx` for single-platform build'

    # uncomment for production multi-platform builds
    # build_cmd="docker buildx build --push"
    # platform_arg="--platform=linux/amd64,linux/arm64"
    # # shellcheck disable=SC2016
    # echo '--> Using `docker buildx` for multi-platform build'
  else
    build_cmd='docker build'
    # shellcheck disable=SC2016
    echo '--> Using `docker build`. Consider installing `docker buildx` for multi-platform support'
  fi

  if [ -n "${FLAG_BUILD_CPUS}" ]; then
    build_arg="--build-arg BUILD_CPUS=${FLAG_BUILD_CPUS}"
    # shellcheck disable=SC2016
    printf -- '--> Using `%s` as build arguments\n' "${build_arg}"
  fi

  if [ -n "${FLAG_PROGRESS}" ]; then
    progress_arg="--progress=${FLAG_PROGRESS}"
    # shellcheck disable=SC2016
    printf -- '--> Using `%s` for progress output\n' "${progress_arg}"
  fi

  local TAG_ARGS=""
  for tag in ${tags}; do
    TAG_ARGS="${TAG_ARGS} -t ${IMAGE_NAME}:${tag}"
  done

  echo ''
  # shellcheck disable=SC2086
  ${build_cmd} ${platform_arg} ${progress_arg} ${TAG_ARGS} ${build_arg} "${context_path}"
  echo '---'
}

cd "${BASE_DIR}/.." || exit 1

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -b=*|--build-cpus=*)
      set_flag_build_cpus "${1#*=}"
      ;;
    -b|--build-cpus)
      set_flag_build_cpus "${2:-}"
      shift
      ;;
    -p=*|--progress=*)
      set_flag_progress "${1#*=}"
      ;;
    -p|--progress)
      set_flag_progress "${2:-}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      print_error 'unrecognized flag'
      usage
      exit 1
      ;;
    *)
      if [ -z "${BUILD_SET}" ] || [ "${BUILD_SET}" == "all" ]; then
        BUILD_SET="$1"
      else
        print_error 'too many image sets specified'
        usage
        exit 1
      fi
      ;;
  esac
  shift
done

readonly BUILD_SET
readonly FLAG_PROGRESS

if [[ "${BUILD_SET}" != 'all' && "${BUILD_SET}" != 'latest' && "${BUILD_SET}" != 'legacy' ]]; then
  print_error 'invalid image set specified'
  usage
  exit 1
fi

if [ "${BUILD_SET}" == 'all' ] || [ "${BUILD_SET}" == 'latest' ]; then
  for context in "${!LATEST_IMAGES[@]}"; do
    tags="${LATEST_IMAGES[${context}]}"
    build_image "${context}" "${tags}"
  done
fi

if [ "${BUILD_SET}" == 'all' ] || [ "${BUILD_SET}" == 'legacy' ]; then
  for context in "${!LEGACY_IMAGES[@]}"; do
    tags="${LEGACY_IMAGES[${context}]}"
    build_image "${context}" "${tags}"
  done
fi

echo 'Build completed'
