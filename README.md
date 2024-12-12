
# **PodmanWiz**

**PodmanWiz** is a Bash script that simplifies container management with Podman. It allows you to create, manage, and customize containers across multiple Linux distributions. The script is now more flexible and configurable using environment variables.

---

## Key Features

- **Customizable Base Images**: Use your preferred base image (e.g., `alpine`, `ubuntu`, `fedora`) with the `-b` flag. Default image is `docker.io/priximmo/buster-systemd-ssh`, but you can set the `BASE_IMAGE` environment variable for different base images.
- **Multi-Container Management**: Create, start, stop, or remove multiple containers in one command.
- **SSH Integration**: Automatically configures SSH for easy access to your containers, including validation for the presence of SSH keys.
- **Ansible Inventory Support**: Generates an Ansible inventory file for seamless automation workflows.
- **Error Handling**: The script now includes error handling for Podman operations (e.g., container creation, starting, and SSH setup) to ensure smooth execution.

---

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/<your-username>/PodmanWiz.git
   cd PodmanWiz
   ```

2. Ensure the script has executable permissions:

   ```bash
   chmod +x podmanwiz.sh
   ```

3. Make sure **Podman** is installed on your system.

---

## Usage

Run the script with the appropriate flags for your use case:

```bash
./podmanwiz.sh [options]
```

### Options:

| Flag      | Description                                                                 |
|-----------|-----------------------------------------------------------------------------|
| `-c <n>`  | Create `<n>` containers.                                                   |
| `-i`      | Display container names and IPs.                                           |
| `-s`      | Start all containers created by the script.                                |
| `-t`      | Stop all containers created by the script.                                 |
| `-d`      | Remove all containers created by the script.                               |
| `-a`      | Generate an Ansible inventory file with container IPs.                     |
| `-b <img>`| Specify a custom base image for the containers (e.g., `alpine`, `ubuntu`). |
| `-h`      | Display the help message.                                                 |

---

## Examples

### Create 3 containers using the `alpine` image:

```bash
./podmanwiz.sh -b alpine -c 3
```

### Start all containers:

```bash
./podmanwiz.sh -s
```

### Generate an Ansible inventory file:

```bash
./podmanwiz.sh -a
```

### Remove all containers:

```bash
./podmanwiz.sh -d
```

---

## Prerequisites

- **Podman**: Ensure Podman is installed and properly configured.
- **Root or Sudo Access**: Some operations require administrative privileges.
- **Public Key Authentication**: SSH setup assumes the presence of `~/.ssh/id_rsa.pub`. If it doesn't exist, the script will display an error message.
- **Environment Variables**: Optionally, you can set the following environment variables:
  - `BASE_IMAGE`: Custom base image for containers.
  - `DATA_DIR`: Directory to store container data (default: `/srv/data`).
  - `ANSIBLE_DIR`: Directory for generating the Ansible inventory file (default: `ansible_dir`).
  - `CONTAINER_USER`: The user for SSH and container management (default: `SUDO_USER` or `$USER`).

---
