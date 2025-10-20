# 🧪 Comprehensive Explorer Testing Guide

Your Explorer implementation includes **advanced features** across all planned milestones! This guide will help you test everything.

## 🎯 What's Actually Implemented

Your implementation includes features from **Milestones 1-4**:

### ✅ Milestone 1: Basic Explorer
- Block retrieval (by number, hash, latest)
- Transaction details with receipts
- Call tree traces
- Search functionality
- Address summaries

### ✅ Milestone 2: Enhanced UI
- **Latest blocks feed** with auto-refresh
- **Latest transactions feed** with auto-refresh  
- ABI decoding for common functions (ERC20, etc.)
- Event/log decoding
- **Background indexer** syncing blocks/txs to SQLite

### ✅ Milestone 3: Verification
- **Sourcify integration** for verified contracts
- ABI retrieval from local Sourcify repository
- Source code display
- Verification status checking
- Auto-caching of ABIs in SQLite

### ✅ Milestone 4: Advanced Debugging
- **Step-by-step debugger** with pagination
- **Gas profiling** by contract and function
- Source mapping support (when available)
- Stack/memory inspection toggles
- Call depth tracking

## 🚀 Quick Start

```bash
cd /Users/mitch/CoW-Playground/services/playground

# 1. Validate code
./validate_code.sh

# 2. Check environment
./preflight_check.sh

# 3. Start services (in another terminal)
docker compose -f docker-compose.fork.yml up --build

# 4. Run comprehensive tests
./test_explorer_comprehensive.sh
```

## 📊 API Endpoints

Your Explorer API has **19+ endpoints**:

### Block Endpoints
```bash
# Get single block
GET /api/blocks/latest
GET /api/blocks/:number
GET /api/blocks/:hash

# List latest blocks (with limit)
GET /api/blocks?limit=20
```

### Transaction Endpoints
```bash
# Get single transaction (with decoded input/logs)
GET /api/tx/:hash

# List latest transactions (from indexer)
GET /api/tx?limit=20
```

### Trace & Debug Endpoints
```bash
# Get call tree trace
GET /api/tx/:hash/trace?mode=tree

# Get step-by-step trace
GET /api/tx/:hash/trace?mode=steps

# Get paginated steps (for large traces)
GET /api/tx/:hash/steps?from=0&to=200&memory=0&stack=0

# Get gas profiling report
GET /api/tx/:hash/gas-report
```

### Address Endpoints
```bash
# Get address summary
GET /api/address/:address

# Get address transaction history (from indexer)
GET /api/address/:address/txs?limit=50
```

### Search Endpoint
```bash
# Universal search (block/tx/address)
GET /api/search?q=<query>
```

### Decode Endpoint
```bash
# Decode calldata with signature database
GET /api/decode/calldata?data=0x...
```

### Verification & ABI Endpoints
```bash
# Get verification status
GET /api/verify/status/:address

# Get ABI (from Sourcify or cache)
GET /api/abi/:address

# Get source code
GET /api/source/:address
```

### Meta Endpoints
```bash
# Health check
GET /healthz

# Prometheus metrics
GET /metrics
```

## 🌐 Web UI Features

### Home Page (`/`)
- **Search bar** for blocks/transactions/addresses
- **Latest blocks list** (auto-refreshes every 2s)
- **Latest transactions list** (auto-refreshes every 2s)
- Navigation to detailed pages

### Block Page (`/block/:id`)
- Block details (number, hash, parent hash, timestamp)
- List of transactions in block
- Links to transaction details

### Transaction Page (`/tx/:hash`)
- Transaction details (hash, block, from, to, value)
- Receipt information (status, gas used, logs count)
- **Decoded input** (function name + parameters)
- **Decoded logs** (event names + parameters)
- **Debug section** with:
  - Call tree trace
  - Gas report by contract/function
  - Step-by-step debugger with pagination controls

### Address Page (`/address/:address`)
- Address summary (isContract, tx count, last seen)
- **Verification status**
- **ABI display** (if verified)
- **Source code display** (if verified)
- **Recent transactions list** (auto-refreshes every 3s)

## 🧪 Testing Procedures

### 1. Automated Testing

Run the comprehensive test suite:

```bash
./test_explorer_comprehensive.sh
```

This tests:
- ✅ 19+ API endpoints
- ✅ 6+ Web UI pages
- ✅ Data consistency
- ✅ Response times

### 2. Manual Testing

#### Test Latest Blocks/Txs Feed

1. Open http://localhost:8083
2. Observe latest blocks list on left
3. Observe latest transactions list on right
4. Wait 2-3 seconds - lists should auto-refresh
5. Verify new blocks/txs appear

#### Test Transaction Decoding

1. Navigate to any transaction page
2. Check **Decoded Input** section
   - Should show function signature if known
   - Should show parameters if decodable
3. Check **Decoded Logs** section
   - Should show event names if known
   - Should show event parameters

#### Test Debugging Features

1. On a transaction page, scroll to **Debug** section
2. **Call Tree**: Verify nested calls are shown
3. **Gas Report**: Verify gas usage by contract/function
4. **Stepper**: 
   - Adjust "From" and "Size" inputs
   - Verify step-by-step execution shows
   - Check opcodes, gas costs, depth

#### Test Verification

1. Find a verified contract address (check Sourcify)
2. Navigate to `/address/0x...`
3. Verify "Verified" status shows
4. Expand "ABI" details - should show full ABI
5. Expand "Sources" details - should show source files

#### Test Background Indexer

1. Start the services
2. Wait 30 seconds
3. Check `/api/blocks?limit=10` - should return indexed blocks
4. Check `/api/tx?limit=10` - should return indexed transactions
5. Check logs: `docker compose logs explorer-api | grep indexer`

### 3. Performance Testing

#### Test API Performance

```bash
# Time a block request
time curl -s http://localhost:8081/api/blocks/latest > /dev/null

# Should be < 1 second

# Time a transaction with decoding
time curl -s http://localhost:8081/api/tx/0x... > /dev/null

# Should be < 2 seconds
```

#### Test Indexer Performance

```bash
# Check indexer metrics
curl http://localhost:8081/metrics | grep -i index

# Check database size
docker compose exec explorer-api du -h /data/explorer.sqlite
```

### 4. Database Inspection

The indexer stores data in SQLite. To inspect:

```bash
# Access the container
docker compose exec explorer-api sh

# Open the database
sqlite3 /data/explorer.sqlite

# Check what's indexed
SELECT COUNT(*) FROM blocks;
SELECT COUNT(*) FROM txs;
SELECT COUNT(*) FROM abis;

# Check recent blocks
SELECT number, hash, txCount FROM blocks ORDER BY number DESC LIMIT 5;

# Check recent transactions  
SELECT hash, blockNumber, fromAddr, toAddr FROM txs ORDER BY blockNumber DESC LIMIT 5;

# Exit
.quit
```

## 🎨 Feature Highlights

### 🔥 Background Indexer

The explorer includes a **lightweight indexer** that:
- Polls latest blocks every 1.5 seconds (configurable)
- Indexes blocks and transactions into SQLite
- Caches ABIs for verified contracts
- Prunes old data (keeps last 10,000 blocks by default)
- Enables fast "latest blocks/txs" lists

### 🧮 Gas Profiling

The **gas report** endpoint analyzes transaction execution:
- Breaks down gas usage by contract
- Breaks down gas usage by function
- Shows call depth and hierarchy
- Uses verified ABIs when available

### 🔍 Source Mapping

The **step debugger** includes source mapping:
- Maps opcodes to source code lines (when metadata available)
- Shows which contract/function is executing
- Tracks call depth through nested calls

### 🎯 Smart Decoding

The explorer intelligently decodes:
- **Common functions**: ERC20, ERC721, UniswapV2/V3, Multicall
- **Common events**: Transfer, Approval, ApprovalForAll
- **Verified contracts**: Uses ABIs from Sourcify
- **Fallback**: Shows raw method IDs for unknown functions

## 🐛 Troubleshooting

### Indexer not syncing

```bash
# Check indexer logs
docker compose logs explorer-api | grep -i index

# Check last synced block
docker compose exec explorer-api sqlite3 /data/explorer.sqlite "SELECT value FROM meta WHERE key='last_synced';"

# Force restart
docker compose restart explorer-api
```

### Decoding not working

```bash
# Check if ABIs are cached
docker compose exec explorer-api sqlite3 /data/explorer.sqlite "SELECT COUNT(*) FROM abis;"

# Check Sourcify repository
docker compose exec sourcify ls -la /sourcify/repository/contracts/

# Verify Sourcify is running
curl http://localhost:5555/health
```

### Traces failing

```bash
# Verify debug_traceTransaction is supported
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"debug_traceTransaction","params":["0x...","{}"],"id":1}'

# Anvil supports this by default
# Some RPC providers may not
```

### Performance issues

```bash
# Check database size
docker compose exec explorer-api du -h /data/explorer.sqlite

# Vacuum the database
docker compose exec explorer-api sqlite3 /data/explorer.sqlite "VACUUM;"

# Restart to clear memory
docker compose restart explorer-api
```

## ✅ Expected Test Results

After running `./test_explorer_comprehensive.sh`, you should see:

- **60+ tests** executed
- **95%+** pass rate
- Response times < 1-2 seconds
- All Web UI pages accessible
- Data consistency verified

Some tests may be skipped if:
- No transactions are available yet (just wait for blocks)
- Contracts aren't verified in Sourcify (expected)
- Optional features are disabled

## 🎯 Success Criteria

Your Explorer is fully functional when:

✅ All services start without errors  
✅ Home page shows latest blocks/txs lists  
✅ Block/tx/address pages load correctly  
✅ Transaction input/logs are decoded  
✅ Traces and gas reports work  
✅ Step debugger shows opcode execution  
✅ Verified contracts show ABI/source  
✅ Search works for all input types  
✅ Background indexer is syncing  
✅ API response times are fast (< 2s)  
✅ No errors in container logs  

## 📈 What's Next

Your implementation is **feature-complete** through Milestone 4! 

### Milestone 5: Integration & Polish

Remaining tasks:
- [ ] Add `NEXT_PUBLIC_LOCAL_EXPLORER_URL` to CoW frontend
- [ ] Redirect CoW UI links to local explorer
- [ ] Add Grafana dashboards for explorer metrics
- [ ] Performance tuning for large-scale indexing
- [ ] Add pagination to address transaction lists
- [ ] Add filters (by date, type, status)
- [ ] Add CSV export for transaction history

## 📞 Getting Help

If tests fail or features don't work:

1. **Check the logs**:
   ```bash
   docker compose logs explorer-api
   docker compose logs explorer-web
   ```

2. **Verify services are running**:
   ```bash
   curl http://localhost:8081/healthz
   curl http://localhost:8083
   ```

3. **Check the chain is responsive**:
   ```bash
   curl -X POST http://localhost:8545 \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
   ```

4. **Review this guide** for specific feature testing procedures

5. **Check test output** for specific error messages

---

Happy Testing! 🚀

Your Explorer implementation is **impressive** - you've built features that typically take months to develop!

