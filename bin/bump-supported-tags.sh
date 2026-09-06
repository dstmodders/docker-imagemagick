#!/usr/bin/env bash
#
# Bump supported tags.
#
# Usage:
#   bump-supported-tags.sh [flags]
#
# Examples:
#   bump-supported-tags.sh
#   bump-supported-tags.sh -d
#
# Flags:
#   -c, --commit    Commit changes
#   -d, --dry-run   Only check and don't apply or commit any changes
#   -h, --help      Show this help message
#
# Environment Variables:
#   NO_COLOR        Set to 1 to disable terminal colors
#                   (see no-color.org, default "0")
#
set -euo pipefail

# define constants
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMIT_ID="$(git rev-parse --verify HEAD)"
COMMIT_MESSAGE='Change tags in DOCKERHUB.md and README.md'
DISTS=('alpine' 'debian')
HEADING_FOR_OVERVIEW='## Overview'
HEADING_FOR_TAGS="## Supported tags and respective \`Dockerfile\` links"
JSON="$(cat "${BASE_DIR}/../versions.json")"
LATEST_VERSIONS_KEYS=()
LEGACY_VERSIONS_KEYS=()
REPOSITORY='https://github.com/dstmodders/docker-imagemagick'

extract_and_sort_keys() {
  local key_path="$1"
  jq -r "${key_path} | keys[]" <<< "${JSON}" | sort -rV
}

mapfile -t LATEST_VERSIONS_KEYS < <(extract_and_sort_keys '.latest')
mapfile -t LEGACY_VERSIONS_KEYS < <(extract_and_sort_keys '.legacy')

readonly BASE_DIR
readonly COMMIT_ID
readonly COMMIT_MESSAGE
readonly DISTS
readonly HEADING_FOR_OVERVIEW
readonly HEADING_FOR_TAGS
readonly JSON
readonly LATEST_VERSIONS_KEYS
readonly LEGACY_VERSIONS_KEYS
readonly REPOSITORY

# define defaults for environment variables
NO_COLOR="${NO_COLOR:-0}"

# define flags
FLAG_COMMIT=0
FLAG_DRY_RUN=0

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

bump_completed() {
  print_separator
  print_bold_color 2 'Bump completed'
  printf '\n'
  exit 0
}

dry_run_completed() {
  print_separator
  print_bold_color 3 'Dry-run completed'
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

print_step_success() {
  local value="${1:-Success}"
  print_bold_color 2 "${value}"
  printf '\n'
}

print_step_skipped() {
  local value="${1:-Skipped}"
  print_bold_color 3 "${value}"
  printf '\n'
}

print_url() {
  local tags="$1"
  local commit="$2"
  local directory="$3"
  local url="[${tags}](${REPOSITORY}/blob/${commit}/${directory}/Dockerfile)"
  printf -- '- %s\n' "${url}"
}

# reference: 7.1.2-30-alpine, 7.1.2-30, alpine, latest
print_latest_tags() {
  for key in "${LATEST_VERSIONS_KEYS[@]}"; do
    for dist in "${DISTS[@]}"; do
      version="$(jq -r ".latest | .[${key}] | .version" <<< "${JSON}")"
      latest="$(jq -r ".latest | .[${key}] | .latest" <<< "${JSON}")"

      tag_dist="${dist}"
      tag_full="${version}-${dist}"
      tag_version="${version}"

      tags=''
      if [ "${dist}" = 'alpine' ]; then
        tags="\`${tag_full}\`, \`${tag_version}\`"
        if [ "${latest}" = 'true' ]; then
          tags="${tags}, \`${tag_dist}\`, \`latest\`"
        fi
      else
        tags="\`${tag_full}\`"
        if [ "${latest}" = 'true' ]; then
          tags="${tags}, \`${tag_dist}\`"
        fi
      fi

      print_url "${tags}" "${COMMIT_ID}" "latest/${dist}"
    done
  done
}

# reference: legacy-6.9.13-55-alpine, legacy-6.9.13-55, legacy-alpine, legacy-latest, legacy
print_legacy_tags() {
  for key in "${LEGACY_VERSIONS_KEYS[@]}"; do
    for dist in "${DISTS[@]}"; do
      version="$(jq -r ".legacy | .[${key}] | .version" <<< "${JSON}")"
      latest="$(jq -r ".legacy | .[${key}] | .latest" <<< "${JSON}")"

      tag_dist="legacy-${dist}"
      tag_full="legacy-${version}-${dist}"
      tag_version="legacy-${version}"

      tags=''
      if [ "${dist}" = 'alpine' ]; then
        tags="\`${tag_full}\`, \`${tag_version}\`"
        if [ "${latest}" = 'true' ]; then
          tags="${tags}, \`${tag_dist}\`, \`legacy-latest\`, \`legacy\`"
        fi
      else
        tags="\`${tag_full}\`"
        if [ "${latest}" = 'true' ]; then
          tags="${tags}, \`${tag_dist}\`"
        fi
      fi

      print_url "${tags}" "${COMMIT_ID}" "legacy/${dist}"
    done
  done
}

replace() {
  local content="$1"
  for file in ./DOCKERHUB.md ./README.md; do
    sed -i "/${HEADING_FOR_TAGS}/,/${HEADING_FOR_OVERVIEW}/ {
      /${HEADING_FOR_TAGS}/!{
        /${HEADING_FOR_OVERVIEW}/!d
      }
      /${HEADING_FOR_TAGS}/!b
      r /dev/stdin
      d
    }" "${file}" <<< "${content}"
  done
}

cd "${BASE_DIR}/.." || exit 1

while [ $# -gt 0 ]; do
  key="$1"
  case "${key}" in
    -c | --commit)
      FLAG_COMMIT=1
      ;;
    -d | --dry-run)
      FLAG_DRY_RUN=1
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    -*)
      die 'unrecognized flag'
      ;;
    *)
      die 'unexpected argument'
      ;;
  esac
  shift 1
done

readonly FLAG_COMMIT
readonly FLAG_DRY_RUN

trap interrupt SIGINT

print_step_dotted 'Generating tags'
printf '\n'
print_separator

printf "%s\n\n" "${HEADING_FOR_TAGS}"

if [ "${FLAG_DRY_RUN}" -eq 1 ]; then
  print_latest_tags
  print_legacy_tags
  dry_run_completed
fi

latest_tags="$(print_latest_tags)"
legacy_tags="$(print_legacy_tags)"
printf '%s\n' "${latest_tags}"
printf '%s\n' "${legacy_tags}"

print_separator
print_step_dotted 'Replacing'
replace "${HEADING_FOR_TAGS}"$'\n'$'\n'"${latest_tags}"$'\n'"${legacy_tags}"$'\n'
print_step_success

if [ "${FLAG_COMMIT}" -eq 1 ]; then
  print_step_dotted 'Committing'
  git add ./DOCKERHUB.md ./README.md
  if [ -n "$(git diff --cached --name-only)" ]; then
    printf '\n'
    print_separator
    git commit -m "${COMMIT_MESSAGE}"
  else
    print_step_skipped
  fi
fi

bump_completed
