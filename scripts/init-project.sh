#!/bin/bash
# init-project.sh - Initialize a new sandboxed project
#
# This script creates a new project directory with:
# - .mise.toml for runtime configuration
# - git repository
# - README with instructions
#
# Usage: ./scripts/init-project.sh <project-name>

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_NAME="$1"

# ============================================================================
# Validation
# ============================================================================

if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}✗ Error: Project name is required${NC}"
    echo ""
    echo -e "Usage: $0 <project-name>"
    echo ""
    echo -e "Example:"
    echo -e "  $0 my-awesome-app"
    echo ""
    exit 1
fi

# Validate project name (alphanumeric, dashes, underscores only)
if ! echo "$PROJECT_NAME" | grep -qE '^[a-zA-Z0-9_-]+$'; then
    echo -e "${RED}✗ Error: Invalid project name${NC}"
    echo -e "${RED}  Project name can only contain letters, numbers, dashes, and underscores${NC}"
    exit 1
fi

PROJECT_DIR="./projects/$PROJECT_NAME"

# Check if project already exists
if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}⚠ Warning: Project '$PROJECT_NAME' already exists at:${NC}"
    echo -e "${YELLOW}  $PROJECT_DIR${NC}"
    echo ""
    read -p "Do you want to reinitialize it? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}→ Aborted${NC}"
        exit 0
    fi
fi

echo -e "${BLUE}=== Initializing Project: $PROJECT_NAME ===${NC}"
echo ""

# ============================================================================
# Create project structure
# ============================================================================

echo -e "${BLUE}→ Creating project directory...${NC}"
mkdir -p "$PROJECT_DIR"

# ============================================================================
# Copy mise template
# ============================================================================

if [ -f ".mise.toml.template" ]; then
    echo -e "${BLUE}→ Creating .mise.toml from template...${NC}"
    cp .mise.toml.template "$PROJECT_DIR/.mise.toml"
    echo -e "${GREEN}✓ .mise.toml created${NC}"
else
    echo -e "${YELLOW}⚠ Warning: .mise.toml.template not found${NC}"
    echo -e "${YELLOW}  Creating default .mise.toml...${NC}"

    cat > "$PROJECT_DIR/.mise.toml" << 'EOF'
# Mise runtime configuration
# Documentation: https://mise.jdx.dev/

[tools]
node = "22"
python = "3.12"
erlang = "27"
elixir = "1.17"

[env]
# Add project-specific environment variables here
# EXAMPLE_VAR = "value"
EOF

    echo -e "${GREEN}✓ Default .mise.toml created${NC}"
fi

# ============================================================================
# Initialize git repository
# ============================================================================

echo -e "${BLUE}→ Initializing git repository...${NC}"
cd "$PROJECT_DIR"
git init >/dev/null 2>&1 || true

# Create .gitignore
cat > .gitignore << 'EOF'
# Dependencies
node_modules/
__pycache__/
*.pyc
_build/
deps/
.mix/

# Environment
.env
.env.local

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Build outputs
dist/
build/
*.o
*.so

# Logs
*.log
npm-debug.log*
EOF

echo -e "${GREEN}✓ Git repository initialized${NC}"

# ============================================================================
# Create README
# ============================================================================

echo -e "${BLUE}→ Creating README.md...${NC}"

cat > README.md << EOF
# $PROJECT_NAME

This project runs in the Claude Code Docker sandbox.

## Getting Started

This project is configured to run in an isolated Docker environment with Claude Code in autonomous (yolo) mode.

### Running Claude Code

From the repository root, run:

\`\`\`bash
./scripts/run-claude.sh $PROJECT_NAME
\`\`\`

This will:
1. Start the Docker container if not running
2. Initialize authentication (first time only)
3. Launch Claude Code with full permissions (sandboxed)

### Runtime Configuration

This project uses [mise](https://mise.jdx.dev/) for managing development tool versions.

Edit \`.mise.toml\` to change runtime versions:

\`\`\`toml
[tools]
node = "22"        # Change Node.js version
python = "3.12"    # Change Python version
erlang = "27"      # Required for Elixir
elixir = "1.17"    # Change Elixir version
\`\`\`

After changing versions, mise will automatically install them when you next start Claude Code.

### Available Runtimes

Pre-configured in the Docker image:
- **Node.js**: npm, npx, node (managed by mise)
- **Python**: pip, python (managed by mise)
- **Elixir**: mix, iex, elixir (managed by mise)
- **Git**: For version control

### Security Notes

- Claude Code runs with \`--dangerously-skip-permissions\` inside the container
- The container is isolated from your host system
- Only the \`projects/$PROJECT_NAME\` directory is accessible
- Full internet access is available for package installation

### Useful Commands

Inside Claude Code, you can use slash commands:
- \`/help\` - Show available commands
- \`/login\` - Re-authenticate if needed
- \`exit\` or \`Ctrl+D\` - Exit Claude Code session

## Project Structure

\`\`\`
$PROJECT_NAME/
├── .mise.toml          # Runtime version configuration
├── .gitignore          # Git ignore patterns
└── README.md           # This file
\`\`\`

## Next Steps

1. Start Claude Code: \`./scripts/run-claude.sh $PROJECT_NAME\`
2. Ask Claude to help you build your project!
3. All changes are automatically synced to your host machine

## Need Help?

- mise documentation: https://mise.jdx.dev/
- Claude Code documentation: https://docs.claude.com/claude-code
- Docker documentation: https://docs.docker.com/
EOF

echo -e "${GREEN}✓ README.md created${NC}"

# ============================================================================
# Create initial commit
# ============================================================================

echo -e "${BLUE}→ Creating initial commit...${NC}"
git add .
git commit -m "Initial commit: Claude Code sandbox project" >/dev/null 2>&1 || true
echo -e "${GREEN}✓ Initial commit created${NC}"

# Return to root directory
cd - >/dev/null

# ============================================================================
# Success message
# ============================================================================

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Project '$PROJECT_NAME' initialized successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Location:${NC} $PROJECT_DIR"
echo ""
echo -e "${BLUE}To start working on your project:${NC}"
echo -e "  ${GREEN}./scripts/run-claude.sh $PROJECT_NAME${NC}"
echo ""
echo -e "${BLUE}To customize runtimes:${NC}"
echo -e "  Edit: ${GREEN}$PROJECT_DIR/.mise.toml${NC}"
echo ""
