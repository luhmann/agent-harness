#!/bin/bash
# kill-agent.sh - Stop and cleanup a parallel AI agent
#
# This script stops and removes a parallel agent container, kills its tmux
# session, and optionally removes the git worktree.
#
# Usage: ./scripts/kill-agent.sh <feature-name> [--remove-worktree]

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
REMOVE_WORKTREE=false
SKIP_TEARDOWN=false

show_usage() {
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Kill Parallel AI Agent${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Usage: $0 <feature-name> [options]"
    echo ""
    echo "Arguments:"
    echo "  feature-name        Name of the agent to kill"
    echo ""
    echo "Options:"
    echo "  --remove-worktree   Also remove the git worktree (with confirmation)"
    echo "  --skip-teardown     Skip running .agent-harness/teardown.sh"
    echo ""
    echo "Examples:"
    echo "  $0 feature-auth"
    echo "  $0 bugfix-123 --remove-worktree"
    echo "  $0 feature-api --skip-teardown"
    echo ""
    echo "To list all agents:"
    echo "  ./scripts/list-agents.sh"
    echo ""
    exit 1
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --remove-worktree)
            REMOVE_WORKTREE=true
            shift
            ;;
        --skip-teardown)
            SKIP_TEARDOWN=true
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
TMUX_SESSION="agent-$FEATURE_NAME"
WORKTREE_PATH=".worktrees/$FEATURE_NAME"

# ============================================================================
# Display header
# ============================================================================

echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Killing Parallel AI Agent${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Feature:${NC} $FEATURE_NAME"
echo -e "${BLUE}Container:${NC} $CONTAINER_NAME"
echo -e "${BLUE}Tmux Session:${NC} $TMUX_SESSION"
echo -e "${BLUE}Worktree:${NC} $WORKTREE_PATH"
echo ""

# ============================================================================
# Check what exists
# ============================================================================

CONTAINER_EXISTS=false
TMUX_EXISTS=false
WORKTREE_EXISTS=false

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    CONTAINER_EXISTS=true
fi

if command -v tmux &> /dev/null && tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    TMUX_EXISTS=true
fi

if [ -d "$WORKTREE_PATH" ]; then
    WORKTREE_EXISTS=true
fi

if [ "$CONTAINER_EXISTS" = false ] && [ "$TMUX_EXISTS" = false ] && [ "$WORKTREE_EXISTS" = false ]; then
    echo -e "${YELLOW}No agent found with name: $FEATURE_NAME${NC}"
    echo ""
    echo -e "${BLUE}Available agents:${NC}"
    ./scripts/list-agents.sh
    exit 1
fi

# ============================================================================
# Show what will be cleaned up
# ============================================================================

echo -e "${BLUE}→ Found:${NC}"
if [ "$CONTAINER_EXISTS" = true ]; then
    CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
    echo -e "  ${GREEN}✓${NC} Container ($CONTAINER_STATUS)"
fi
if [ "$TMUX_EXISTS" = true ]; then
    echo -e "  ${GREEN}✓${NC} Tmux session"
fi
if [ "$WORKTREE_EXISTS" = true ]; then
    # Check if worktree has uncommitted changes
    WORKTREE_CLEAN=true
    if [ -d "$WORKTREE_PATH/.git" ] || git -C "$WORKTREE_PATH" rev-parse --git-dir > /dev/null 2>&1; then
        if ! git -C "$WORKTREE_PATH" diff-index --quiet HEAD -- 2>/dev/null; then
            WORKTREE_CLEAN=false
        fi
    fi

    if [ "$WORKTREE_CLEAN" = false ]; then
        echo -e "  ${YELLOW}⚠${NC} Worktree (has uncommitted changes)"
    else
        echo -e "  ${GREEN}✓${NC} Worktree"
    fi
fi
echo ""

# ============================================================================
# Warn if worktree has uncommitted changes
# ============================================================================

if [ "$WORKTREE_EXISTS" = true ] && [ "$WORKTREE_CLEAN" = false ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  ⚠  WARNING: Uncommitted Changes${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}The worktree has uncommitted changes.${NC}"
    echo ""
    echo -e "${BLUE}To view changes:${NC}"
    echo -e "  ${GREEN}cd $WORKTREE_PATH && git status${NC}"
    echo ""
    echo -e "${BLUE}You might want to:${NC}"
    echo -e "  1. Commit your changes: ${GREEN}cd $WORKTREE_PATH && git add . && git commit -m 'message'${NC}"
    echo -e "  2. Push to remote: ${GREEN}cd $WORKTREE_PATH && git push${NC}"
    echo -e "  3. Create a backup: ${GREEN}cp -r $WORKTREE_PATH $WORKTREE_PATH.backup${NC}"
    echo ""

    if [ "$REMOVE_WORKTREE" = true ]; then
        echo -e "${RED}Note: You requested --remove-worktree flag${NC}"
        echo -e "${RED}      This will DELETE all uncommitted changes!${NC}"
        echo ""
    fi
fi

# ============================================================================
# Run repository teardown script (if exists)
# ============================================================================

if [ "$SKIP_TEARDOWN" = false ] && [ "$WORKTREE_EXISTS" = true ] && [ "$CONTAINER_EXISTS" = true ]; then
    if [ -f "$WORKTREE_PATH/.agent-harness/teardown.sh" ]; then
        echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}  Running Repository Teardown${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${BLUE}→ Found .agent-harness/teardown.sh${NC}"
        echo -e "${BLUE}  Running teardown script...${NC}"
        echo ""

        # Get project name and branch from worktree
        PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel)")
        BRANCH=$(cd "$WORKTREE_PATH" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

        # Generate DB name (same as setup)
        DB_NAME="${PROJECT_NAME}_${FEATURE_NAME}" | tr '[:upper:]' '[:lower:]' | tr '-' '_'

        # Get agent type from container inspect (if possible)
        AGENT_TYPE=$(docker exec "$CONTAINER_NAME" bash -c "ps aux | grep -E '(claude|codex)' | grep -v grep | head -1" 2>/dev/null | grep -o -E '(claude|codex)' | head -1 || echo "unknown")

        # Export environment variables for teardown script
        TEARDOWN_ENV="export FEATURE_NAME='$FEATURE_NAME' && \
export BRANCH_NAME='$BRANCH' && \
export WORKTREE_PATH='/workspace' && \
export PROJECT_NAME='$PROJECT_NAME' && \
export DB_NAME='$DB_NAME' && \
export AGENT_TYPE='$AGENT_TYPE'"

        # Run teardown script inside container
        if docker exec "$CONTAINER_NAME" bash -c "cd /workspace && $TEARDOWN_ENV && bash .agent-harness/teardown.sh" 2>&1; then
            echo ""
            echo -e "${GREEN}✓ Teardown completed successfully${NC}"
        else
            echo ""
            echo -e "${YELLOW}⚠ Teardown script encountered errors (continuing anyway)${NC}"
        fi
        echo ""
    fi
elif [ "$SKIP_TEARDOWN" = true ]; then
    echo -e "${YELLOW}ℹ Skipping teardown script (--skip-teardown flag)${NC}"
    echo ""
fi

# ============================================================================
# Stop and remove container
# ============================================================================

if [ "$CONTAINER_EXISTS" = true ]; then
    echo -e "${BLUE}→ Stopping and removing container...${NC}"

    CONTAINER_RUNNING=$(docker ps --format '{{.Names}}' | grep "^${CONTAINER_NAME}$" || true)

    if [ -n "$CONTAINER_RUNNING" ]; then
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1
        echo -e "${GREEN}✓ Container stopped${NC}"
    fi

    docker rm "$CONTAINER_NAME" >/dev/null 2>&1
    echo -e "${GREEN}✓ Container removed${NC}"
else
    echo -e "${YELLOW}ℹ No container to remove${NC}"
fi

echo ""

# ============================================================================
# Kill tmux session
# ============================================================================

if [ "$TMUX_EXISTS" = true ]; then
    echo -e "${BLUE}→ Killing tmux session...${NC}"
    tmux kill-session -t "$TMUX_SESSION" 2>/dev/null || true
    echo -e "${GREEN}✓ Tmux session killed${NC}"
else
    echo -e "${YELLOW}ℹ No tmux session to kill${NC}"
fi

echo ""

# ============================================================================
# Remove worktree if requested
# ============================================================================

if [ "$REMOVE_WORKTREE" = true ] && [ "$WORKTREE_EXISTS" = true ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  ⚠  REMOVE WORKTREE${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${RED}This will remove the worktree and all its contents!${NC}"
    echo -e "${RED}Location: $WORKTREE_PATH${NC}"
    echo ""

    if [ "$WORKTREE_CLEAN" = false ]; then
        echo -e "${RED}⚠  The worktree has UNCOMMITTED CHANGES that will be LOST!${NC}"
        echo ""
    fi

    # Get branch name
    BRANCH=$(cd "$WORKTREE_PATH" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    echo -e "${BLUE}Branch:${NC} $BRANCH"
    echo ""

    read -p "Are you sure you want to remove the worktree? (type 'yes' to confirm): " -r
    echo ""

    if [ "$REPLY" = "yes" ]; then
        echo -e "${BLUE}→ Removing worktree...${NC}"

        # Remove worktree using git (safer)
        if git worktree list | grep -q "$WORKTREE_PATH"; then
            git worktree remove "$WORKTREE_PATH" --force 2>/dev/null || {
                # If git worktree remove fails, try manual cleanup
                echo -e "${YELLOW}  Git worktree remove failed, trying manual cleanup...${NC}"
                rm -rf "$WORKTREE_PATH"
            }
        else
            # Worktree not in git's list, just remove directory
            rm -rf "$WORKTREE_PATH"
        fi

        echo -e "${GREEN}✓ Worktree removed${NC}"

        # Remove parent directory if empty
        if [ -d ".worktrees" ] && [ -z "$(ls -A .worktrees)" ]; then
            rmdir .worktrees
            echo -e "${GREEN}✓ Removed empty .worktrees directory${NC}"
        fi
    else
        echo -e "${BLUE}→ Worktree removal cancelled${NC}"
        echo ""
        echo -e "${BLUE}To remove it later:${NC}"
        echo -e "  ${GREEN}git worktree remove $WORKTREE_PATH${NC}"
        echo -e "  ${GREEN}# or${NC}"
        echo -e "  ${GREEN}./scripts/kill-agent.sh $FEATURE_NAME --remove-worktree${NC}"
    fi
elif [ "$WORKTREE_EXISTS" = true ]; then
    echo -e "${BLUE}ℹ Worktree preserved: $WORKTREE_PATH${NC}"
    echo ""
    echo -e "${BLUE}To remove the worktree:${NC}"
    echo -e "  ${GREEN}git worktree remove $WORKTREE_PATH${NC}"
    echo -e "  ${GREEN}# or${NC}"
    echo -e "  ${GREEN}./scripts/kill-agent.sh $FEATURE_NAME --remove-worktree${NC}"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Cleanup completed${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

CLEANED_UP=""
if [ "$CONTAINER_EXISTS" = true ]; then
    CLEANED_UP="$CLEANED_UP\n  ${GREEN}✓${NC} Container stopped and removed"
fi
if [ "$TMUX_EXISTS" = true ]; then
    CLEANED_UP="$CLEANED_UP\n  ${GREEN}✓${NC} Tmux session killed"
fi
if [ "$REMOVE_WORKTREE" = true ] && [ "$WORKTREE_EXISTS" = true ] && [ "$REPLY" = "yes" ]; then
    CLEANED_UP="$CLEANED_UP\n  ${GREEN}✓${NC} Worktree removed"
elif [ "$WORKTREE_EXISTS" = true ]; then
    CLEANED_UP="$CLEANED_UP\n  ${BLUE}ℹ${NC} Worktree preserved"
fi

echo -e "${BLUE}Cleaned up:${NC}"
echo -e "$CLEANED_UP"
echo ""

if [ "$WORKTREE_EXISTS" = true ] && [ "$REMOVE_WORKTREE" = false ]; then
    echo -e "${BLUE}Next steps (if you want to merge your work):${NC}"
    echo -e "  1. Review changes: ${GREEN}cd $WORKTREE_PATH && git status${NC}"
    echo -e "  2. Push to remote: ${GREEN}cd $WORKTREE_PATH && git push${NC}"
    echo -e "  3. Merge to main: ${GREEN}git checkout main && git merge $BRANCH${NC}"
    echo -e "  4. Remove worktree: ${GREEN}git worktree remove $WORKTREE_PATH${NC}"
    echo ""
fi

echo -e "${BLUE}View remaining agents:${NC}"
echo -e "  ${GREEN}./scripts/list-agents.sh${NC}"
echo ""
