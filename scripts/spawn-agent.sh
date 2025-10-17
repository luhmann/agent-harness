#!/bin/bash
# spawn-agent.sh - Spawn parallel AI agents in isolated git worktrees
#
# This script creates a git worktree and launches an AI agent in a separate
# Docker container, allowing multiple agents to work in parallel on different
# features/branches.
#
# Usage: ./scripts/spawn-agent.sh <feature-name> [branch] [agent-type] [--task "text"] [--task-file FILE] [--detach]

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ============================================================================
# Parse arguments
# ============================================================================

FEATURE_NAME=""
BRANCH=""
AGENT_TYPE=""
TASK_TEXT=""
TASK_FILE=""
DETACH=false

# Show usage
show_usage() {
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Spawn Parallel AI Agent${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Usage: $0 <feature-name> [branch] [agent-type] [options]"
    echo ""
    echo "Arguments:"
    echo "  feature-name    Name for this agent instance (used for container/session)"
    echo "  branch          Git branch (optional, creates new if doesn't exist)"
    echo "  agent-type      'claude' or 'codex' (optional, shows menu if not specified)"
    echo ""
    echo "Options:"
    echo "  --task TEXT     Send task text to agent after it starts"
    echo "  --task-file FILE  Send task from file to agent after it starts"
    echo "  --detach        Detach from tmux session after starting"
    echo ""
    echo "Examples:"
    echo "  $0 feature-auth"
    echo "  $0 feature-api feature/api-endpoints claude"
    echo "  $0 bugfix-123 main codex --task 'Fix the login bug'"
    echo "  $0 refactor-db develop --task-file tasks/refactor.txt --detach"
    echo ""
    exit 1
}

# Parse positional and flag arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --task)
            TASK_TEXT="$2"
            shift 2
            ;;
        --task-file)
            TASK_FILE="$2"
            shift 2
            ;;
        --detach)
            DETACH=true
            shift
            ;;
        --help|-h)
            show_usage
            ;;
        *)
            if [ -z "$FEATURE_NAME" ]; then
                FEATURE_NAME="$1"
            elif [ -z "$BRANCH" ]; then
                BRANCH="$1"
            elif [ -z "$AGENT_TYPE" ]; then
                AGENT_TYPE="$1"
            else
                echo -e "${RED}✗ Unknown argument: $1${NC}"
                show_usage
            fi
            shift
            ;;
    esac
done

# Validate feature name
if [ -z "$FEATURE_NAME" ]; then
    echo -e "${RED}✗ Feature name is required${NC}"
    echo ""
    show_usage
fi

# Sanitize feature name (replace spaces and special chars)
FEATURE_NAME=$(echo "$FEATURE_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')

# Set default branch if not specified
if [ -z "$BRANCH" ]; then
    BRANCH="feature/$FEATURE_NAME"
fi

CONTAINER_NAME="agent-harness-$FEATURE_NAME"
TMUX_SESSION="agent-$FEATURE_NAME"
WORKTREE_PATH=".worktrees/$FEATURE_NAME"

# ============================================================================
# Display header
# ============================================================================

echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Spawning Parallel AI Agent${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Feature:${NC} $FEATURE_NAME"
echo -e "${BLUE}Branch:${NC} $BRANCH"
echo -e "${BLUE}Container:${NC} $CONTAINER_NAME"
echo -e "${BLUE}Worktree:${NC} $WORKTREE_PATH"
echo -e "${BLUE}Tmux Session:${NC} $TMUX_SESSION"
echo ""

# ============================================================================
# Check dependencies
# ============================================================================

echo -e "${BLUE}→ Checking dependencies...${NC}"

# Check Docker
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    echo -e "${RED}  Please start Docker and try again${NC}"
    exit 1
fi

# Check tmux
if ! command -v tmux &> /dev/null; then
    echo -e "${RED}✗ tmux is not installed${NC}"
    echo -e "${RED}  Please install tmux: brew install tmux (macOS) or apt-get install tmux (Linux)${NC}"
    exit 1
fi

# Check git
if ! command -v git &> /dev/null; then
    echo -e "${RED}✗ git is not installed${NC}"
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}✗ Not in a git repository${NC}"
    echo -e "${RED}  Please run this script from the agent-harness repository root${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Dependencies OK${NC}"
echo ""

# ============================================================================
# Check for conflicts
# ============================================================================

echo -e "${BLUE}→ Checking for conflicts...${NC}"

# Check if worktree already exists
if [ -d "$WORKTREE_PATH" ]; then
    echo -e "${RED}✗ Worktree already exists: $WORKTREE_PATH${NC}"
    echo -e "${RED}  Use './scripts/attach-agent.sh $FEATURE_NAME' to attach to existing agent${NC}"
    echo -e "${RED}  Or use './scripts/kill-agent.sh $FEATURE_NAME' to remove it first${NC}"
    exit 1
fi

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}✗ Container already exists: $CONTAINER_NAME${NC}"
    echo -e "${RED}  Use './scripts/kill-agent.sh $FEATURE_NAME' to remove it first${NC}"
    exit 1
fi

# Check if tmux session already exists
if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
    echo -e "${RED}✗ Tmux session already exists: $TMUX_SESSION${NC}"
    echo -e "${RED}  Use './scripts/attach-agent.sh $FEATURE_NAME' to attach${NC}"
    exit 1
fi

echo -e "${GREEN}✓ No conflicts${NC}"
echo ""

# ============================================================================
# Create git worktree
# ============================================================================

echo -e "${BLUE}→ Creating git worktree...${NC}"

# Check if branch exists
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo -e "${BLUE}  Branch '$BRANCH' exists, checking out...${NC}"
    git worktree add "$WORKTREE_PATH" "$BRANCH"
else
    echo -e "${YELLOW}  Branch '$BRANCH' does not exist, creating new branch...${NC}"
    git worktree add -b "$BRANCH" "$WORKTREE_PATH"
fi

echo -e "${GREEN}✓ Worktree created: $WORKTREE_PATH${NC}"
echo ""

# ============================================================================
# Copy .mise.toml.template if needed
# ============================================================================

echo -e "${BLUE}→ Setting up worktree configuration...${NC}"

if [ ! -f "$WORKTREE_PATH/.mise.toml" ]; then
    if [ -f ".mise.toml.template" ]; then
        echo -e "${BLUE}  Copying .mise.toml.template...${NC}"
        cp .mise.toml.template "$WORKTREE_PATH/.mise.toml"
        echo -e "${GREEN}✓ .mise.toml created${NC}"
    else
        echo -e "${YELLOW}  Warning: .mise.toml.template not found${NC}"
    fi
fi

echo ""

# ============================================================================
# Build Docker image if needed
# ============================================================================

echo -e "${BLUE}→ Checking Docker image...${NC}"

IMAGE_NAME="agent-harness-claude-sandbox"
if ! docker images | grep -q "$IMAGE_NAME"; then
    echo -e "${YELLOW}  Image not found, building (this may take 5-10 minutes)...${NC}"
    docker-compose build
    echo -e "${GREEN}✓ Image built${NC}"
else
    echo -e "${GREEN}✓ Image exists${NC}"
fi

echo ""

# ============================================================================
# Get host auth directories
# ============================================================================

HOST_CLAUDE_DIR="$HOME/.claude"
HOST_CODEX_DIR="$HOME/.codex"

# ============================================================================
# Start Docker container
# ============================================================================

echo -e "${BLUE}→ Starting Docker container...${NC}"

# Get absolute path for worktree
WORKTREE_ABS_PATH="$(cd "$WORKTREE_PATH" && pwd)"

# Start container with docker run (mimicking docker-compose.yml settings)
docker run -d \
    --name "$CONTAINER_NAME" \
    --hostname "agent-$FEATURE_NAME" \
    --security-opt no-new-privileges:true \
    --cap-drop ALL \
    --cap-add CHOWN \
    --cap-add SETUID \
    --cap-add SETGID \
    --cap-add DAC_OVERRIDE \
    --memory "${MEMORY_LIMIT:-4g}" \
    --cpus "${CPU_LIMIT:-2.0}" \
    --pids-limit 512 \
    -v "$WORKTREE_ABS_PATH:/workspace" \
    -v claude-config:/home/claudedev/.claude \
    -v codex-config:/home/claudedev/.codex \
    -v mise-cache:/home/claudedev/.local/share/mise/cache \
    -v "$(pwd)/scripts:/scripts:ro" \
    --add-host host.docker.internal:host-gateway \
    -e MISE_DATA_DIR=/home/claudedev/.local/share/mise \
    -e MISE_CACHE_DIR=/home/claudedev/.local/share/mise/cache \
    -e PROJECT_NAME="$FEATURE_NAME" \
    -e CLAUDE_CONFIG_DIR=/home/claudedev/.claude \
    -e CODEX_CONFIG_DIR=/home/claudedev/.codex \
    -e CODEX_APPROVAL_MODE=full-access \
    -e TERM=xterm-256color \
    -w /workspace \
    -it \
    "$IMAGE_NAME" \
    /bin/bash -c "tail -f /dev/null" > /dev/null

echo -e "${GREEN}✓ Container started: $CONTAINER_NAME${NC}"
echo ""

# ============================================================================
# Run repository setup script (if exists)
# ============================================================================

if [ -f "$WORKTREE_PATH/.agent-harness/setup.sh" ]; then
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Running Repository Setup${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}→ Found .agent-harness/setup.sh${NC}"
    echo -e "${BLUE}  Running setup script...${NC}"
    echo ""

    # Get project name from git
    PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel)")

    # Generate unique DB name: projectname_featurename
    DB_NAME="${PROJECT_NAME}_${FEATURE_NAME}" | tr '[:upper:]' '[:lower:]' | tr '-' '_'

    # Export environment variables for setup script
    SETUP_ENV="export FEATURE_NAME='$FEATURE_NAME' && \
export BRANCH_NAME='$BRANCH' && \
export WORKTREE_PATH='/workspace' && \
export PROJECT_NAME='$PROJECT_NAME' && \
export DB_NAME='$DB_NAME' && \
export AGENT_TYPE='$AGENT_TYPE'"

    # Run setup script inside container
    if docker exec "$CONTAINER_NAME" bash -c "cd /workspace && eval \"\$(mise activate bash)\" && mise install && $SETUP_ENV && bash .agent-harness/setup.sh"; then
        echo ""
        echo -e "${GREEN}✓ Setup completed successfully${NC}"
        echo ""
    else
        echo ""
        echo -e "${RED}✗ Setup script failed${NC}"
        echo ""

        # Run teardown if it exists
        if [ -f "$WORKTREE_PATH/.agent-harness/teardown.sh" ]; then
            echo -e "${YELLOW}→ Running teardown script...${NC}"
            docker exec "$CONTAINER_NAME" bash -c "cd /workspace && $SETUP_ENV && bash .agent-harness/teardown.sh" 2>/dev/null || true
            echo ""
        fi

        # Cleanup
        echo -e "${YELLOW}→ Cleaning up container and worktree...${NC}"
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1
        git worktree remove "$WORKTREE_PATH" --force >/dev/null 2>&1

        echo -e "${RED}✗ Agent spawn aborted due to setup failure${NC}"
        echo ""
        exit 1
    fi
fi

# ============================================================================
# Initialize authentication
# ============================================================================

echo -e "${BLUE}→ Initializing authentication...${NC}"
echo ""

docker exec "$CONTAINER_NAME" /scripts/init-auth.sh "$HOST_CLAUDE_DIR" "$HOST_CODEX_DIR" || {
    AUTH_EXIT_CODE=$?
    if [ $AUTH_EXIT_CODE -ne 1 ]; then
        echo -e "${RED}✗ Authentication initialization failed${NC}"
        echo -e "${YELLOW}→ Cleaning up...${NC}"
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1
        git worktree remove "$WORKTREE_PATH" --force >/dev/null 2>&1
        exit 1
    fi
}

echo ""

# ============================================================================
# Agent selection menu (if not already selected)
# ============================================================================

if [ -z "$AGENT_TYPE" ]; then
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Select AI Coding Agent${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${MAGENTA}1)${NC} ${GREEN}Claude Code${NC} (Anthropic)"
    echo -e "   → Surgical edits, multi-step tasks"
    echo ""
    echo -e "${MAGENTA}2)${NC} ${GREEN}Codex CLI${NC} (OpenAI)"
    echo -e "   → Fast, open-source, community-driven"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""

    while true; do
        read -p "Enter your choice (1-2): " choice
        case $choice in
            1)
                AGENT_TYPE="claude"
                break
                ;;
            2)
                AGENT_TYPE="codex"
                break
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 1 or 2.${NC}"
                ;;
        esac
    done
    echo ""
fi

# Validate agent type
case $AGENT_TYPE in
    claude|1)
        AGENT_TYPE="claude"
        ;;
    codex|2)
        AGENT_TYPE="codex"
        ;;
    *)
        echo -e "${RED}✗ Invalid agent type: $AGENT_TYPE${NC}"
        echo -e "${RED}  Must be 'claude' or 'codex'${NC}"
        exit 1
        ;;
esac

# ============================================================================
# Read task from file if specified
# ============================================================================

if [ -n "$TASK_FILE" ]; then
    if [ ! -f "$TASK_FILE" ]; then
        echo -e "${RED}✗ Task file not found: $TASK_FILE${NC}"
        exit 1
    fi
    echo -e "${BLUE}→ Reading task from file: $TASK_FILE${NC}"
    TASK_TEXT="$(cat "$TASK_FILE")"
    echo ""
fi

# ============================================================================
# Create tmux session and launch agent
# ============================================================================

echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Launching $AGENT_TYPE agent in tmux${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""

# Build the agent command
if [ "$AGENT_TYPE" = "claude" ]; then
    AGENT_CMD="claude --dangerously-skip-permissions"
    echo -e "${YELLOW}⚠ Claude Code will run with ${NC}${RED}--dangerously-skip-permissions${NC}"
else
    AGENT_CMD="codex --approval full-access"
    echo -e "${YELLOW}⚠ Codex CLI will run in ${NC}${RED}full-access mode${NC}"
fi

echo -e "${YELLOW}  This means it can execute any command WITHOUT asking${NC}"
echo -e "${YELLOW}  However, it's sandboxed within the Docker container${NC}"
echo ""
echo -e "${BLUE}ℹ Working directory:${NC} /workspace"
echo -e "${BLUE}ℹ Container:${NC} $CONTAINER_NAME"
echo -e "${BLUE}ℹ Tmux session:${NC} $TMUX_SESSION"
echo ""

if [ "$DETACH" = true ]; then
    echo -e "${BLUE}ℹ Running in detached mode${NC}"
    echo -e "${BLUE}ℹ To attach:${NC} ./scripts/attach-agent.sh $FEATURE_NAME"
else
    echo -e "${BLUE}ℹ To detach:${NC} Press Ctrl+B then D"
    echo -e "${BLUE}ℹ To attach later:${NC} ./scripts/attach-agent.sh $FEATURE_NAME"
fi

echo -e "${BLUE}ℹ To view logs:${NC} ./scripts/logs-agent.sh $FEATURE_NAME"
echo -e "${BLUE}ℹ To stop:${NC} ./scripts/kill-agent.sh $FEATURE_NAME"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════${NC}"
echo ""

# Small delay
sleep 2

# Create tmux session and run agent
if [ -n "$TASK_TEXT" ]; then
    # If task provided, we need to send it after agent starts
    # This is complex - we'll create a helper script inside the container

    # Create temporary script inside container
    TEMP_SCRIPT="/tmp/start-agent-$FEATURE_NAME.sh"
    docker exec "$CONTAINER_NAME" bash -c "cat > $TEMP_SCRIPT" <<EOF
#!/bin/bash
cd /workspace
eval "\$(mise activate bash)"
mise install

# Start agent in background with task
echo "$TASK_TEXT" | $AGENT_CMD
EOF

    docker exec "$CONTAINER_NAME" chmod +x "$TEMP_SCRIPT"

    # Create tmux session and run the script
    tmux new-session -d -s "$TMUX_SESSION" \
        "docker exec -it $CONTAINER_NAME bash -c '$TEMP_SCRIPT'"
else
    # No task, just run agent normally
    tmux new-session -d -s "$TMUX_SESSION" \
        "docker exec -it $CONTAINER_NAME bash -c 'cd /workspace && eval \"\$(mise activate bash)\" && mise install && exec $AGENT_CMD'"
fi

# Attach to session if not detached
if [ "$DETACH" = false ]; then
    tmux attach-session -t "$TMUX_SESSION"

    # After detaching/exiting
    echo ""
    echo -e "${GREEN}✓ Detached from agent session${NC}"
    echo -e "${BLUE}ℹ Container is still running in the background${NC}"
    echo -e "${BLUE}ℹ To reattach:${NC} ./scripts/attach-agent.sh $FEATURE_NAME"
    echo ""
else
    echo -e "${GREEN}✓ Agent started in background${NC}"
    echo -e "${BLUE}ℹ To attach:${NC} ./scripts/attach-agent.sh $FEATURE_NAME"
    echo ""
fi

# ============================================================================
# Summary
# ============================================================================

echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Parallel Agent Summary${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Feature:${NC} $FEATURE_NAME"
echo -e "${BLUE}Agent:${NC} $AGENT_TYPE"
echo -e "${BLUE}Branch:${NC} $BRANCH"
echo -e "${BLUE}Worktree:${NC} $WORKTREE_PATH"
echo -e "${BLUE}Container:${NC} $CONTAINER_NAME"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo -e "  • List all agents: ${GREEN}./scripts/list-agents.sh${NC}"
echo -e "  • Attach to agent: ${GREEN}./scripts/attach-agent.sh $FEATURE_NAME${NC}"
echo -e "  • View logs: ${GREEN}./scripts/logs-agent.sh $FEATURE_NAME${NC}"
echo -e "  • Stop agent: ${GREEN}./scripts/kill-agent.sh $FEATURE_NAME${NC}"
echo ""
echo -e "${YELLOW}When done:${NC}"
echo -e "  1. Stop agent: ${GREEN}./scripts/kill-agent.sh $FEATURE_NAME --remove-worktree${NC}"
echo -e "  2. Merge changes: ${GREEN}cd $WORKTREE_PATH && git push && cd - && git merge $BRANCH${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo ""
