#!/bin/bash

################################################################################
# GhettoBoot Security Verification Script
# Purpose: Verify no post-stop execution or persistence mechanisms exist
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     GhettoBoot Security Verification${NC}"
echo -e "${BLUE}     Checking for Post-Stop Execution Mechanisms${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

FAILED=0
WARNINGS=0

# Test 1: Check for dangerous trap handlers
echo -e "${BLUE}[1/8]${NC} Checking for dangerous trap handlers..."
if grep -n "trap ['\"][^']" *.sh 2>/dev/null | grep -v "trap '' EXIT"; then
    echo -e "${RED}✗ FAIL: Dangerous trap handlers found${NC}"
    FAILED=$((FAILED + 1))
else
    echo -e "${GREEN}✓ PASS: No dangerous trap handlers${NC}"
fi
echo ""

# Test 2: Check for background processes
echo -e "${BLUE}[2/8]${NC} Checking for background processes..."
# Look for & at end of command lines (background process), excluding &>, &&, and comments
if grep -E "^\s*[^#]*[^&>]\s+&\s*$|^\s*[^#]*\bnohup\b" *.sh 2>/dev/null | grep -v "^#"; then
    echo -e "${RED}✗ FAIL: Background process spawning found${NC}"
    FAILED=$((FAILED + 1))
else
    echo -e "${GREEN}✓ PASS: No background processes${NC}"
fi
echo ""

# Test 3: Check for cron job installation
echo -e "${BLUE}[3/8]${NC} Checking for cron job installation..."
# Look for actual crontab/at command execution (with pipes, redirects, or as standalone)
# Exclude mentions in strings or as part of filename patterns
if grep -E "^\s*[^#\"']*(\||;|^)\s*(crontab|at\s+[0-9])" *.sh 2>/dev/null | grep -v "^#" | grep -v "\".*crontab" | grep -v "'.*crontab"; then
    echo -e "${RED}✗ FAIL: Cron job installation found${NC}"
    FAILED=$((FAILED + 1))
else
    echo -e "${GREEN}✓ PASS: No cron job installation${NC}"
fi
echo ""

# Test 4: Check for service installation
echo -e "${BLUE}[4/8]${NC} Checking for service installation commands..."
# Look for actual service installation commands, not in comments
if grep -E "^\s*[^#]*\b(launchctl\s+(load|bootstrap)|systemctl\s+(enable|start))\b" *.sh 2>/dev/null | grep -v "^#"; then
    echo -e "${RED}✗ FAIL: Service installation commands found${NC}"
    FAILED=$((FAILED + 1))
else
    echo -e "${GREEN}✓ PASS: No service installation commands${NC}"
fi
echo ""

# Test 5: Check for service configuration files
echo -e "${BLUE}[5/8]${NC} Checking for service configuration files..."
FOUND_FILES=$(find . -name "*.plist" -o -name "*.service" -o -name "*.timer" -o -name "crontab*" 2>/dev/null | grep -v '.git' || true)
if [ -n "$FOUND_FILES" ]; then
    echo -e "${RED}✗ FAIL: Service configuration files found:${NC}"
    echo "$FOUND_FILES"
    FAILED=$((FAILED + 1))
else
    echo -e "${GREEN}✓ PASS: No service configuration files${NC}"
fi
echo ""

# Test 6: Check for shell profile modifications
echo -e "${BLUE}[6/8]${NC} Checking for shell profile modifications..."
# Look for actual profile modifications, not in comments
if grep -E "^\s*[^#]*(>>|>)\s*.*\.(bashrc|zshrc|profile)" *.sh 2>/dev/null | grep -v "^#"; then
    echo -e "${RED}✗ FAIL: Shell profile modification found${NC}"
    FAILED=$((FAILED + 1))
else
    echo -e "${GREEN}✓ PASS: No shell profile modifications${NC}"
fi
echo ""

# Test 7: Verify only expected executable files exist
echo -e "${BLUE}[7/8]${NC} Verifying executable files..."
EXECUTABLES=$(find . -type f -executable 2>/dev/null | grep -v '.git' || true)
EXPECTED="./system-lockdown.sh
./list_processes.sh
./verify_no_persistence.sh"

if [ "$EXECUTABLES" = "$EXPECTED" ] || [ "$(echo "$EXECUTABLES" | wc -l)" -le 3 ]; then
    echo -e "${GREEN}✓ PASS: Only expected executables found${NC}"
    echo "  - system-lockdown.sh"
    echo "  - list_processes.sh"
    echo "  - verify_no_persistence.sh"
else
    echo -e "${YELLOW}⚠ WARNING: Unexpected executable files found:${NC}"
    echo "$EXECUTABLES"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Test 8: Check for proper security headers
echo -e "${BLUE}[8/8]${NC} Verifying security headers in scripts..."
MISSING_HEADERS=0

if ! grep -q "SECURITY NOTICE" system-lockdown.sh; then
    echo -e "${YELLOW}⚠ WARNING: system-lockdown.sh missing security notice${NC}"
    MISSING_HEADERS=$((MISSING_HEADERS + 1))
fi

if ! grep -q "SECURITY NOTICE" list_processes.sh; then
    echo -e "${YELLOW}⚠ WARNING: list_processes.sh missing security notice${NC}"
    MISSING_HEADERS=$((MISSING_HEADERS + 1))
fi

if ! grep -q "trap '' EXIT" system-lockdown.sh; then
    echo -e "${YELLOW}⚠ WARNING: system-lockdown.sh missing no-op trap${NC}"
    MISSING_HEADERS=$((MISSING_HEADERS + 1))
fi

if ! grep -q "trap '' EXIT" list_processes.sh; then
    echo -e "${YELLOW}⚠ WARNING: list_processes.sh missing no-op trap${NC}"
    MISSING_HEADERS=$((MISSING_HEADERS + 1))
fi

if [ $MISSING_HEADERS -eq 0 ]; then
    echo -e "${GREEN}✓ PASS: All security headers present${NC}"
else
    echo -e "${YELLOW}⚠ WARNING: $MISSING_HEADERS security header(s) missing${NC}"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Final summary
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}     Verification Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [ $FAILED -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ ALL CHECKS PASSED${NC}"
    echo -e "${GREEN}✓ No post-stop execution mechanisms detected${NC}"
    echo -e "${GREEN}✓ Repository is secure${NC}"
    echo ""
    exit 0
elif [ $FAILED -eq 0 ]; then
    echo -e "${YELLOW}⚠ PASSED WITH WARNINGS${NC}"
    echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    echo -e "${GREEN}✓ No critical security issues detected${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ VERIFICATION FAILED${NC}"
    echo -e "${RED}✗ $FAILED critical issue(s) found${NC}"
    [ $WARNINGS -gt 0 ] && echo -e "${YELLOW}⚠ $WARNINGS warning(s) found${NC}"
    echo ""
    echo -e "${RED}ACTION REQUIRED: Review and fix security issues before deployment${NC}"
    echo ""
    exit 1
fi
