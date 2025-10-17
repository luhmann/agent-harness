#!/bin/bash
# install.sh - Install AI Agent Harness commands globally
#
# This script creates symlinks in ~/.local/bin to make agent commands
# available globally from any directory.
#
# Usage: ./scripts/install.sh [--uninstall]

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"

# Commands to install
declare -A COMMANDS=(
    ["spawn-agent"]="$SCRIPT_DIR/spawn-agent.sh"
    ["list-agents"]="$SCRIPT_DIR/list-agents.sh"
    ["attach-agent"]="$SCRIPT_DIR/attach-agent.sh"
    ["kill-agent"]="$SCRIPT_DIR/kill-agent.sh"
    ["logs-agent"]="$SCRIPT_DIR/logs-agent.sh"
)

# ============================================================================
# Functions
# ============================================================================

show_help() {
    echo -e "${CYAN}AI Agent Harness - Installation Script${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --uninstall    Remove installed commands"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "This script installs agent-harness commands globally by creating"
    echo "symlinks in ~/.local/bin, allowing you to run commands like:"
    echo "  spawn-agent, list-agents, attach-agent, kill-agent, logs-agent"
    echo "from any directory."
}

check_path() {
    if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
        return 0
    else
        return 1
    fi
}

add_to_path() {
    local shell_rc=""

    # Detect shell
    if [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    else
        # Try to detect from SHELL environment variable
        case "$SHELL" in
            */bash)
                shell_rc="$HOME/.bashrc"
                ;;
            */zsh)
                shell_rc="$HOME/.zshrc"
                ;;
            *)
                echo -e "${YELLOW}⚠ Could not detect shell. Please add this to your shell RC file:${NC}"
                echo -e "${BLUE}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
                return 1
                ;;
        esac
    fi

    echo -e "${BLUE}→ Adding ~/.local/bin to PATH in $shell_rc${NC}"

    # Check if already in RC file
    if grep -q "\.local/bin" "$shell_rc" 2>/dev/null; then
        echo -e "${YELLOW}ℹ PATH configuration already exists in $shell_rc${NC}"
    else
        echo "" >> "$shell_rc"
        echo "# Added by AI Agent Harness installer" >> "$shell_rc"
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
        echo -e "${GREEN}✓ Added to $shell_rc${NC}"
    fi

    echo -e "${YELLOW}ℹ Run this to activate in current shell:${NC}"
    echo -e "${BLUE}  export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
}

install_commands() {
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  AI Agent Harness - Global Installation${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""

    # Create ~/.local/bin if it doesn't exist
    if [ ! -d "$BIN_DIR" ]; then
        echo -e "${BLUE}→ Creating $BIN_DIR${NC}"
        mkdir -p "$BIN_DIR"
        echo -e "${GREEN}✓ Directory created${NC}"
    else
        echo -e "${GREEN}✓ $BIN_DIR exists${NC}"
    fi

    echo ""
    echo -e "${BLUE}→ Installing commands...${NC}"

    # Create symlinks
    local installed=0
    local skipped=0

    for cmd in "${!COMMANDS[@]}"; do
        local target="${COMMANDS[$cmd]}"
        local link="$BIN_DIR/$cmd"

        if [ -L "$link" ]; then
            # Symlink exists, check if it points to our script
            local current_target="$(readlink "$link")"
            if [ "$current_target" = "$target" ]; then
                echo -e "${YELLOW}  ⊙ $cmd already installed${NC}"
                ((skipped++))
            else
                echo -e "${YELLOW}  → $cmd exists but points elsewhere, updating...${NC}"
                rm "$link"
                ln -s "$target" "$link"
                echo -e "${GREEN}  ✓ $cmd updated${NC}"
                ((installed++))
            fi
        elif [ -e "$link" ]; then
            echo -e "${RED}  ✗ $cmd exists as a regular file (not symlink)${NC}"
            echo -e "${RED}    Please remove $link manually${NC}"
        else
            ln -s "$target" "$link"
            echo -e "${GREEN}  ✓ $cmd installed${NC}"
            ((installed++))
        fi
    done

    echo ""
    echo -e "${GREEN}✓ Installation summary:${NC}"
    echo -e "${GREEN}  Installed: $installed${NC}"
    if [ $skipped -gt 0 ]; then
        echo -e "${YELLOW}  Already installed: $skipped${NC}"
    fi

    # Check PATH
    echo ""
    if check_path; then
        echo -e "${GREEN}✓ ~/.local/bin is already in your PATH${NC}"
    else
        echo -e "${YELLOW}⚠ ~/.local/bin is not in your PATH${NC}"
        echo ""
        add_to_path
    fi

    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✓ Installation complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}Available commands:${NC}"
    echo -e "${GREEN}  spawn-agent${NC}    - Spawn parallel agents on feature branches"
    echo -e "${GREEN}  list-agents${NC}    - List all running agents"
    echo -e "${GREEN}  attach-agent${NC}   - Attach to an agent's terminal"
    echo -e "${GREEN}  kill-agent${NC}     - Stop and cleanup agents"
    echo -e "${GREEN}  logs-agent${NC}     - View agent container logs"
    echo ""
    echo -e "${BLUE}Quick start:${NC}"
    echo -e "${YELLOW}  cd ~/my-project${NC}"
    echo -e "${YELLOW}  spawn-agent auth feature/auth${NC}"
    echo ""
}

uninstall_commands() {
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  AI Agent Harness - Uninstall${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════${NC}"
    echo ""

    if [ ! -d "$BIN_DIR" ]; then
        echo -e "${YELLOW}ℹ ~/.local/bin doesn't exist, nothing to uninstall${NC}"
        return 0
    fi

    echo -e "${BLUE}→ Removing commands...${NC}"

    local removed=0
    local not_found=0

    for cmd in "${!COMMANDS[@]}"; do
        local link="$BIN_DIR/$cmd"

        if [ -L "$link" ]; then
            rm "$link"
            echo -e "${GREEN}  ✓ $cmd removed${NC}"
            ((removed++))
        elif [ -e "$link" ]; then
            echo -e "${YELLOW}  ⚠ $cmd exists but is not a symlink (skipped)${NC}"
        else
            ((not_found++))
        fi
    done

    echo ""
    if [ $removed -gt 0 ]; then
        echo -e "${GREEN}✓ Removed $removed command(s)${NC}"
    fi
    if [ $not_found -gt 0 ]; then
        echo -e "${YELLOW}ℹ $not_found command(s) were not installed${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Note: PATH configuration in your shell RC file was not removed.${NC}"
    echo -e "${YELLOW}You can manually remove this line if desired:${NC}"
    echo -e "${BLUE}  export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

# Parse arguments
case "${1:-}" in
    --uninstall)
        uninstall_commands
        ;;
    --help|-h)
        show_help
        ;;
    "")
        install_commands
        ;;
    *)
        echo -e "${RED}✗ Unknown option: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac
