#!/usr/bin/env bash
#
# Build images locally.
#
# Usage:
#   build.sh [flags] [<image set>]
#
# Examples:
#   build.sh
#   build.sh -p plain latest
#
# Arguments:
#   <image set>                 Image set: "all", "latest", "legacy"
#                               (default "all")
#
# Flags:
#   -b, --build-cpus <number>   Set the number of CPUs to use for parallel
#                               builds
#
#   -p, --progress <string>     Set type of progress output: "auto", "plain",
#                               "tty", "rawjson"
#                               (default "auto")
#
#   -h, --help                  Show this help message
#
# Environment Variables:
#   NO_COLOR                    Set to 1 to disable terminal colors
#                               (see no-color.org, default "0")
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

if docker buildx version > /dev/null 2>&1; then
  BUILDX_AVAILABLE=1
fi

readonly BASE_DIR
readonly BUILDX_AVAILABLE
readonly IMAGE_NAME
readonly LATEST_IMAGES
readonly LEGACY_IMAGES

# define defaults for environment variables
NO_COLOR="${NO_COLOR:-0}"

# define arguments
ARG_BUILD_SET='all'

# define flags
FLAG_BUILD_CPUS=''
FLAG_PROGRESS=''

usage() {
  awk '
    NR==1 && /^#!/ { next }            # skip shebang
    /^#/ {                             # collect comment lines
      sub(/^# ?/, "")
      buf = buf ? buf ORS $0 : $0
      next
    }
    buf { exit }                       # stop after first non-comment
    END {
      if (buf) {
        sub(/[[:space:]]+$/, "", buf)  # trim trailing whitespace
        print buf
      }
    }
  ' "$0"
}

print_bold_color() {
  local color="$1"
  local value="$2"
  local output="${3:-1}"

  if [ "${NO_COLOR}" = '1' ] || ! [ -t "${output}" ]; then
    printf '%s' "${value}" >&"${output}"
  else
    printf "$(tput bold)$(tput setaf "${color}")%s$(tput sgr0)" "${value}" >&"${output}"
  fi
}

print_error() {
  local message="$1"
  print_bold_color 1 "error: ${message}" 2
  printf '\n' >&2
}

die() {
  local message="$1"
  print_error "${message}"
  exit 1
}

print_separator() {
  print_bold_color 0 '---'
  printf '\n'
}

build_completed() {
  print_separator
  print_bold_color 2 'Build completed'
  printf '\n'
  exit 0
}

# shellcheck disable=SC2329
interrupt() {
  printf '\n'
  print_separator
  print_bold_color 1 'Interrupted'
  printf '\n'
  exit 130
}

print_step() {
  local message="$1"
  local value="${2:-}"

  printf -- '--> %s' "${message}"
  if [ -n "${value}" ]; then
    printf ': '
    print_bold_color 7 "${value}"
  fi
}

print_step_dotted() {
  local message="$1"
  local value="${2:-}"

  print_step "${message}" "${value}"
  printf '... '
}

set_flag_build_cpus() {
  local value="$1"
  if [ -n "${value}" ] && [[ "${value}" =~ ^[0-9]+$ ]]; then
    FLAG_BUILD_CPUS="${value}"
    return 0
  else
    # shellcheck disable=SC2016
    die 'flag `--build-cpus` value should be a number'
  fi
}

set_flag_progress() {
  local value="$1"
  if [ -n "${value}" ] && [[ "${value}" =~ ^([0-9]+|auto|plain|tty|rawjson)$ ]]; then
    FLAG_PROGRESS="${value}"
    return 0
  else
    # shellcheck disable=SC2016
    die 'flag `--progress` value should be one of: "auto", "plain", "tty", "rawjson"'
  fi
}

build_image() {
  local context_path="$1"
  local tags="$2"

  local build_arg=""
  local build_cmd=""
  local platform_arg=""
  local progress_arg=""

  print_step_dotted 'Building image(s) for context' "${context_path}"
  printf '\n'

  if [ "${BUILDX_AVAILABLE}" -eq 1 ]; then
    build_cmd='docker buildx build --load'
    platform_arg=''
    # shellcheck disable=SC2016
    print_step_dotted 'Using single-platform build' '`docker buildx`'
    printf '\n'

    # uncomment for production multi-platform builds
    # build_cmd="docker buildx build --push"
    # platform_arg="--platform=linux/amd64,linux/arm64"
    # # shellcheck disable=SC2016
    # print_step_dotted 'Using multi-platform build' '`docker buildx`'
    # printf '\n'
  else
    build_cmd='docker build'
    # shellcheck disable=SC2016
    printf -- '--> Using `docker build`. Consider installing `docker buildx` for multi-platform support'
    printf '\n'
  fi

  if [ -n "${FLAG_BUILD_CPUS}" ]; then
    build_arg="--build-arg BUILD_CPUS=${FLAG_BUILD_CPUS}"
    # shellcheck disable=SC2016
    print_step_dotted 'Using build argument' "\`${build_arg}\`"
    printf '\n'
  fi

  if [ -n "${FLAG_PROGRESS}" ]; then
    progress_arg="--progress=${FLAG_PROGRESS}"
    # shellcheck disable=SC2016
    print_step_dotted 'Using build progress output' "\`${progress_arg}\`"
    printf '\n'
  fi

  local TAG_ARGS=""
  for tag in ${tags}; do
    TAG_ARGS="${TAG_ARGS} -t ${IMAGE_NAME}:${tag}"
  done

  print_separator
  # shellcheck disable=SC2086
  ${build_cmd} ${platform_arg} ${progress_arg} ${TAG_ARGS} ${build_arg} "${context_path}"
}

cd "${BASE_DIR}/.." || exit 1

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -b=* | --build-cpus=*)
      set_flag_build_cpus "${1#*=}"
      ;;
    -b | --build-cpus)
      set_flag_build_cpus "${2:-}"
      shift
      ;;
    -p=* | --progress=*)
      set_flag_progress "${1#*=}"
      ;;
    -p | --progress)
      set_flag_progress "${2:-}"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      die 'unrecognized flag'
      ;;
    *)
      if [ -z "${ARG_BUILD_SET}" ] || [ "${ARG_BUILD_SET}" = "all" ]; then
        ARG_BUILD_SET="$1"
      else
        die 'too many image sets specified'
      fi
      ;;
  esac
  shift
done

readonly ARG_BUILD_SET
readonly FLAG_BUILD_CPUS
readonly FLAG_PROGRESS

if ! command -v docker > /dev/null 2>&1; then
  die 'Docker CLI is not installed'
fi

if ! docker info > /dev/null 2>&1; then
  die 'Docker daemon is not running'
fi

if [[ "${ARG_BUILD_SET}" != 'all' && "${ARG_BUILD_SET}" != 'latest' && "${ARG_BUILD_SET}" != 'legacy' ]]; then
  die 'invalid image set specified'
fi

trap interrupt SIGINT

contexts=()

if [ "${ARG_BUILD_SET}" = 'all' ] || [ "${ARG_BUILD_SET}" = 'latest' ]; then
  contexts=("${!LATEST_IMAGES[@]}")
fi

if [ "${ARG_BUILD_SET}" = 'all' ] || [ "${ARG_BUILD_SET}" = 'legacy' ]; then
  contexts=("${contexts[@]}" "${!LEGACY_IMAGES[@]}")
fi

total=${#contexts[@]}
index=0

for context in "${contexts[@]}"; do
  index=$((index + 1))
  if [ -n "${LATEST_IMAGES[$context]:-}" ]; then
    tags="${LATEST_IMAGES[$context]}"
  elif [ -n "${LEGACY_IMAGES[$context]:-}" ]; then
    tags="${LEGACY_IMAGES[$context]}"
  fi

  build_image "${context}" "${tags}"
  if [ "${index}" -lt "${total}" ]; then
    print_separator
  fi
done

build_completed
