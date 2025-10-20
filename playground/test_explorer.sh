#!/bin/bash
# Test script for the local Explorer API and Web UI

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
EXPLORER_API="http://localhost:8081"
EXPLORER_WEB="http://localhost:8083"
SOURCIFY="http://localhost:5555"
CHAIN_RPC="http://localhost:8545"

# Test counters
TOTAL=0
PASSED=0
FAILED=0

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

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
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
        echo "  Response: $(echo "$body" | head -c 100)..."
        return 0
    else
        log_error "$name (Expected $expected_code, got $http_code)"
        echo "  Response: $body"
        return 1
    fi
}

test_json_field() {
    local name=$1
    local url=$2
    local field=$3
    
    ((TOTAL++))
    log_info "Testing: $name"
    
    response=$(curl -s "$url")
    value=$(echo "$response" | grep -o "\"$field\"" || true)
    
    if [ -n "$value" ]; then
        log_success "$name (found field '$field')"
        echo "  Sample: $(echo "$response" | head -c 150)..."
        return 0
    else
        log_error "$name (field '$field' not found)"
        echo "  Response: $response"
        return 1
    fi
}

echo ""
echo "========================================"
echo "  Explorer Stack Testing Suite"
echo "========================================"
echo ""

# Check if services are running
log_info "Checking if services are accessible..."
if ! curl -s "$CHAIN_RPC" -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' > /dev/null; then
    log_error "Chain RPC not accessible at $CHAIN_RPC"
    exit 1
fi
log_success "Chain RPC is accessible"

# Phase 1: Basic Service Health
echo ""
echo "========================================"
echo "  Phase 1: Service Health Checks"
echo "========================================"
echo ""

test_endpoint "Explorer API Health" "$EXPLORER_API/healthz"
test_endpoint "Explorer API Metrics" "$EXPLORER_API/metrics"
test_endpoint "Explorer Web UI" "$EXPLORER_WEB"
test_endpoint "Sourcify Health" "$SOURCIFY/health" || log_warning "Sourcify may not be ready yet"

# Phase 2: Get blockchain data for testing
echo ""
echo "========================================"
echo "  Phase 2: Fetching Test Data"
echo "========================================"
echo ""

log_info "Fetching latest block number from chain..."
LATEST_BLOCK=$(curl -s "$CHAIN_RPC" -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
  grep -o '"result":"[^"]*"' | cut -d'"' -f4)
LATEST_BLOCK_DEC=$((LATEST_BLOCK))
log_info "Latest block: $LATEST_BLOCK_DEC (0x${LATEST_BLOCK#0x})"

log_info "Fetching latest block details..."
BLOCK_RESPONSE=$(curl -s "$CHAIN_RPC" -X POST -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$LATEST_BLOCK\",true],\"id\":1}")
BLOCK_HASH=$(echo "$BLOCK_RESPONSE" | grep -o '"hash":"[^"]*"' | head -1 | cut -d'"' -f4)
log_info "Block hash: $BLOCK_HASH"

# Get a transaction from the block
TX_HASH=$(echo "$BLOCK_RESPONSE" | grep -o '"hash":"0x[^"]*"' | tail -1 | cut -d'"' -f4)
if [ -z "$TX_HASH" ] || [ "$TX_HASH" = "$BLOCK_HASH" ]; then
    log_warning "No transactions found in latest block, checking previous blocks..."
    PREV_BLOCK=$((LATEST_BLOCK_DEC - 1))
    PREV_BLOCK_HEX=$(printf "0x%x" $PREV_BLOCK)
    PREV_BLOCK_RESPONSE=$(curl -s "$CHAIN_RPC" -X POST -H "Content-Type: application/json" \
      -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$PREV_BLOCK_HEX\",true],\"id\":1}")
    TX_HASH=$(echo "$PREV_BLOCK_RESPONSE" | grep -o '"hash":"0x[^"]*"' | grep -v "$BLOCK_HASH" | head -1 | cut -d'"' -f4)
fi

if [ -n "$TX_HASH" ] && [ "$TX_HASH" != "$BLOCK_HASH" ]; then
    log_info "Transaction hash: $TX_HASH"
else
    log_warning "No transactions found - some tests will be skipped"
    TX_HASH=""
fi

# Phase 3: Explorer API Endpoints
echo ""
echo "========================================"
echo "  Phase 3: Explorer API Endpoints"
echo "========================================"
echo ""

test_endpoint "Get block by 'latest'" "$EXPLORER_API/api/blocks/latest"
test_endpoint "Get block by number" "$EXPLORER_API/api/blocks/$LATEST_BLOCK_DEC"
test_endpoint "Get block by hash" "$EXPLORER_API/api/blocks/$BLOCK_HASH"

if [ -n "$TX_HASH" ]; then
    test_endpoint "Get transaction" "$EXPLORER_API/api/tx/$TX_HASH"
    test_endpoint "Get transaction trace (tree mode)" "$EXPLORER_API/api/tx/$TX_HASH/trace?mode=tree"
    test_json_field "Transaction trace has data" "$EXPLORER_API/api/tx/$TX_HASH/trace?mode=tree" "result"
else
    log_warning "Skipping transaction tests (no TX found)"
fi

# Phase 4: Search functionality
echo ""
echo "========================================"
echo "  Phase 4: Search Functionality"
echo "========================================"
echo ""

test_endpoint "Search by block number" "$EXPLORER_API/api/search?q=$LATEST_BLOCK_DEC"
test_endpoint "Search by block hash" "$EXPLORER_API/api/search?q=$BLOCK_HASH"

if [ -n "$TX_HASH" ]; then
    test_endpoint "Search by transaction hash" "$EXPLORER_API/api/search?q=$TX_HASH"
fi

# Phase 5: Address functionality
echo ""
echo "========================================"
echo "  Phase 5: Address Functionality"
echo "========================================"
echo ""

# Use a known address (zero address)
TEST_ADDRESS="0x0000000000000000000000000000000000000000"
test_endpoint "Get address summary" "$EXPLORER_API/api/address/$TEST_ADDRESS"

# Try to get an address from a transaction if available
if [ -n "$TX_HASH" ]; then
    TX_RESPONSE=$(curl -s "$EXPLORER_API/api/tx/$TX_HASH")
    FROM_ADDRESS=$(echo "$TX_RESPONSE" | grep -o '"from":"[^"]*"' | head -1 | cut -d'"' -f4)
    if [ -n "$FROM_ADDRESS" ]; then
        log_info "Testing with address from transaction: $FROM_ADDRESS"
        test_endpoint "Get real address summary" "$EXPLORER_API/api/address/$FROM_ADDRESS"
    fi
fi

# Phase 6: Web UI Accessibility
echo ""
echo "========================================"
echo "  Phase 6: Web UI Pages"
echo "========================================"
echo ""

test_endpoint "Home page" "$EXPLORER_WEB/"
test_endpoint "Block page (latest)" "$EXPLORER_WEB/block/latest"
test_endpoint "Block page (by number)" "$EXPLORER_WEB/block/$LATEST_BLOCK_DEC"

if [ -n "$TX_HASH" ]; then
    test_endpoint "Transaction page" "$EXPLORER_WEB/tx/$TX_HASH"
fi

test_endpoint "Address page" "$EXPLORER_WEB/address/$TEST_ADDRESS"

# Phase 7: Data Consistency
echo ""
echo "========================================"
echo "  Phase 7: Data Consistency Checks"
echo "========================================"
echo ""

((TOTAL++))
log_info "Comparing block data: RPC vs Explorer API"
RPC_BLOCK=$(curl -s "$CHAIN_RPC" -X POST -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$LATEST_BLOCK\",false],\"id\":1}")
API_BLOCK=$(curl -s "$EXPLORER_API/api/blocks/$LATEST_BLOCK_DEC")

RPC_NUMBER=$(echo "$RPC_BLOCK" | grep -o '"number":"[^"]*"' | cut -d'"' -f4)
API_NUMBER=$(echo "$API_BLOCK" | grep -o '"number":[0-9]*' | grep -o '[0-9]*')

if [ "$LATEST_BLOCK_DEC" = "$API_NUMBER" ]; then
    log_success "Block number consistency check"
else
    log_error "Block number mismatch (RPC: $LATEST_BLOCK_DEC, API: $API_NUMBER)"
fi

# Summary
echo ""
echo "========================================"
echo "  Test Summary"
echo "========================================"
echo ""
echo "Total Tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    echo ""
    echo "Your explorer stack is working correctly."
    echo ""
    echo "Access points:"
    echo "  - Explorer Web UI: $EXPLORER_WEB"
    echo "  - Explorer API: $EXPLORER_API"
    echo "  - Sourcify: $SOURCIFY"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    echo "Please check the logs above for details."
    exit 1
fi


