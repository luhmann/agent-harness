#!/bin/bash
# attach.sh - Attach to running Claude Code container
#
# This script provides direct shell access to the container for:
# - Debugging
# - Manual commands
# - Inspecting container state
#
# Usage: ./scripts/attach.sh

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONTAINER_NAME="claude-agent-sandbox"

echo -e "${BLUE}=== Attach to Claude Code Container ===${NC}"
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
# Check if container exists and is running
# ============================================================================

CONTAINER_RUNNING=$(docker ps --filter "name=^${CONTAINER_NAME}$" --format "{{.Names}}" 2>/dev/null || true)

if [ -z "$CONTAINER_RUNNING" ]; then
    # Check if container exists but is stopped
    CONTAINER_EXISTS=$(docker ps -a --filter "name=^${CONTAINER_NAME}$" --format "{{.Names}}" 2>/dev/null || true)

    if [ -z "$CONTAINER_EXISTS" ]; then
        echo -e "${RED}✗ Container does not exist${NC}"
        echo -e "${YELLOW}  Run './scripts/run-claude.sh' to create it${NC}"
        exit 1
    else
        echo -e "${YELLOW}→ Container exists but is stopped${NC}"
        echo -e "${BLUE}→ Starting container...${NC}"
        docker start "$CONTAINER_NAME" >/dev/null
        echo -e "${GREEN}✓ Container started${NC}"
        echo ""
    fi
fi

# ============================================================================
# Attach to container
# ============================================================================

echo -e "${GREEN}✓ Attaching to container shell${NC}"
echo ""
echo -e "${BLUE}ℹ You are now inside the container as user 'claudedev'${NC}"
echo -e "${BLUE}ℹ Working directory: /workspace${NC}"
echo -e "${BLUE}ℹ To exit: Type 'exit' or press Ctrl+D${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Execute interactive bash shell in the container
docker exec -it "$CONTAINER_NAME" bash

echo ""
echo -e "${GREEN}✓ Detached from container${NC}"
echo -e "${BLUE}ℹ Container is still running in the background${NC}"
echo ""
