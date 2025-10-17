#!/bin/bash
# run-agent.sh - Interactive AI coding agent launcher
#
# This script provides an interactive menu to choose between:
# - Claude Code (Anthropic)
# - Codex CLI (OpenAI)
#
# Both agents run in yolo/full-access mode within the sandboxed container.
#
# Usage: ./scripts/run-agent.sh [PROJECT_NAME]

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

CONTAINER_NAME="claude-agent-sandbox"
PROJECT_NAME="${1:-sandbox}"

# Detect host auth directories
HOST_CLAUDE_DIR="$HOME/.claude"
HOST_CODEX_DIR="$HOME/.codex"

# Detect if script was called via symlink or with env var (for backward compatibility)
SCRIPT_NAME="$(basename "$0")"
SELECTED_AGENT="${SELECTED_AGENT:-}"

if [[ "$SCRIPT_NAME" == "run-claude.sh" ]]; then
    SELECTED_AGENT="claude"
fi

# ============================================================================
# Display header
# ============================================================================

echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  AI Agent Harness - Autonomous Coding Sandbox${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Container:${NC} $CONTAINER_NAME"
echo -e "${BLUE}Project:${NC} $PROJECT_NAME"
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
# Check if container exists and start if needed
# ============================================================================

CONTAINER_EXISTS=$(docker ps -a --filter "name=^${CONTAINER_NAME}$" --format "{{.Names}}" 2>/dev/null || true)

if [ -z "$CONTAINER_EXISTS" ]; then
    echo -e "${YELLOW}→ Container does not exist, creating...${NC}"

    # Build image if needed
    if ! docker images | grep -q "agent-harness.*claude-sandbox"; then
        echo -e "${BLUE}→ Building Docker image (this may take 5-10 minutes)...${NC}"
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
# Initialize authentication for both agents
# ============================================================================

echo -e "${BLUE}→ Initializing authentication...${NC}"
echo ""

# Run init-auth.sh inside container
docker exec "$CONTAINER_NAME" /scripts/init-auth.sh "$HOST_CLAUDE_DIR" "$HOST_CODEX_DIR" || {
    AUTH_EXIT_CODE=$?
    if [ $AUTH_EXIT_CODE -ne 1 ]; then
        echo -e "${RED}✗ Authentication initialization failed${NC}"
        exit 1
    fi
    # Exit code 1 means partial/no auth (expected for first run)
}

echo ""

# ============================================================================
# Set up project directory
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
# Agent selection menu (if not already selected via symlink)
# ============================================================================

if [ -z "$SELECTED_AGENT" ]; then
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Select AI Coding Agent${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${MAGENTA}1)${NC} ${GREEN}Claude Code${NC} (Anthropic)"
    echo -e "   → Surgical edits, multi-step tasks"
    echo -e "   → Requires: Claude.ai or Console account"
    echo ""
    echo -e "${MAGENTA}2)${NC} ${GREEN}Codex CLI${NC} (OpenAI)"
    echo -e "   → Fast, open-source, community-driven"
    echo -e "   → Requires: ChatGPT Plus/Pro/Team account"
    echo ""
    echo -e "${MAGENTA}3)${NC} ${YELLOW}Exit${NC}"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""

    # Read user selection
    while true; do
        read -p "Enter your choice (1-3): " choice
        case $choice in
            1)
                SELECTED_AGENT="claude"
                break
                ;;
            2)
                SELECTED_AGENT="codex"
                break
                ;;
            3)
                echo -e "${BLUE}→ Exiting${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 1, 2, or 3.${NC}"
                ;;
        esac
    done

    echo ""
fi

# ============================================================================
# Launch selected agent
# ============================================================================

case $SELECTED_AGENT in
    claude)
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Launching Claude Code (YOLO Mode)${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${YELLOW}⚠ Claude Code will run with ${NC}${RED}--dangerously-skip-permissions${NC}"
        echo -e "${YELLOW}  This means it can execute any command WITHOUT asking${NC}"
        echo -e "${YELLOW}  However, it's sandboxed within the Docker container${NC}"
        echo ""
        echo -e "${BLUE}ℹ Working directory:${NC} /workspace/$PROJECT_NAME"
        echo -e "${BLUE}ℹ To exit:${NC} Type 'exit' or press Ctrl+D"
        echo -e "${BLUE}ℹ To stop container:${NC} ./scripts/cleanup.sh"
        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        echo ""

        # Small delay
        sleep 2

        # Launch Claude Code
        docker exec -it "$CONTAINER_NAME" bash -c "
            cd /workspace/$PROJECT_NAME && \
            eval \"\$(mise activate bash)\" && \
            mise install && \
            exec claude --dangerously-skip-permissions
        "
        ;;

    codex)
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}  Launching Codex CLI (Full Access Mode)${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${YELLOW}⚠ Codex CLI will run in ${NC}${RED}full-access mode${NC}"
        echo -e "${YELLOW}  This means it can execute any command WITH network access${NC}"
        echo -e "${YELLOW}  However, it's sandboxed within the Docker container${NC}"
        echo ""
        echo -e "${BLUE}ℹ Working directory:${NC} /workspace/$PROJECT_NAME"
        echo -e "${BLUE}ℹ To exit:${NC} Type 'exit' or press Ctrl+D"
        echo -e "${BLUE}ℹ To stop container:${NC} ./scripts/cleanup.sh"
        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
        echo ""

        # Small delay
        sleep 2

        # Launch Codex CLI
        docker exec -it "$CONTAINER_NAME" bash -c "
            cd /workspace/$PROJECT_NAME && \
            eval \"\$(mise activate bash)\" && \
            mise install && \
            exec codex --approval full-access
        "
        ;;

    *)
        echo -e "${RED}✗ Invalid agent selection: $SELECTED_AGENT${NC}"
        exit 1
        ;;
esac

# ============================================================================
# Session ended
# ============================================================================

echo ""
echo -e "${GREEN}✓ Agent session ended${NC}"
echo -e "${BLUE}ℹ Container is still running in the background${NC}"
echo -e "${BLUE}ℹ Run './scripts/run-agent.sh $PROJECT_NAME' to resume${NC}"
echo ""
