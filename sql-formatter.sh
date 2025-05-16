#!/usr/bin/env bash

### Pass-through script to the sql-formatter node module by zeroturnaround.
###
### Usage:
###   <Options> sql-formatter.sh <Arguments>
###
### Options:
###   INSTALL_DIR: The install directory to be maintained by this script (default: "${HOME}/.sql-formatter")
###
### Remarks:
###   This script tries to locally manage all the components necessary for
###   sql-formatter to work. Specifically, it creates a .sql-formatter folder
###   in your HOME directory, installs node and npm into that directory,
###   then installs the sql-formatter module. It's also self-updating, in that it will re-install
###   everything if a new version of nodejs is released.
###
###   To prevent hitting the nodejs website too often, the script ensures that it only attempts to
###   install/re-install nodejs once per day.

set -e

INSTALL_DIR="${INSTALL_DIR:-"${HOME}"/.sql-formatter}"
NODE_CHECKSUM_FILE="${INSTALL_DIR}/node_checksum"
NODE_DIR="${INSTALL_DIR}/node"
NODE_BIN="${NODE_DIR}/bin"
NODE_VERSION='v17.9.1'
NODE_LATEST_URL="https://nodejs.org/dist/${NODE_VERSION}"
NODE_MODULES_DIR="${INSTALL_DIR}/node_modules"
NODE_MODULES_BIN="${NODE_MODULES_DIR}/bin"
SQLFORMATTER_VERSION="10.0.0"
readonly INSTALL_DIR NODE_BIN NODE_MODULES_DIR NODE_MODULES_BIN

function call_sql_formatter {
  PATH="${NODE_BIN}:${PATH}" "${NODE_MODULES_BIN}/sql-formatter" "$@"
}

function attempted_install {
  local today
  today="$(date '+%Y-%m-%d')"

  if [[ -f "${INSTALL_DIR}/today.txt" ]] && [[ "${today}" == "$(cat "${INSTALL_DIR}/today.txt")" ]]; then
    return
  fi

  return 1
}

function ensure_attempt_install_daily {
  if ! attempted_install; then
    >&2 echo 'no install atttempts made for today; installing sql-formatter'
    install_sql_formatter
  fi

  date '+%Y-%m-%d' > "${INSTALL_DIR}/today.txt"
}

function error_exit {
  >&2 echo "$1"
  exit "${2:-1}"
}

function get_checksum {
   curl --silent --location "${NODE_LATEST_URL}/SHASUMS256.txt.asc" 2>/dev/null \
     | grep "$(get_os_name)" \
     | cut --delimiter ' ' --field 1
}

function get_latest_filename {
  printf 'node-%s-%s' "${NODE_VERSION}" "$(get_os_name)"
}

function get_latest_tarball {
  curl --location "${NODE_LATEST_URL}/$(get_latest_filename)" 2>/dev/null
}

function get_os_name {
  case "$(uname)" in
    "Darwin")
      if [[ "$(uname -m)" == "arm64" ]]; then
        echo -n "darwin-arm64.tar.gz"
      else
        echo -n "darwin-x64.tar.gz"
      fi
      ;;
    "Linux")
      echo -n "linux-x64.tar.gz"
      ;;
    *)
      error_exit "Unsupported operating system $(uname)"
      ;;
  esac
}

function install_sql_formatter {
  local checksum
  checksum="$(get_checksum)"
  if ! [[ -f "${NODE_CHECKSUM_FILE}" ]] || [[ "${checksum}" == "$(cat "${NODE_CHECKSUM_FILE}")" ]]; then
    rm -rf "${NODE_DIR:?}"

    mkdir --parents "${NODE_DIR}"

    get_latest_tarball \
      | tar \
        --extract \
        --gunzip \
        --directory "${NODE_DIR}" \
        --strip-components 1

    chmod 755 "${NODE_BIN}/"*

    echo -n "${checksum}" > "${NODE_CHECKSUM_FILE}"
    chmod 644 "${NODE_CHECKSUM_FILE}"
  fi

  >&2 PATH="${NODE_BIN}:${PATH}" "${NODE_BIN}/npm" install \
    --global \
    --prefix "${NODE_MODULES_DIR}" \
    "sql-formatter@${SQLFORMATTER_VERSION}"

  chmod 755 "${NODE_MODULES_BIN}"/*
}

function main {
  ensure_attempt_install_daily
  call_sql_formatter "$@"
}

main "$@"
