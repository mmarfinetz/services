# Explorer Testing - Quick Start Guide

This is a quick reference for testing the new Explorer functionality.

## ⚡ Quick Start (TL;DR)

```bash
cd /Users/mitch/CoW-Playground/services/playground

# 1. Validate code structure
./validate_code.sh

# 2. Check prerequisites (Docker, ports, etc.)
./preflight_check.sh

# 3. Start services
docker compose -f docker-compose.fork.yml up --build

# 4. In another terminal, run tests
./test_explorer.sh
```

## 📋 Testing Checklist

### Before Starting Docker

- [ ] Run `./validate_code.sh` - All checks pass
- [ ] Docker Desktop is running
- [ ] Ports are available (8081, 8083, 5555, 8545)
- [ ] `.env` file is configured (see below)

### After Starting Docker

- [ ] All containers start without errors
- [ ] Chain RPC responds: `curl http://localhost:8545 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'`
- [ ] Explorer API health: `curl http://localhost:8081/healthz`
- [ ] Explorer Web loads: `curl http://localhost:8083`

### Running Tests

- [ ] Run `./test_explorer.sh` - All tests pass
- [ ] Manual UI testing (see below)

## 🔧 Environment Setup

Create `.env` file in the `playground/` directory:

```bash
# Required
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
CHAIN=1
ENV=local

# For fork mode only
ETH_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY
```

## 🌐 Service URLs

Once running:

| Service | URL | Purpose |
|---------|-----|---------|
| **Explorer Web** | http://localhost:8083 | User-facing block explorer |
| **Explorer API** | http://localhost:8081 | Backend API |
| **Explorer API Health** | http://localhost:8081/healthz | Health check |
| **Explorer API Metrics** | http://localhost:8081/metrics | Prometheus metrics |
| **Sourcify** | http://localhost:5555 | Contract verification |
| **Chain RPC** | http://localhost:8545 | Local blockchain |
| **CoW Explorer** | http://localhost:8001 | Existing CoW explorer |

## ✅ Manual Testing Checklist

### 1. Health Checks
```bash
curl http://localhost:8081/healthz
# Expected: {"ok":true,"network":"local"}

curl http://localhost:8081/metrics
# Expected: Prometheus metrics output
```

### 2. Block Operations
- [ ] Get latest block: http://localhost:8083/block/latest
- [ ] Get block by number: http://localhost:8083/block/1
- [ ] Click on block hash - should navigate to same block
- [ ] Verify block data (number, timestamp, hash, transactions)

### 3. Transaction Operations
- [ ] Navigate to a transaction from a block page
- [ ] Verify transaction details (hash, from, to, value, gas)
- [ ] Check receipt data (logs, status)
- [ ] Click "Debug" or "Trace" tab (if available)
- [ ] Verify trace data is displayed

### 4. Search Functionality
- [ ] Search by block number
- [ ] Search by block hash
- [ ] Search by transaction hash
- [ ] Search by address
- [ ] Try invalid inputs (should handle gracefully)

### 5. Address Pages
- [ ] Navigate to an address page
- [ ] Verify contract detection works
- [ ] Check transaction count
- [ ] Verify last seen block

### 6. API Endpoints

```bash
# Get latest block
curl http://localhost:8081/api/blocks/latest | jq

# Get block by number
curl http://localhost:8081/api/blocks/1 | jq

# Get transaction (replace with real hash)
curl http://localhost:8081/api/tx/0x... | jq

# Get trace (replace with real hash)
curl http://localhost:8081/api/tx/0x.../trace?mode=tree | jq

# Search
curl "http://localhost:8081/api/search?q=latest" | jq

# Address info (replace with real address)
curl http://localhost:8081/api/address/0x... | jq
```

## 🐛 Common Issues

### Docker not starting
```bash
# Check Docker is running
docker info

# If not, start Docker Desktop
open -a Docker
```

### Port conflicts
```bash
# Check what's using a port
lsof -i :8081

# Kill the process if needed
kill -9 <PID>
```

### No transactions found
```bash
# In fork mode, you may need to wait for blocks
# Or send a test transaction
cast send --rpc-url http://localhost:8545 0x... --value 0.1ether --private-key 0x...
```

### API returns 404
```bash
# Check chain is synced
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Check API logs
docker compose -f docker-compose.fork.yml logs explorer-api
```

### Web UI not loading
```bash
# Check API is accessible from web container
docker compose -f docker-compose.fork.yml exec explorer-web sh
wget -O- http://explorer-api:8081/healthz

# Check browser console for errors
# Check that NEXT_PUBLIC_API_BASE is set correctly
```

## 📊 Expected Results

After completing all tests:

- ✅ All automated tests pass
- ✅ Web UI loads without errors
- ✅ Block data is accurate and complete
- ✅ Transactions show correct details
- ✅ Traces/debug data is available
- ✅ Search works for all input types
- ✅ Address pages show contract status
- ✅ No errors in container logs

## 🚀 What's Working (Milestone 1)

Current functionality:
- ✅ Block retrieval (by number, hash, "latest")
- ✅ Transaction details with receipts
- ✅ Call traces (tree and step modes)
- ✅ Basic search (blocks, txs, addresses)
- ✅ Address summaries (contract detection, tx count)
- ✅ Minimal Web UI for viewing data
- ✅ Prometheus metrics
- ✅ SQLite caching for performance
- ✅ Sourcify service running (integration TBD)

## 📈 Coming Next

**Milestone 2** - Enhanced UI:
- Latest blocks/txs feed
- Pagination
- ABI decoding (4byte/verified contracts)

**Milestone 3** - Verification:
- Contract verification via Sourcify
- Source code display
- Verified badge

**Milestone 4** - Advanced Debugging:
- Enhanced trace viewer
- Step-by-step execution
- Stack/memory inspection
- Gas profiling

**Milestone 5** - Integration:
- CoW frontend integration
- Performance tuning
- Production hardening

## 📝 Notes

- The explorer uses on-demand RPC reads with minimal DB writes
- SQLite is in WAL mode for concurrent reads
- Traces use `debug_traceTransaction` (requires supporting RPC)
- React 17+ doesn't require explicit React imports in JSX
- Next.js pages require default exports

## 🔗 Related Files

- `test_explorer.sh` - Automated test suite
- `validate_code.sh` - Code structure validation
- `preflight_check.sh` - Prerequisites checker
- `TESTING_EXPLORER.md` - Full testing guide
- `docker-compose.fork.yml` - Docker composition (fork mode)
- `docker-compose.non-interactive.yml` - Docker composition (local mode)

## 📞 Getting Help

If tests fail:
1. Check the error message carefully
2. Review container logs: `docker compose logs <service>`
3. Verify prerequisites with `./preflight_check.sh`
4. Check this guide's troubleshooting section
5. Review the full guide: `TESTING_EXPLORER.md`

