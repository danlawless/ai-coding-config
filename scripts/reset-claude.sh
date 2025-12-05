#!/bin/bash
# reset-claude.sh - Reset Claude Code to fix authentication and connection issues
#
# Works on: macOS, Linux, WSL
#
# Use this script when:
#   - Claude Code shows "Invalid bearer token" errors after login
#   - Authentication succeeds but immediately fails
#   - Claude processes are hung or stuck
#   - IDE connection issues
#
# What this script does:
#   1. Kills any running Claude Code processes
#   2. Removes IDE lock files that can cause stuck state
#   3. Clears stored credentials (macOS Keychain / Linux secret storage)
#   4. Optionally backs up and removes ~/.claude.json for a complete reset
#
# Usage:
#   ./reset-claude.sh              # Standard reset (keeps config)
#   ./reset-claude.sh --full       # Full reset (backs up and removes config)
#   ./reset-claude.sh --processes  # Only kill processes (quick cleanup)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin*)  echo "macos" ;;
        Linux*)   
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        MINGW*|CYGWIN*|MSYS*) echo "windows" ;;
        *)        echo "unknown" ;;
    esac
}

OS=$(detect_os)

echo -e "${YELLOW}🔧 Claude Code Reset Script${NC}"
echo "================================"
echo -e "Detected OS: ${BLUE}$OS${NC}"
echo ""

# Parse arguments
FULL_RESET=false
PROCESSES_ONLY=false

for arg in "$@"; do
    case $arg in
        --full) FULL_RESET=true ;;
        --processes) PROCESSES_ONLY=true ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --processes  Only kill hung processes (quick cleanup)"
            echo "  --full       Full reset including config backup"
            echo "  --help       Show this help message"
            exit 0
            ;;
    esac
done

# Step 1: Kill Claude processes
echo -e "${YELLOW}[1/4]${NC} Killing Claude Code processes..."
killed=0

# Kill main claude processes
if pkill -f "claude" 2>/dev/null; then
    ((killed++)) || true
fi

# Also kill any node processes that might be Claude-related MCP servers
if pkill -f "mcp-server" 2>/dev/null; then
    ((killed++)) || true
fi

if [ $killed -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Killed Claude and related processes"
else
    echo -e "  ${GREEN}✓${NC} No Claude processes running"
fi

# If only killing processes, stop here
if [ "$PROCESSES_ONLY" = true ]; then
    echo ""
    echo -e "${GREEN}✅ Process cleanup complete!${NC}"
    exit 0
fi

# Step 2: Remove lock files
echo -e "${YELLOW}[2/4]${NC} Removing IDE lock files..."
if [ -d "$HOME/.claude/ide" ]; then
    lock_count=$(find "$HOME/.claude/ide" -name "*.lock" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$lock_count" -gt 0 ]; then
        rm -f "$HOME/.claude/ide/"*.lock
        echo -e "  ${GREEN}✓${NC} Removed $lock_count lock file(s)"
    else
        echo -e "  ${GREEN}✓${NC} No lock files found"
    fi
else
    echo -e "  ${GREEN}✓${NC} No IDE directory found"
fi

# Step 3: Clear stored credentials (OS-specific)
echo -e "${YELLOW}[3/4]${NC} Clearing stored credentials..."
case $OS in
    macos)
        if security delete-generic-password -s "Claude Code-credentials" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Removed macOS Keychain entry"
        else
            echo -e "  ${GREEN}✓${NC} No Keychain entry found"
        fi
        ;;
    linux|wsl)
        # Try secret-tool (GNOME Keyring / libsecret)
        if command -v secret-tool &>/dev/null; then
            if secret-tool clear service "Claude Code-credentials" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Removed Linux secret storage entry"
            else
                echo -e "  ${GREEN}✓${NC} No secret storage entry found"
            fi
        else
            echo -e "  ${YELLOW}⚠${NC} secret-tool not found - credentials may be stored elsewhere"
            echo -e "    Install libsecret-tools for credential management"
        fi
        ;;
    windows)
        echo -e "  ${YELLOW}⚠${NC} Windows credential clearing not implemented"
        echo -e "    Manually clear credentials in Windows Credential Manager"
        ;;
    *)
        echo -e "  ${YELLOW}⚠${NC} Unknown OS - skipping credential clearing"
        ;;
esac

# Step 4: Handle config file (optional full reset)
echo -e "${YELLOW}[4/4]${NC} Config file handling..."
if [ "$FULL_RESET" = true ]; then
    if [ -f "$HOME/.claude.json" ]; then
        backup_name="$HOME/.claude.json.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$HOME/.claude.json" "$backup_name"
        echo -e "  ${GREEN}✓${NC} Backed up config to: $backup_name"
        echo -e "  ${GREEN}✓${NC} Removed ~/.claude.json (will regenerate on next launch)"
    else
        echo -e "  ${GREEN}✓${NC} No config file found"
    fi
else
    echo -e "  ${GREEN}✓${NC} Keeping config file (use --full to reset)"
fi

# Optional: Clear debug logs if they're huge
debug_dir="$HOME/.claude/debug"
if [ -d "$debug_dir" ]; then
    debug_size=$(du -sm "$debug_dir" 2>/dev/null | cut -f1)
    if [ "$debug_size" -gt 50 ]; then
        echo ""
        echo -e "${YELLOW}Note:${NC} Debug logs are ${debug_size}MB. Run to clear:"
        echo "  rm -rf ~/.claude/debug/*"
    fi
fi

echo ""
echo -e "${GREEN}✅ Reset complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Run: claude"
echo "  2. Run: /login"
echo "  3. Send a test message"
echo ""
echo "Quick reference:"
echo "  ./reset-claude.sh --processes  # Just kill hung processes"
echo "  ./reset-claude.sh --full       # Full reset with config backup"
echo ""
if [ "$OS" = "macos" ] || [ "$OS" = "linux" ] || [ "$OS" = "wsl" ]; then
    echo "If issues persist, try restarting your computer."
fi
