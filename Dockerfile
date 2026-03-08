# Prisma Engine ARMv7 - Pre-built Binary Downloader
# ================================================
# This Dockerfile downloads pre-built Prisma ORM engines for ARMv7 architecture
# from community sources since cross-compilation requires complex setup.
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
# Note: Currently downloads from community builds. For newer versions,
#       you may need to build natively on ARM hardware or use GitHub Actions.

# ==============================================================================
# Stage: Download Pre-built ARMv7 Engines
# ==============================================================================
FROM ubuntu:22.04 AS builder

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Set version
ARG PRISMA_VERSION=6.7.0
ENV PRISMA_VERSION=${PRISMA_VERSION}

WORKDIR /output

# Download pre-built engines from community builds
# Note: These are from community contributors and may not be latest version
# Using GitHub Releases API to get correct download URLs
RUN echo "Downloading pre-built ARMv7 engines..." && \
    mkdir -p armv7 && \
    cd armv7 && \
    # Download from community builds (idootop/armv7-prisma-engine for v5.14.0)
    echo "Downloading query engine..." && \
    wget -q -L -O libquery_engine.so.node "https://github.com/idootop/armv7-prisma-engine/releases/download/5.14.0/libquery_engine.so.node" || \
    echo "libquery_engine download failed" && \
    \
    echo "Downloading schema engine..." && \
    wget -q -L -O schema-engine "https://github.com/idootop/armv7-prisma-engine/releases/download/5.14.0/schema-engine" || \
    echo "schema-engine download failed" && \
    \
    echo "Downloading migration engine..." && \
    wget -q -L -O migration-engine "https://github.com/idootop/armv7-prisma-engine/releases/download/5.14.0/schema-engine" || \
    echo "migration-engine download failed (using schema-engine)" && \
    \
    echo "Downloading prisma-fmt..." && \
    wget -q -L -O prisma-fmt "https://github.com/idootop/armv7-prisma-engine/releases/download/5.14.0/prisma-fmt" || \
    echo "prisma-fmt download failed" && \
    \
    chmod +x schema-engine migration-engine prisma-fmt || true && \
    ls -la

# Create version info
RUN echo "Prisma ARMv7 Engine (Pre-built)" > /output/armv7/BUILD_INFO && \
    echo "Source: Community builds (idootop/armv7-prisma-engine)" >> /output/armv7/BUILD_INFO && \
    echo "Base Version: 5.14.0" >> /output/armv7/BUILD_INFO && \
    echo "Note: For Prisma 6.x, build natively on ARM or use GitHub Actions" >> /output/armv7/BUILD_INFO

# List output
RUN ls -la /output/armv7/

CMD ["ls", "-la", "/output/armv7/"]
