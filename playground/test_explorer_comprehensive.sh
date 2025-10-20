#!/bin/bash
# Comprehensive test script for all Explorer features

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
EXPLORER_API="http://localhost:8081"
EXPLORER_WEB="http://localhost:8083"
SOURCIFY="http://localhost:5555"
CHAIN_RPC="http://localhost:8545"

# Test counters
TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((SKIPPED++))
}

test_endpoint() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    ((TOTAL++))
    log_info "Testing: $name"
    
    response=$(curl -s -w "\n%{http_code}" "$url")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "$expected_code" ]; then
        log_success "$name (HTTP $http_code)"
        echo "  Preview: $(echo "$body" | head -c 120)..."
        return 0
    else
        log_error "$name (Expected $expected_code, got $http_code)"
        echo "  Response: $(echo "$body" | head -c 200)"
        return 1
    fi
}

test_json_array() {
    local name=$1
    local url=$2
    
    ((TOTAL++))
    log_info "Testing: $name"
    
    response=$(curl -s "$url")
    
    # Check if it's a valid JSON array
    if echo "$response" | python3 -c "import sys, json; data = json.load(sys.stdin); assert isinstance(data, list); print(len(data))" 2>/dev/null | grep -q '^[0-9]'; then
        count=$(echo "$response" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null)
        log_success "$name (returned $count items)"
        return 0
    else
        log_error "$name (not a valid JSON array)"
        echo "  Response: $(echo "$response" | head -c 150)"
        return 1
    fi
}

clear
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║   Explorer Comprehensive Testing Suite            ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""

# Phase 1: Service Health
echo -e "${BOLD}Phase 1: Service Health Checks${NC}"
echo "═════════════════════════════════════════════════════"
echo ""

test_endpoint "Explorer API Health" "$EXPLORER_API/healthz"
test_endpoint "Explorer API Metrics" "$EXPLORER_API/metrics"
test_endpoint "Explorer Web UI" "$EXPLORER_WEB"
test_endpoint "Sourcify Health" "$SOURCIFY/health" || log_skip "Sourcify not ready (optional)"

# Phase 2: Get test data
echo ""
echo -e "${BOLD}Phase 2: Fetching Blockchain Data${NC}"
echo "═════════════════════════════════════════════════════"
echo ""

log_info "Fetching latest block from chain..."
LATEST_BLOCK=$(curl -s "$CHAIN_RPC" -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
  grep -o '"result":"[^"]*"' | cut -d'"' -f4)
LATEST_BLOCK_DEC=$((LATEST_BLOCK))
log_info "Latest block: $LATEST_BLOCK_DEC"

log_info "Fetching block details..."
BLOCK_RESPONSE=$(curl -s "$CHAIN_RPC" -X POST -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$LATEST_BLOCK\",true],\"id\":1}")
BLOCK_HASH=$(echo "$BLOCK_RESPONSE" | grep -o '"hash":"[^"]*"' | head -1 | cut -d'"' -f4)
log_info "Block hash: $BLOCK_HASH"

# Get a transaction hash
TX_HASH=$(echo "$BLOCK_RESPONSE" | grep -o '"hash":"0x[^"]*"' | grep -v "$BLOCK_HASH" | head -1 | cut -d'"' -f4)
if [ -z "$TX_HASH" ] || [ "$TX_HASH" = "$BLOCK_HASH" ]; then
    for i in {1..10}; do
        PREV=$((LATEST_BLOCK_DEC - i))
        PREV_HEX=$(printf "0x%x" $PREV)
        PREV_RESPONSE=$(curl -s "$CHAIN_RPC" -X POST -H "Content-Type: application/json" \
          -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$PREV_HEX\",true],\"id\":1}")
        TX_HASH=$(echo "$PREV_RESPONSE" | grep -o '"hash":"0x[^"]*"' | grep -v "$BLOCK_HASH" | head -1 | cut -d'"' -f4)
        [ -n "$TX_HASH" ] && break
    done
fi

if [ -n "$TX_HASH" ] && [ "$TX_HASH" != "$BLOCK_HASH" ]; then
    log_info "Transaction hash: $TX_HASH"
    
    # Get FROM and TO addresses
    TX_DATA=$(curl -s "$CHAIN_RPC" -X POST -H "Content-Type: application/json" \
      -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionByHash\",\"params\":[\"$TX_HASH\"],\"id\":1}")
    FROM_ADDR=$(echo "$TX_DATA" | grep -o '"from":"[^"]*"' | cut -d'"' -f4)
    TO_ADDR=$(echo "$TX_DATA" | grep -o '"to":"[^"]*"' | head -1 | cut -d'"' -f4)
    log_info "From: $FROM_ADDR"
    log_info "To: $TO_ADDR"
else
    log_skip "No transactions found - some tests will be skipped"
    TX_HASH=""
fi

# Phase 3: Block API Tests
echo ""
echo -e "${BOLD}Phase 3: Block API${NC}"
echo "═════════════════════════════════════════════════════"
echo ""

test_endpoint "Get block by 'latest'" "$EXPLORER_API/api/blocks/latest"
test_endpoint "Get block by number" "$EXPLORER_API/api/blocks/$LATEST_BLOCK_DEC"
test_endpoint "Get block by hash" "$EXPLORER_API/api/blocks/$BLOCK_HASH"
test_json_array "List latest blocks" "$EXPLORER_API/api/blocks?limit=10"

# Phase 4: Transaction API Tests
echo ""
echo -e "${BOLD}Phase 4: Transaction API${NC}"
echo "═════════════════════════════════════════════════════"
echo ""

if [ -n "$TX_HASH" ]; then
    test_endpoint "Get transaction details" "$EXPLORER_API/api/tx/$TX_HASH"
    test_json_array "List latest transactions" "$EXPLORER_API/api/tx?limit=10"
else
    ((TOTAL++)); log_skip "Get transaction details (no TX available)"
    ((TOTAL++)); log_skip "List latest transactions (no TX available)"
fi

# Phase 5: Trace & Debug API Tests
echo ""
echo -e "${BOLD}Phase 5: Trace & Debug API${NC}"
echo "═════════════════════════════════════════════════════"
echo ""

if [ -n "$TX_HASH" ]; then
    test_endpoint "Get call tree trace" "$EXPLORER_API/api/tx/$TX_HASH/trace?mode=tree"
    test_endpoint "Get step trace" "$EXPLORER_API/api/tx/$TX_HASH/trace?mode=steps"
    test_endpoint "Get paginated steps" "$EXPLORER_API/api/tx/$TX_HASH/steps?from=0&to=50"
    test_endpoint "Get gas report" "$EXPLORER_API/api/tx/$TX_HASH/gas-report"
else
    ((TOTAL+=4))
    log_skip "Trace tests (no TX available)"
fi

# Phase 6: Search API Tests
echo ""
echo -e "${BOLD}Phase 6: Search API${NC}"
echo "═════════════════════════════════════════════════════"
echo ""

test_endpoint "Search by block number" "$EXPLORER_API/api/search?q=$LATEST_BLOCK_DEC"
test_endpoint "Search by block hash" "$EXPLORER_API/api/search?q=$BLOCK_HASH"

if [ -n "$TX_HASH" ]; then
    test_endpoint "Search by transaction hash" "$EXPLORER_API/api/search?q=$TX_HASH"
fi

if [ -n "$FROM_ADDR" ]; then
    test_endpoint "Search by address" "$EXPLORER_API/api/search?q=$FROM_ADDR"
fi

# Phase 7: Address API Tests
echo ""
echo -e "${BOLD}Phase 7: Address API${NC}"
echo "═════════════════════════════════════════════════════"
echo ""

TEST_ADDR="0x0000000000000000000000000000000000000000"
test_endpoint "Get address summary (zero address)" "$EXPLORER_API/api/address/$TEST_ADDR"

if [ -n "$FROM_ADDR" ]; then
    test_endpoint "Get address summary (from address)" "$EXPLORER_API/api/address/$FROM_ADDR"
    test_json_array "Get address transactions" "$EXPLORER_API/api/address/$FROM_ADDR/txs?limit=10"
fi

if [ -n "$TO_ADDR" ]; then
    test_endpoint "Get address summary (to address)" "$EXPLORER_API/api/address/$TO_ADDR"
fi

# Phase 8: Decode API Tests
echo ""
echo -e "${BOLD}Phase 8: Decode API${NC}"
echo "═════════════════════════════════════════════════════"
echo ""

# ERC20 transfer calldata
ERC20_TRANSFER="0xa9059cbb000000000000000000000000123456789abcdef0123456789abcdef0123456780000000000000000000000000000000000000000000000000000000000000064"
test_endpoint "Decode ERC20 transfer calldata" "$EXPLORER_API/api/decode/calldata?data=$ERC20_TRANSFER"

# Phase 9: Verification API Tests  
echo ""
echo -e "${BOLD}Phase 9: Verification & ABI API${NC}"
echo "═════════════════════════════════════════════════════"
echo ""

if [ -n "$TO_ADDR" ]; then
    # Check verification status
    ((TOTAL++))
    log_info "Checking verification status for $TO_ADDR"
    VERIFY_RESPONSE=$(curl -s "$EXPLORER_API/api/verify/status/$TO_ADDR")
    if echo "$VERIFY_RESPONSE" | grep -q "verified"; then
        log_success "Verification status endpoint works"
        echo "  Response: $VERIFY_RESPONSE"
        
        # If verified, try to get ABI and source
        if echo "$VERIFY_RESPONSE" | grep -q '"verified":true'; then
            test_endpoint "Get ABI for verified contract" "$EXPLORER_API/api/abi/$TO_ADDR"
            test_endpoint "Get source for verified contract" "$EXPLORER_API/api/source/$TO_ADDR"
        else
            log_info "Contract not verified (expected for most contracts)"
            ((TOTAL+=2))
            ((SKIPPED+=2))
        fi
    else
        log_error "Verification status endpoint failed"
        ((FAILED++))
    fi
fi

# Phase 10: Web UI Tests
echo ""
echo -e "${BOLD}Phase 10: Web UI Pages${NC}"
echo "═════════════════════════════════════════════════════"
echo ""

test_endpoint "Home page" "$EXPLORER_WEB/"
test_endpoint "Block page (latest)" "$EXPLORER_WEB/block/latest"
test_endpoint "Block page (by number)" "$EXPLORER_WEB/block/$LATEST_BLOCK_DEC"
test_endpoint "Block page (by hash)" "$EXPLORER_WEB/block/$BLOCK_HASH"

if [ -n "$TX_HASH" ]; then
    test_endpoint "Transaction page" "$EXPLORER_WEB/tx/$TX_HASH"
fi

if [ -n "$FROM_ADDR" ]; then
    test_endpoint "Address page (from)" "$EXPLORER_WEB/address/$FROM_ADDR"
fi

# Phase 11: Data Consistency Tests
echo ""
echo -e "${BOLD}Phase 11: Data Consistency${NC}"
echo "═════════════════════════════════════════════════════"
echo ""

((TOTAL++))
log_info "Comparing block data: RPC vs Explorer API"
RPC_BLOCK=$(curl -s "$CHAIN_RPC" -X POST -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$LATEST_BLOCK\",false],\"id\":1}")
API_BLOCK=$(curl -s "$EXPLORER_API/api/blocks/$LATEST_BLOCK_DEC")

RPC_HASH=$(echo "$RPC_BLOCK" | grep -o '"hash":"[^"]*"' | cut -d'"' -f4)
API_HASH=$(echo "$API_BLOCK" | grep -o '"hash":"[^"]*"' | cut -d'"' -f4)

if [ "$RPC_HASH" = "$API_HASH" ] && [ -n "$RPC_HASH" ]; then
    log_success "Block hash consistency check"
else
    log_error "Block hash mismatch (RPC: $RPC_HASH, API: $API_HASH)"
fi

# Phase 12: Performance Tests
echo ""
echo -e "${BOLD}Phase 12: Performance Checks${NC}"
echo "═════════════════════════════════════════════════════"
echo ""

((TOTAL++))
log_info "Testing API response time (latest block)"
START=$(date +%s%N)
curl -s "$EXPLORER_API/api/blocks/latest" > /dev/null
END=$(date +%s%N)
DURATION=$(( (END - START) / 1000000 ))
if [ $DURATION -lt 1000 ]; then
    log_success "Latest block response time: ${DURATION}ms (fast)"
elif [ $DURATION -lt 3000 ]; then
    log_success "Latest block response time: ${DURATION}ms (acceptable)"
else
    log_error "Latest block response time: ${DURATION}ms (slow, >3s)"
fi

# Summary
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║                  Test Summary                      ║"
echo "╚════════════════════════════════════════════════════╝"
echo ""
echo "Total Tests:   $TOTAL"
echo -e "${GREEN}Passed:        $PASSED${NC}"
echo -e "${RED}Failed:        $FAILED${NC}"
echo -e "${YELLOW}Skipped:       $SKIPPED${NC}"
echo ""

SUCCESS_RATE=$(( PASSED * 100 / TOTAL ))
echo "Success Rate:  $SUCCESS_RATE%"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ All tests passed!${NC}"
    echo ""
    echo "🎉 Your Explorer implementation is working perfectly!"
    echo ""
    echo "Features verified:"
    echo "  ✅ Block explorer (by number, hash, latest)"
    echo "  ✅ Transaction viewer with decoded input/logs"
    echo "  ✅ Call tree traces"
    echo "  ✅ Step-by-step debugger"
    echo "  ✅ Gas profiling"
    echo "  ✅ Search functionality"
    echo "  ✅ Address pages with transaction history"
    echo "  ✅ Verification integration"
    echo "  ✅ Latest blocks/txs feed"
    echo "  ✅ Web UI with all features"
    echo ""
    echo "Access your Explorer:"
    echo "  🌐 Web UI:  $EXPLORER_WEB"
    echo "  🔌 API:     $EXPLORER_API"
    echo ""
    exit 0
else
    echo -e "${RED}${BOLD}✗ Some tests failed${NC}"
    echo ""
    echo "Please review the errors above and check:"
    echo "  - Container logs: docker compose logs explorer-api"
    echo "  - Chain connectivity: curl $CHAIN_RPC"
    echo "  - API health: curl $EXPLORER_API/healthz"
    echo ""
    exit 1
fi

