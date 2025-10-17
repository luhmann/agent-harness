#!/bin/bash
# attach-agent.sh - Attach to a running parallel AI agent's tmux session
#
# This script attaches to the tmux session of a parallel agent that was
# spawned with spawn-agent.sh
#
# Usage: ./scripts/attach-agent.sh <feature-name>

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# Parse arguments
# ============================================================================

FEATURE_NAME="$1"

show_usage() {
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Attach to Parallel AI Agent${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Usage: $0 <feature-name>"
    echo ""
    echo "Arguments:"
    echo "  feature-name    Name of the agent to attach to"
    echo ""
    echo "Examples:"
    echo "  $0 feature-auth"
    echo "  $0 bugfix-123"
    echo ""
    echo "To list all agents:"
    echo "  ./scripts/list-agents.sh"
    echo ""
    exit 1
}

if [ -z "$FEATURE_NAME" ]; then
    echo -e "${RED}✗ Feature name is required${NC}"
    echo ""
    show_usage
fi

# Sanitize feature name
FEATURE_NAME=$(echo "$FEATURE_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

CONTAINER_NAME="agent-harness-$FEATURE_NAME"
TMUX_SESSION="agent-$FEATURE_NAME"

# ============================================================================
# Display header
# ============================================================================

echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Attaching to Parallel AI Agent${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Feature:${NC} $FEATURE_NAME"
echo -e "${BLUE}Tmux Session:${NC} $TMUX_SESSION"
echo ""

# ============================================================================
# Check dependencies
# ============================================================================

if ! command -v tmux &> /dev/null; then
    echo -e "${RED}✗ tmux is not installed${NC}"
    echo -e "${RED}  Please install tmux: brew install tmux (macOS) or apt-get install tmux (Linux)${NC}"
    exit 1
fi

# ============================================================================
# Check if container exists and is running
# ============================================================================

echo -e "${BLUE}→ Checking container status...${NC}"

if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}✗ Container does not exist: $CONTAINER_NAME${NC}"
    echo ""
    echo -e "${BLUE}Available agents:${NC}"
    ./scripts/list-agents.sh
    exit 1
fi

CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)

if [ "$CONTAINER_STATUS" != "running" ]; then
    echo -e "${RED}✗ Container is not running (status: $CONTAINER_STATUS)${NC}"
    echo ""
    echo -e "${BLUE}To start the container:${NC}"
    echo -e "  ${GREEN}docker start $CONTAINER_NAME${NC}"
    echo ""
    echo -e "${BLUE}Or respawn the agent:${NC}"
    echo -e "  ${GREEN}./scripts/kill-agent.sh $FEATURE_NAME${NC}"
    echo -e "  ${GREEN}./scripts/spawn-agent.sh $FEATURE_NAME${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Container is running${NC}"
echo ""

# ============================================================================
# Check if tmux session exists
# ============================================================================

echo -e "${BLUE}→ Checking tmux session...${NC}"

if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo -e "${RED}✗ Tmux session does not exist: $TMUX_SESSION${NC}"
    echo ""
    echo -e "${BLUE}The container is running but no tmux session is active.${NC}"
    echo -e "${BLUE}This might happen if:${NC}"
    echo -e "  1. The agent was stopped/exited"
    echo -e "  2. The tmux session was killed manually"
    echo -e "  3. The container was restarted"
    echo ""
    echo -e "${BLUE}To check active sessions:${NC}"
    echo -e "  ${GREEN}tmux ls${NC}"
    echo ""
    echo -e "${BLUE}To create a new shell session in the container:${NC}"
    echo -e "  ${GREEN}docker exec -it $CONTAINER_NAME bash${NC}"
    echo ""
    echo -e "${BLUE}To respawn the agent:${NC}"
    echo -e "  ${GREEN}./scripts/kill-agent.sh $FEATURE_NAME${NC}"
    echo -e "  ${GREEN}./scripts/spawn-agent.sh $FEATURE_NAME${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Tmux session exists${NC}"
echo ""

# ============================================================================
# Attach to tmux session
# ============================================================================

echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Attaching to Agent Session${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}ℹ To detach:${NC} Press Ctrl+B then D"
echo -e "${BLUE}ℹ To view logs:${NC} ./scripts/logs-agent.sh $FEATURE_NAME"
echo -e "${BLUE}ℹ To stop:${NC} ./scripts/kill-agent.sh $FEATURE_NAME"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""

# Small delay
sleep 1

# Attach to the tmux session
tmux attach-session -t "$TMUX_SESSION"

# After detaching
echo ""
echo -e "${GREEN}✓ Detached from agent session${NC}"
echo -e "${BLUE}ℹ Container is still running in the background${NC}"
echo -e "${BLUE}ℹ To reattach:${NC} ./scripts/attach-agent.sh $FEATURE_NAME"
echo ""
