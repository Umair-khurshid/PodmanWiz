#!/usr/bin/env bash

set -eo pipefail

# Variables ###############################################
CONTAINER_USER=${SUDO_USER:-$USER}
ANSIBLE_DIR=${ANSIBLE_DIR:-"ansible_dir"}
DATA_DIR=${DATA_DIR:-"/srv/data"}
BASE_IMAGE=${BASE_IMAGE:-"docker.io/priximmo/buster-systemd-ssh"} # Default image

# Functions ###############################################

help() {
  echo "
Usage: $0 [options]

Options:
  -c <number>   Create <number> of containers.
  -i            Display information about containers (name and IP).
  -s            Start all containers created by this script.
  -t            Stop all containers created by this script.
  -d            Remove (drop) all containers created by this script.
  -a            Generate an Ansible inventory file with container IPs.
  -b <image>    Specify the base image (e.g., alpine, ubuntu, fedora).
  -h            Display this help message.
  "
}

createContainers() {
  CONTAINER_NUMBER=$1
  CONTAINER_HOME=/home/${CONTAINER_USER}
  CONTAINER_CMD="sudo podman exec"

  # Ensure the data directory exists
  if [ ! -d "${DATA_DIR}" ]; then
    echo "Directory ${DATA_DIR} does not exist. Creating it..."
    sudo mkdir -p "${DATA_DIR}"
    sudo chmod 755 "${DATA_DIR}"
    echo "Directory ${DATA_DIR} created."
  fi

  # Calculate the ID range for new containers
  id_already=$(sudo podman ps -a --format '{{ .Names }}' | awk -v user="${CONTAINER_USER}" '$1 ~ "^"user {count++} END {print count}')
  id_min=$((id_already + 1))
  id_max=$((id_already + CONTAINER_NUMBER))

  # Create containers in a loop
  for i in $(seq $id_min $id_max); do
    if ! sudo podman run -d --systemd=true --publish-all=true -v ${DATA_DIR}:/srv/data \
      --name ${CONTAINER_USER}-container-$i -h ${CONTAINER_USER}-container-$i \
      ${BASE_IMAGE}; then
      echo "Error: Failed to create container ${CONTAINER_USER}-container-$i"
      exit 1
    fi

    # Start the container
    if ! sudo podman start ${CONTAINER_USER}-container-$i; then
      echo "Error: Failed to start container ${CONTAINER_USER}-container-$i"
      exit 1
    fi

    # Configure the container based on the base image
    if [[ "${BASE_IMAGE}" == *"debian"* || "${BASE_IMAGE}" == *"ubuntu"* ]]; then
      ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i apt-get update
      ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i apt-get install -y openssh-server sudo
    elif [[ "${BASE_IMAGE}" == *"alpine"* ]]; then
      ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i apk add --no-cache openssh sudo
    elif [[ "${BASE_IMAGE}" == *"fedora"* || "${BASE_IMAGE}" == *"centos"* ]]; then
      ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i dnf install -y openssh-server sudo
    fi

    # Set up SSH for the user
    ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i /bin/sh -c "useradd -m -p sa3tHJ3/KuYvI ${CONTAINER_USER}"
    ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i /bin/sh -c "mkdir -m 0700 ${CONTAINER_HOME}/.ssh && chown ${CONTAINER_USER}:${CONTAINER_USER} ${CONTAINER_HOME}/.ssh"

    # Check if SSH public key exists before copying
    if [ ! -f "${HOME}/.ssh/id_rsa.pub" ]; then
      echo "Error: SSH public key ${HOME}/.ssh/id_rsa.pub not found."
      exit 1
    fi

    sudo podman cp ${HOME}/.ssh/id_rsa.pub ${CONTAINER_USER}-container-$i:${CONTAINER_HOME}/.ssh/authorized_keys
    ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i /bin/sh -c "chmod 600 ${CONTAINER_HOME}/.ssh/authorized_keys && chown ${CONTAINER_USER}:${CONTAINER_USER} ${CONTAINER_HOME}/.ssh/authorized_keys"
    ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i /bin/sh -c "echo '${CONTAINER_USER} ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"
    ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i /bin/sh -c "service ssh start"
  done

  infoContainers
}

infoContainers() {
  echo ""
  echo "Container information:"
  echo ""
  sudo podman ps -aq | awk '{system("sudo podman inspect -f \"{{.Name}} -- IP: {{.NetworkSettings.IPAddress}}\" "$1)}'
  echo ""
}

dropContainers() {
  sudo podman ps -a --format '{{.Names}}' | awk -v user="${CONTAINER_USER}" '$1 ~ "^"user {print $1" - dropping..."; system("sudo podman rm -f "$1)}'
  infoContainers
}

startContainers() {
  sudo podman ps -a --format '{{.Names}}' | awk -v user="${CONTAINER_USER}" '$1 ~ "^"user {print $1" - starting..."; system("sudo podman start "$1)}'
  infoContainers
}

stopContainers() {
  sudo podman ps -a --format '{{.Names}}' | awk -v user="${CONTAINER_USER}" '$1 ~ "^"user {print $1" - stopping..."; system("sudo podman stop "$1)}'
  infoContainers
}

createAnsible() {
  echo ""
  mkdir -p ${ANSIBLE_DIR}
  echo "all:" > ${ANSIBLE_DIR}/00_inventory.yml
  echo "  vars:" >> ${ANSIBLE_DIR}/00_inventory.yml
  echo "    ansible_python_interpreter: /usr/bin/python3" >> ${ANSIBLE_DIR}/00_inventory.yml
  echo "  hosts:" >> ${ANSIBLE_DIR}/00_inventory.yml
  sudo podman ps -aq | awk '{system("sudo podman inspect -f \"  {{.NetworkSettings.IPAddress}}:\" "$1)}' >> ${ANSIBLE_DIR}/00_inventory.yml
  mkdir -p ${ANSIBLE_DIR}/host_vars
  mkdir -p ${ANSIBLE_DIR}/group_vars
  echo "Ansible inventory created at ${ANSIBLE_DIR}/00_inventory.yml"
}

# Main Execution ##########################################

if [ "$#" -eq 0 ]; then
  help
  exit 1
fi

while getopts ":c:ahitsdb:" options; do
  case "${options}" in
    c)
      createContainers ${OPTARG}
      ;;
    i)
      infoContainers
      ;;
    s)
      startContainers
      ;;
    t)
      stopContainers
      ;;
    d)
      dropContainers
      ;;
    a)
      createAnsible
      ;;
    b)
      BASE_IMAGE=${OPTARG}
      if ! sudo podman images ${BASE_IMAGE} > /dev/null 2>&1; then
        echo "Error: Base image ${BASE_IMAGE} not found."
        exit 1
      fi
      ;;
    h)
      help
      exit 0
      ;;
    *)
      help
      exit 1
      ;;
  esac
done
#!/usr/bin/env bash

set -eo pipefail

# Variables ###############################################
CONTAINER_USER=${SUDO_USER:-$USER}
ANSIBLE_DIR=${ANSIBLE_DIR:-"ansible_dir"}
DATA_DIR=${DATA_DIR:-"/srv/data"}
BASE_IMAGE=${BASE_IMAGE:-"docker.io/priximmo/buster-systemd-ssh"} # Default image

# Functions ###############################################

help() {
  echo "
Usage: $0 [options]

Options:
  -c <number>   Create <number> of containers.
  -i            Display information about containers (name and IP).
  -s            Start all containers created by this script.
  -t            Stop all containers created by this script.
  -d            Remove (drop) all containers created by this script.
  -a            Generate an Ansible inventory file with container IPs.
  -b <image>    Specify the base image (e.g., alpine, ubuntu, fedora).
  -h            Display this help message.
  "
}

createContainers() {
  CONTAINER_NUMBER=$1
  CONTAINER_HOME=/home/${CONTAINER_USER}
  CONTAINER_CMD="sudo podman exec"

  # Ensure the data directory exists
  if [ ! -d "${DATA_DIR}" ]; then
    echo "Directory ${DATA_DIR} does not exist. Creating it..."
    sudo mkdir -p "${DATA_DIR}"
    sudo chmod 755 "${DATA_DIR}"
    echo "Directory ${DATA_DIR} created."
  fi

  # Calculate the ID range for new containers
  id_already=$(sudo podman ps -a --format '{{ .Names }}' | awk -v user="${CONTAINER_USER}" '$1 ~ "^"user {count++} END {print count}')
  id_min=$((id_already + 1))
  id_max=$((id_already + CONTAINER_NUMBER))

  # Create containers in a loop
  for i in $(seq $id_min $id_max); do
    if ! sudo podman run -d --systemd=true --publish-all=true -v ${DATA_DIR}:/srv/data \
      --name ${CONTAINER_USER}-container-$i -h ${CONTAINER_USER}-container-$i \
      ${BASE_IMAGE}; then
      echo "Error: Failed to create container ${CONTAINER_USER}-container-$i"
      exit 1
    fi

    # Start the container
    if ! sudo podman start ${CONTAINER_USER}-container-$i; then
      echo "Error: Failed to start container ${CONTAINER_USER}-container-$i"
      exit 1
    fi

    # Configure the container based on the base image
    if [[ "${BASE_IMAGE}" == *"debian"* || "${BASE_IMAGE}" == *"ubuntu"* ]]; then
      ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i apt-get update
      ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i apt-get install -y openssh-server sudo
    elif [[ "${BASE_IMAGE}" == *"alpine"* ]]; then
      ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i apk add --no-cache openssh sudo
    elif [[ "${BASE_IMAGE}" == *"fedora"* || "${BASE_IMAGE}" == *"centos"* ]]; then
      ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i dnf install -y openssh-server sudo
    fi

    # Set up SSH for the user
    ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i /bin/sh -c "useradd -m -p sa3tHJ3/KuYvI ${CONTAINER_USER}"
    ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i /bin/sh -c "mkdir -m 0700 ${CONTAINER_HOME}/.ssh && chown ${CONTAINER_USER}:${CONTAINER_USER} ${CONTAINER_HOME}/.ssh"

    # Check if SSH public key exists before copying
    if [ ! -f "${HOME}/.ssh/id_rsa.pub" ]; then
      echo "Error: SSH public key ${HOME}/.ssh/id_rsa.pub not found."
      exit 1
    fi

    sudo podman cp ${HOME}/.ssh/id_rsa.pub ${CONTAINER_USER}-container-$i:${CONTAINER_HOME}/.ssh/authorized_keys
    ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i /bin/sh -c "chmod 600 ${CONTAINER_HOME}/.ssh/authorized_keys && chown ${CONTAINER_USER}:${CONTAINER_USER} ${CONTAINER_HOME}/.ssh/authorized_keys"
    ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i /bin/sh -c "echo '${CONTAINER_USER} ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"
    ${CONTAINER_CMD} ${CONTAINER_USER}-container-$i /bin/sh -c "service ssh start"
  done

  infoContainers
}

infoContainers() {
  echo ""
  echo "Container information:"
  echo ""
  sudo podman ps -aq | awk '{system("sudo podman inspect -f \"{{.Name}} -- IP: {{.NetworkSettings.IPAddress}}\" "$1)}'
  echo ""
}

dropContainers() {
  sudo podman ps -a --format '{{.Names}}' | awk -v user="${CONTAINER_USER}" '$1 ~ "^"user {print $1" - dropping..."; system("sudo podman rm -f "$1)}'
  infoContainers
}

startContainers() {
  sudo podman ps -a --format '{{.Names}}' | awk -v user="${CONTAINER_USER}" '$1 ~ "^"user {print $1" - starting..."; system("sudo podman start "$1)}'
  infoContainers
}

stopContainers() {
  sudo podman ps -a --format '{{.Names}}' | awk -v user="${CONTAINER_USER}" '$1 ~ "^"user {print $1" - stopping..."; system("sudo podman stop "$1)}'
  infoContainers
}

createAnsible() {
  echo ""
  mkdir -p ${ANSIBLE_DIR}
  echo "all:" > ${ANSIBLE_DIR}/00_inventory.yml
  echo "  vars:" >> ${ANSIBLE_DIR}/00_inventory.yml
  echo "    ansible_python_interpreter: /usr/bin/python3" >> ${ANSIBLE_DIR}/00_inventory.yml
  echo "  hosts:" >> ${ANSIBLE_DIR}/00_inventory.yml
  sudo podman ps -aq | awk '{system("sudo podman inspect -f \"  {{.NetworkSettings.IPAddress}}:\" "$1)}' >> ${ANSIBLE_DIR}/00_inventory.yml
  mkdir -p ${ANSIBLE_DIR}/host_vars
  mkdir -p ${ANSIBLE_DIR}/group_vars
  echo "Ansible inventory created at ${ANSIBLE_DIR}/00_inventory.yml"
}

# Main Execution ##########################################

if [ "$#" -eq 0 ]; then
  help
  exit 1
fi

while getopts ":c:ahitsdb:" options; do
  case "${options}" in
    c)
      createContainers ${OPTARG}
      ;;
    i)
      infoContainers
      ;;
    s)
      startContainers
      ;;
    t)
      stopContainers
      ;;
    d)
      dropContainers
      ;;
    a)
      createAnsible
      ;;
    b)
      BASE_IMAGE=${OPTARG}
      if ! sudo podman images ${BASE_IMAGE} > /dev/null 2>&1; then
        echo "Error: Base image ${BASE_IMAGE} not found."
        exit 1
      fi
      ;;
    h)
      help
      exit 0
      ;;
    *)
      help
      exit 1
      ;;
  esac
done

