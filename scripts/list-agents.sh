#!/bin/bash
# list-agents.sh - List all running parallel AI agents
#
# This script displays information about all parallel agent containers
# that were spawned with spawn-agent.sh
#
# Usage: ./scripts/list-agents.sh

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# Display header
# ============================================================================

echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Parallel AI Agents${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════${NC}"
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
# Find all agent-harness containers
# ============================================================================

# Get list of containers matching agent-harness-* pattern
CONTAINERS=$(docker ps -a --filter "name=agent-harness-" --format "{{.Names}}" | grep "^agent-harness-" || true)

if [ -z "$CONTAINERS" ]; then
    echo -e "${YELLOW}No parallel agents found${NC}"
    echo ""
    echo -e "${BLUE}To spawn a new agent:${NC}"
    echo -e "  ${GREEN}./scripts/spawn-agent.sh <feature-name>${NC}"
    echo ""
    exit 0
fi

# ============================================================================
# Display agents in table format
# ============================================================================

# Table header
printf "${BLUE}%-20s %-15s %-30s %-12s %-15s${NC}\n" \
    "FEATURE" "STATUS" "BRANCH" "AGENT" "UPTIME"
echo "────────────────────────────────────────────────────────────────────────────────"

# Process each container
echo "$CONTAINERS" | while read -r container_name; do
    # Extract feature name from container name (remove "agent-harness-" prefix)
    FEATURE_NAME="${container_name#agent-harness-}"

    # Get container status
    STATUS=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null || echo "unknown")

    # Color code the status
    case $STATUS in
        running)
            STATUS_COLOR="${GREEN}"
            STATUS_TEXT="running"
            ;;
        exited)
            STATUS_COLOR="${RED}"
            STATUS_TEXT="stopped"
            ;;
        paused)
            STATUS_COLOR="${YELLOW}"
            STATUS_TEXT="paused"
            ;;
        *)
            STATUS_COLOR="${RED}"
            STATUS_TEXT="$STATUS"
            ;;
    esac

    # Get uptime (or created time if not running)
    if [ "$STATUS" = "running" ]; then
        CREATED=$(docker inspect --format='{{.State.StartedAt}}' "$container_name" 2>/dev/null || echo "unknown")
        # Calculate uptime
        if [ "$CREATED" != "unknown" ]; then
            CREATED_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${CREATED%.*}" "+%s" 2>/dev/null || echo "0")
            NOW_EPOCH=$(date "+%s")
            DIFF=$((NOW_EPOCH - CREATED_EPOCH))

            DAYS=$((DIFF / 86400))
            HOURS=$(((DIFF % 86400) / 3600))
            MINUTES=$(((DIFF % 3600) / 60))

            if [ $DAYS -gt 0 ]; then
                UPTIME="${DAYS}d ${HOURS}h"
            elif [ $HOURS -gt 0 ]; then
                UPTIME="${HOURS}h ${MINUTES}m"
            else
                UPTIME="${MINUTES}m"
            fi
        else
            UPTIME="unknown"
        fi
    else
        UPTIME="-"
    fi

    # Try to get branch from worktree
    WORKTREE_PATH=".worktrees/$FEATURE_NAME"
    if [ -d "$WORKTREE_PATH" ]; then
        BRANCH=$(cd "$WORKTREE_PATH" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    else
        BRANCH="(no worktree)"
    fi

    # Detect agent type (try to find running process)
    AGENT_TYPE="-"
    if [ "$STATUS" = "running" ]; then
        # Check for claude or codex process
        if docker exec "$container_name" pgrep -f "claude.*skip-permissions" >/dev/null 2>&1; then
            AGENT_TYPE="claude"
        elif docker exec "$container_name" pgrep -f "codex.*full-access" >/dev/null 2>&1; then
            AGENT_TYPE="codex"
        fi
    fi

    # Truncate branch if too long
    if [ ${#BRANCH} -gt 28 ]; then
        BRANCH="${BRANCH:0:25}..."
    fi

    # Print row
    printf "%-20s ${STATUS_COLOR}%-15s${NC} %-30s %-12s %-15s\n" \
        "$FEATURE_NAME" "$STATUS_TEXT" "$BRANCH" "$AGENT_TYPE" "$UPTIME"
done

echo ""

# ============================================================================
# Display summary and helpful commands
# ============================================================================

# Count running vs stopped
RUNNING_COUNT=$(docker ps --filter "name=agent-harness-" --format "{{.Names}}" | grep "^agent-harness-" | wc -l | tr -d ' ')
TOTAL_COUNT=$(echo "$CONTAINERS" | wc -l | tr -d ' ')
STOPPED_COUNT=$((TOTAL_COUNT - RUNNING_COUNT))

echo -e "${BLUE}Summary:${NC} $RUNNING_COUNT running, $STOPPED_COUNT stopped, $TOTAL_COUNT total"
echo ""

# Show helpful commands
echo -e "${BLUE}Commands:${NC}"
echo -e "  Spawn new agent:   ${GREEN}./scripts/spawn-agent.sh <feature-name>${NC}"
echo -e "  Attach to agent:   ${GREEN}./scripts/attach-agent.sh <feature-name>${NC}"
echo -e "  View logs:         ${GREEN}./scripts/logs-agent.sh <feature-name>${NC}"
echo -e "  Stop agent:        ${GREEN}./scripts/kill-agent.sh <feature-name>${NC}"
echo ""

# ============================================================================
# Check for worktrees without containers
# ============================================================================

if [ -d ".worktrees" ]; then
    ORPHANED_WORKTREES=""
    for worktree in .worktrees/*; do
        if [ -d "$worktree" ]; then
            FEATURE_NAME=$(basename "$worktree")
            CONTAINER_NAME="agent-harness-$FEATURE_NAME"
            if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                ORPHANED_WORKTREES="$ORPHANED_WORKTREES\n  - $FEATURE_NAME"
            fi
        fi
    done

    if [ -n "$ORPHANED_WORKTREES" ]; then
        echo -e "${YELLOW}Warning: Found worktrees without containers:${NC}"
        echo -e "$ORPHANED_WORKTREES"
        echo ""
        echo -e "${BLUE}To clean up:${NC} git worktree remove .worktrees/<feature-name>"
        echo ""
    fi
fi

# ============================================================================
# Check for tmux sessions
# ============================================================================

if command -v tmux &> /dev/null; then
    TMUX_SESSIONS=$(tmux ls 2>/dev/null | grep "^agent-" || true)
    if [ -n "$TMUX_SESSIONS" ]; then
        echo -e "${BLUE}Active tmux sessions:${NC}"
        echo "$TMUX_SESSIONS" | while read -r session; do
            SESSION_NAME=$(echo "$session" | cut -d: -f1)
            FEATURE_NAME="${SESSION_NAME#agent-}"
            echo -e "  ${GREEN}$SESSION_NAME${NC} (attach: ./scripts/attach-agent.sh $FEATURE_NAME)"
        done
        echo ""
    fi
fi
