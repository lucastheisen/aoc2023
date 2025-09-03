#!/usr/bin/env bash

### Bootstraps a mac workstation with the tools necessary for working on ASIAS
### ETL projects.
###
### Usage:
###   <Options> ./install.sh
###
### Options:
###   ANSIBLE_VENV_VERSION: sets the version of ansible-venv.
###   AND_EXIT: when paired with BOOTSTRAP_START_OVER, will exit after removal
###     without re-installing.
###   BASH_INSTALL_VERSION: the version of bash to install.
###   BRANCH: sets the branch of bootstrap to bootstrap from. if unversioned,
###     use the current state of the working copy of this project.
###   BOOTSTRAP_START_OVER: removes the directories and files installed by this
###     script.
###   DEBUG: turns on -x
###   LOCAL_PREFIX: the directory under which all bootstrap related artifacts
###     are installed.
###   PROFILE_D_BREW: the /etc/profile.d file to initialize brew (default:
###     /etc/profile.d/Z90_brew.sh). probably should not be changed.
###   SKIP_INSTALL_ANSIBLE: skip running the ansible-venv install.
###   SKIP_INSTALL_BREW: skip the install of homebrew.
###   SKIP_INSTALL_BREW_CASKS: skip the install of brew casks.
###   SKIP_RUN_BOOTSTRAP: skip running the local.yml ansible.
###
### Examples:
###   # run local copy of install.sh
###   BRANCH=unversioned bash ./install.sh
###   
###   # install mac bash to test code on non-mac
###   # note, this requires yacc, so you may need to:
###   #   sudo apt-get install bison flex
###   # prior to running this
###   FAKE_MAC=1 ./install.sh
###
### See also
### * pd-shell-bootstrap: https://gitlab.mitre.org/org-mitre-caasd/pd-shell-bootstrap

set -e

# Must use -n instead of -v to maintain compatability with preinstalled bash 3.2.57(1)-release
if [[ -n "${DEBUG}" ]]; then
  set -x
fi

readonly ANSIBLE_VENV_VERSION="${ANSIBLE_VENV_VERSION:-v1.1.1}"
readonly ARTIFACTS_BASE_URL="https://artifacts.mitre.org/artifactory"
readonly BRANCH="${BRANCH:-master}"
readonly BASH_INSTALL_VERSION="${BASH_INSTALL_VERSION:-5.1.8}"
readonly LOCAL_PREFIX="${LOCAL_PREFIX:-/usr/local/pd-mac-bootstrap}"
readonly PROFILE_D_BREW="${PROFILE_D_BREW:-/etc/profile.d/Z90_brew.sh}"
readonly TEXT_RED='\033[0;31m'
readonly TEXT_CLEAR='\033[0m'

# Used to generate inventory/host_vars/localhost.yml
readonly CLCONF_VERSION=3.0.11

function brew_prefix {
  # this algorithm for determining dir is take from the homebrew install script
  local os
  os="$(uname)"

  if command -v brew &> /dev/null; then
    dirname "$(dirname "$(command -v brew)")"
    return
  fi

  # Allows troubleshooting by non-mac users
  if [[ "${os}" == "Linux" ]]; then
    printf /home/linuxbrew/.linuxbrew
    return
  fi

  if [[ "${os}" == "Darwin" ]]; then
    local machine
    machine="$(uname -m)"

    if [[ "${machine}" == "arm64" ]]; then
      printf /opt/homebrew
      return
    else
      printf /usr/local
      return
    fi
  fi

  log "brew_prefix" "homebrew only works with mac or linux"
  return 1
}

function error_exit {
  >&2 echo "$1"
  exit "${2:-1}"
}

function init_podman_machine {
  set +e
  podman machine init
  initialized=$?
  set -e
  if (("${initialized}" == 125)); then
    log "init_podman_machine" "podman vm already initialized"
    return
  fi

  return "${initialized}"
}

function install_ansible {
  if [[ "${SKIP_INSTALL_ANSIBLE+n}" == "n" ]]; then
    log "install_ansible" "skipping..."
    return
  fi

  export ANSIBLE_VENV_VERSION
  log "install_ansible" "ansible-venv version ${ANSIBLE_VENV_VERSION}"
  if [[ ${ANSIBLE_VENV_VERSION} == "unversioned" ]]; then
    "${HOME}/git/caasd-ansible-venv/bin/install"
  else
    curl \
      --silent \
      https://gitlab.mitre.org/org-mitre-caasd/ansible-venv/-/raw/master/bin/install \
      | ANSIBLE_VENV_INSTALL_DIR="${LOCAL_PREFIX}/ansible-venv" \
          ANSIBLE_VENV_LINK_DIR="${LOCAL_PREFIX}/bin" \
          "${LOCAL_PREFIX}/bin/bash"
  fi
  # force bash PATH cache to update and locate new ansible
  export PATH="${PATH}"

  # first ansible command will _actually_ install ansible
  log "install_ansible" "first-run ansible to complete install (from ${LOCAL_PREFIX})"
  "${LOCAL_PREFIX}/bin/bash" <<EOF
if [[ ! "\$(command -v ansible)" =~ ^${LOCAL_PREFIX}/bin ]]; then
  >&2 echo "Expected ansible-venv and found \$(command -v ansible). Must ensure ansible-venv is found before other instances of ansible."
  exit 1
fi

exec ansible --version
EOF
}

function install_clconf {
  if ! clconf version 2>/dev/null | grep "${CLCONF_VERSION}"; then
    echo "Installing clconf"
    sudo curl --location --output /usr/local/bin/clconf --silent \
      "https://github.com/pastdev/clconf/releases/download/v${CLCONF_VERSION}/clconf-darwin"
    sudo chmod a+x /usr/local/bin/clconf
  fi
}

function asias_release_artifacts_latest_version {
  # https://gitlab.mitre.org/org-mitre-caasd/pd-shell-bootstrap/-/blob/master/roles/dev_tools/files/usr/local/bin/update-dev-tools#L27-40
  local repo=$1
  local url="${ARTIFACTS_BASE_URL}/api/storage/asias-release-artifacts-local/${repo}"

  log vv "getting latest version for: ${url}"
  # must specify gnu versions of cut/sort/tail that this script has installed
  curl --fail --silent "${url}" \
    | clconf \
      --stdin \
      getv / \
      --template-string '{{range gets "/children/*/uri"}}{{.Value}}{{"\n"}}{{end}}' \
    | "${LOCAL_PREFIX}/bin/cut" --characters 2- \
    | "${LOCAL_PREFIX}/bin/sort" --version-sort \
    | "${LOCAL_PREFIX}/bin/tail" --lines 1
}

function install_bash {
  local version=$1
  local install_prefix=$2
  local src_prefix=$3
  log "install_bash" "installing ${version} to ${install_prefix} from ${src_prefix}"

  local installed_version
  # shellcheck disable=SC2016
  if installed_version="$(
        "${install_prefix}/bin/bash" \
          -c \
          'echo "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}.${BASH_VERSINFO[2]}"')" \
      && [[ "${installed_version}" == "${version}" ]]; then
    log "install_bash" "bash version ${version} already installed"
    return
  fi

  log "install_bash" "installing version ${version}"

  sudo mkdir -p "${src_prefix}"
  curl --silent "https://ftp.gnu.org/gnu/bash/bash-${version}.tar.gz" \
    | sudo tar --extract --gunzip --directory "${src_prefix}" --strip-components 1

  # shellcheck disable=SC2164
  pushd "${src_prefix}"
  sudo ./configure "--prefix=${install_prefix}"
  sudo make install
  popd
}

function install_bash_wrapper {
  set -e
  local local_prefix=$1
  local bash_install_prefix=$2
  local bash_wrapper_bin=$3
  local bash_wrapper=$4

  log "install_bash_wrapper" "installing ${bash_wrapper} wrapper"

  sudo mkdir -p "${bash_wrapper_bin}"

  # careful, this is partially interpolated NOW, but partially interpolated at
  # invocation time. this wrapper will add bash_install_prefix/bin
  sudo dd of="${bash_wrapper}" &> /dev/null <<EOF
#!${bash_install_prefix}/bin/bash

function bash_wrapper_set_path {
  IFS=: read -ra parts <<<"\${PATH}"
  PATH=""
  for part in "\${parts[@]}"; do
    # avoid duplicates
    if [[ "\${PATH}" =~ (^|:)\${part}(:|$) ]]; then
      # skip duplicates
      continue
    fi
    if [[ ! "\${PATH}" =~ (^|:)${local_prefix}/bin(:|$) ]] \
        && (
          [[ "/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin" =~ (^|:)\${part}(:|$) ]] \
          || [[ -x "\${part}/bash" ]]
        ); then
      PATH="\${PATH+\${PATH}:}${local_prefix}/bin"
    fi

    PATH="\${PATH+\${PATH}:}\${part}"
  done
}

# we call this path setter here in case there is no login shell which would mean the profile
# where paths could be set gets run.  we also export the function so that the asias_profile.sh can
# re-set the path properly after /etc/profile's path_helper messes it up.
bash_wrapper_set_path
export -f bash_wrapper_set_path

exec "${bash_install_prefix}/bin/bash" "\$@"
EOF

  sudo chmod 755 "${bash_wrapper}"
}

function install_brew {
  if [[ "${SKIP_INSTALL_BREW+n}" == "n" ]]; then
    log "install_brew" "skipping..."
    return
  fi

  if command -v brew &> /dev/null; then
    log "install_brew" "brew was already installed, updating..."
    brew update
  else
    log "install_brew" "installing brew"
    curl \
      --fail \
      --show-error \
      --silent \
      --location \
      https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
      | bash

    # Probably want to address this in the bootstrap
    # this is a printout that happens if homebrew was not previously installed, the bootstrap breaks
    # ==> Next steps:
    # - Run these two commands in your terminal to add Homebrew to your PATH:
    #     echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/ltheisen/.bash_profile
    #     eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    local prefix
    prefix="$(brew_prefix)"

    log "install_brew" "creating ${PROFILE_D_BREW}"
    sudo mkdir -p "$(dirname "${PROFILE_D_BREW}")"
    echo "eval \"\$('${prefix}/bin/brew' shellenv)\"" | sudo dd of="${PROFILE_D_BREW}" 

    log "install_brew" "initializing ${prefix} brew for remainder of bootstrap"
    eval "$(bash "${prefix}/bin/brew" shellenv)"
  fi
}

function install_brew_casks {
  if [[ "${SKIP_INSTALL_BREW_CASKS+n}" == "n" ]]; then
    log "install_brew_casks" "skipping..."
    return
  fi

  log "install_brew_casks" "installing tools required for ansible"
  brew install \
    argo \
    autoconf \
    bats-core \
    binutils \
    coreutils \
    diffutils \
    ed \
    findutils \
    flex \
    gawk \
    gnu-indent \
    gnu-sed \
    gnu-tar \
    gnu-which \
    gpatch \
    grep \
    gzip \
    jq \
    less \
    m4 \
    make \
    maven \
    mysql \
    nano \
    openssl \
    podman \
    python3 \
    screen \
    shellcheck \
    unixodbc \
    watch \
    wdiff \
    wget

    # the proper flock comes from a separate `tap`
    # https://github.com/discoteq/flock#installing
    brew tap discoteq/discoteq
    brew install flock
}

function symlink_mitre_ca {
  # This sets the mitre certs to be useable by ansible. 
  # Ansible will check /usr/local/etc/openssl for certs. When openssl is installed it will 
  # include the os keychain in it's cert.pem file which is located in 
  # /usr/local/etc/openssl@1.1/cert.pem, since ansible does not check there for certs, we create
  # a symlink below that will find that cert when check the contents of the openssl directory.
  # https://github.com/ansible/ansible/blob/754c54d3d6fb4346ed2c47db1f9757bd6ccfb473/lib/ansible/module_utils/urls.py#L1073
  # https://formulae.brew.sh/formula/openssl@1.1
  sudo mkdir -p /usr/local/etc/openssl
  sudo rm -f  /usr/local/etc/openssl/cert.pem
  sudo ln -s /usr/local/etc/openssl@1.1/cert.pem /usr/local/etc/openssl/cert.pem
}

# installs a version of bash equal to current mac so that it can re-execute this
# script with that version in order to ensure that no modern bash features are
# used in this script.
function install_fake_mac {
  local mac_version="3.2.57"
  local mac_local_prefix="/usr/local/macbash"
  local mac_install_prefix="${mac_local_prefix}/bash-${mac_version}"
  local mac_src="${mac_install_prefix}/src"
  local mac_wrapper_bin="${mac_local_prefix}/bin"
  local mac_wrapper="${mac_wrapper_bin}/bash"

  if [[ "$(basename "$0")" != "install.sh" ]]; then
    error_exit "fake_mac can only be used from local dir, not curlbashed"
  fi

  install_bash "${mac_version}" "${mac_install_prefix}" "${mac_src}"
  install_bash_wrapper \
    "${mac_local_prefix}" \
    "${mac_install_prefix}" \
    "${mac_wrapper_bin}" \
    "${mac_wrapper}"

  # ensure a separate dir just to test ansible install
  export ANSIBLE_VENV="${HOME}/.fakemac-ansible-venv"

  unset FAKE_MAC
  cmd=("${mac_wrapper}" "$(readlink --canonicalize-existing "$0")" "$@")
  log "install_fake_mac" "Running (as $(id)): $(printf '%q ' "${cmd[@]}" | sed 's/ $//g')"
  log "install_fake_mac" ""
  log "install_fake_mac" ""
  exec "${cmd[@]}"
}

function install_gnu_non_g_links {
  local wrapper_bin=$1

  local cmd
  echo "wrapper_bin: ${wrapper_bin}"
  for cmd in "${wrapper_bin}"/*; do
    if [[ -L "${cmd}" ]] && [[ "$(readlink "${cmd}")" =~ ^${HOMEBREW_PREFIX}/opt ]]; then
      log "install_gnu_non_g_links" "remove previous linking ${cmd} from ${wrapper_bin}"
      sudo rm -f "${cmd}"
    fi
  done

  for cmd in "${HOMEBREW_PREFIX}"/opt/*/libexec/gnubin/*; do
    if [[ -L "${wrapper_bin}/$(basename "${cmd}")" ]]; then
      log "install_gnu_non_g_links" "skipping ${cmd} as it already has a proper symlink"
      continue
    fi
    log "install_gnu_non_g_links" "linking ${cmd} in ${wrapper_bin}"
    sudo ln -s "${cmd}" "${wrapper_bin}"
  done
}

function log {
  >&2 echo -e "$(date +"%Y-%m-%dT%H:%M:%S%z") [$1]: $2"
}

function run_bootstrap {
  local temp_dir=$1

  if [[ "${SKIP_RUN_BOOTSTRAP+n}" == "n" ]]; then
    log "run_bootstrap" "skipping..."
    return
  fi
  log "run_bootstrap" "run the bootstrap playbook"
  local ciman_version
  ciman_version="$(asias_release_artifacts_latest_version ciman)"
  log "run_bootstrap" "ciman version: '${ciman_version}'"
  # It turns out that it is not possible to extract non-tarred .gz files in native ansible
  # https://github.com/ansible/community/wiki/Module:-unarchive
  # Note that get_url can decompress as of ansible-core 2.14; however, our venv uses 2.13.5
  # https://gitlab.mitre.org/org-mitre-caasd/ansible-venv/-/blob/master/lib/requirements.txt#L1
  local ciman_url
  if [[ "$(uname -m)" == "arm64" ]]; then
    ciman_url="https://artifacts.mitre.org/artifactory/asias-release-artifacts-local/ciman/${ciman_version}/ciman-darwin-arm64.gz"
  else
    ciman_url="https://artifacts.mitre.org/artifactory/asias-release-artifacts-local/ciman/${ciman_version}/ciman-darwin.gz"
  fi
  curl "${ciman_url}" | zcat | sudo dd of=/usr/local/bin/ciman
  sudo chmod 755 /usr/local/bin/ciman
  log "run_bootstrap" "Put open shift client in /usr/local/bin"
  arch_name=$(uname -m | awk '{if ($0 == "x86_64") print "amd64"; else print $0}')
  curl "https://downloads-openshift-console.apps.epic-osc.mitre.org/${arch_name}/mac/oc" | sudo dd of=/usr/local/bin/oc
  sudo chmod 755 /usr/local/bin/oc
  if [[ "${BRANCH}" == "unversioned" ]]; then
    mkdir -p ./inventory/host_vars
    printf "bash_version: %s\nroot_install_dir: %s" "${BASH_INSTALL_VERSION}" "${LOCAL_PREFIX}" > ./inventory/host_vars/localhost.yml
    "${LOCAL_PREFIX}/bin/bash" <(echo "exec ansible-playbook ./local.yml")
  else
    curl \
      --silent \
      "https://gitlab.mitre.org/org-mitre-caasd/pd-mac-bootstrap/-/archive/${BRANCH}/pd-mac-bootstrap-${BRANCH}.tar.gz" \
      |  tar --extract --gunzip --strip-components 1 --directory "${temp_dir}"
    (
      cd "${temp_dir}"
      mkdir -p ./inventory/host_vars
      printf "bash_version: %s\nroot_install_dir: %s" "${BASH_INSTALL_VERSION}" "${LOCAL_PREFIX}" > ./inventory/host_vars/localhost.yml
      "${LOCAL_PREFIX}/bin/bash" <(echo "exec ansible-playbook ./local.yml")
    )
  fi
}

function save_project_hash {
  echo "Store the commit hash for future update check"
  git ls-remote https://gitlab.mitre.org/org-mitre-caasd/pd-mac-bootstrap.git \
    | grep HEAD \
    | sudo dd of=/etc/pd-mac-bootstrap.txt
}

function set_admin_permissions {
  echo "%admin  ALL=(ALL) NOPASSWD:ALL" | sudo dd of="/private/etc/sudoers.d/nopass"
}

function start_over {
  log "start_over" "removing all of ${LOCAL_PREFIX}"
  sudo rm -rf "${LOCAL_PREFIX:?}"
  sudo rm -rf "${HOMEBREW_PREFIX:?}"
  sudo rm -rf "${PROFILE_D_BREW:?}"

  # if FAKE_MAC was used, this folder gets created
  rm -rf "${HOME}/.fakemac-ansible-venv"

  # simply cleanup and do not re-install
  if [[ "${AND_EXIT+n}" == "n" ]]; then
    exit 0
  fi
}

function main {
  if [[ -n "${ZSH_VERSION}" ]]; then
    echo -e "${TEXT_RED}The script is currently running with zsh.  Please run this script again using bash.${TEXT_CLEAR}"
    exit 1
  fi
  if [[ "${FAKE_MAC+n}" != "n" ]]; then
    if [[ "$(uname -m)" == "arm64" ]]; then
      # Must install rosetta 2 on arm-based macs
      softwareupdate --install-rosetta --agree-to-license
    fi
    # Fails if xcode command line tools are already installed
    # Otherwise we need to wait for the user to notify when the install is complete,
    # as it opens a GUI and the command does not wait for it.
    if sudo xcode-select --install ; then
      read -r -p "Press enter when the GUI installer has completed to continue the bootstrap."
    fi
  fi
  set_admin_permissions
  HOMEBREW_PREFIX="${HOMEBREW_PREFIX:-$(brew_prefix)}"
  export HOMEBREW_PREFIX

  if [[ "${BOOTSTRAP_START_OVER+n}" == "n" ]]; then
    start_over
  fi

  log "main" "current ${BASH} version: ${BASH_VERSION} found at $(command -v bash)"

  # for testing on non-mac
  if [[ "${FAKE_MAC+n}" == "n" ]]; then
    install_fake_mac "$@"
  fi

  local install_prefix="${install_prefix:-${LOCAL_PREFIX}/bash-${BASH_INSTALL_VERSION}}"
  local src_prefix="${src_prefix:-${install_prefix}/src}"
  local wrapper_bin="${LOCAL_PREFIX}/bin"
  local wrapper="${wrapper_bin}/bash"

  install_bash "${BASH_INSTALL_VERSION}" "${install_prefix}" "${src_prefix}"
  install_bash_wrapper \
    "${LOCAL_PREFIX}" \
    "${install_prefix}" \
    "${wrapper_bin}" \
    "${wrapper}"

  install_clconf
  install_brew
  install_brew_casks
  symlink_mitre_ca
  install_gnu_non_g_links "${wrapper_bin}"

  # init_podman_machine

  install_ansible

  local temp_dir
  temp_dir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '${temp_dir:?}'" EXIT
  run_bootstrap "${temp_dir}"

  save_project_hash

  if [[ ! $(command -v docker) ]]; then
    echo "To finish the docker installation, run the docker application in the Applications folder."
  fi
  log "main" "Done!"
  log "main" "Remember to check the huddle page if you have issues, and if you run into something not mentioned there, update it with the solution!"
  log "main" "https://huddle.mitre.org/pages/viewpage.action?pageId=123967171"
}

# Only run main when not sourced:
#   https://stackoverflow.com/a/28776166/516433
if (return 0 2>/dev/null); then
  export ANSIBLE_VENV_VERSION ARTIFACTS_BASE_URL BASH_INSTALL_VERSION LOCAL_PREFIX PROFILE_D_BREW
  export TEXT_RED TEXT_CLEAR
else
  main "$@"
fi
