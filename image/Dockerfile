# Generic GPU development environment. Code and data stay on the NAS.
FROM nvidia/cuda:13.4.2-cudnn-devel-ubuntu26.04

# Install system tools at build time. Job sessions do not need apt or sudo.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential gfortran cmake ninja-build pkg-config gdb \
    python3 python3-dev python3-venv python3-pip python-is-python3 \
    git git-lfs openssh-client rsync curl wget ca-certificates \
    bash-completion less nano vim-tiny tmux htop procps psmisc \
    file ripgrep jq tree unzip zip xz-utils bzip2 bubblewrap \
    iproute2 iputils-ping bind9-dnsutils netcat-openbsd \
    libssl-dev libffi-dev libopenblas-dev libhdf5-dev \
    libgl1 libglib2.0-0t64 libsm6 libxext6 libxrender1 ffmpeg \
    # Third-party scientific builds (MPI codes such as KISIP, FITS)
    libopenmpi-dev openmpi-bin libfftw3-dev libgsl-dev \
    libcfitsio-dev libcfitsio-bin \
    # Native builds: compiler cache, Rust bindgen, fast linker
    ccache clang libclang-dev mold \
    # Compression and data tools
    zstd pigz lz4 libzstd-dev liblz4-dev libblosc2-dev sqlite3 parallel \
    # Profiling and debugging that works without admin rights
    time strace lsof valgrind heaptrack sysstat nvtop numactl hwloc \
    # Everyday command-line tools: search, disk usage, progress, benchmarks, shell linting
    fd-find fzf ncdu pv hyperfine shellcheck 7zip pciutils patchelf \
    # GitHub and data transfer (S3, Drive, fast multi-connection downloads)
    gh rclone aria2 \
    # Headless rendering (EGL) and figures
    libegl1 libopengl0 imagemagick graphviz \
    # Locale and time zone
    locales tzdata \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 MPLBACKEND=Agg

# Ubuntu names the binary fdfind.
RUN ln -s /usr/bin/fdfind /usr/local/bin/fd

# Let Codex's system bubblewrap create namespaces on Ubuntu.
RUN chmod u+s /usr/bin/bwrap

# Rust toolchain (rustup, shared, read-only); caches live on the NAS (entrypoint).
ENV RUSTUP_HOME=/opt/rust/rustup PATH="/opt/rust/cargo/bin:$PATH"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | CARGO_HOME=/opt/rust/cargo sh -s -- -y --no-modify-path \
      --profile minimal --component clippy,rustfmt --default-toolchain stable \
    && chmod -R a+rX /opt/rust

# Python 3.10 and 3.12 from uv. Ubuntu 26.04 only packages 3.14, which stays for system tools.
# /opt/venv makes 3.12 the default; `uv venv --python 3.10` selects the other one.
RUN curl -fsSL https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh \
    && UV_PYTHON_INSTALL_DIR=/opt/python UV_PYTHON_BIN_DIR=/usr/local/bin uv python install 3.10 3.12 \
    && chmod -R a+rX /opt/python \
    && python3.12 -m venv /opt/venv \
    && /opt/venv/bin/python -m pip install --no-cache-dir jupyterlab
ENV PATH="/opt/venv/bin:$PATH" PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

# Node.js LTS for MCP servers and JavaScript tools. Ubuntu's nodejs (18) is end-of-life.
ARG NODE_VERSION=24.22.2
ARG NODE_SHA256=48cc0e21e048790e54c0cf5749c2725005313d652651c40b7a21feb9697aaf75
RUN curl -fsSL -o /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" \
    && echo "${NODE_SHA256}  /tmp/node.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 --no-same-owner \
    && rm /tmp/node.tar.xz \
    && node --version

# TensorRT from NVIDIA's tar file (C++ headers, libs, trtexec, Python wheel).
# The nvidia/cuda tensorrt tags are arm64-only, and apt lags behind the latest release.
ARG TRT_VERSION=11.3.0 TRT_BUILD=11.3.0.99 TRT_CUDA=13.4
ENV TENSORRT_DIR=/opt/tensorrt PATH="/opt/tensorrt/bin:$PATH"
RUN mkdir -p /opt/tensorrt \
    && curl -fsSL "https://developer.download.nvidia.com/compute/machine-learning/tensorrt/${TRT_VERSION}/tars/TensorRT-Enterprise-${TRT_BUILD}-Linux-x86_64-cuda-${TRT_CUDA}-Release-external.tar.zst" \
    | tar -I zstd -x -C /opt/tensorrt --strip-components=1 \
    && echo /opt/tensorrt/lib > /etc/ld.so.conf.d/tensorrt.conf && ldconfig \
    && /opt/venv/bin/python -m pip install --no-cache-dir /opt/tensorrt/python/tensorrt-*-cp312-none-linux_x86_64.whl \
    && /opt/venv/bin/python -c "import tensorrt; print(tensorrt.__version__)"

# The job's user can set the link without root permissions.
# Build and compile caches (cargo registry/targets, ccache, uv, Triton kernels,
# torch.compile/Inductor) default to the NAS so they persist across jobs.
RUN mkdir -m 1777 /run/rcp && ln -s /run/rcp/home /app \
    && printf '%s\n' \
    '#!/bin/bash' \
    'set -euo pipefail' \
    ': "${NAS_HOME:?Set NAS_HOME to your mounted NAS folder}"' \
    'test -d "$NAS_HOME"' \
    'ln -sfn -- "$NAS_HOME" /run/rcp/home' \
    'export CARGO_HOME="${CARGO_HOME:-$NAS_HOME/.cache/cargo}"' \
    'export CCACHE_DIR="${CCACHE_DIR:-$NAS_HOME/.cache/ccache}"' \
    'export UV_CACHE_DIR="${UV_CACHE_DIR:-$NAS_HOME/.cache/uv}"' \
    'export TRITON_CACHE_DIR="${TRITON_CACHE_DIR:-$NAS_HOME/.cache/triton}"' \
    'export TORCHINDUCTOR_CACHE_DIR="${TORCHINDUCTOR_CACHE_DIR:-$NAS_HOME/.cache/torchinductor}"' \
    'cd -- "${WORK_DIR:-/app}"' \
    'exec "$@"' \
    > /usr/local/bin/rcp-entrypoint \
    && chmod 755 /usr/local/bin/rcp-entrypoint
WORKDIR /
ENTRYPOINT ["/usr/local/bin/rcp-entrypoint"]
CMD ["/bin/bash"]
