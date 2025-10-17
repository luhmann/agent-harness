#!/bin/bash
# init-auth.sh - Hybrid authentication initialization for AI coding agents
#
# This script implements the hybrid auth strategy for both:
# - Claude Code (Anthropic)
# - Codex CLI (OpenAI)
#
# Strategy:
# 1. Check if container already has authentication
# 2. If not, try to copy from host directories
# 3. Otherwise, prompt user to login manually
#
# Usage: init-auth.sh [HOST_CLAUDE_DIR] [HOST_CODEX_DIR]

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Container paths
CONTAINER_CLAUDE_DIR="/home/claudedev/.claude"
CONTAINER_CODEX_DIR="/home/claudedev/.codex"
CLAUDE_CREDENTIALS="$CONTAINER_CLAUDE_DIR/.credentials.json"
CODEX_CONFIG="$CONTAINER_CODEX_DIR/config.toml"

# Host paths (passed as arguments or environment variables)
HOST_CLAUDE_DIR="${1:-$HOST_CLAUDE_DIR}"
HOST_CODEX_DIR="${2:-$HOST_CODEX_DIR}"

# Track authentication status
CLAUDE_AUTH_OK=false
CODEX_AUTH_OK=false

echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  AI Agent Authentication Initialization${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo ""

# Create directories if they don't exist
mkdir -p "$CONTAINER_CLAUDE_DIR"
mkdir -p "$CONTAINER_CODEX_DIR"

# ============================================================================
# Function: Initialize Claude Code Authentication
# ============================================================================

init_claude_auth() {
    echo -e "${BLUE}[Claude Code] Checking authentication...${NC}"

    # Check if already authenticated
    if [ -f "$CLAUDE_CREDENTIALS" ]; then
        # Verify the credentials file is valid JSON
        if jq empty "$CLAUDE_CREDENTIALS" 2>/dev/null; then
            echo -e "${GREEN}✓ Claude Code authentication already configured${NC}"
            CLAUDE_AUTH_OK=true
            return 0
        else
            echo -e "${YELLOW}⚠ Credentials file exists but is invalid${NC}"
        fi
    fi

    # Try to copy from host
    if [ -n "$HOST_CLAUDE_DIR" ] && [ -d "$HOST_CLAUDE_DIR" ]; then
        if [ -f "$HOST_CLAUDE_DIR/.credentials.json" ]; then
            echo -e "${BLUE}→ Copying Claude authentication from host...${NC}"

            # Copy all files from host .claude directory
            cp -r "$HOST_CLAUDE_DIR"/* "$CONTAINER_CLAUDE_DIR/" 2>/dev/null || true

            # Ensure proper permissions
            chmod 700 "$CONTAINER_CLAUDE_DIR"
            chmod 600 "$CONTAINER_CLAUDE_DIR/.credentials.json" 2>/dev/null || true

            # Verify copy was successful
            if [ -f "$CLAUDE_CREDENTIALS" ] && jq empty "$CLAUDE_CREDENTIALS" 2>/dev/null; then
                echo -e "${GREEN}✓ Claude Code authentication copied successfully${NC}"
                CLAUDE_AUTH_OK=true
                return 0
            fi
        fi
    fi

    # Authentication not available
    echo -e "${YELLOW}⚠ Claude Code authentication not found${NC}"
    return 1
}

# ============================================================================
# Function: Initialize Codex CLI Authentication
# ============================================================================

init_codex_auth() {
    echo -e "${BLUE}[Codex CLI] Checking authentication...${NC}"

    # Check if already authenticated
    if [ -f "$CODEX_CONFIG" ]; then
        echo -e "${GREEN}✓ Codex CLI authentication already configured${NC}"
        CODEX_AUTH_OK=true
        return 0
    fi

    # Try to copy from host
    if [ -n "$HOST_CODEX_DIR" ] && [ -d "$HOST_CODEX_DIR" ]; then
        if [ -f "$HOST_CODEX_DIR/config.toml" ]; then
            echo -e "${BLUE}→ Copying Codex authentication from host...${NC}"

            # Copy all files from host .codex directory
            cp -r "$HOST_CODEX_DIR"/* "$CONTAINER_CODEX_DIR/" 2>/dev/null || true

            # Ensure proper permissions
            chmod 700 "$CONTAINER_CODEX_DIR"
            chmod 600 "$CONTAINER_CODEX_DIR/config.toml" 2>/dev/null || true

            # Verify copy was successful
            if [ -f "$CODEX_CONFIG" ]; then
                echo -e "${GREEN}✓ Codex CLI authentication copied successfully${NC}"
                CODEX_AUTH_OK=true
                return 0
            fi
        fi
    fi

    # Authentication not available
    echo -e "${YELLOW}⚠ Codex CLI authentication not found${NC}"
    return 1
}

# ============================================================================
# Main: Initialize both agents
# ============================================================================

# Initialize Claude Code
init_claude_auth || true
echo ""

# Initialize Codex CLI
init_codex_auth || true
echo ""

# ============================================================================
# Display summary and instructions
# ============================================================================

echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  Authentication Summary${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
echo ""

if [ "$CLAUDE_AUTH_OK" = true ] && [ "$CODEX_AUTH_OK" = true ]; then
    # Both authenticated
    echo -e "${GREEN}✓ Claude Code: Authenticated${NC}"
    echo -e "${GREEN}✓ Codex CLI:   Authenticated${NC}"
    echo ""
    echo -e "${GREEN}You can use both agents without logging in!${NC}"
    echo ""
    exit 0

elif [ "$CLAUDE_AUTH_OK" = true ]; then
    # Only Claude authenticated
    echo -e "${GREEN}✓ Claude Code: Authenticated${NC}"
    echo -e "${YELLOW}⚠ Codex CLI:   Not authenticated${NC}"
    echo ""
    echo -e "${BLUE}To use Codex CLI, run:${NC} ${GREEN}codex login${NC}"
    echo -e "${BLUE}Then authenticate with your ChatGPT account${NC}"
    echo ""
    exit 1

elif [ "$CODEX_AUTH_OK" = true ]; then
    # Only Codex authenticated
    echo -e "${YELLOW}⚠ Claude Code: Not authenticated${NC}"
    echo -e "${GREEN}✓ Codex CLI:   Authenticated${NC}"
    echo ""
    echo -e "${BLUE}To use Claude Code, run:${NC} ${GREEN}/login${NC} ${BLUE}(inside Claude)${NC}"
    echo -e "${BLUE}Then authenticate with your Claude.ai account${NC}"
    echo ""
    exit 1

else
    # Neither authenticated
    echo -e "${YELLOW}⚠ Claude Code: Not authenticated${NC}"
    echo -e "${YELLOW}⚠ Codex CLI:   Not authenticated${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Authentication Required${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}For Claude Code:${NC}"
    echo -e "  1. Select Claude Code in the agent menu"
    echo -e "  2. Run: ${GREEN}/login${NC}"
    echo -e "  3. Authenticate with Claude.ai or Console account"
    echo ""
    echo -e "${BLUE}For Codex CLI:${NC}"
    echo -e "  1. Select Codex CLI in the agent menu"
    echo -e "  2. Run: ${GREEN}codex login${NC}"
    echo -e "  3. Authenticate with ChatGPT Plus/Pro/Team account"
    echo ""
    echo -e "${BLUE}ℹ Authentication persists in Docker volumes:${NC}"
    echo -e "  • Claude: ${GREEN}claude-config${NC}"
    echo -e "  • Codex:  ${GREEN}codex-config${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    exit 1
fi
