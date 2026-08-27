#!/usr/bin/env bash
#
# Bump base images and packages in Dockerfiles. Also, bump the binfmt Docker
# image in GHA build workflow.
#
# Usage:
#   bump-packages.sh [flags]
#
# Examples:
#   bump-packages.sh
#   bump-packages.sh -l
#
# Flags:
#   -c, --commit    Commit changes
#   -d, --dry-run   Only check and don't apply or commit any changes
#   -l, --list      Only list packages and their current versions
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
GHA_BINFMT_IMAGE_NAME='tonistiigi/binfmt'
GHA_BUILD_WORKFLOW_PATH='.github/workflows/build.yml'

readonly BASE_DIR
readonly GHA_BINFMT_IMAGE_NAME
readonly GHA_BUILD_WORKFLOW_PATH

# define defaults for environment variables
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
NO_COLOR="${NO_COLOR:-0}"

# define flags
FLAG_COMMIT=0
FLAG_DRY_RUN=0
FLAG_LIST=0

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

list_completed() {
  print_separator
  print_bold_color 3 'List completed'
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

print_step_skipped() {
  local value="${1:-Skipped}"
  print_bold_color 3 "${value}"
  printf '\n'
}

get_base_image() {
  local dockerfile="$1"
  grep '^FROM' "${dockerfile}" | head -1 | awk '{print $2}'
}

get_latest_release() {
  local owner="$1"
  local repo="$2"
  local -a curl_args=(-sf)

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl_args+=(-H "Authorization: token ${GITHUB_TOKEN}")
  fi

  # shellcheck disable=SC2086
  curl "${curl_args[@]}" "https://api.github.com/repos/${owner}/${repo}/releases/latest" 2> /dev/null \
    | grep '"tag_name"' \
    | head -1 \
    | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || echo ''
}

get_latest_alpine_release() {
  docker run --rm alpine:latest cat /etc/alpine-release 2> /dev/null \
    | tr -d '[:space:]' \
    || echo ''
}

get_latest_debian_release() {
  local codename
  codename="$(docker run --rm debian:latest cat /etc/os-release 2> /dev/null \
    | grep '^VERSION_CODENAME=' \
    | cut -d '=' -f 2 \
    | tr -d '[:space:]' \
    || echo '')"

  if [ -n "${codename}" ]; then
    echo "${codename}-slim"
  fi
}

get_packages_from_dockerfile() {
  local dockerfile="$1"
  sed -n \
    -e '/apk add --no-cache/,/&&/p' \
    -e '/apk add --no-cache --virtual/,/&&/p' \
    -e '/apt-get install -y --no-install-recommends/,/&&/p' \
    "${dockerfile}" \
    | sed -E ':a;N;$!ba;s/\\\n/ /g' \
    | grep -oE '([a-zA-Z0-9+.]+(-[a-zA-Z0-9+.]+)*=[^[:space:]]+)' \
    | sed "s/'//g" \
    | sort \
    | uniq
}

get_latest_apk_package_version() {
  local base_image

  local name="$1"
  local dockerfile="$2"

  base_image="$(get_base_image "${dockerfile}")"

  local escaped_name
  # shellcheck disable=SC2001
  escaped_name="$(echo "${name}" | sed "s/[.[\*^$(){}+?|]/\\\\&/g")"

  local version
  version="$(docker run --rm -u root "${base_image}" /bin/sh -c "
    apk update &>/dev/null \
    && apk info '${name}' \
    | grep '^${name}.*description' \
    | sed -E 's/^${escaped_name}-(.*) description:/\1/' \
    | head -1
  " 2>&1)"

  if [ -z "${version}" ]; then
    echo ''
  else
    echo "${version}"
  fi
}

get_latest_apt_package_version() {
  local package_name="$1"
  local dockerfile="$2"

  local base_image
  base_image="$(get_base_image "${dockerfile}")"

  local version
  version="$(docker run --rm -u root "${base_image}" /bin/bash -c "
    apt-get update &>/dev/null \
    && apt-cache show '${package_name}' \
    | grep '^Version:' \
    | awk '{print \$2}' \
    | sort -V \
    | tail -n 1
  " 2>&1)"

  if [ -z "${version}" ] || [ "${version}" = 'E: No packages found' ]; then
    echo ''
  else
    echo "${version}"
  fi
}

replace_package_in_dockerfile() {
  local escaped_package_name
  local escaped_current_version
  local escaped_new_version

  local dockerfile="$1"
  local package_name="$2"
  local current_version="$3"
  local new_version="$4"

  escape_for_sed() {
    printf '%s\n' "$1" | sed -e 's/[\/&]/\\&/g'
  }

  escaped_package_name="$(escape_for_sed "${package_name}")"
  escaped_current_version="$(escape_for_sed "${current_version}")"
  escaped_new_version="$(escape_for_sed "${new_version}")"

  sed -i "s/${escaped_package_name}='${escaped_current_version}'/${escaped_package_name}='${escaped_new_version}'/g" "${dockerfile}"
}

update_package_in_dockerfile() {
  local dockerfile="$1"
  local package_name="$2"
  local current_version="$3"
  local latest_version="$4"

  if [ -z "${latest_version}" ]; then
    die "couldn't find the latest version for ${package_name}"
  fi

  if [ "${current_version}" != "${latest_version}" ]; then
    printf '%s ' "${package_name}"
    print_bold_color 7 "${current_version}"
    printf ' → '
    print_bold_color 4 "${latest_version}"
    printf ' '
    print_bold_color 3 'outdated'
  else
    printf '%s ' "${package_name}"
    print_bold_color 7 "${current_version}"
    printf ' '
    print_bold_color 2 'up-to-date'
  fi
  printf '\n'

  if [ "${FLAG_DRY_RUN}" -eq 1 ]; then
    return 0
  fi

  replace_package_in_dockerfile "${dockerfile}" "${package_name}" "${current_version}" "${latest_version}"
}

commit_changes() {
  local file="$1"
  local commit_message_first_line="$2"
  local commit_message="${3:-}"

  if [ "${FLAG_DRY_RUN}" -eq 0 ] && [ "${FLAG_COMMIT}" -eq 1 ]; then
    print_separator
    print_step_dotted 'Committing'
    git add "${file}"
    if [ -n "$(git diff --cached --name-only)" ]; then
      printf '\n'
      print_separator
      if [ -n "${commit_message}" ]; then
        git commit -m "${commit_message_first_line}" -m "${commit_message}"
      else
        git commit -m "${commit_message_first_line}"
      fi
    else
      print_step_skipped
    fi
    print_separator
  fi
}

update_binfmt_image() {
  local current_full
  local current_version
  local latest_full
  local latest_tag
  local latest_version

  current_full="$(grep -oE "${GHA_BINFMT_IMAGE_NAME}:[^'\"]+" "${GHA_BUILD_WORKFLOW_PATH}" | head -1)"
  current_version="${current_full#"${GHA_BINFMT_IMAGE_NAME}":}"

  if [ "${FLAG_LIST}" -eq 1 ]; then
    printf '%s ' "${GHA_BINFMT_IMAGE_NAME}"
    print_bold_color 7 "${current_version}"
    printf '\n'
    return 0
  fi

  latest_tag="$(get_latest_release 'tonistiigi' 'binfmt')"
  if [ -z "${latest_tag}" ]; then
    printf '%s ' "${GHA_BINFMT_IMAGE_NAME}"
    print_bold_color 7 "${current_version}"
    printf ' '
    print_bold_color 3 'unknown'
    printf '\n'
    return 0
  fi

  latest_tag="${latest_tag#deploy/}"
  if [[ "${latest_tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]] || [[ "${latest_tag}" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]]; then
    latest_version="qemu-${latest_tag}"
  else
    printf '%s ' "${GHA_BINFMT_IMAGE_NAME}"
    print_bold_color 7 "${current_version}"
    printf ' '
    print_bold_color 3 'unknown'
    printf '\n'
    return 0
  fi

  if [ "${current_version}" != "${latest_version}" ]; then
    printf '%s ' "${GHA_BINFMT_IMAGE_NAME}"
    print_bold_color 7 "${current_version}"
    printf ' → '
    print_bold_color 4 "${latest_version}"
    printf ' '
    print_bold_color 3 'outdated'
  else
    printf '%s ' "${GHA_BINFMT_IMAGE_NAME}"
    print_bold_color 7 "${current_version}"
    printf ' '
    print_bold_color 2 'up-to-date'
  fi
  printf '\n'

  latest_full="${GHA_BINFMT_IMAGE_NAME}:${latest_version}"
  if [ "${FLAG_DRY_RUN}" -eq 0 ] && [ "${current_version}" != "${latest_version}" ]; then
    sed -i "s|${current_full}|${latest_full}|g" "${GHA_BUILD_WORKFLOW_PATH}"
    if [ "${FLAG_COMMIT}" -eq 1 ]; then
      commit_changes "${GHA_BUILD_WORKFLOW_PATH}" "Bump ${GHA_BINFMT_IMAGE_NAME} from ${current_version} to ${latest_version} in build GHA workflow"
    fi
  fi
}

update_base_image() {
  local current_full
  local current_version
  local image_name
  local latest_version

  local dockerfile="$1"
  local label="$2"

  current_full="$(grep '^FROM' "${dockerfile}" | head -1)"
  image_name="$(echo "${current_full}" | awk '{print $2}' | cut -d ':' -f 1)"
  current_version="$(echo "${current_full}" | awk '{print $2}' | cut -d ':' -f 2)"

  if [ "${FLAG_LIST}" -eq 1 ]; then
    printf '%s ' "${label}"
    print_bold_color 7 "${current_version}"
    printf '\n'
    return 0
  fi

  case "${image_name}" in
    alpine)
      latest_version="$(get_latest_alpine_release)"
      ;;
    debian)
      latest_version="$(get_latest_debian_release)"
      ;;
    *)
      latest_version=''
      ;;
  esac

  if [ -z "${latest_version}" ]; then
    printf '%s ' "${label}"
    print_bold_color 7 "${current_version}"
    printf ' '
    print_bold_color 3 'unknown'
    printf '\n'
    return 0
  fi

  if [ "${current_version}" != "${latest_version}" ]; then
    printf '%s ' "${label}"
    print_bold_color 7 "${current_version}"
    printf ' → '
    print_bold_color 4 "${latest_version}"
    printf ' '
    print_bold_color 3 'outdated'
  else
    printf '%s ' "${label}"
    print_bold_color 7 "${current_version}"
    printf ' '
    print_bold_color 2 'up-to-date'
  fi
  printf '\n'

  if [ "${FLAG_DRY_RUN}" -eq 0 ] && [ "${current_version}" != "${latest_version}" ]; then
    sed -i "s|FROM ${image_name}:${current_version}|FROM ${image_name}:${latest_version}|" "${dockerfile}"
    if [ "${FLAG_COMMIT}" -eq 1 ]; then
      commit_changes "${dockerfile}" "Bump ${label} image from ${current_version} to ${latest_version}"
    fi
  fi
}

update_alpine_dockerfile() {
  local commit_list=()
  local dockerfile="$1"
  local commit_message_first_line="$2"

  while IFS= read -r line; do
    package_name="$(echo "${line}" | cut -d '=' -f 1)"
    current_version="$(echo "${line}" | cut -d '=' -f 2)"

    if [ "${FLAG_LIST}" -eq 0 ]; then
      latest_version="$(get_latest_apk_package_version "${package_name}" "${dockerfile}")"
      update_package_in_dockerfile "${dockerfile}" "${package_name}" "${current_version}" "${latest_version}"

      if [ "${FLAG_DRY_RUN}" -eq 0 ] && [ "${FLAG_COMMIT}" -eq 1 ] && [ "${current_version}" != "${latest_version}" ]; then
        commit_list+=("- Bump ${package_name} from ${current_version} to ${latest_version}")
      fi
    else
      printf '%s ' "${package_name}"
      print_bold_color 7 "${current_version}"
      printf '\n'
    fi
  done <<< "$(get_packages_from_dockerfile "${dockerfile}")"

  if [ "${FLAG_DRY_RUN}" -eq 0 ] && [ "${FLAG_COMMIT}" -eq 1 ] && [ "${#commit_list[@]}" -gt 0 ]; then
    mapfile -t sorted_commit_list < <(printf "%s\n" "${commit_list[@]}" | sort)
    commit_message="$(printf "%s\n" "${sorted_commit_list[@]}")"
    commit_changes "${dockerfile}" "${commit_message_first_line}" "${commit_message}"
  fi
}

update_debian_dockerfile() {
  local commit_list=()
  local dockerfile="$1"
  local commit_message_first_line="$2"

  while IFS= read -r line; do
    package_name="$(echo "${line}" | cut -d '=' -f 1)"
    current_version="$(echo "${line}" | cut -d '=' -f 2)"

    if [ "${FLAG_LIST}" -eq 0 ]; then
      latest_version="$(get_latest_apt_package_version "${package_name}" "${dockerfile}")"
      update_package_in_dockerfile "${dockerfile}" "${package_name}" "${current_version}" "${latest_version}"

      if [ "${FLAG_DRY_RUN}" -eq 0 ] && [ "${FLAG_COMMIT}" -eq 1 ] && [ "${current_version}" != "${latest_version}" ]; then
        commit_list+=("- Bump ${package_name} from ${current_version} to ${latest_version}")
      fi
    else
      printf '%s ' "${package_name}"
      print_bold_color 7 "${current_version}"
      printf '\n'
    fi
  done <<< "$(get_packages_from_dockerfile "${dockerfile}")"

  if [ "${FLAG_DRY_RUN}" -eq 0 ] && [ "${FLAG_COMMIT}" -eq 1 ] && [ "${#commit_list[@]}" -gt 0 ]; then
    mapfile -t sorted_commit_list < <(printf "%s\n" "${commit_list[@]}" | sort)
    commit_message="$(printf "%s\n" "${sorted_commit_list[@]}")"
    commit_changes "${dockerfile}" "${commit_message_first_line}" "${commit_message}"
  fi
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
    -l | --list)
      FLAG_LIST=1
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
readonly FLAG_LIST

trap interrupt SIGINT

if [ "${FLAG_LIST}" -eq 0 ]; then
  if ! command -v docker > /dev/null 2>&1; then
    die 'Docker CLI is not installed'
  fi

  if ! docker info > /dev/null 2>&1; then
    die 'Docker daemon is not running'
  fi

  if ! command -v curl > /dev/null 2>&1; then
    die 'curl is required'
  fi

  print_step_dotted 'Pulling Docker images'
  printf '\n'
  print_separator
  docker pull "$(get_base_image './latest/alpine/Dockerfile')"
  print_separator
  docker pull "$(get_base_image './latest/debian/Dockerfile')"
  print_separator
  docker pull alpine:latest
  print_separator
  docker pull debian:latest
  print_separator
fi

print_step_dotted 'Checking GitHub Actions binfmt image'
printf '\n'
print_separator
update_binfmt_image
print_separator

print_step_dotted 'Checking base images'
printf '\n'
print_separator
update_base_image './latest/alpine/Dockerfile' 'latest/alpine'
update_base_image './latest/debian/Dockerfile' 'latest/debian'
update_base_image './legacy/alpine/Dockerfile' 'legacy/alpine'
update_base_image './legacy/debian/Dockerfile' 'legacy/debian'
print_separator

print_step_dotted 'Checking latest Alpine packages'
printf '\n'
print_separator
update_alpine_dockerfile './latest/alpine/Dockerfile' 'Bump packages in latest alpine image'
print_separator

print_step_dotted 'Checking latest Debian packages'
printf '\n'
print_separator
update_debian_dockerfile './latest/debian/Dockerfile' 'Bump packages in latest debian image'
print_separator

print_step_dotted 'Checking legacy Alpine packages'
printf '\n'
print_separator
update_alpine_dockerfile './legacy/alpine/Dockerfile' 'Bump packages in legacy alpine image'
print_separator

print_step_dotted 'Checking legacy Debian packages'
printf '\n'
print_separator
update_debian_dockerfile './legacy/debian/Dockerfile' 'Bump packages in legacy debian image'

if [ "${FLAG_LIST}" -eq 1 ]; then
  list_completed
fi

if [ "${FLAG_DRY_RUN}" -eq 1 ]; then
  dry_run_completed
else
  bump_completed
fi
