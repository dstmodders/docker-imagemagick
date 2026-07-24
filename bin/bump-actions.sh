#!/usr/bin/env bash
#
# Bump GitHub Actions versions and the binfmt Docker image.
#
# Usage:
#   bump-actions.sh [flags]
#
# Flags:
#   -c, --commit    commit changes
#   -d, --dry-run   only check and don't apply or commit any changes
#   -l, --list      only list actions and their current versions
#   -h, --help      help for bump-actions.sh
#
# Environment Variables:
#   GITHUB_TOKEN    GitHub token for API requests (avoids rate limiting)
#
set -euo pipefail

# define constants
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
BINFMT_IMAGE_NAME='tonistiigi/binfmt'
WORKFLOW_DIR='.github/workflows'
WORKFLOW_FILES=('build.yml' 'ci.yml' 'update.yml')

readonly BASE_DIR
readonly BINFMT_IMAGE_NAME
readonly WORKFLOW_DIR
readonly WORKFLOW_FILES

# define defaults for environment variables
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# define flags
FLAG_COMMIT=0
FLAG_DRY_RUN=0
FLAG_LIST=0

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

print_title() {
  print_bold "[$1]"
  printf '\n\n'
}

commit_changes() {
  local commit_message_first_line="$1"
  local commit_message_body="$2"
  shift 2
  local files=("$@")

  if [ "${FLAG_DRY_RUN}" -eq 0 ] && [ "${FLAG_COMMIT}" -eq 1 ]; then
    printf 'Committing...'
    git add "${files[@]}"

    if [ -n "$(git diff --cached --name-only)" ]; then
      printf '\n'
      echo '---'
      if [ -n "${commit_message_body}" ]; then
        git commit -m "${commit_message_first_line}" -m "${commit_message_body}"
      else
        git commit -m "${commit_message_first_line}"
      fi
    else
      printf ' Skipped\n'
    fi
  fi
}

get_unique_actions() {
  local file="$1"
  grep -oE '[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+@[^[:space:]#]+' "${file}" \
    | sed 's/#.*//; s/[[:space:]]*$//' \
    | sort -u
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

update_actions() {
  local workflow_file="$1"
  local workflow_path="${WORKFLOW_DIR}/${workflow_file}"
  local -a files=()
  local -a commit_messages=()
  local action_name
  local current_version
  local latest_version
  local owner
  local repo
  local current_major
  local latest_major

  print_title "${workflow_file}"

  while IFS= read -r line; do
    action_name="$(echo "${line}" | cut -d'@' -f1)"
    current_version="$(echo "${line}" | cut -d'@' -f2)"
    owner="$(echo "${action_name}" | cut -d'/' -f1)"
    repo="$(echo "${action_name}" | cut -d'/' -f2)"

    if [ "${FLAG_LIST}" -eq 0 ]; then
      latest_version="$(get_latest_release "${owner}" "${repo}")"

      if [ -z "${latest_version}" ]; then
        printf '%s %s ' "${action_name}" "${current_version}"
        print_bold_color 3 'unknown'
        printf '\n'
        continue
      fi

      if [[ "${current_version}" =~ ^v[0-9]+$ ]]; then
        current_major="${current_version#v}"
        latest_major="${latest_version#v}"
        latest_major="${latest_major%%.*}"

        if [ "${current_major}" != "${latest_major}" ] && [ "${latest_major}" -gt "${current_major}" ] 2> /dev/null; then
          latest_version="v${latest_major}"
          printf '%s ' "${action_name}"
          print_bold "${current_version} => "
          print_bold_color 4 "${latest_version}"
          printf ' '
          print_bold_color 3 'outdated'
        else
          latest_version="${current_version}"
          printf '%s ' "${action_name}"
          print_bold "${current_version}"
          printf ' '
          print_bold_color 2 'up-to-date'
        fi
      else
        if [ "${current_version}" != "${latest_version}" ]; then
          printf '%s ' "${action_name}"
          print_bold "${current_version} => "
          print_bold_color 4 "${latest_version}"
          printf ' '
          print_bold_color 3 'outdated'
        else
          printf '%s ' "${action_name}"
          print_bold "${current_version}"
          printf ' '
          print_bold_color 2 'up-to-date'
        fi
      fi
      printf '\n'

      if [ "${FLAG_DRY_RUN}" -eq 0 ] && [ "${current_version}" != "${latest_version}" ]; then
        sed -i "s|${action_name}@${current_version}|${action_name}@${latest_version}|g" "${workflow_path}"
        files+=("${workflow_path}")
        commit_messages+=("- Bump ${action_name} from ${current_version} to ${latest_version}")
      fi
    else
      printf '%s ' "${action_name}"
      print_bold "${current_version}"
      printf '\n'
    fi
  done <<< "$(get_unique_actions "${workflow_path}")"

  if [ "${workflow_file}" = 'build.yml' ]; then
    update_binfmt_image files commit_messages
  fi

  if [ "${FLAG_DRY_RUN}" -eq 0 ] && [ "${#commit_messages[@]}" -gt 0 ]; then
    local workflow_name
    workflow_name="$(grep -m1 '^name:' "${workflow_path}" | sed 's/^name: *//' | tr '[:upper:]' '[:lower:]')"
    echo '---'
    commit_message_body="$(printf '%s\n' "${commit_messages[@]}")"
    commit_changes "Bump actions in ${workflow_name} GA workflow" "${commit_message_body}" "${files[@]}"
  fi
}

update_binfmt_image() {
  local -n _files_ref=$1
  local -n _messages_ref=$2

  local latest_tag
  local latest_version
  local current_version
  local current_full
  local latest_full
  local workflow_path="${WORKFLOW_DIR}/build.yml"

  current_full="$(grep -oE "${BINFMT_IMAGE_NAME}:[^'\"]+" "${workflow_path}" | head -1)"
  current_version="${current_full#"${BINFMT_IMAGE_NAME}":}"

  if [ "${FLAG_LIST}" -eq 1 ]; then
    printf '%s ' "${BINFMT_IMAGE_NAME}"
    print_bold "${current_version}"
    printf '\n'
    return 0
  fi

  latest_tag="$(get_latest_release 'tonistiigi' 'binfmt')"

  if [ -z "${latest_tag}" ]; then
    printf '%s %s ' "${BINFMT_IMAGE_NAME}" "${current_version}"
    print_bold_color 3 'unknown'
    printf '\n'
    return 0
  fi

  latest_tag="${latest_tag#deploy/}"

  if [[ "${latest_tag}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]]; then
    latest_version="qemu-${latest_tag}"
  elif [[ "${latest_tag}" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]]; then
    latest_version="qemu-${latest_tag}"
  else
    printf '%s %s ' "${BINFMT_IMAGE_NAME}" "${current_version}"
    print_bold_color 3 'unknown'
    printf '\n'
    return 0
  fi

  latest_full="${BINFMT_IMAGE_NAME}:${latest_version}"

  if [ "${current_version}" != "${latest_version}" ]; then
    printf '%s ' "${BINFMT_IMAGE_NAME}"
    print_bold "${current_version} => "
    print_bold_color 4 "${latest_version}"
    printf ' '
    print_bold_color 3 'outdated'
  else
    printf '%s ' "${BINFMT_IMAGE_NAME}"
    print_bold "${current_version}"
    printf ' '
    print_bold_color 2 'up-to-date'
  fi
  printf '\n'

  if [ "${FLAG_DRY_RUN}" -eq 0 ] && [ "${current_version}" != "${latest_version}" ]; then
    sed -i "s|${current_full}|${latest_full}|g" "${workflow_path}"
    _files_ref+=("${workflow_path}")
    _messages_ref+=("- Bump ${BINFMT_IMAGE_NAME} from ${current_version} to ${latest_version}")
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
readonly FLAG_LIST

if [ "${FLAG_LIST}" -eq 0 ]; then
  if ! command -v curl > /dev/null 2>&1; then
    print_error 'curl is required'
    exit 1
  fi
fi

last_index=$((${#WORKFLOW_FILES[@]} - 1))

for index in "${!WORKFLOW_FILES[@]}"; do
  update_actions "${WORKFLOW_FILES[$index]}"

  if [ "${index}" -lt "${last_index}" ]; then
    printf '\n'
  fi
done
