# Generic GPU development environment. Code and data stay on the NAS.
# Latest published CUDA image verified on 2026-09-29.
FROM nvidia/cuda:13.4.1-cudnn-devel-ubuntu24.04

# Install system tools at build time. Job sessions do not need apt or sudo.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential gfortran cmake ninja-build pkg-config gdb \
    python3 python3-dev python3-venv python3-pip python-is-python3 \
    git git-lfs openssh-client rsync curl wget ca-certificates \
    bash-completion less nano vim-tiny tmux htop procps psmisc \
    file ripgrep jq tree unzip zip xz-utils bzip2 \
    iproute2 iputils-ping dnsutils netcat-openbsd \
    libssl-dev libffi-dev libopenblas-dev libhdf5-dev \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Python tools installed at build time.
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/python -m pip install --no-cache-dir jupyterlab uv
ENV PATH="/opt/venv/bin:$PATH" PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

# The job's user can set the link without root permissions.
RUN mkdir -m 1777 /run/rcp && ln -s /run/rcp/home /app \
    && printf '%s\n' \
    '#!/bin/bash' \
    'set -euo pipefail' \
    ': "${NAS_HOME:?Set NAS_HOME to your mounted NAS folder}"' \
    'test -d "$NAS_HOME"' \
    'ln -sfn -- "$NAS_HOME" /run/rcp/home' \
    'cd -- "${WORK_DIR:-/app}"' \
    'exec "$@"' \
    > /usr/local/bin/rcp-entrypoint \
    && chmod 755 /usr/local/bin/rcp-entrypoint
WORKDIR /
ENTRYPOINT ["/usr/local/bin/rcp-entrypoint"]
CMD ["/bin/bash"]
