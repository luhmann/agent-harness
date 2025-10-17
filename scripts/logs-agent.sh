#!/bin/bash
# logs-agent.sh - View logs from a parallel AI agent container
#
# This script displays Docker logs for a parallel agent container
#
# Usage: ./scripts/logs-agent.sh <feature-name> [--tail N] [--follow]

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

FEATURE_NAME=""
TAIL_LINES=""
FOLLOW=false

show_usage() {
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  View Parallel AI Agent Logs${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Usage: $0 <feature-name> [options]"
    echo ""
    echo "Arguments:"
    echo "  feature-name    Name of the agent to view logs for"
    echo ""
    echo "Options:"
    echo "  --tail N        Show only the last N lines (default: all)"
    echo "  --follow, -f    Follow log output (like tail -f)"
    echo ""
    echo "Examples:"
    echo "  $0 feature-auth"
    echo "  $0 bugfix-123 --tail 100"
    echo "  $0 feature-api --follow"
    echo "  $0 refactor-db --tail 50 --follow"
    echo ""
    echo "To list all agents:"
    echo "  ./scripts/list-agents.sh"
    echo ""
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --tail)
            TAIL_LINES="$2"
            shift 2
            ;;
        --follow|-f)
            FOLLOW=true
            shift
            ;;
        --help|-h)
            show_usage
            ;;
        *)
            if [ -z "$FEATURE_NAME" ]; then
                FEATURE_NAME="$1"
            else
                echo -e "${RED}✗ Unknown argument: $1${NC}"
                show_usage
            fi
            shift
            ;;
    esac
done

if [ -z "$FEATURE_NAME" ]; then
    echo -e "${RED}✗ Feature name is required${NC}"
    echo ""
    show_usage
fi

# Sanitize feature name
FEATURE_NAME=$(echo "$FEATURE_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

CONTAINER_NAME="agent-harness-$FEATURE_NAME"

# ============================================================================
# Display header
# ============================================================================

echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Viewing Agent Logs${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Feature:${NC} $FEATURE_NAME"
echo -e "${BLUE}Container:${NC} $CONTAINER_NAME"
if [ -n "$TAIL_LINES" ]; then
    echo -e "${BLUE}Tail:${NC} Last $TAIL_LINES lines"
fi
if [ "$FOLLOW" = true ]; then
    echo -e "${BLUE}Mode:${NC} Follow (Ctrl+C to exit)"
fi
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
# Check if container exists
# ============================================================================

if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}✗ Container does not exist: $CONTAINER_NAME${NC}"
    echo ""
    echo -e "${BLUE}Available agents:${NC}"
    ./scripts/list-agents.sh
    exit 1
fi

# Check container status
CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)

if [ "$CONTAINER_STATUS" = "running" ]; then
    echo -e "${GREEN}✓ Container is running${NC}"
elif [ "$CONTAINER_STATUS" = "exited" ]; then
    echo -e "${YELLOW}⚠ Container is stopped (showing logs from last run)${NC}"
else
    echo -e "${YELLOW}⚠ Container status: $CONTAINER_STATUS${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ============================================================================
# Build docker logs command
# ============================================================================

DOCKER_LOGS_CMD="docker logs"

if [ -n "$TAIL_LINES" ]; then
    DOCKER_LOGS_CMD="$DOCKER_LOGS_CMD --tail $TAIL_LINES"
fi

if [ "$FOLLOW" = true ]; then
    DOCKER_LOGS_CMD="$DOCKER_LOGS_CMD --follow"
fi

# Add timestamps for better context
DOCKER_LOGS_CMD="$DOCKER_LOGS_CMD --timestamps"

DOCKER_LOGS_CMD="$DOCKER_LOGS_CMD $CONTAINER_NAME"

# ============================================================================
# Display logs
# ============================================================================

# Execute the logs command
eval "$DOCKER_LOGS_CMD"

# ============================================================================
# Footer (only shows if not following)
# ============================================================================

if [ "$FOLLOW" = false ]; then
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}Commands:${NC}"
    echo -e "  Follow logs:       ${GREEN}$0 $FEATURE_NAME --follow${NC}"
    echo -e "  Last 100 lines:    ${GREEN}$0 $FEATURE_NAME --tail 100${NC}"
    echo -e "  Attach to agent:   ${GREEN}./scripts/attach-agent.sh $FEATURE_NAME${NC}"
    echo -e "  List all agents:   ${GREEN}./scripts/list-agents.sh${NC}"
    echo ""
fi
