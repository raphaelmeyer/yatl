FROM debian:trixie

ARG USER_UID=1000
ARG USER_GID=1000
ARG WASM_TOOLS_VERSION=1.256.0

ENV LANG=C.utf8 LC_ALL=C.utf8

RUN groupadd -g "${USER_GID}" user \
    && useradd -m -u "${USER_UID}" -g "${USER_GID}" -s /bin/bash user

    # xz-utils required ?
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential ca-certificates curl git \
       libffi-dev libgmp-dev libncurses-dev zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl --location https://taskfile.dev/install.sh | sh -s -- -d -b /usr/local/bin

RUN mkdir -p /workspace /workspace/yatlc/dist-newstyle /home/user/claude-config \
    && chown user:user /workspace /workspace/yatlc/dist-newstyle /home/user/claude-config

USER user

RUN BOOTSTRAP_HASKELL_NONINTERACTIVE=1 \
    BOOTSTRAP_HASKELL_GHC_VERSION=recommended \
    BOOTSTRAP_HASKELL_CABAL_VERSION=recommended \
    BOOTSTRAP_HASKELL_HLS_VERSION=recommended \
    BOOTSTRAP_HASKELL_INSTALL_HLS=1 \
    curl -sSf https://get-ghcup.haskell.org | sh

RUN curl https://wasmtime.dev/install.sh -sSf | bash

RUN mkdir -p /home/user/.local/bin \
    && curl -fsSL https://github.com/bytecodealliance/wasm-tools/releases/download/v${WASM_TOOLS_VERSION}/wasm-tools-${WASM_TOOLS_VERSION}-x86_64-linux.tar.gz \
       | tar xz -C /tmp \
    && mv /tmp/wasm-tools-${WASM_TOOLS_VERSION}-x86_64-linux/wasm-tools /home/user/.local/bin/wasm-tools \
    && rm -rf /tmp/wasm-tools-${WASM_TOOLS_VERSION}-x86_64-linux

RUN curl -fsSL https://claude.ai/install.sh | bash

ENV CLAUDE_CONFIG_DIR=/home/user/claude-config
ENV PATH="/home/user/.local/bin:/home/user/.ghcup/bin:/home/user/.cabal/bin:${PATH}"

VOLUME /home/user/.cabal
VOLUME ${CLAUDE_CONFIG_DIR}
VOLUME /workspace/yatlc/dist-newstyle

WORKDIR /workspace
