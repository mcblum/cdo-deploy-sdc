#!/bin/bash
DOCKER_GPG="https://download.docker.com/linux/ubuntu/gpg"
DOCKER_APT="https://download.docker.com/linux/ubuntu"

# Detect Ubuntu release - We only support the latest Ubuntu LTS releases
detect_os() {
    source /etc/lsb-release

    if [[ ${DISTRIB_CODENAME} == "jammy" || ${DISTRIB_CODENAME} == "focal" ]]; then
        echo ${DISTRIB_CODENAME}
    else
        echo "${DISTRIB_CODENAME} is not supported by this installation script."
        exit 1
    fi
    echo "Detected Ubuntu version ${DISTRIB_RELEASE}: ${DISTRIB_CODENAME}"

    # Detect x86 cpu architecture or arm64 cpu architecture
    if [[ $(arch) == arm64 || $(arch) == aarch64 ]]; then
        ARCH="arm64"
    elif [[ $(arch) == x86_64 ]]; then
        ARCH="amd64"
    else
        echo "Unable to determine CPU architecture. Only arm64/aarch64 and amd64/x86_64 are supported"
        exit 1
    fi

    echo "Detected ${ARCH} CPU architecture"
}

# Offer to uninstall ubuntu provided docker apt packages, if any
do_legacy_uninstall() {
    packages="docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc"
    echo "Do you wish to uninstall any legacy docker packages that may be installed? (Recommended)"
    echo "See https://docs.docker.com/engine/install/ubuntu/#prerequisites for more information"
    read -r -p "Remove ${packages} [y/N] " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        sudo apt-get remove $packages -y
    fi
}

install_docker() {
    # Install needed packages to add the official docker-ce apt repository
    sudo apt update
    sudo apt install apt-transport-https ca-certificates curl software-properties-common -y

    # Add and trust the official docker-ce apt repository
    echo "${DISTRIB_CODENAME}: Installing the gpg key for the docker-ce apt repository"
    if [ ${DISTRIB_CODENAME} == "jammy" ]; then
        curl -s ${DOCKER_GPG} | sudo gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/docker.gpg --import
        sudo chmod 644 /etc/apt/trusted.gpg.d/docker*
    elif [ ${DISTRIB_CODENAME} == "focal" ]; then
    curl -fsSL ${DOCKER_GPG} | sudo apt-key add -
    fi

    # Add apt repository for the correct CPU archtecture and Ubuntu release version
    echo "Adding the docker-ce apt repository for CPU architecture ${ARCH} for Ubuntu ${DISTRIB_CODENAME}"
    sudo add-apt-repository "deb [arch=${ARCH}] ${DOCKER_APT} ${DISTRIB_CODENAME} stable" -y

    # Install the docker community edition (docker-ce)
    echo "Installing docker-ce (Community Edition)"
    sudo apt-get update
    sudo apt install docker-ce -y
}

finalize_docker_install() {
    # Repoprt the docker daemon status
    echo ""
    echo "Docker daemon status after installation"
    echo $(sudo systemctl status docker | grep 'Active')
    echo ""

    # Add the current user to the docker permissions group
    echo "Adding the current user ${USER} to the docker permissions group"
    sudo usermod -aG docker ${USER}
    echo "Done!"
    newgrp docker
}

detect_os

do_legacy_uninstall

install_docker

finalize_docker_install
