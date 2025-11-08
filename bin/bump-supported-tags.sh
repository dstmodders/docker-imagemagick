#!/usr/bin/env bash
#
# Bump supported tags.
#
# Usage:
#   bump-supported-tags.sh [flags]
#
# Flags:
#   -c, --commit    commit changes
#   -d, --dry-run   only check and don't apply or commit any changes
#   -h, --help      help for bump-supported-tags.sh
#
set -euo pipefail

# define constants
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMIT_ID="$(git rev-parse --verify HEAD)"
COMMIT_MESSAGE='Change tags in DOCKERHUB.md and README.md'
DISTS=('alpine' 'debian')
HEADING_FOR_OVERVIEW='## Overview'
HEADING_FOR_TAGS="## Supported tags and respective \`Dockerfile\` links"
JSON="$(cat ./versions.json)"
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

# define flags
FLAG_COMMIT=0
FLAG_DRY_RUN=0

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

print_url() {
  local tags="$1"
  local commit="$2"
  local directory="$3"
  local url="[${tags}](${REPOSITORY}/blob/${commit}/${directory}/Dockerfile)"
  echo "- ${url}"
}

# reference: 7.1.2-2-alpine, 7.1.2-2, alpine, latest
print_latest_tags() {
  for key in "${LATEST_VERSIONS_KEYS[@]}"; do
    for dist in "${DISTS[@]}"; do
      version="$(jq -r ".latest | .[${key}] | .version" <<< "${JSON}")"
      latest="$(jq -r ".latest | .[${key}] | .latest" <<< "${JSON}")"

      tag_dist="${dist}"
      tag_full="${version-${dist}}"
      tag_version="${version}"

      tags=''
      if [ "${dist}" == 'alpine' ]; then
        tags="\`${tag_full}\`, \`${tag_version}\`, \`${tag_dist}\`"
        if [ "${latest}" == 'true' ]; then
          tags="${tags}, \`latest\`"
        fi
      else
        tags="\`${tag_full}\`, \`${tag_dist}\`"
      fi

      print_url "${tags}" "${COMMIT_ID}" "latest/${dist}"
    done
  done
}

# reference: legacy-6.9.13-29-alpine, legacy-6.9.13-29, legacy-alpine, legacy-latest, legacy
print_legacy_tags() {
  for key in "${LEGACY_VERSIONS_KEYS[@]}"; do
    for dist in "${DISTS[@]}"; do
      version="$(jq -r ".legacy | .[${key}] | .version" <<< "${JSON}")"
      latest="$(jq -r ".legacy | .[${key}] | .latest" <<< "${JSON}")"

      tag_dist="legacy-${dist}"
      tag_full="legacy-${version}-${dist}"
      tag_version="legacy-${version}"

      tags=''
      if [ "${dist}" == 'alpine' ]; then
        tags="\`${tag_full}\`, \`${tag_version}\`, \`${tag_dist}\`"
        if [ "${latest}" == 'true' ]; then
          tags="${tags}, \`legacy-latest\`, \`legacy\`"
        fi
      else
        tags="\`${tag_full}\`, \`${tag_dist}\`"
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
    -c|--commit)
      FLAG_COMMIT=1
      ;;
    -d|--dry-run)
      FLAG_DRY_RUN=1
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
      ;;
  esac
  shift 1
done

readonly FLAG_COMMIT
readonly FLAG_DRY_RUN

printf "%s\n\n" "${HEADING_FOR_TAGS}"

if [ "${FLAG_DRY_RUN}" -eq 1 ]; then
  print_latest_tags
  print_legacy_tags
  exit 0
else
  latest_tags="$(print_latest_tags)"
  legacy_tags="$(print_legacy_tags)"
  echo "${latest_tags}"
  echo "${legacy_tags}"

  echo '---'
  printf 'Replacing...'
  replace "${HEADING_FOR_TAGS}"$'\n'$'\n'"${latest_tags}"$'\n'"${legacy_tags}"$'\n'
  printf ' Done\n'

  if [ "${FLAG_COMMIT}" -eq 1 ]; then
    printf 'Committing...'
    git add ./DOCKERHUB.md ./README.md
    if [ -n "$(git diff --cached --name-only)" ]; then
      printf '\n'
      echo '---'
      git commit -m "${COMMIT_MESSAGE}"
    else
      printf ' Skipped\n'
    fi
  fi
fi
