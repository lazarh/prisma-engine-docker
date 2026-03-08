# Prisma Engine ARMv7 Cross-Compilation Docker Image
# ================================================
# This Dockerfile builds Prisma ORM engines for ARMv7 (32-bit ARM) architecture.
# It cross-compiles from x86_64 to ARMv7 using the ARM hard-float ABI.
#
# Usage:
#   docker build -t prisma-armv7-builder .
#   docker run -v $(pwd)/output:/output prisma-armv7-builder
#
# Output:
#   - libquery_engine.so.node  (Query engine library for Node.js)
#   - schema-engine           (Schema engine for migrations/introspection)
#   - migration-engine       (Migration engine)
#   - prisma-fmt            (Schema formatter)
#
# Environment Variables:
#   PRISMA_VERSION - Version of prisma-engines to build (default: 6.7.0)
#   OPENSSL_VERSION - OpenSSL version to build (default: 3.0.15)

# ==============================================================================
# Stage 1: Base image with cross-compilation tools
# ==============================================================================
FROM ubuntu:22.04 AS builder

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc-arm-linux-gnueabihf \
    g++-arm-linux-gnueabihf \
    libc6-dev-armhf-cross \
    libc6-armhf-cross \
    libssl-dev \
    pkg-config \
    wget \
    curl \
    git \
    make \
    perl \
    && rm -rf /var/lib/apt/lists/*

# Install Rust toolchain
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
ENV PATH="/root/.cargo/bin:${PATH}"

# Set default versions
ARG PRISMA_VERSION=6.7.0
ARG OPENSSL_VERSION=3.0.16

ENV PRISMA_VERSION=${PRISMA_VERSION}
ENV OPENSSL_VERSION=${OPENSSL_VERSION}

# ==============================================================================
# Stage 2: Build OpenSSL 3.0.x for ARMv7
# ==============================================================================
FROM builder AS openssl-builder

WORKDIR /tmp

# Download and extract OpenSSL
RUN wget -q https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar xzf openssl-${OPENSSL_VERSION}.tar.gz && \
    rm openssl-${OPENSSL_VERSION}.tar.gz

WORKDIR /tmp/openssl-${OPENSSL_VERSION}

# Configure OpenSSL for ARMv7 with hard-float ABI
# Using linux-armv4 target which is compatible with ARMv7
# Disable problematic NIST curves that cause build issues on ARM
RUN ./Configure --prefix=/opt/openssl-armv7 \
    --openssldir=/opt/openssl-armv7 \
    linux-armv4 \
    -mfpu=vfpv4 \
    -mfloat-abi=hard \
    -Wno-error \
    no-shared \
    no-async \
    no-ec_nistp_64_gcc_128

# Cross-compile OpenSSL for ARMv7
# Use single-threaded build to avoid race conditions, add -Wno-error
RUN make -j2 \
    CC=arm-linux-gnueabihf-gcc \
    AR="arm-linux-gnueabihf-ar" \
    RANLIB="arm-linux-gnueabihf-ranlib" \
    ARCH=arm \
    CFLAGS="-O2 -Wno-error"

RUN make install \
    CC=arm-linux-gnueabihf-gcc \
    AR="arm-linux-gnueabihf-ar" \
    RANLIB="arm-linux-gnueabihf-ranlib" \
    DESTDIR=/tmp/openssl-install

# ==============================================================================
# Stage 3: Build Prisma Engines for ARMv7
# ==============================================================================
FROM builder AS prisma-builder

# Copy pre-built OpenSSL from previous stage
COPY --from=openssl-builder /tmp/openssl-install/usr/local /opt/openssl-armv7

WORKDIR /tmp/prisma-engines

# Clone prisma-engines at specified version
RUN git clone --depth=1 --branch ${PRISMA_VERSION} https://github.com/prisma/prisma-engines.git /tmp/prisma-engines

# Set cross-compilation environment
ENV OPENSSL_DIR=/opt/openssl-armv7
ENV OPENSSL_LIB_DIR=/opt/openssl-armv7/lib
ENV OPENSSL_INCLUDE_DIR=/opt/openssl-armv7/include
ENV OPENSSL_STATIC=1
ENV CARGO_TARGET_ARM_UNKNOWN_LINUX_GNUEABIHF_LINKER=arm-linux-gnueabihf-gcc
ENV CC_arm_unknown_linux_gnueabihf=arm-linux-gnueabihf-gcc
ENV CXX_arm_unknown_linux_gnueabihf=arm-linux-gnueabihf-g++

# Create .cargo/config.toml for cross-compilation
RUN mkdir -p /tmp/prisma-engines/.cargo && \
    printf '%s\n' \
        '[target.armv7-unknown-linux-gnueabihf]' \
        'linker = "arm-linux-gnueabihf-gcc"' \
        'runner = "arm-linux-gnueabihf-gcc"' \
        '' \
        '[build]' \
        'target = "armv7-unknown-linux-gnueabihf"' \
        > /tmp/prisma-engines/.cargo/config.toml

# Symlink ARM libraries for linking
RUN ln -sf /usr/arm-linux-gnueabihf/lib/ld-linux-armhf.so.3 /lib/ld-linux-armhf.so.3 || true

# Build prisma-fmt (standalone, no external dependencies)
WORKDIR /tmp/prisma-engines/prisma-fmt
RUN cargo build --release --target armv7-unknown-linux-gnueabihf

# Build schema-engine
WORKDIR /tmp/prisma-engines/schema-engine
RUN cargo build --release --target armv7-unknown-linux-gnueabihf

# Build migration-engine
WORKDIR /tmp/prisma-engines/migration-engine
RUN cargo build --release --target armv7-unknown-linux-gnueabihf

# Build query-engine (as a library for Node-API)
WORKDIR /tmp/prisma-engines/query-engine
RUN cargo build --release --target armv7-unknown-linux-gnueabihf --lib

# ==============================================================================
# Stage 4: Extract and Package Binaries
# ==============================================================================
FROM debian:bookworm-slim AS output

# Install dependencies for copying files
RUN apt-get update && apt-get install -y \
    libc6-armhf-cross \
    libc6-dev-armhf-cross \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /output

# Copy binaries from builder stage
# Note: In cross-compilation, we copy the compiled binaries from the x86_64 host
# that were built for the ARM target. The actual binaries are in the builder.

# Copy from prisma-builder stage - create dummy files as placeholders
# The actual binaries will be created when running the container with proper emulation
# or when built natively on ARM hardware

# For cross-compilation to work properly, we need QEMU or native ARM build
# This Dockerfile is designed to be run with --platform linux/arm/v7 for native ARM
# or with QEMU emulation on x86_64

# Create output directory structure
RUN mkdir -p /output/armv7

# Create a marker file with build info
RUN echo "Prisma ARMv7 Engine Build" > /output/armv7/BUILD_INFO && \
    echo "Version: ${PRISMA_VERSION}" >> /output/armv7/BUILD_INFO && \
    echo "OpenSSL: ${OPENSSL_VERSION}" >> /output/armv7/BUILD_INFO && \
    echo "Target: armv7-unknown-linux-gnueabihf" >> /output/armv7/BUILD_INFO

# Copy built binaries from prisma-builder (when built natively on ARM or with emulation)
COPY --from=prisma-builder /tmp/prisma-engines/target/armv7-unknown-linux-gnueabihf/release/prisma-fmt /output/armv7/
COPY --from=prisma-builder /tmp/prisma-engines/target/armv7-unknown-linux-gnueabihf/release/schema-engine /output/armv7/
COPY --from=prisma-builder /tmp/prisma-engines/target/armv7-unknown-linux-gnueabihf/release/migration-engine /output/armv7/
COPY --from=prisma-builder /tmp/prisma-engines/target/armv7-unknown-linux-gnueabihf/release/libquery_engine.so /output/armv7/libquery_engine.so.node

# Make binaries executable
RUN chmod +x /output/armv7/prisma-fmt \
    /output/armv7/schema-engine \
    /output/armv7/migration-engine \
    /output/armv7/libquery_engine.so.node || true

# Create a tarball for easy distribution
RUN cd /output && tar -czvf prisma-armv7-engines.tar.gz armv7/

# ==============================================================================
# Builder Stage - Main entry point
# ==============================================================================
FROM builder AS final

# Copy all stages
COPY --from=openssl-builder /tmp/openssl-install /tmp/openssl-install
COPY --from=prisma-builder /tmp/prisma-engines /tmp/prisma-engines

WORKDIR /output

# Copy built binaries
RUN mkdir -p /output/armv7 && \
    cp /tmp/prisma-engines/target/armv7-unknown-linux-gnueabihf/release/prisma-fmt /output/armv7/ && \
    cp /tmp/prisma-engines/target/armv7-unknown-linux-gnueabihf/release/schema-engine /output/armv7/ && \
    cp /tmp/prisma-engines/target/armv7-unknown-linux-gnueabihf/release/migration-engine /output/armv7/ && \
    cp /tmp/prisma-engines/target/armv7-unknown-linux-gnueabihf/release/libquery_engine.so /output/armv7/libquery_engine.so.node && \
    chmod +x /output/armv7/*

# Default command - build is complete
CMD ["ls", "-la", "/output/armv7/"]
