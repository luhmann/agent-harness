#!/bin/bash
# cleanup.sh - Cleanup AI Agent Harness resources
#
# This script can:
# 1. Stop the container
# 2. Remove the container
# 3. Remove Docker volumes (auth, cache)
# 4. Remove Docker images
#
# Usage: ./scripts/cleanup.sh [--full]

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONTAINER_NAME="claude-agent-sandbox"
FULL_CLEANUP=false

# Parse arguments
if [ "$1" == "--full" ] || [ "$1" == "-f" ]; then
    FULL_CLEANUP=true
fi

echo -e "${BLUE}=== AI Agent Harness Cleanup ===${NC}"
echo ""

# ============================================================================
# Check if Docker is running
# ============================================================================

if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    echo -e "${RED}  Please start Docker and try again${NC}"
    exit 1
fi

# ============================================================================
# Stop container if running
# ============================================================================

CONTAINER_RUNNING=$(docker ps --filter "name=^${CONTAINER_NAME}$" --format "{{.Names}}" 2>/dev/null || true)

if [ -n "$CONTAINER_RUNNING" ]; then
    echo -e "${BLUE}→ Stopping container...${NC}"
    docker stop "$CONTAINER_NAME" >/dev/null
    echo -e "${GREEN}✓ Container stopped${NC}"
else
    echo -e "${YELLOW}ℹ Container is not running${NC}"
fi

# ============================================================================
# Full cleanup if requested
# ============================================================================

if [ "$FULL_CLEANUP" = true ]; then
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  ⚠  FULL CLEANUP MODE${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${RED}This will remove:${NC}"
    echo -e "${RED}  - Container and all its data${NC}"
    echo -e "${RED}  - Claude Code authentication (you'll need to login again)${NC}"
    echo -e "${RED}  - Codex CLI authentication (you'll need to login again)${NC}"
    echo -e "${RED}  - Mise cache (runtimes will be re-downloaded)${NC}"
    echo -e "${RED}  - Docker image${NC}"
    echo ""
    echo -e "${BLUE}Note: Your project files in ./projects/ will NOT be deleted${NC}"
    echo ""

    read -p "Are you sure? (type 'yes' to confirm) " -r
    echo ""

    if [ "$REPLY" != "yes" ]; then
        echo -e "${BLUE}→ Cleanup cancelled${NC}"
        exit 0
    fi

    # Remove container
    CONTAINER_EXISTS=$(docker ps -a --filter "name=^${CONTAINER_NAME}$" --format "{{.Names}}" 2>/dev/null || true)
    if [ -n "$CONTAINER_EXISTS" ]; then
        echo -e "${BLUE}→ Removing container...${NC}"
        docker rm "$CONTAINER_NAME" >/dev/null
        echo -e "${GREEN}✓ Container removed${NC}"
    fi

    # Remove volumes
    echo -e "${BLUE}→ Removing volumes...${NC}"

    # Find and remove volumes associated with this project
    VOLUMES=$(docker volume ls --filter name=agent-harness-claude --format "{{.Name}}" 2>/dev/null || true)

    if [ -n "$VOLUMES" ]; then
        echo "$VOLUMES" | while read -r volume; do
            echo -e "${BLUE}  → Removing volume: $volume${NC}"
            docker volume rm "$volume" >/dev/null 2>&1 || true
        done
        echo -e "${GREEN}✓ Volumes removed${NC}"
    else
        echo -e "${YELLOW}ℹ No volumes to remove${NC}"
    fi

    # Remove images
    echo -e "${BLUE}→ Removing images...${NC}"

    IMAGES=$(docker images --filter "reference=agent-harness-claude*" --format "{{.ID}}" 2>/dev/null || true)

    if [ -n "$IMAGES" ]; then
        echo "$IMAGES" | while read -r image; do
            echo -e "${BLUE}  → Removing image: $image${NC}"
            docker rmi "$image" >/dev/null 2>&1 || true
        done
        echo -e "${GREEN}✓ Images removed${NC}"
    else
        echo -e "${YELLOW}ℹ No images to remove${NC}"
    fi

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✓ Full cleanup completed${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}To rebuild the environment:${NC}"
    echo -e "  ${GREEN}./scripts/run-agent.sh${NC}"
    echo ""

else
    # Normal cleanup - just stop the container
    echo ""
    echo -e "${GREEN}✓ Cleanup completed${NC}"
    echo ""
    echo -e "${BLUE}Container stopped but preserved.${NC}"
    echo -e "${BLUE}Authentication and cache volumes are preserved.${NC}"
    echo ""
    echo -e "${BLUE}To restart:${NC}"
    echo -e "  ${GREEN}./scripts/run-agent.sh${NC}"
    echo ""
    echo -e "${BLUE}For full cleanup (remove all data):${NC}"
    echo -e "  ${YELLOW}./scripts/cleanup.sh --full${NC}"
    echo ""
fi
