# Base image plus Blender, for rendering on RCP (Cycles with CUDA/OptiX, or EEVEE).
# Build: docker build --platform linux/amd64 -t registry.rcp.epfl.ch/cvlab-pancey/base-blender:0.1 image-blender
FROM registry.rcp.epfl.ch/cvlab-pancey/base:0.2

ARG BLENDER_VERSION=5.1.2
ARG BLENDER_SHA256=aaccb355f50183979b698bcce7467103a76261b5fa59f4972295842662a285fb

# Libraries Blender loads even when running without a display.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libx11-6 libxi6 libxxf86vm1 libxfixes3 libxrender1 libxext6 libxkbcommon0 \
    libxcursor1 libxinerama1 libxrandr2 libsm6 libice6 bubblewrap \
    libgl1 libegl1 libglu1-mesa libwayland-client0 libwayland-egl1 libdecor-0-0 \
    && rm -rf /var/lib/apt/lists/*

# Also support Codex when building from a base published before this fix.
RUN chmod u+s /usr/bin/bwrap

RUN curl -fsSL -o /tmp/blender.tar.xz \
        "https://download.blender.org/release/Blender${BLENDER_VERSION%.*}/blender-${BLENDER_VERSION}-linux-x64.tar.xz" \
    && echo "${BLENDER_SHA256}  /tmp/blender.tar.xz" | sha256sum -c - \
    && mkdir -p /opt/blender \
    && tar -xJf /tmp/blender.tar.xz -C /opt/blender --strip-components=1 \
    && rm /tmp/blender.tar.xz \
    && ln -s /opt/blender/blender /usr/local/bin/blender

# Give jobs access to the GPU's graphics libraries too (EEVEE, OptiX), not only CUDA.
ENV NVIDIA_DRIVER_CAPABILITIES=all
