# 🧪 Explorer Testing Suite

Complete testing infrastructure for the local Explorer API and Web UI.

## 📚 Quick Links

| Document | Purpose |
|----------|---------|
| **[TEST_SUITE_SUMMARY.md](TEST_SUITE_SUMMARY.md)** | Overview of all testing tools |
| **[TESTING_QUICKSTART.md](TESTING_QUICKSTART.md)** | Quick reference guide |
| **[TESTING_EXPLORER.md](TESTING_EXPLORER.md)** | Comprehensive testing guide |

## 🛠️ Testing Tools

### 1. 🚀 **Master Test Runner** (Recommended)
```bash
./run_all_tests.sh
```
**Runs everything in sequence:**
- ✅ Code validation
- ✅ Preflight checks  
- ✅ Waits for services
- ✅ Automated tests
- 📊 Summary report

**Use this for:** Complete end-to-end testing

---

### 2. 🔍 **Code Validator**
```bash
./validate_code.sh
```
**Validates code structure:**
- File existence
- JSON syntax
- TypeScript structure
- React components
- Dockerfiles
- Dependencies

**Use this:** Before starting Docker, after code changes

---

### 3. ✈️ **Preflight Checker**
```bash
./preflight_check.sh
```
**Validates environment:**
- Docker status
- Port availability
- Configuration files
- Disk space
- Service definitions

**Use this:** Before `docker compose up`

---

### 4. 🧪 **Automated Test Suite**
```bash
./test_explorer.sh
```
**Tests all functionality:**
- Service health
- Block operations
- Transaction operations
- Search functionality
- Address operations
- Web UI pages
- Data consistency

**Use this:** After services are running

---

## 🎯 Testing Workflow

### Simple (One Command)
```bash
./run_all_tests.sh
```

### Manual (Step by Step)
```bash
# 1. Validate code
./validate_code.sh

# 2. Check environment
./preflight_check.sh

# 3. Start services (in another terminal)
docker compose -f docker-compose.fork.yml up --build

# 4. Run tests
./test_explorer.sh
```

---

## 🌐 Service URLs

Once services are running:

| Service | URL | Description |
|---------|-----|-------------|
| 🌐 **Explorer Web** | http://localhost:8083 | User interface |
| 🔌 **Explorer API** | http://localhost:8081 | Backend API |
| 💚 **API Health** | http://localhost:8081/healthz | Health check |
| 📊 **Metrics** | http://localhost:8081/metrics | Prometheus metrics |
| ✅ **Sourcify** | http://localhost:5555 | Contract verification |
| ⛓️ **Chain RPC** | http://localhost:8545 | Local blockchain |

---

## ✅ Test Coverage

### Automated Tests

- [x] Health endpoints
- [x] Block retrieval (latest, by number, by hash)
- [x] Transaction details and receipts
- [x] Transaction traces (tree and step modes)
- [x] Search (blocks, transactions, addresses)
- [x] Address information
- [x] Web UI accessibility
- [x] Data consistency

### Manual Tests Checklist

- [ ] Navigate through blocks
- [ ] View transaction details
- [ ] Use search functionality
- [ ] View address pages
- [ ] Check contract detection
- [ ] View debug/trace data
- [ ] Test error handling
- [ ] Check performance

---

## 🐛 Troubleshooting

### Docker not running
```bash
# Start Docker Desktop
open -a Docker

# Verify
docker info
```

### Services not starting
```bash
# Check logs
docker compose -f docker-compose.fork.yml logs explorer-api

# Restart
docker compose -f docker-compose.fork.yml restart explorer-api
```

### Tests failing
```bash
# Check service health
curl http://localhost:8081/healthz

# Verify chain is responding
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Port conflicts
```bash
# Find what's using a port
lsof -i :8081

# Kill it if needed
kill -9 <PID>
```

---

## 📋 Environment Setup

Create `.env` file:

```bash
# Required
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
CHAIN=1
ENV=local

# For fork mode
ETH_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY
```

---

## 🎯 Success Criteria

Your Explorer is ready when:

✅ Code validation passes  
✅ Preflight checks pass  
✅ All containers start successfully  
✅ All automated tests pass  
✅ Web UI loads at http://localhost:8083  
✅ Manual navigation works  
✅ Search works correctly  
✅ No errors in logs  

---

## 📊 Current Status

**Milestone 1: Basic Explorer** ✅ COMPLETE

What's working:
- Block explorer with retrieval
- Transaction details with receipts
- Call traces and debugging
- Search functionality
- Address summaries
- Contract detection
- Web UI with navigation
- SQLite caching
- Prometheus metrics

**Milestone 2: Enhanced UI** 📅 NEXT
- Latest blocks/transactions feed
- Pagination
- ABI decoding
- Event/log decoding

---

## 📖 Documentation Structure

```
playground/
├── TESTING_README.md          ← You are here (overview)
├── TEST_SUITE_SUMMARY.md      ← Detailed tool descriptions
├── TESTING_QUICKSTART.md      ← Quick reference guide
├── TESTING_EXPLORER.md        ← Comprehensive testing guide
├── run_all_tests.sh           ← Master test runner
├── validate_code.sh           ← Code structure validator
├── preflight_check.sh         ← Environment checker
└── test_explorer.sh           ← Automated test suite
```

---

## 🚀 Quick Commands

```bash
# Run everything
./run_all_tests.sh

# Just validate
./validate_code.sh && ./preflight_check.sh

# Start services
docker compose -f docker-compose.fork.yml up --build

# Just test
./test_explorer.sh

# Check logs
docker compose -f docker-compose.fork.yml logs -f explorer-api

# Restart a service
docker compose -f docker-compose.fork.yml restart explorer-api

# Clean restart
docker compose -f docker-compose.fork.yml down -v
docker compose -f docker-compose.fork.yml up --build
```

---

## 💡 Pro Tips

1. **Always run `validate_code.sh` first** - it's fast and catches obvious issues
2. **Use `run_all_tests.sh`** - it's the easiest way to test everything
3. **Watch the logs** - most issues are visible in container logs
4. **Test incrementally** - test after each change, not all at once
5. **Keep services running** - faster iterations during development

---

## 📞 Getting Help

1. **Read the test output** - errors are usually clear
2. **Check container logs** - `docker compose logs <service>`
3. **Review the guides** - comprehensive troubleshooting included
4. **Use the validation scripts** - they often identify the issue
5. **Check TESTING_QUICKSTART.md** - has common problem solutions

---

## 🎉 Ready to Test!

Start with:
```bash
./run_all_tests.sh
```

Or read the [Quick Start Guide](TESTING_QUICKSTART.md) for more details.

Good luck! 🚀

