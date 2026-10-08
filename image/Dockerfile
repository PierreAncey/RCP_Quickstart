# Generic GPU development environment. Code and data stay on the NAS.
FROM nvidia/cuda:13.4.2-tensorrt-devel-ubuntu24.04

# Install system tools at build time. Job sessions do not need apt or sudo.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential gfortran cmake ninja-build pkg-config gdb \
    python3 python3-dev python3-venv python3-pip python-is-python3 \
    git git-lfs openssh-client rsync curl wget ca-certificates \
    bash-completion less nano vim-tiny tmux htop procps psmisc \
    file ripgrep jq tree unzip zip xz-utils bzip2 bubblewrap \
    iproute2 iputils-ping dnsutils netcat-openbsd \
    libssl-dev libffi-dev libopenblas-dev libhdf5-dev \
    libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 ffmpeg \
    # Third-party scientific builds (MPI codes such as KISIP, FITS)
    libopenmpi-dev openmpi-bin libfftw3-dev libgsl-dev \
    libcfitsio-dev libcfitsio-bin \
    # Native builds: compiler cache, Rust bindgen, fast linker
    ccache clang libclang-dev mold \
    # Compression and data tools
    zstd pigz lz4 libzstd-dev liblz4-dev libblosc2-dev sqlite3 parallel \
    # Profiling and debugging that works without admin rights
    time strace lsof valgrind heaptrack sysstat nvtop numactl hwloc \
    # Locale and time zone
    locales tzdata \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 MPLBACKEND=Agg

# Let Codex's system bubblewrap create namespaces on Ubuntu 24.04.
RUN chmod u+s /usr/bin/bwrap

# Rust toolchain (rustup, shared, read-only); caches live on the NAS (entrypoint).
ENV RUSTUP_HOME=/opt/rust/rustup PATH="/opt/rust/cargo/bin:$PATH"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | CARGO_HOME=/opt/rust/cargo sh -s -- -y --no-modify-path \
      --profile minimal --component clippy,rustfmt --default-toolchain stable \
    && chmod -R a+rX /opt/rust

# Python tools installed at build time.
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/python -m pip install --no-cache-dir jupyterlab uv
ENV PATH="/opt/venv/bin:$PATH" PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1

# The job's user can set the link without root permissions.
# Build caches (cargo registry/targets, ccache, uv) default to the NAS so they persist.
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
    'cd -- "${WORK_DIR:-/app}"' \
    'exec "$@"' \
    > /usr/local/bin/rcp-entrypoint \
    && chmod 755 /usr/local/bin/rcp-entrypoint
WORKDIR /
ENTRYPOINT ["/usr/local/bin/rcp-entrypoint"]
CMD ["/bin/bash"]
