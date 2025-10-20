#!/bin/bash
# Master test runner - orchestrates all testing steps

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo ""
echo "╔════════════════════════════════════════╗"
echo "║   Explorer Testing Suite - Full Run   ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Step 1: Code Validation
echo -e "${BOLD}Step 1/3: Code Validation${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ./validate_code.sh; then
    echo ""
    echo -e "${GREEN}✓ Code validation passed${NC}"
else
    echo ""
    echo -e "${RED}✗ Code validation failed${NC}"
    echo ""
    echo "Please fix the errors above before proceeding."
    exit 1
fi

echo ""
read -p "Press Enter to continue to preflight checks..."
clear

# Step 2: Preflight Checks
echo ""
echo "╔════════════════════════════════════════╗"
echo "║   Explorer Testing Suite - Full Run   ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo -e "${BOLD}Step 2/3: Preflight Checks${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ./preflight_check.sh; then
    echo ""
    echo -e "${GREEN}✓ Preflight checks passed${NC}"
else
    echo ""
    echo -e "${YELLOW}⚠ Preflight checks had warnings${NC}"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

echo ""
echo -e "${BOLD}${BLUE}Services Status Check${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if services are running
if curl -s http://localhost:8081/healthz > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Services are running${NC}"
    echo ""
    read -p "Press Enter to run automated tests..."
else
    echo -e "${YELLOW}⚠ Services don't appear to be running${NC}"
    echo ""
    echo "You need to start the Docker services first:"
    echo ""
    echo -e "${BLUE}  docker compose -f docker-compose.fork.yml up --build${NC}"
    echo ""
    echo "Or for non-interactive mode:"
    echo ""
    echo -e "${BLUE}  docker compose -f docker-compose.non-interactive.yml up --build${NC}"
    echo ""
    read -p "Do you want to wait for services to start? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Waiting for services to be ready..."
        echo "(Make sure you've started Docker compose in another terminal)"
        echo ""
        
        MAX_WAIT=60
        WAITED=0
        while [ $WAITED -lt $MAX_WAIT ]; do
            if curl -s http://localhost:8081/healthz > /dev/null 2>&1; then
                echo ""
                echo -e "${GREEN}✓ Services are now running${NC}"
                break
            fi
            echo -n "."
            sleep 2
            WAITED=$((WAITED + 2))
        done
        
        if [ $WAITED -ge $MAX_WAIT ]; then
            echo ""
            echo -e "${RED}✗ Timeout waiting for services${NC}"
            echo ""
            echo "Please start Docker services manually and run this script again."
            exit 1
        fi
    else
        echo ""
        echo "Please start services first, then run:"
        echo -e "${BLUE}  ./test_explorer.sh${NC}"
        exit 0
    fi
fi

clear

# Step 3: Automated Tests
echo ""
echo "╔════════════════════════════════════════╗"
echo "║   Explorer Testing Suite - Full Run   ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo -e "${BOLD}Step 3/3: Automated Tests${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if ./test_explorer.sh; then
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║          All Tests Passed! ✓           ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo -e "${GREEN}${BOLD}🎉 Congratulations!${NC} All automated tests passed."
    echo ""
    echo -e "${BOLD}Next Steps:${NC}"
    echo ""
    echo "1. Manual testing:"
    echo "   - Open http://localhost:8083 in your browser"
    echo "   - Try searching for blocks, transactions, addresses"
    echo "   - Navigate through the UI"
    echo ""
    echo "2. Check the services:"
    echo "   - Explorer Web: http://localhost:8083"
    echo "   - Explorer API: http://localhost:8081"
    echo "   - Sourcify: http://localhost:5555"
    echo ""
    echo "3. Review documentation:"
    echo "   - Quick start: cat TESTING_QUICKSTART.md"
    echo "   - Full guide: cat TESTING_EXPLORER.md"
    echo ""
    exit 0
else
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║         Some Tests Failed ✗            ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo -e "${RED}${BOLD}Some tests failed.${NC} Please review the output above."
    echo ""
    echo -e "${BOLD}Troubleshooting:${NC}"
    echo ""
    echo "1. Check service logs:"
    echo "   docker compose -f docker-compose.fork.yml logs explorer-api"
    echo "   docker compose -f docker-compose.fork.yml logs explorer-web"
    echo ""
    echo "2. Review the testing guide:"
    echo "   cat TESTING_EXPLORER.md"
    echo ""
    echo "3. Check for common issues:"
    echo "   cat TESTING_QUICKSTART.md"
    echo ""
    exit 1
fi

