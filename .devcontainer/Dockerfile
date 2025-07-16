# syntax=docker/dockerfile:1

FROM openwrt/sdk:x86-64-openwrt-24.10
# suppress clear apt cache
USER root
RUN rm /etc/apt/apt.conf.d/docker-clean

ARG USERNAME=vscode
ARG UID=10000
ARG GID=$UID

# Setup user and group id
# Remove all general users and create a new user for USER direction.
RUN set -eux; \
    for i in $(awk -F: '$3 >= 1000 && $3 <= 60000 { print $1 }' /etc/passwd); do \
    userdel $i; \
    done; \
    for i in $(awk -F: '$3 >= 1000 && $3 <= 60000 { print $1 }' /etc/passwd); do \
    groupdel $i; \
    done; \
    rm -rf /home/*; \
    groupadd --gid "${GID}" "${USERNAME}"; \
    useradd --uid "${UID}" --gid "${GID}" -s /bin/bash -m "${USERNAME}"
RUN chown -R "${USERNAME}" /builder

# Default user
USER vscode
