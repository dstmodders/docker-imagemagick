#!/usr/bin/env bash
#
# Bump the latest or legacy ImageMagick version.
#
# Usage:
#   bump-imagemagick.sh [flags] [latest|legacy] [version]
#
# Flags:
#   -c, --commit    commit changes
#   -d, --dry-run   only check and don't apply or commit any changes
#   -h, --help      help for bump-imagemagick.sh
#
# Environment Variables:
#   GITHUB_TOKEN    GitHub token for API requests (avoids rate limiting)
#
set -euo pipefail

# define constants
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKERHUB_START_LINE=10
JSON="$(cat "${BASE_DIR}/../versions.json")"
README_START_LINE=17

readonly BASE_DIR
readonly DOCKERHUB_START_LINE
readonly JSON
readonly README_START_LINE

# define defaults for environment variables
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

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

version_exists() {
  local repo="$1"
  local version="$2"
  local -a curl_args=(-sf)

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl_args+=(-H "Authorization: token ${GITHUB_TOKEN}")
  fi

  # shellcheck disable=SC2086
  curl "${curl_args[@]}" "https://api.github.com/repos/ImageMagick/${repo}/tags?per_page=100" 2> /dev/null \
    | jq -e "any(.name == \"${version}\")" > /dev/null
}

summary() {
  local dir="$1"
  local old_version="$2"
  local new_version="$3"
  local files=(
    "${dir}/alpine/Dockerfile"
    "${dir}/debian/Dockerfile"
    'DOCKERHUB.md'
    'README.md'
    'bin/bump-supported-tags.sh'
    'versions.json'
  )

  print_bold '[FILES]'
  printf '\n\n'
  mapfile -t sorted_files < <(printf "%s\n" "${files[@]}" | LC_ALL=C sort)
  for file in "${sorted_files[@]}"; do
    echo "${file}"
  done

  printf '\n'
  print_bold '[VERSION]'
  printf '\n\n'

  echo "Current: ${old_version}"
  echo "New: ${new_version}"
}

replace() {
  local dir="$1"
  local old_version="$2"
  local new_version="$3"

  printf 'Replacing...'
  sed -i "${DOCKERHUB_START_LINE},\$s/\`${old_version}\`/\`${new_version}\`/g" ./DOCKERHUB.md
  sed -i "${README_START_LINE},\$s/\`${old_version}\`/\`${new_version}\`/g" ./README.md
  sed -i "s/\"${old_version}\"/\"${new_version}\"/" ./versions.json
  sed -i "/^# reference:/s/${old_version}/${new_version}/g" ./bin/bump-supported-tags.sh
  sed -i "s/^ARG IMAGEMAGICK_VERSION=\"${old_version}\"$/ARG IMAGEMAGICK_VERSION=\"${new_version}\"/" "./${dir}/alpine/Dockerfile"
  sed -i "s/^ARG IMAGEMAGICK_VERSION=\"${old_version}\"$/ARG IMAGEMAGICK_VERSION=\"${new_version}\"/" "./${dir}/debian/Dockerfile"
  printf ' Done\n'
}

cd "${BASE_DIR}/.." || exit 1

name=''
new_version=''

while [ $# -gt 0 ]; do
  key="$1"
  case "${key}" in
    latest | legacy)
      name="${key}"
      ;;
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
      print_error 'unrecognized flag'
      usage
      exit 1
      ;;
    *)
      new_version="${key}"
      ;;
  esac
  shift 1
done

readonly FLAG_COMMIT
readonly FLAG_DRY_RUN

if [ -z "${name}" ]; then
  echo 'Choose bump option:'
  options=('latest' 'legacy')
  select opt in "${options[@]}"; do
    case "${opt}" in
      latest)
        name='latest'
        break
        ;;
      legacy)
        name='legacy'
        break
        ;;
      *) print_error 'unrecognized option (choose number 1 or 2)' ;;
    esac
  done
fi

if ! command -v curl > /dev/null 2>&1; then
  print_error 'curl is required'
  exit 1
fi

if [ -n "${name}" ]; then
  old_version="$(jq -r ".${name}.[-1].version" <<< "${JSON}")"

  if [ -z "${new_version}" ]; then
    echo "Current version: ${old_version}"
    while [ -z "${new_version}" ]; do
      read -rp "Enter new ${name} version: " new_version
      if [ -z "${new_version}" ]; then
        print_error 'empty version'
      fi
    done
    echo '---'
  fi

  if [ "${name}" == 'latest' ]; then
    upstream_repo='ImageMagick'
  else
    upstream_repo='ImageMagick6'
  fi

  if ! version_exists "${upstream_repo}" "${new_version}"; then
    print_error "couldn't verify version ${new_version} in the ${upstream_repo} tags API"
    exit 1
  fi

  summary "${name}" "${old_version}" "${new_version}"
  echo '---'

  if [ "${FLAG_DRY_RUN}" -eq 1 ]; then
    exit 0
  fi

  replace "${name}" "${old_version}" "${new_version}"

  if [ "${FLAG_COMMIT}" -eq 1 ]; then
    printf 'Committing...'
    git add \
      "${name}/alpine/Dockerfile" \
      "${name}/debian/Dockerfile" \
      DOCKERHUB.md \
      README.md \
      bin/bump-supported-tags.sh \
      versions.json
    if [ -n "$(git diff --cached --name-only)" ]; then
      printf '\n'
      echo '---'
      git commit -m "Bump ImageMagick from ${old_version} to ${new_version}"
    else
      printf ' Skipped\n'
    fi
  fi

  exit 0
fi
