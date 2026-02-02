#!/usr/bin/env bash
#
# Run all CI checks locally without GitHub Actions
# This script mimics the CI pipeline
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0

# Function to run a check
run_check() {
    local name="$1"
    local command="$2"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Running: ${name}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if eval "$command"; then
        echo -e "${GREEN}✓ ${name} passed${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ ${name} failed${NC}"
        ((FAILED++))
        return 1
    fi
}

# Print header
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║                                                        ║"
echo "║          ExFlowGraph CI Checks - Local Run            ║"
echo "║                                                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Change to project root
cd "$(dirname "$0")/.."

echo -e "${YELLOW}Project: ExFlowGraph${NC}"
echo -e "${YELLOW}Location: $(pwd)${NC}"
echo ""

# Install dependencies if needed
if [ ! -d "deps" ]; then
    echo -e "${YELLOW}Installing dependencies...${NC}"
    mix deps.get
fi

# Main Module Checks
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           MAIN MODULE CHECKS                          ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"

# 1. Compilation with warnings as errors
run_check "Compile (warnings as errors)" \
    "mix compile --warnings-as-errors --force"

# 2. Format check
run_check "Format check" \
    "mix format --check-formatted"

# 3. Tests
run_check "Unit tests" \
    "mix test"

# 4. Coverage
run_check "Test coverage (>80%)" \
    "mix coveralls && mix coveralls | grep -q 'TOTAL.*[89][0-9]\.[0-9]%\|TOTAL.*100\.0%'"

# 5. Credo
run_check "Credo (code quality)" \
    "mix credo --strict"

# 6. Dialyzer (skip if PLT doesn't exist)
if [ -f "priv/plts/dialyzer.plt" ]; then
    run_check "Dialyzer (type checking)" \
        "mix dialyzer"
else
    echo -e "${YELLOW}⊘ Dialyzer skipped (PLT not built). Run: mix dialyzer --plt${NC}"
fi

# 7. Sobelow
run_check "Sobelow (security)" \
    "mix sobelow --config"

# 8. Dependency audit
run_check "Dependency audit" \
    "mix deps.audit"

# 9. Unused dependencies
run_check "Unused dependencies check" \
    "mix deps.unlock --check-unused"

# 10. Documentation
run_check "Documentation build" \
    "mix docs 2>&1 | tee /tmp/docs_output.txt && ! grep -i warning /tmp/docs_output.txt"

# Demo App Checks
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           DEMO APP CHECKS                             ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"

cd demo

# Install demo dependencies if needed
if [ ! -d "deps" ]; then
    echo -e "${YELLOW}Installing demo dependencies...${NC}"
    mix deps.get
fi

# 11. Demo compilation
run_check "Demo compile (warnings as errors)" \
    "mix compile --warnings-as-errors --force"

# 12. Demo format check
run_check "Demo format check" \
    "mix format --check-formatted"

# 13. Demo Credo
run_check "Demo Credo" \
    "mix credo --strict"

# 14. Demo Sobelow
run_check "Demo Sobelow" \
    "mix sobelow --config"

# 15. Demo dependency audit
run_check "Demo dependency audit" \
    "mix deps.audit"

# 16. Demo unused dependencies
run_check "Demo unused dependencies" \
    "mix deps.unlock --check-unused"

cd ..

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}                 SUMMARY                   ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}Passed: ${PASSED}${NC}"
echo -e "${RED}Failed: ${FAILED}${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                        ║${NC}"
    echo -e "${GREEN}║     ✓ All checks passed!              ║${NC}"
    echo -e "${GREEN}║                                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                        ║${NC}"
    echo -e "${RED}║     ✗ Some checks failed              ║${NC}"
    echo -e "${RED}║                                        ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════╝${NC}"
    exit 1
fi
