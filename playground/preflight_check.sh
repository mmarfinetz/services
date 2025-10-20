#!/bin/bash
# Pre-flight check for Explorer stack

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "========================================"
echo "  Explorer Stack Pre-flight Check"
echo "========================================"
echo ""

# Check Docker
echo -n "Checking Docker... "
if command -v docker &> /dev/null; then
    if docker info &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker is running"
    else
        echo -e "${RED}✗${NC} Docker daemon is not running"
        echo "  Please start Docker Desktop or Docker daemon"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} Docker is not installed"
    exit 1
fi

# Check Docker Compose
echo -n "Checking Docker Compose... "
if docker compose version &> /dev/null; then
    VERSION=$(docker compose version --short)
    echo -e "${GREEN}✓${NC} Docker Compose $VERSION"
else
    echo -e "${RED}✗${NC} Docker Compose is not available"
    exit 1
fi

# Check for .env file
echo -n "Checking .env file... "
if [ -f .env ]; then
    echo -e "${GREEN}✓${NC} Found"
    
    # Check required variables
    source .env
    
    MISSING_VARS=()
    [ -z "$POSTGRES_USER" ] && MISSING_VARS+=("POSTGRES_USER")
    [ -z "$POSTGRES_PASSWORD" ] && MISSING_VARS+=("POSTGRES_PASSWORD")
    [ -z "$CHAIN" ] && MISSING_VARS+=("CHAIN")
    [ -z "$ENV" ] && MISSING_VARS+=("ENV")
    
    if [ ${#MISSING_VARS[@]} -gt 0 ]; then
        echo -e "  ${YELLOW}⚠${NC} Missing variables: ${MISSING_VARS[*]}"
        echo "  These should be set in .env file"
    fi
    
    # Check for fork-specific variables
    if [ -f docker-compose.fork.yml ]; then
        if [ -z "$ETH_RPC_URL" ]; then
            echo -e "  ${YELLOW}⚠${NC} ETH_RPC_URL not set (required for fork mode)"
        fi
    fi
else
    echo -e "${YELLOW}⚠${NC} Not found"
    echo ""
    echo "  Creating example .env file..."
    cat > .env.example << 'EOF'
# PostgreSQL Configuration
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres

# Chain Configuration
CHAIN=1
ENV=local

# Fork Mode Configuration (only needed for fork mode)
# ETH_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_API_KEY

# Optional: Explorer Configuration
# EXPLORER_DB_PATH=/data/explorer.sqlite
# EXPLORER_PORT=8081
# EXPLORER_WEB_PORT=8083
EOF
    echo -e "  ${GREEN}✓${NC} Created .env.example"
    echo "  Please copy it to .env and configure:"
    echo "    cp .env.example .env"
    echo "    # Edit .env with your settings"
fi

# Check port availability
echo ""
echo "Checking port availability..."
PORTS=(8545 8080 8081 8083 5432 5555)
PORT_NAMES=("Chain RPC" "Orderbook" "Explorer API" "Explorer Web" "PostgreSQL" "Sourcify")
PORTS_OK=true

for i in "${!PORTS[@]}"; do
    PORT=${PORTS[$i]}
    NAME=${PORT_NAMES[$i]}
    
    if lsof -Pi :$PORT -sTCP:LISTEN -t &> /dev/null; then
        echo -e "  ${YELLOW}⚠${NC} Port $PORT ($NAME) is already in use"
        PORTS_OK=false
    else
        echo -e "  ${GREEN}✓${NC} Port $PORT ($NAME) is available"
    fi
done

if [ "$PORTS_OK" = false ]; then
    echo ""
    echo -e "${YELLOW}Warning:${NC} Some ports are in use. This may cause conflicts."
    echo "You may need to stop other services or use different ports."
fi

# Check disk space
echo ""
echo -n "Checking disk space... "
AVAILABLE=$(df -h . | awk 'NR==2 {print $4}')
echo -e "${GREEN}✓${NC} $AVAILABLE available"

# Check if explorer files exist
echo ""
echo "Checking Explorer files..."
if [ -d "explorer-api" ]; then
    echo -e "  ${GREEN}✓${NC} explorer-api/ directory exists"
    
    if [ -f "explorer-api/package.json" ]; then
        echo -e "  ${GREEN}✓${NC} explorer-api/package.json exists"
    else
        echo -e "  ${RED}✗${NC} explorer-api/package.json missing"
    fi
    
    if [ -f "explorer-api/Dockerfile" ]; then
        echo -e "  ${GREEN}✓${NC} explorer-api/Dockerfile exists"
    else
        echo -e "  ${RED}✗${NC} explorer-api/Dockerfile missing"
    fi
else
    echo -e "  ${RED}✗${NC} explorer-api/ directory not found"
fi

if [ -d "explorer-web" ]; then
    echo -e "  ${GREEN}✓${NC} explorer-web/ directory exists"
    
    if [ -f "explorer-web/package.json" ]; then
        echo -e "  ${GREEN}✓${NC} explorer-web/package.json exists"
    else
        echo -e "  ${RED}✗${NC} explorer-web/package.json missing"
    fi
    
    if [ -f "explorer-web/Dockerfile" ]; then
        echo -e "  ${GREEN}✓${NC} explorer-web/Dockerfile exists"
    else
        echo -e "  ${RED}✗${NC} explorer-web/Dockerfile missing"
    fi
else
    echo -e "  ${RED}✗${NC} explorer-web/ directory not found"
fi

# Check compose files
echo ""
echo "Checking Docker Compose files..."
if [ -f "docker-compose.fork.yml" ]; then
    echo -e "  ${GREEN}✓${NC} docker-compose.fork.yml exists"
    
    # Check if explorer services are in the compose file
    if grep -q "explorer-api:" docker-compose.fork.yml; then
        echo -e "  ${GREEN}✓${NC} explorer-api service configured"
    else
        echo -e "  ${YELLOW}⚠${NC} explorer-api service not found in compose file"
    fi
    
    if grep -q "explorer-web:" docker-compose.fork.yml; then
        echo -e "  ${GREEN}✓${NC} explorer-web service configured"
    else
        echo -e "  ${YELLOW}⚠${NC} explorer-web service not found in compose file"
    fi
    
    if grep -q "sourcify:" docker-compose.fork.yml; then
        echo -e "  ${GREEN}✓${NC} sourcify service configured"
    else
        echo -e "  ${YELLOW}⚠${NC} sourcify service not found in compose file"
    fi
else
    echo -e "  ${RED}✗${NC} docker-compose.fork.yml not found"
fi

if [ -f "docker-compose.non-interactive.yml" ]; then
    echo -e "  ${GREEN}✓${NC} docker-compose.non-interactive.yml exists"
else
    echo -e "  ${YELLOW}⚠${NC} docker-compose.non-interactive.yml not found"
fi

# Summary
echo ""
echo "========================================"
echo "  Summary"
echo "========================================"
echo ""

if [ -f .env ] && [ "$PORTS_OK" = true ] && [ -d explorer-api ] && [ -d explorer-web ]; then
    echo -e "${GREEN}✓ System is ready to start the Explorer stack${NC}"
    echo ""
    echo "To start the services, run:"
    echo ""
    echo "  # Fork mode:"
    echo "  docker compose -f docker-compose.fork.yml up --build"
    echo ""
    echo "  # Non-interactive mode:"
    echo "  docker compose -f docker-compose.non-interactive.yml up --build"
    echo ""
    echo "After services are running, test with:"
    echo "  ./test_explorer.sh"
    echo ""
else
    echo -e "${YELLOW}⚠ Some checks failed or warnings were issued${NC}"
    echo ""
    echo "Please review the output above and fix any issues before starting."
    echo ""
fi

