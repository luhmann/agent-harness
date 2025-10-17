#!/bin/bash
# init-auth.sh - Hybrid authentication initialization for Claude Code
#
# This script implements the hybrid auth strategy:
# 1. Check if container already has authentication
# 2. If not, try to copy from host ~/.claude directory
# 3. Otherwise, prompt user to login manually
#
# Usage: init-auth.sh [HOST_CLAUDE_DIR]

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Container paths
CONTAINER_CLAUDE_DIR="/home/claudedev/.claude"
CREDENTIALS_FILE="$CONTAINER_CLAUDE_DIR/.credentials.json"

# Host path (passed as argument or environment variable)
HOST_CLAUDE_DIR="${1:-$HOST_CLAUDE_DIR}"

echo -e "${BLUE}=== Claude Code Authentication Initialization ===${NC}"
echo ""

# Create .claude directory if it doesn't exist
mkdir -p "$CONTAINER_CLAUDE_DIR"

# ============================================================================
# Step 1: Check if container already has authentication
# ============================================================================

if [ -f "$CREDENTIALS_FILE" ]; then
    echo -e "${GREEN}✓ Authentication already configured${NC}"
    echo -e "${GREEN}✓ Credentials found at: $CREDENTIALS_FILE${NC}"
    echo ""

    # Verify the credentials file is valid JSON
    if ! jq empty "$CREDENTIALS_FILE" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Warning: Credentials file exists but is not valid JSON${NC}"
        echo -e "${YELLOW}  You may need to re-authenticate using '/login' in Claude Code${NC}"
        echo ""
    else
        echo -e "${GREEN}✓ Credentials validated successfully${NC}"
        echo ""
    fi

    exit 0
fi

# ============================================================================
# Step 2: Try to copy authentication from host
# ============================================================================

if [ -n "$HOST_CLAUDE_DIR" ] && [ -d "$HOST_CLAUDE_DIR" ]; then
    echo -e "${BLUE}→ Found host Claude directory: $HOST_CLAUDE_DIR${NC}"

    # Check if host has credentials
    if [ -f "$HOST_CLAUDE_DIR/.credentials.json" ]; then
        echo -e "${BLUE}→ Copying authentication from host...${NC}"

        # Copy all files from host .claude directory
        cp -r "$HOST_CLAUDE_DIR"/* "$CONTAINER_CLAUDE_DIR/" 2>/dev/null || true

        # Ensure proper permissions
        chmod 700 "$CONTAINER_CLAUDE_DIR"
        chmod 600 "$CONTAINER_CLAUDE_DIR/.credentials.json" 2>/dev/null || true

        # Verify copy was successful
        if [ -f "$CREDENTIALS_FILE" ]; then
            echo -e "${GREEN}✓ Authentication copied successfully${NC}"
            echo -e "${GREEN}✓ You can now use Claude Code without logging in${NC}"
            echo ""
            exit 0
        else
            echo -e "${YELLOW}⚠ Copy completed but credentials file not found${NC}"
            echo -e "${YELLOW}  Continuing with manual login...${NC}"
            echo ""
        fi
    else
        echo -e "${YELLOW}⚠ Host directory exists but no credentials found${NC}"
        echo -e "${YELLOW}  at: $HOST_CLAUDE_DIR/.credentials.json${NC}"
        echo ""
    fi
fi

# ============================================================================
# Step 3: Prompt for manual login
# ============================================================================

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  No authentication found${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "To use Claude Code, you need to authenticate."
echo ""
echo -e "Once Claude Code starts, run the following command:"
echo -e "${GREEN}  /login${NC}"
echo ""
echo -e "This will open a browser where you can:"
echo -e "  1. Log in with your Claude.ai account (recommended), OR"
echo -e "  2. Log in with your Claude Console account (API credits)"
echo ""
echo -e "${BLUE}ℹ After successful login, authentication will persist across${NC}"
echo -e "${BLUE}  container restarts in the '${NC}claude-config${BLUE}' volume${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Exit with code 1 to indicate manual login is needed
exit 1
