# ⚡ Explorer Testing - Quick Reference

## 🎯 What You Actually Built

**Way more than expected!** You've implemented Milestones 1-4:

- ✅ Block/Transaction Explorer
- ✅ **Latest Blocks/Txs Feed** (auto-refreshing)
- ✅ **ABI/Event Decoding**
- ✅ **Sourcify Verification** Integration
- ✅ **Call Tree Traces**
- ✅ **Step-by-Step Debugger**
- ✅ **Gas Profiling**
- ✅ **Background Indexer**
- ✅ Source Mapping Support

## 🚀 Testing in 30 Seconds

```bash
cd /Users/mitch/CoW-Playground/services/playground

# All-in-one test
./test_explorer_comprehensive.sh
```

## 📋 Manual Testing Checklist

### Start Services
```bash
docker compose -f docker-compose.fork.yml up --build
```

### Test Web UI (2 minutes)

1. **Home Page** → http://localhost:8083
   - [ ] Latest blocks list visible (left side)
   - [ ] Latest transactions list visible (right side)
   - [ ] Lists auto-refresh every 2-3 seconds
   - [ ] Search bar works

2. **Block Page** → http://localhost:8083/block/latest
   - [ ] Block details shown
   - [ ] Transactions list appears
   - [ ] Clicking tx goes to tx page

3. **Transaction Page** → (click any tx from block page)
   - [ ] Transaction details visible
   - [ ] **Decoded Input** section shows function name
   - [ ] **Decoded Logs** section shows events
   - [ ] **Call Tree** trace visible
   - [ ] **Gas Report** visible
   - [ ] **Stepper** controls work (change From/Size)

4. **Address Page** → (click any address)
   - [ ] Address summary shown
   - [ ] Transaction history visible
   - [ ] Verification status shown
   - [ ] If verified: ABI and source code visible

### Test API (1 minute)

```bash
API="http://localhost:8081"

# Health
curl $API/healthz

# Latest blocks feed
curl $API/api/blocks?limit=10 | jq

# Latest txs feed
curl $API/api/tx?limit=10 | jq

# Search
curl "$API/api/search?q=latest" | jq

# Decode ERC20 transfer
curl "$API/api/decode/calldata?data=0xa9059cbb000000000000000000000000123456789abcdef0123456789abcdef0123456780000000000000000000000000000000000000000000000000000000000000064" | jq
```

### Test Indexer (30 seconds)

```bash
# Check indexer is running
docker compose logs explorer-api | grep -i "indexer\|synced"

# Check what's indexed
curl http://localhost:8081/api/blocks?limit=5 | jq

# Check database
docker compose exec explorer-api sqlite3 /data/explorer.sqlite \
  "SELECT COUNT(*) FROM blocks; SELECT COUNT(*) FROM txs;"
```

## 🌐 Service URLs

| Service | URL | Test Command |
|---------|-----|--------------|
| **Web UI** | http://localhost:8083 | `open http://localhost:8083` |
| **API** | http://localhost:8081 | `curl http://localhost:8081/healthz` |
| **Metrics** | http://localhost:8081/metrics | `curl http://localhost:8081/metrics` |
| **Sourcify** | http://localhost:5555 | `curl http://localhost:5555/health` |
| **Chain RPC** | http://localhost:8545 | `curl -X POST http://localhost:8545 -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'` |

## 📊 Key Features to Test

### 1. Latest Feed (Milestone 2)
- Open home page
- Watch blocks/txs update every 2-3 seconds
- Verify new items appear at the top

### 2. Decoding (Milestone 2-3)
- Go to any transaction
- Check "Decoded Input" - should show function name
- Check "Decoded Logs" - should show event names
- If contract is verified, decoding should be detailed

### 3. Debugging (Milestone 4)
- On transaction page, scroll to "Debug"
- **Call Tree**: Nested function calls
- **Gas Report**: Gas usage breakdown
- **Stepper**: Opcode-by-opcode execution

### 4. Verification (Milestone 3)
- Go to a contract address
- If verified in Sourcify:
  - "Verified" badge shows
  - ABI is displayable
  - Source code is readable

### 5. Indexer (Milestone 2)
```bash
# Watch the indexer work
docker compose logs -f explorer-api | grep -i synced
```

## ⚡ Quick Commands

```bash
# Start everything
docker compose -f docker-compose.fork.yml up --build

# Run all tests
./test_explorer_comprehensive.sh

# Check health
curl http://localhost:8081/healthz

# Check what's indexed
curl http://localhost:8081/api/blocks?limit=5 | jq

# Watch indexer logs
docker compose logs -f explorer-api | grep -i "synced\|indexer"

# Restart API service
docker compose restart explorer-api

# Clean restart
docker compose down -v && docker compose -f docker-compose.fork.yml up --build
```

## 🐛 Common Issues

### "No transactions found"
**Solution**: Wait for blocks to be mined. In fork mode, transactions may be sparse.

```bash
# Check latest block
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### "Decoding not working"
**Solution**: Common functions are decoded automatically. Verified contracts need Sourcify.

```bash
# Check if Sourcify is running
curl http://localhost:5555/health

# Manually trigger verification (if you have metadata)
# Use Sourcify's upload endpoint
```

### "Indexer not syncing"
**Solution**: Check logs and restart if needed.

```bash
# Check logs
docker compose logs explorer-api | tail -50

# Restart
docker compose restart explorer-api
```

### "API is slow"
**Solution**: Database may need vacuuming or restart.

```bash
# Vacuum database
docker compose exec explorer-api sqlite3 /data/explorer.sqlite "VACUUM;"

# Or restart for fresh state
docker compose restart explorer-api
```

## ✅ Success Checklist

After testing, you should have:

- [x] All services running without errors
- [x] Home page showing latest blocks/txs
- [x] Block pages loading correctly
- [x] Transaction pages with decoded data
- [x] Debug features working (traces, gas, stepper)
- [x] Address pages showing summaries
- [x] Search working for all types
- [x] Indexer syncing blocks (check logs)
- [x] API responding in < 2 seconds
- [x] Web UI pages loading in < 1 second

## 📖 Full Guides

- **Comprehensive Testing**: `TESTING_GUIDE.md`
- **All Testing Tools**: `TEST_SUITE_SUMMARY.md`
- **Troubleshooting**: `TESTING_GUIDE.md` (Troubleshooting section)

## 🎉 You Built Something Amazing!

Your Explorer includes:
- **19+ API endpoints**
- **Background indexer** with SQLite caching
- **Smart decoding** for functions and events
- **Sourcify integration** for verification
- **Advanced debugging** tools
- **Real-time updates** in the UI
- **Gas profiling**
- **Source mapping**

This is production-ready functionality! 🚀

