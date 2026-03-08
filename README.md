# Prisma Engine Docker - ARMv7 Cross-Compilation

<div align="center">

[![Docker Build](https://img.shields.io/docker/build/lazarh/prisma-engine-docker.svg)](https://hub.docker.com/r/lazarh/prisma-engine-docker)
[![License](https://img.shields.io/github/license/lazarh/prisma-engine-docker.svg)](LICENSE)

</div>

This project provides Docker build environments for cross-compiling [Prisma ORM](https://www.prisma.io/) engines for **ARMv7** (32-bit ARM) architecture, enabling deployment on devices like Raspberry Pi 3 and other ARMv7-based systems.

## Why This Project?

Prisma officially supports only:
- **x86_64** (amd64)
- **ARM64** (aarch64)

However, many embedded devices and older single-board computers use **ARMv7** (armhf) architecture. This project bridges that gap by providing Docker-based build environments for cross-compiling Prisma engines to ARMv7.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Build Output](#build-output)
- [Usage with Your Project](#usage-with-your-project)
- [Environment Variables](#environment-variables)
- [Building Different Versions](#building-different-versions)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features

- Cross-compiles Prisma engines from x86_64 to ARMv7
- Builds OpenSSL 3.0.x from source for ARMv7
- Produces all required engine binaries:
  - `libquery_engine.so.node` (Query Engine - Node-API library)
  - `schema-engine` (Schema Engine - migrations & introspection)
  - `migration-engine` (Migration Engine)
  - `prisma-fmt` (Schema Formatter)
- Configurable Prisma version via build arguments
- Easy integration with existing projects

## Prerequisites

### System Requirements

- **Docker** 20.10+ with buildx support
- **qemu-user-static** (for cross-architecture builds on x86_64)
- **~15GB** free disk space
- **~30 minutes** build time

### Install QEMU for Cross-Compilation

On x86_64 host, you need QEMU to emulate ARM:

```bash
# Install QEMU for ARMv7
sudo apt-get install -y qemu-user-static qemu-user

# Register ARMv7 emulation (requires Docker with experimental features)
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

## Quick Start

### 1. Build the Docker Image

```bash
# Clone this repository
git clone https://github.com/lazarh/prisma-engine-docker.git
cd prisma-engine-docker

# Build the image (this downloads dependencies and compiles)
docker build -t prisma-armv7-builder .
```

### 2. Build the Engines

```bash
# Run the container to build engines
# Output will be in ./output directory
mkdir -p output
docker run -v $(pwd)/output:/output prisma-armv7-builder

# List the built binaries
ls -la output/armv7/
```

Expected output:
```
armv7/
├── BUILD_INFO
├── libquery_engine.so.node  (Query Engine)
├── migration-engine         (Migration Engine)
├── prisma-fmt              (Schema Formatter)
└── schema-engine           (Schema Engine)
```

### 3. Use in Your Project

Copy the built binaries to your project and configure your application.

See [Usage with Your Project](#usage-with-your-project) for detailed instructions.

## Build Output

After building, you'll find the following binaries in the `output/armv7/` directory:

| Binary | Purpose | Environment Variable |
|--------|---------|---------------------|
| `libquery_engine.so.node` | Query Engine (Node-API) | `PRISMA_QUERY_ENGINE_LIBRARY` |
| `schema-engine` | Schema Engine (migrations, introspection) | `PRISMA_SCHEMA_ENGINE_BINARY` |
| `migration-engine` | Migration Engine | `PRISMA_MIGRATION_ENGINE_BINARY` |
| `prisma-fmt` | Schema Formatter | `PRISMA_FMT_BINARY` |

## Usage with Your Project

### Step 1: Copy Binaries to Your Project

Create a directory in your project (e.g., `prisma/engines/armv7/`) and copy the binaries:

```bash
# Copy binaries to your project
cp output/armv7/* /path/to/your/project/prisma/engines/armv7/
```

### Step 2: Configure Environment Variables

Set the following environment variables in your application's Docker container:

```dockerfile
# In your application's Dockerfile
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma/engines/armv7/libquery_engine.so.node
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma/engines/armv7/schema-engine
ENV PRISMA_MIGRATION_ENGINE_BINARY=/app/prisma/engines/armv7/migration-engine
ENV PRISMA_FMT_BINARY=/app/prisma/engines/armv7/prisma-fmt
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1
```

### Step 3: Copy Binaries in Dockerfile

```dockerfile
# In your application's Dockerfile
COPY --from=builder /app/prisma/engines/armv7 /app/prisma/engines/armv7
```

### Example: Integration with Next.js + Prisma Project

```dockerfile
# Stage 1: Builder
FROM node:22-bookworm AS builder
WORKDIR /app

# ... your existing build steps ...

# Copy ARMv7 Prisma engines
COPY --from=prisma-armv7-engines /output/armv7 /app/prisma/engines/armv7

# Generate Prisma client with ARMv7 engines
ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma/engines/armv7/libquery_engine.so.node
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma/engines/armv7/schema-engine
ENV PRISMA_MIGRATION_ENGINE_BINARY=/app/prisma/engines/armv7/migration-engine
ENV PRISMA_FMT_BINARY=/app/prisma/engines/armv7/prisma-fmt
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1

RUN npx prisma generate

# ... rest of your build ...

# Stage 2: Production
FROM node:22-bookworm-slim
WORKDIR /app

# Copy ARMv7 Prisma engines
COPY --from=builder /app/prisma/engines/armv7 /app/prisma/engines/armv7

ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma/engines/armv7/libquery_engine.so.node
ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma/engines/armv7/schema-engine
ENV PRISMA_MIGRATION_ENGINE_BINARY=/app/prisma/engines/armv7/migration-engine
ENV PRISMA_FMT_BINARY=/app/prisma/engines/armv7/prisma-fmt
ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1

# ... rest of your Dockerfile ...
```

## Environment Variables

### Build-Time Variables

These are used when building the Docker image:

| Variable | Default | Description |
|----------|---------|-------------|
| `PRISMA_VERSION` | `6.7.0` | Prisma Engine version to build |
| `OPENSSL_VERSION` | `3.0.15` | OpenSSL version for ARMv7 |

Example:
```bash
docker build \
    --build-arg PRISMA_VERSION=5.22.0 \
    --build-arg OPENSSL_VERSION=3.0.15 \
    -t prisma-armv7-builder .
```

### Runtime Variables

These are used when running your application:

| Variable | Description |
|----------|-------------|
| `PRISMA_QUERY_ENGINE_LIBRARY` | Path to `libquery_engine.so.node` |
| `PRISMA_SCHEMA_ENGINE_BINARY` | Path to `schema-engine` |
| `PRISMA_MIGRATION_ENGINE_BINARY` | Path to `migration-engine` |
| `PRISMA_FMT_BINARY` | Path to `prisma-fmt` |
| `PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING` | Set to `1` to bypass checksum validation |

## Building Different Versions

### Build Specific Prisma Version

```bash
docker build \
    --build-arg PRISMA_VERSION=5.22.0 \
    -t prisma-armv7-builder:5.22.0 .
```

### Build Latest Prisma Version

```bash
docker build \
    --build-arg PRISMA_VERSION=latest \
    -t prisma-armv7-builder:latest .
```

Note: Using `latest` clones the main branch which may be unstable.

### Build with Different OpenSSL Version

```bash
docker build \
    --build-arg OPENSSL_VERSION=3.1.4 \
    -t prisma-armv7-builder .
```

## Troubleshooting

### Error: "Exec format error"

This usually means QEMU is not properly configured. Install and register QEMU:

```bash
sudo apt-get install -y qemu-user-static
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

### Error: "cannot execute binary file"

The binaries may not be compatible with your target. Ensure:
1. You're targeting ARMv7 architecture
2. QEMU is properly configured (for x86_64 builds)
3. Your deployment target uses ARMv7

### Build Fails with OpenSSL Errors

The OpenSSL build may fail on some systems. Try:
- Using a different OpenSSL version
- Ensuring all build dependencies are installed
- Checking Docker has sufficient memory (at least 4GB)

### Prisma Version Not Found

Ensure the version tag exists in the prisma-engines repository:
- [Prisma Engine Releases](https://github.com/prisma/prisma-engines/tags)

## Alternative: Native ARM Build

If you have access to ARMv7 hardware (e.g., Raspberry Pi 3), you can build natively:

```bash
# On ARMv7 host
git clone https://github.com/lazarh/prisma-engine-docker.git
cd prisma-engine-docker

# Modify Dockerfile to remove cross-compilation and build directly
# Then build:
docker build -t prisma-armv7-builder .
```

## GitHub Actions Integration

Example workflow for automated builds:

```yaml
name: Build ARMv7 Engines

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3
        with:
          platforms: arm/v7
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Build engines
        run: |
          docker build -t prisma-armv7-engines .
          mkdir -p output
          docker run -v $(pwd)/output:/output prisma-armv7-engines
      
      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: prisma-armv7-engines
          path: output/armv7/
```

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

- [Prisma](https://www.prisma.io/) - Amazing ORM
- [prisma-engines](https://github.com/prisma/prisma-engines) - Engine source code
- [idootop/armv7-prisma-engine](https://github.com/idootop/armv7-prisma-engine) - Inspiration
- [ImBIOS/prisma-armv7-builds](https://github.com/ImBIOS/prisma-armv7-builds) - Community builds
