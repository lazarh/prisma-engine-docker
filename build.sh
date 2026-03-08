#!/bin/bash
#
# Build Script for Prisma ARMv7 Engines
# ======================================
# This script builds Prisma ORM engines for ARMv7 architecture.
#
# Usage:
#   ./build.sh                    # Build with default Prisma version (6.7.0)
#   ./build.sh 5.22.0            # Build specific Prisma version
#   ./build.sh --clean           # Clean output directory before build
#   ./build.sh --help            # Show help
#

set -e

# Configuration
DEFAULT_PRISMA_VERSION="6.7.0"
DEFAULT_OPENSSL_VERSION="3.0.15"
IMAGE_NAME="prisma-armv7-builder"
OUTPUT_DIR="output"
PRISMA_VERSION="${1:-$DEFAULT_PRISMA_VERSION}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
Prisma ARMv7 Engine Build Script

Usage:
    $0 [version] [options]

Arguments:
    version         Prisma version to build (default: $DEFAULT_PRISMA_VERSION)

Options:
    --clean         Clean output directory before build
    --help          Show this help message

Examples:
    $0                          # Build default version ($DEFAULT_PRISMA_VERSION)
    $0 5.22.0                   # Build specific version
    $0 --clean                  # Clean and build default version
    $0 5.22.0 --clean          # Clean and build specific version

Environment Variables:
    PRISMA_VERSION     Prisma version (overrides argument)
    OPENSSL_VERSION    OpenSSL version to build (default: $DEFAULT_OPENSSL_VERSION)

EOF
}

# Parse arguments
CLEAN_BUILD=false
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Restore positional arguments
set -- "${POSITIONAL_ARGS[@]}"

if [ -n "$1" ]; then
    PRISMA_VERSION="$1"
fi

# Validate version format
if [[ ! "$PRISMA_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && [ "$PRISMA_VERSION" != "latest" ]; then
    log_error "Invalid version format: $PRISMA_VERSION"
    log_error "Expected format: X.Y.Z (e.g., 6.7.0) or 'latest'"
    exit 1
fi

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    # Check Docker version
    DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "0")
    if [ "$(echo "$DOCKER_VERSION < 20.10" | bc)" = "1" ]; then
        log_error "Docker version 20.10+ required. Current: $DOCKER_VERSION"
        exit 1
    fi

    # Check buildx
    if ! docker buildx version &> /dev/null; then
        log_warn "Docker buildx not available. Some features may not work."
    fi

    # Check disk space (require ~15GB)
    AVAILABLE_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | tr -d 'G')
    if [ "$AVAILABLE_SPACE" -lt 15 ]; then
        log_error "Insufficient disk space. Need at least 15GB, available: ${AVAILABLE_SPACE}GB"
        exit 1
    fi

    log_info "Prerequisites check passed."
}

# Setup QEMU for cross-compilation
setup_qemu() {
    log_info "Setting up QEMU for ARMv7..."

    # Check if we're on x86_64
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        log_info "Detected x86_64 host, setting up QEMU emulation..."

        # Try to set up QEMU
        if command -v qemu-user-static &> /dev/null; then
            docker run --rm --privileged multiarch/qemu-user-static --reset -p yes 2>/dev/null || {
                log_warn "QEMU setup failed. Build may not work on x86_64 without proper emulation."
            }
        else
            log_warn "qemu-user-static not installed. For x86_64 hosts, install with:"
            log_warn "  sudo apt-get install -y qemu-user-static"
            log_warn "  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes"
        fi
    else
        log_info "Building on ARM architecture - no QEMU needed."
    fi
}

# Clean output directory
clean_output() {
    if [ "$CLEAN_BUILD" = true ]; then
        log_info "Cleaning output directory..."
        rm -rf "$OUTPUT_DIR"
        mkdir -p "$OUTPUT_DIR"
    else
        mkdir -p "$OUTPUT_DIR"
    fi
}

# Build the Docker image
build_docker_image() {
    log_info "Building Docker image..."
    log_info "  Prisma Version: $PRISMA_VERSION"
    log_info "  OpenSSL Version: $DEFAULT_OPENSSL_VERSION"

    docker build \
        --build-arg PRISMA_VERSION="$PRISMA_VERSION" \
        --build-arg OPENSSL_VERSION="$DEFAULT_OPENSSL_VERSION" \
        -t "$IMAGE_NAME:$PRISMA_VERSION" \
        -t "$IMAGE_NAME:latest" \
        .

    log_info "Docker image built successfully."
}

# Run the build
run_build() {
    log_info "Running build container..."

    docker run \
        -v "$(pwd)/$OUTPUT_DIR:/output" \
        "$IMAGE_NAME:$PRISMA_VERSION"

    log_info "Build complete!"
}

# Display results
show_results() {
    log_info "Build output in: $OUTPUT_DIR/armv7/"
    
    if [ -d "$OUTPUT_DIR/armv7" ]; then
        echo
        log_info "Built binaries:"
        ls -lh "$OUTPUT_DIR/armv7/"
        
        # Check for expected files
        EXPECTED_FILES=(
            "libquery_engine.so.node"
            "schema-engine"
            "migration-engine"
            "prisma-fmt"
        )
        
        echo
        for file in "${EXPECTED_FILES[@]}"; do
            if [ -f "$OUTPUT_DIR/armv7/$file" ]; then
                log_info "  ✓ $file"
            else
                log_warn "  ✗ $file (missing)"
            fi
        done
    else
        log_error "No output directory created. Build may have failed."
        exit 1
    fi
}

# Main execution
main() {
    echo "=============================================="
    echo "  Prisma ARMv7 Engine Build Script"
    echo "=============================================="
    echo
    
    check_prerequisites
    setup_qemu
    clean_output
    build_docker_image
    run_build
    show_results
    
    echo
    log_info "Build completed successfully!"
    echo
    echo "Next steps:"
    echo "  1. Copy binaries to your project:"
    echo "     cp -r $OUTPUT_DIR/armv7/ /your/project/prisma/engines/"
    echo
    echo "  2. Set environment variables in your Dockerfile:"
    echo "     ENV PRISMA_QUERY_ENGINE_LIBRARY=/app/prisma/engines/armv7/libquery_engine.so.node"
    echo "     ENV PRISMA_SCHEMA_ENGINE_BINARY=/app/prisma/engines/armv7/schema-engine"
    echo "     ENV PRISMA_MIGRATION_ENGINE_BINARY=/app/prisma/engines/armv7/migration-engine"
    echo "     ENV PRISMA_FMT_BINARY=/app/prisma/engines/armv7/prisma-fmt"
    echo "     ENV PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING=1"
    echo
}

# Run main
main "$@"
