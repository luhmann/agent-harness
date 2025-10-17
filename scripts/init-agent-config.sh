#!/bin/bash
# init-agent-config.sh - Generate .agent-harness configuration templates
#
# This script creates template setup.sh and teardown.sh files for
# repository-specific agent initialization and cleanup.
#
# Usage: ./scripts/init-agent-config.sh [template-type]

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

TEMPLATE_TYPE="${1:-}"

# ============================================================================
# Show usage
# ============================================================================

show_usage() {
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Initialize Agent Configuration${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Usage: $0 [template-type]"
    echo ""
    echo "Template Types:"
    echo "  postgres    PostgreSQL database with dump import"
    echo "  mysql       MySQL database with dump import"
    echo "  redis       Redis instance per worktree"
    echo "  minimal     Minimal template with comments"
    echo "  custom      Empty template for custom setup"
    echo ""
    echo "If no template type is specified, you'll be prompted to choose."
    echo ""
    echo "Examples:"
    echo "  $0 postgres"
    echo "  $0 mysql"
    echo "  $0"
    echo ""
    exit 1
}

# ============================================================================
# Check if we're in a git repository
# ============================================================================

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}✗ Not in a git repository${NC}"
    echo -e "${RED}  Please run this script from your project repository root${NC}"
    exit 1
fi

CONFIG_DIR=".agent-harness"

# ============================================================================
# Template selection
# ============================================================================

if [ "$TEMPLATE_TYPE" = "--help" ] || [ "$TEMPLATE_TYPE" = "-h" ]; then
    show_usage
fi

if [ -z "$TEMPLATE_TYPE" ]; then
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Select Configuration Template${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}1)${NC} ${GREEN}PostgreSQL${NC} - Database with dump import"
    echo -e "   Creates unique PostgreSQL database per worktree"
    echo -e "   Imports latest dump matching naming pattern"
    echo ""
    echo -e "${BLUE}2)${NC} ${GREEN}MySQL${NC} - Database with dump import"
    echo -e "   Creates unique MySQL database per worktree"
    echo -e "   Imports SQL dump files"
    echo ""
    echo -e "${BLUE}3)${NC} ${GREEN}Redis${NC} - Redis instance per worktree"
    echo -e "   Spawns Docker Redis container for each worktree"
    echo ""
    echo -e "${BLUE}4)${NC} ${GREEN}Minimal${NC} - Minimal template with examples"
    echo -e "   Basic structure with helpful comments"
    echo ""
    echo -e "${BLUE}5)${NC} ${GREEN}Custom${NC} - Empty template"
    echo -e "   Blank files for custom configuration"
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""

    while true; do
        read -p "Enter your choice (1-5): " choice
        case $choice in
            1) TEMPLATE_TYPE="postgres"; break ;;
            2) TEMPLATE_TYPE="mysql"; break ;;
            3) TEMPLATE_TYPE="redis"; break ;;
            4) TEMPLATE_TYPE="minimal"; break ;;
            5) TEMPLATE_TYPE="custom"; break ;;
            *) echo -e "${RED}Invalid choice. Please enter 1-5.${NC}" ;;
        esac
    done
    echo ""
fi

# ============================================================================
# Check if config already exists
# ============================================================================

if [ -d "$CONFIG_DIR" ]; then
    echo -e "${YELLOW}⚠ Configuration directory already exists: $CONFIG_DIR${NC}"
    echo ""
    if [ -f "$CONFIG_DIR/setup.sh" ] || [ -f "$CONFIG_DIR/teardown.sh" ]; then
        echo -e "${YELLOW}Existing files:${NC}"
        [ -f "$CONFIG_DIR/setup.sh" ] && echo -e "  - setup.sh"
        [ -f "$CONFIG_DIR/teardown.sh" ] && echo -e "  - teardown.sh"
        echo ""
        read -p "Overwrite existing files? (y/N): " -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}→ Aborted${NC}"
            exit 0
        fi
    fi
else
    mkdir -p "$CONFIG_DIR"
    echo -e "${BLUE}→ Created directory: $CONFIG_DIR${NC}"
fi

# ============================================================================
# Generate templates
# ============================================================================

echo -e "${BLUE}→ Generating $TEMPLATE_TYPE template...${NC}"
echo ""

case $TEMPLATE_TYPE in
    postgres)
        # PostgreSQL template with dump import
        cat > "$CONFIG_DIR/setup.sh" << 'EOF'
#!/bin/bash
# PostgreSQL Setup Script
#
# This script runs when spawning a new agent. It creates a unique PostgreSQL
# database for this worktree and imports the latest dump.
#
# Environment variables available:
#   FEATURE_NAME    - Feature/agent name (e.g., "auth")
#   BRANCH_NAME     - Git branch (e.g., "feature/auth")
#   WORKTREE_PATH   - Path to worktree ("/workspace")
#   PROJECT_NAME    - Project name from git
#   DB_NAME         - Auto-generated unique DB name (e.g., "myproject_auth")
#   AGENT_TYPE      - Agent type ("claude" or "codex")

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Setting up worktree: $FEATURE_NAME"
echo "Database: $DB_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Find latest dump by parsing date from filename (e.g., dg-stage-prod-2025-10-16.sql)
# Adjust the pattern to match your dump file naming convention
LATEST_DUMP=$(ls dumps/*.sql 2>/dev/null | \
    sed 's/.*-\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\)\.sql/\1 &/' | \
    sort -r | \
    head -1 | \
    cut -d' ' -f2)

if [ -z "$LATEST_DUMP" ]; then
    echo "❌ No dump files found in dumps/"
    echo "   Place SQL dump files in dumps/ directory"
    exit 1
fi

DUMP_DATE=$(echo "$LATEST_DUMP" | grep -oP '\d{4}-\d{2}-\d{2}' || echo "unknown")
echo "→ Found dump: $(basename $LATEST_DUMP) (Date: $DUMP_DATE)"
echo ""

# Create database
echo "→ Creating database: $DB_NAME"
createdb "$DB_NAME" -h host.docker.internal

# Import dump
echo "→ Importing data..."
psql -h host.docker.internal -d "$DB_NAME" -f "$LATEST_DUMP" -q

# Update .mise.toml with database URL
echo "→ Configuring environment..."
cat >> .mise.toml << MISE_EOF

# Auto-generated by .agent-harness/setup.sh
[env]
DATABASE_URL = "postgresql://user:password@host.docker.internal:5432/$DB_NAME"
DB_NAME = "$DB_NAME"
MISE_EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ Setup complete"
echo "  Database: $DB_NAME"
echo "  Dump: $(basename $LATEST_DUMP)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
EOF

        cat > "$CONFIG_DIR/teardown.sh" << 'EOF'
#!/bin/bash
# PostgreSQL Teardown Script
#
# This script runs when killing an agent. It drops the database created
# during setup.

echo "→ Cleaning up database: $DB_NAME"
dropdb "$DB_NAME" -h host.docker.internal --if-exists
echo "✓ Cleanup complete"
EOF
        ;;

    mysql)
        # MySQL template
        cat > "$CONFIG_DIR/setup.sh" << 'EOF'
#!/bin/bash
# MySQL Setup Script

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Setting up worktree: $FEATURE_NAME"
echo "Database: $DB_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Find latest SQL dump
LATEST_DUMP=$(ls -t dumps/*.sql 2>/dev/null | head -1)

if [ -z "$LATEST_DUMP" ]; then
    echo "❌ No dump files found in dumps/"
    exit 1
fi

echo "→ Found dump: $(basename $LATEST_DUMP)"
echo ""

# Create database
echo "→ Creating database: $DB_NAME"
mysql -h host.docker.internal -e "CREATE DATABASE $DB_NAME"

# Import dump
echo "→ Importing data..."
mysql -h host.docker.internal "$DB_NAME" < "$LATEST_DUMP"

# Update environment
cat >> .mise.toml << MISE_EOF

[env]
DATABASE_URL = "mysql://user:password@host.docker.internal:3306/$DB_NAME"
DB_NAME = "$DB_NAME"
MISE_EOF

echo ""
echo "✓ Setup complete: $DB_NAME"
EOF

        cat > "$CONFIG_DIR/teardown.sh" << 'EOF'
#!/bin/bash
# MySQL Teardown Script

echo "→ Cleaning up database: $DB_NAME"
mysql -h host.docker.internal -e "DROP DATABASE IF EXISTS $DB_NAME"
echo "✓ Cleanup complete"
EOF
        ;;

    redis)
        # Redis template
        cat > "$CONFIG_DIR/setup.sh" << 'EOF'
#!/bin/bash
# Redis Setup Script

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Setting up worktree: $FEATURE_NAME"
echo "Redis instance: redis-$FEATURE_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start Redis container
echo "→ Starting Redis container..."
docker run -d \
    --name "redis-$FEATURE_NAME" \
    --network bridge \
    -p 0:6379 \
    redis:7-alpine

# Get assigned port
REDIS_PORT=$(docker port "redis-$FEATURE_NAME" 6379 | cut -d':' -f2)

# Update environment
cat >> .mise.toml << MISE_EOF

[env]
REDIS_URL = "redis://host.docker.internal:$REDIS_PORT"
REDIS_HOST = "host.docker.internal"
REDIS_PORT = "$REDIS_PORT"
MISE_EOF

echo ""
echo "✓ Setup complete"
echo "  Redis: host.docker.internal:$REDIS_PORT"
EOF

        cat > "$CONFIG_DIR/teardown.sh" << 'EOF'
#!/bin/bash
# Redis Teardown Script

echo "→ Stopping Redis container: redis-$FEATURE_NAME"
docker stop "redis-$FEATURE_NAME" 2>/dev/null || true
docker rm "redis-$FEATURE_NAME" 2>/dev/null || true
echo "✓ Cleanup complete"
EOF
        ;;

    minimal)
        # Minimal template with comments
        cat > "$CONFIG_DIR/setup.sh" << 'EOF'
#!/bin/bash
# Setup Script
#
# This script runs when spawning a new agent worktree.
# Use it to prepare the environment (create databases, start services, etc.)
#
# Available environment variables:
#   FEATURE_NAME    - Feature/agent name
#   BRANCH_NAME     - Git branch name
#   WORKTREE_PATH   - Path to worktree (/workspace)
#   PROJECT_NAME    - Project name from git
#   DB_NAME         - Auto-generated unique DB name
#   AGENT_TYPE      - Agent type (claude/codex)

set -e

echo "Setting up worktree: $FEATURE_NAME"

# Example: Create database
# createdb "$DB_NAME" -h host.docker.internal

# Example: Import dump
# psql -h host.docker.internal -d "$DB_NAME" -f dumps/latest.sql

# Example: Run migrations
# export DATABASE_URL="postgresql://user:pass@host.docker.internal:5432/$DB_NAME"
# npm run migrate:latest

# Example: Update environment variables
# cat >> .mise.toml << MISE_EOF
# [env]
# DATABASE_URL = "postgresql://user:pass@host.docker.internal:5432/$DB_NAME"
# MISE_EOF

echo "✓ Setup complete"
EOF

        cat > "$CONFIG_DIR/teardown.sh" << 'EOF'
#!/bin/bash
# Teardown Script
#
# This script runs when killing an agent.
# Use it to clean up resources (drop databases, stop services, etc.)

echo "Cleaning up: $FEATURE_NAME"

# Example: Drop database
# dropdb "$DB_NAME" -h host.docker.internal --if-exists

# Example: Stop Docker services
# docker stop "redis-$FEATURE_NAME" 2>/dev/null || true
# docker rm "redis-$FEATURE_NAME" 2>/dev/null || true

echo "✓ Cleanup complete"
EOF
        ;;

    custom)
        # Empty custom template
        cat > "$CONFIG_DIR/setup.sh" << 'EOF'
#!/bin/bash
# Custom Setup Script

set -e

# Add your setup logic here

EOF

        cat > "$CONFIG_DIR/teardown.sh" << 'EOF'
#!/bin/bash
# Custom Teardown Script

# Add your teardown logic here

EOF
        ;;

    *)
        echo -e "${RED}✗ Unknown template type: $TEMPLATE_TYPE${NC}"
        echo ""
        show_usage
        ;;
esac

# Make scripts executable
chmod +x "$CONFIG_DIR/setup.sh"
chmod +x "$CONFIG_DIR/teardown.sh"

echo -e "${GREEN}✓ Created $CONFIG_DIR/setup.sh${NC}"
echo -e "${GREEN}✓ Created $CONFIG_DIR/teardown.sh${NC}"
echo ""

# ============================================================================
# Create .gitignore if needed
# ============================================================================

if [ ! -f "$CONFIG_DIR/.gitignore" ]; then
    cat > "$CONFIG_DIR/.gitignore" << 'EOF'
# Optional: ignore state files created during setup/teardown
.state
*.tmp
EOF
    echo -e "${GREEN}✓ Created $CONFIG_DIR/.gitignore${NC}"
    echo ""
fi

# ============================================================================
# Success message
# ============================================================================

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Agent configuration created${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Files created:${NC}"
echo -e "  $CONFIG_DIR/setup.sh"
echo -e "  $CONFIG_DIR/teardown.sh"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Edit the scripts to match your project needs"
echo -e "  2. Test with: ${GREEN}spawn-agent test-feature${NC}"
echo -e "  3. Commit to git: ${GREEN}git add $CONFIG_DIR${NC}"
echo ""
echo -e "${YELLOW}Note: These scripts will run automatically when spawning/killing agents${NC}"
echo ""
