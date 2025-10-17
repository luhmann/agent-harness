#!/bin/bash
# run-claude.sh - Main entry point for Claude Code sandbox
#
# This script:
# 1. Checks if container exists and starts it if needed
# 2. Initializes authentication (hybrid strategy)
# 3. Launches Claude Code in yolo mode (--dangerously-skip-permissions)
#
# Usage: ./scripts/run-claude.sh [PROJECT_NAME]

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONTAINER_NAME="claude-agent-sandbox"
PROJECT_NAME="${1:-sandbox}"

# Detect host .claude directory
HOST_CLAUDE_DIR="$HOME/.claude"

echo -e "${BLUE}=== Claude Code Sandbox Launcher ===${NC}"
echo -e "${BLUE}Container: $CONTAINER_NAME${NC}"
echo -e "${BLUE}Project: $PROJECT_NAME${NC}"
echo ""

# ============================================================================
# Step 1: Check if Docker is running
# ============================================================================

if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    echo -e "${RED}  Please start Docker and try again${NC}"
    exit 1
fi

# ============================================================================
# Step 2: Check if container exists
# ============================================================================

CONTAINER_EXISTS=$(docker ps -a --filter "name=^${CONTAINER_NAME}$" --format "{{.Names}}" 2>/dev/null || true)

if [ -z "$CONTAINER_EXISTS" ]; then
    echo -e "${YELLOW}→ Container does not exist, creating...${NC}"

    # Build image if needed
    if ! docker images | grep -q "agent-harness-claude-claude-sandbox"; then
        echo -e "${BLUE}→ Building Docker image (this may take a few minutes)...${NC}"
        docker-compose build
        echo -e "${GREEN}✓ Image built successfully${NC}"
        echo ""
    fi

    # Create and start container
    echo -e "${BLUE}→ Starting container...${NC}"
    docker-compose up -d
    echo -e "${GREEN}✓ Container created and started${NC}"
    echo ""
else
    # Check if container is running
    CONTAINER_RUNNING=$(docker ps --filter "name=^${CONTAINER_NAME}$" --format "{{.Names}}" 2>/dev/null || true)

    if [ -z "$CONTAINER_RUNNING" ]; then
        echo -e "${YELLOW}→ Container exists but is stopped, starting...${NC}"
        docker start "$CONTAINER_NAME" >/dev/null
        echo -e "${GREEN}✓ Container started${NC}"
        echo ""
    else
        echo -e "${GREEN}✓ Container is already running${NC}"
        echo ""
    fi
fi

# ============================================================================
# Step 3: Initialize authentication
# ============================================================================

echo -e "${BLUE}→ Initializing authentication...${NC}"

# Pass host .claude directory to init script if it exists
if [ -d "$HOST_CLAUDE_DIR" ]; then
    docker exec "$CONTAINER_NAME" /scripts/init-auth.sh "$HOST_CLAUDE_DIR" || {
        # Exit code 1 means manual login needed (expected behavior)
        if [ $? -eq 1 ]; then
            echo -e "${YELLOW}→ Manual login will be required${NC}"
        else
            echo -e "${RED}✗ Authentication initialization failed${NC}"
            exit 1
        fi
    }
else
    docker exec "$CONTAINER_NAME" /scripts/init-auth.sh || {
        if [ $? -eq 1 ]; then
            echo -e "${YELLOW}→ Manual login will be required${NC}"
        else
            echo -e "${RED}✗ Authentication initialization failed${NC}"
            exit 1
        fi
    }
fi

echo ""

# ============================================================================
# Step 4: Set up project directory
# ============================================================================

# Ensure project directory exists on host
mkdir -p "./projects/$PROJECT_NAME"

# Check if .mise.toml exists, copy template if not
if [ ! -f "./projects/$PROJECT_NAME/.mise.toml" ]; then
    if [ -f ".mise.toml.template" ]; then
        echo -e "${BLUE}→ Creating .mise.toml from template...${NC}"
        cp .mise.toml.template "./projects/$PROJECT_NAME/.mise.toml"
        echo -e "${GREEN}✓ .mise.toml created${NC}"
        echo ""
    fi
fi

# ============================================================================
# Step 5: Launch Claude Code in yolo mode
# ============================================================================

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Launching Claude Code in YOLO mode${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}⚠ Claude Code will run with --dangerously-skip-permissions${NC}"
echo -e "${YELLOW}  This means it can execute any command WITHOUT asking for approval${NC}"
echo -e "${YELLOW}  However, it's sandboxed within the Docker container${NC}"
echo ""
echo -e "${BLUE}ℹ Working directory: /workspace/$PROJECT_NAME${NC}"
echo -e "${BLUE}ℹ To exit Claude Code: Type 'exit' or press Ctrl+D${NC}"
echo -e "${BLUE}ℹ To stop the container: ./scripts/cleanup.sh${NC}"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Small delay to let user read the warnings
sleep 2

# Execute Claude Code in the container
# - Change to project directory
# - Activate mise environment
# - Launch Claude Code with yolo mode
docker exec -it "$CONTAINER_NAME" bash -c "
    cd /workspace/$PROJECT_NAME && \
    eval \"\$(mise activate bash)\" && \
    mise install && \
    exec claude --dangerously-skip-permissions
"

echo ""
echo -e "${GREEN}✓ Claude Code session ended${NC}"
echo -e "${BLUE}ℹ Container is still running in the background${NC}"
echo -e "${BLUE}ℹ Run './scripts/run-claude.sh $PROJECT_NAME' to resume${NC}"
echo ""
