#!/usr/bin/env bash
set -e

echo "=== Testing GitHub Actions Workflow Locally ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if act is installed
if ! command -v act &> /dev/null; then
    echo "act is not installed. Installing via Homebrew..."
    brew install act
fi

echo -e "${YELLOW}Running individual CI jobs locally...${NC}"
echo ""

# Run specific jobs
echo -e "${GREEN}1. Running tests job...${NC}"
act -j test --matrix elixir:1.18 --matrix otp:27

echo ""
echo -e "${GREEN}2. Running coverage job...${NC}"
act -j coverage

echo ""
echo -e "${GREEN}3. Running code quality job...${NC}"
act -j code_quality

echo ""
echo -e "${GREEN}4. Running security job...${NC}"
act -j security

echo ""
echo -e "${GREEN}5. Running docs job...${NC}"
act -j docs

echo ""
echo -e "${GREEN}6. Running demo app job...${NC}"
act -j demo

echo ""
echo -e "${GREEN}=== All CI jobs completed ===${NC}"
