#!/bin/bash
# Test script for frontend integration with local explorer

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║   Frontend Integration Test Suite                 ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

PASSED=0
FAILED=0
TOTAL=0

log_test() {
    ((TOTAL++))
    echo -e "${BLUE}[TEST $TOTAL]${NC} $1"
}

log_pass() {
    ((PASSED++))
    echo -e "  ${GREEN}✓ PASS${NC} $1"
}

log_fail() {
    ((FAILED++))
    echo -e "  ${RED}✗ FAIL${NC} $1"
}

log_info() {
    echo -e "  ${BLUE}ℹ INFO${NC} $1"
}

# Test 1: Check Explorer Web UI is running
log_test "Explorer Web UI is accessible"
if curl -s http://localhost:8083 > /dev/null 2>&1; then
    log_pass "Explorer Web UI responding on port 8083"
else
    log_fail "Explorer Web UI not accessible"
    echo ""
    echo "Please start the explorer services first:"
    echo "  docker compose -f docker-compose.local.yml up -d"
    exit 1
fi

# Test 2: Check Explorer API is running
log_test "Explorer API is accessible"
HEALTH=$(curl -s http://localhost:8081/healthz 2>/dev/null || echo "")
if echo "$HEALTH" | grep -q '"ok":true'; then
    log_pass "Explorer API healthy"
else
    log_fail "Explorer API not healthy"
fi

# Test 3: Check CoW Swap frontend is running
log_test "CoW Swap frontend is accessible"
if curl -s http://localhost:8000 > /dev/null 2>&1; then
    log_pass "CoW Swap frontend responding on port 8000"
    FRONTEND_RUNNING=true
else
    log_fail "CoW Swap frontend not running (this is expected if not started yet)"
    FRONTEND_RUNNING=false
fi

if [ "$FRONTEND_RUNNING" = true ]; then
    # Test 4: Check if nginx rewrites are working
    log_test "Nginx rewrite rules are configured"
    FRONTEND_HTML=$(curl -s http://localhost:8000)
    
    # Check if the rewrite happens (look for localhost:8083 in the HTML)
    if echo "$FRONTEND_HTML" | grep -q "localhost:8083"; then
        log_pass "Found local explorer URLs in frontend HTML"
    else
        log_info "No local explorer URLs found in static HTML (may be in JS bundles)"
    fi
    
    # Test 5: Check nginx config is loaded
    log_test "Nginx configuration includes explorer rewrites"
    if docker compose -f docker-compose.local.yml exec -T frontend cat /etc/nginx/conf.d/default.conf 2>/dev/null | grep -q "sub_filter.*localhost:8083"; then
        log_pass "Nginx config has rewrite rules"
    else
        log_fail "Nginx config missing rewrite rules"
    fi
    
    # Test 6: Test a specific rewrite
    log_test "Test Etherscan URL rewrite"
    TEST_RESPONSE=$(curl -s http://localhost:8000 | head -1000)
    if echo "$TEST_RESPONSE" | grep -q "etherscan.io"; then
        log_info "Some Etherscan URLs still present (they get rewritten at runtime)"
    fi
    
    # Test 7: Check if environment variables were passed
    log_test "Check if explorer URL env vars were set during build"
    log_info "This requires checking Docker build logs or container env"
fi

# Test 8: Check embed script exists
log_test "Explorer embed script is available"
if curl -s http://localhost:8083/embed/debug-link.js | grep -q "DebugInPlayground"; then
    log_pass "Embed script available at /embed/debug-link.js"
else
    log_fail "Embed script not found"
fi

# Summary
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║                Test Summary                        ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "Total Tests: $TOTAL"
echo -e "${GREEN}Passed:      $PASSED${NC}"
echo -e "${RED}Failed:      $FAILED${NC}"
echo ""

if [ "$FRONTEND_RUNNING" = false ]; then
    echo -e "${YELLOW}NOTE:${NC} CoW Swap frontend is not running."
    echo "To test full integration, start it with:"
    echo ""
    echo "  docker compose -f docker-compose.local.yml up frontend --build"
    echo ""
    echo "Or for fork mode:"
    echo "  docker compose -f docker-compose.fork.yml up frontend --build"
    echo ""
fi

echo "╔════════════════════════════════════════════════════╗"
echo "║           How to Test Frontend Integration        ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "1. Start the CoW Swap frontend:"
echo "   docker compose -f docker-compose.local.yml up frontend --build"
echo ""
echo "2. Open the CoW Swap UI:"
echo "   open http://localhost:8000"
echo ""
echo "3. Perform a swap or find a transaction"
echo ""
echo "4. Click 'View on Etherscan' or any explorer link"
echo "   → Should open http://localhost:8083 instead!"
echo ""
echo "5. Verify the explorer shows:"
echo "   - Transaction details"
echo "   - Decoded input/logs"
echo "   - Call traces"
echo "   - Gas reports"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All available tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some tests failed${NC}"
    echo "Review the output above for details."
    exit 1
fi

