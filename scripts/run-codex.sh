#!/bin/bash
# run-codex.sh - Direct launcher for Codex CLI
#
# This script bypasses the interactive menu and launches Codex CLI directly.
# Useful for:
# - Users who prefer Codex
# - Running multiple agents in parallel (different terminals)
# - Scripted/automated workflows
#
# Usage: ./scripts/run-codex.sh [PROJECT_NAME]

# Simply export the agent selection and call the main run-agent script
export SELECTED_AGENT="codex"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Call run-agent.sh with the codex agent preselected
exec "$SCRIPT_DIR/run-agent.sh" "$@"
