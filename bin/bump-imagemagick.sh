#!/usr/bin/env bash
#
# Bump the latest or legacy ImageMagick version.
#
# Usage:
#   bump-imagemagick.sh [flags] [<image set>] [<version>]
#
# Examples:
#   bump-imagemagick.sh
#   bump-imagemagick.sh -d latest 7.1.2-30
#
# Arguments:
#   <image set>     Image set: "latest" or "legacy"
#   <version>       ImageMagick version
#
# Flags:
#   -c, --commit    Commit changes
#   -d, --dry-run   Only check and don't apply or commit any changes
#   -h, --help      Show this help message
#
# Environment Variables:
#   GITHUB_TOKEN    GitHub token for API requests to avoid rate limiting
#                   (default "")
#
#   NO_COLOR        Set to 1 to disable terminal colors
#                   (see no-color.org, default "0")
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

print_step_failed() {
  local value="${1:-Failed}"
  print_bold_color 1 "${value}"
  printf '\n'
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

  print_step_dotted 'Printing affected files'
  printf '\n'
  print_separator
  mapfile -t sorted_files < <(printf "%s\n" "${files[@]}" | LC_ALL=C sort)
  for file in "${sorted_files[@]}"; do
    printf '%s\n' "${file}"
  done
}

replace() {
  local dir="$1"
  local old_version="$2"
  local new_version="$3"

  print_step_dotted 'Replacing'
  sed -i "${DOCKERHUB_START_LINE},\$s/\`${old_version}\`/\`${new_version}\`/g" ./DOCKERHUB.md
  sed -i "${README_START_LINE},\$s/\`${old_version}\`/\`${new_version}\`/g" ./README.md
  jq --indent 2 '
    .'"${dir}"' |= map(del(.latest))
    | .'"${dir}"' += [{"version": "'"${new_version}"'", "latest": true}]
    | .'"${dir}"' |= if length > 5 then .[-5:] else . end
  ' ./versions.json > ./versions.json.tmp && mv ./versions.json.tmp ./versions.json
  sed -i "/^# reference:/s/${old_version}/${new_version}/g" ./bin/bump-supported-tags.sh
  sed -i "s/^ARG IMAGEMAGICK_VERSION=\"${old_version}\"$/ARG IMAGEMAGICK_VERSION=\"${new_version}\"/" "./${dir}/alpine/Dockerfile"
  sed -i "s/^ARG IMAGEMAGICK_VERSION=\"${old_version}\"$/ARG IMAGEMAGICK_VERSION=\"${new_version}\"/" "./${dir}/debian/Dockerfile"
  print_step_success
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
      die 'unrecognized flag'
      ;;
    *)
      new_version="${key}"
      ;;
  esac
  shift 1
done

readonly FLAG_COMMIT
readonly FLAG_DRY_RUN

if ! command -v curl > /dev/null 2>&1; then
  die 'curl is required'
fi

trap interrupt SIGINT

if [ -z "${name}" ]; then
  print_step_dotted 'Choose image set option'
  printf '\n'
  print_separator

  options=('latest' 'legacy')
  select opt in "${options[@]}"; do
    case "${opt}" in
      latest)
        name='latest'
        print_separator
        break
        ;;
      legacy)
        name='legacy'
        print_separator
        break
        ;;
      *)
        print_error 'unrecognized option (choose number 1 or 2)'
        ;;
    esac
  done
fi

if [ -z "${name}" ]; then
  die 'image set not specified'
fi

old_version="$(jq -r ".${name}.[-1].version" <<< "${JSON}")"

if [ -z "${new_version}" ]; then
  printf 'Current version: %s\n' "${old_version}"
  while [ -z "${new_version}" ]; do
    read -rp "Enter new ${name} version: " new_version
    if [ -z "${new_version}" ]; then
      print_error 'empty version'
    fi
  done
  print_separator
fi

print_step_dotted 'Setting image set' "${name}"
print_step_success

print_step_dotted 'Setting new version' "${new_version}"
print_step_success

if [ "${name}" = 'latest' ]; then
  upstream_repo='ImageMagick'
else
  upstream_repo='ImageMagick6'
fi

print_step_dotted 'Setting upstream repository' "${upstream_repo}"
print_step_success

print_step_dotted 'Checking tag existence' "${new_version}"
if ! version_exists "${upstream_repo}" "${new_version}"; then
  print_step_failed
  print_separator
  die "couldn't find tag ${new_version} in the ${upstream_repo} upstream repository"
else
  print_step_success
fi

summary "${name}" "${old_version}" "${new_version}"
if [ "${FLAG_DRY_RUN}" -eq 1 ]; then
  dry_run_completed
fi

print_separator
replace "${name}" "${old_version}" "${new_version}"

if [ "${FLAG_COMMIT}" -eq 1 ]; then
  print_step_dotted 'Committing'
  if [ "${old_version}" != "${new_version}" ]; then
    git add \
      "${name}/alpine/Dockerfile" \
      "${name}/debian/Dockerfile" \
      DOCKERHUB.md \
      README.md \
      bin/bump-supported-tags.sh \
      versions.json
    if [ -n "$(git diff --cached --name-only)" ]; then
      printf '\n'
      print_separator
      git commit -m "Bump ImageMagick from ${old_version} to ${new_version}"
    else
      print_step_skipped
    fi
  else
    print_step_skipped
  fi
fi

bump_completed
