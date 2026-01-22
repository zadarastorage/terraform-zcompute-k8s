# BATS test container for shell script testing
# Supports both Ubuntu and Debian for OS compatibility testing
ARG BASE_IMAGE=ubuntu:22.04
FROM ${BASE_IMAGE}

# Install dependencies used by the scripts under test
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    bash \
    git \
    pciutils \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Install yq (used by setup.sh for config manipulation)
RUN curl -fsSL https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64 \
    -o /usr/local/bin/yq && chmod +x /usr/local/bin/yq

# Install BATS and helper libraries
RUN git clone --depth 1 https://github.com/bats-core/bats-core.git /opt/bats-core && \
    /opt/bats-core/install.sh /usr/local && \
    git clone --depth 1 https://github.com/bats-core/bats-support.git /opt/bats-support && \
    git clone --depth 1 https://github.com/bats-core/bats-assert.git /opt/bats-assert && \
    git clone --depth 1 https://github.com/bats-core/bats-file.git /opt/bats-file

# Set up BATS library path
ENV BATS_LIB_PATH=/opt

WORKDIR /workspace
ENTRYPOINT ["bats"]
