#!/bin/bash
# Validate Explorer code without running Docker

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "========================================"
echo "  Explorer Code Validation"
echo "========================================"
echo ""

ERRORS=0
WARNINGS=0

# Function to check file
check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description"
        return 0
    else
        echo -e "${RED}✗${NC} $description - File not found: $file"
        ((ERRORS++))
        return 1
    fi
}

# Function to check syntax
check_json_syntax() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        if python3 -m json.tool "$file" &> /dev/null || node -e "require('$file')" &> /dev/null; then
            echo -e "${GREEN}✓${NC} $description - Valid JSON"
            return 0
        else
            echo -e "${RED}✗${NC} $description - Invalid JSON"
            ((ERRORS++))
            return 1
        fi
    fi
}

# Check Explorer API files
echo "Checking Explorer API structure..."
echo ""

check_file "explorer-api/package.json" "Explorer API package.json"
check_file "explorer-api/tsconfig.json" "Explorer API tsconfig.json"
check_file "explorer-api/Dockerfile" "Explorer API Dockerfile"
check_file "explorer-api/src/server.ts" "Explorer API server.ts"
check_file "explorer-api/src/config.ts" "Explorer API config.ts"
check_file "explorer-api/src/rpc.ts" "Explorer API rpc.ts"
check_file "explorer-api/src/db.ts" "Explorer API db.ts"
check_file "explorer-api/src/services.ts" "Explorer API services.ts"

echo ""
echo "Checking Explorer Web structure..."
echo ""

check_file "explorer-web/package.json" "Explorer Web package.json"
check_file "explorer-web/next.config.js" "Explorer Web next.config.js"
check_file "explorer-web/Dockerfile" "Explorer Web Dockerfile"
check_file "explorer-web/pages/index.tsx" "Explorer Web index page"
check_file "explorer-web/pages/block/[id].tsx" "Explorer Web block page"
check_file "explorer-web/pages/tx/[hash].tsx" "Explorer Web transaction page"
check_file "explorer-web/pages/address/[address].tsx" "Explorer Web address page"

echo ""
echo "Validating JSON files..."
echo ""

check_json_syntax "explorer-api/package.json" "Explorer API package.json"
check_json_syntax "explorer-api/tsconfig.json" "Explorer API tsconfig.json"
check_json_syntax "explorer-web/package.json" "Explorer Web package.json"

echo ""
echo "Checking TypeScript syntax (Explorer API)..."
echo ""

# Check if we can at least parse the TypeScript files
if command -v node &> /dev/null; then
    TS_FILES=(
        "explorer-api/src/server.ts"
        "explorer-api/src/config.ts"
        "explorer-api/src/rpc.ts"
        "explorer-api/src/db.ts"
        "explorer-api/src/services.ts"
    )
    
    for file in "${TS_FILES[@]}"; do
        if [ -f "$file" ]; then
            # Basic syntax check - look for obvious issues
            if grep -q "import.*from" "$file"; then
                echo -e "${GREEN}✓${NC} $file - Has valid imports"
            else
                echo -e "${YELLOW}⚠${NC} $file - No imports found (may be intentional)"
                ((WARNINGS++))
            fi
            
            # Check for basic structure
            if grep -qE "(export|function|class|const|let)" "$file"; then
                echo -e "${GREEN}✓${NC} $file - Has valid exports/declarations"
            else
                echo -e "${YELLOW}⚠${NC} $file - No exports found"
                ((WARNINGS++))
            fi
        fi
    done
else
    echo -e "${YELLOW}⚠${NC} Node.js not found - skipping detailed syntax checks"
    ((WARNINGS++))
fi

echo ""
echo "Checking React/Next.js files..."
echo ""

TSX_FILES=(
    "explorer-web/pages/index.tsx"
    "explorer-web/pages/block/[id].tsx"
    "explorer-web/pages/tx/[hash].tsx"
    "explorer-web/pages/address/[address].tsx"
)

for file in "${TSX_FILES[@]}"; do
    if [ -f "$file" ]; then
        # Check for React imports
        if grep -q "import.*react" "$file" || grep -q "import.*React" "$file"; then
            echo -e "${GREEN}✓${NC} $file - Has React imports"
        else
            echo -e "${YELLOW}⚠${NC} $file - No React import found"
            ((WARNINGS++))
        fi
        
        # Check for export default
        if grep -q "export default" "$file"; then
            echo -e "${GREEN}✓${NC} $file - Has default export"
        else
            echo -e "${RED}✗${NC} $file - No default export (required for Next.js pages)"
            ((ERRORS++))
        fi
    fi
done

echo ""
echo "Checking Docker Compose configuration..."
echo ""

if [ -f "docker-compose.fork.yml" ]; then
    echo -e "${GREEN}✓${NC} docker-compose.fork.yml exists"
    
    # Check for explorer services
    if grep -q "explorer-api:" docker-compose.fork.yml; then
        echo -e "${GREEN}✓${NC} explorer-api service defined"
        
        # Check for required config
        if grep -A 10 "explorer-api:" docker-compose.fork.yml | grep -q "JSON_RPC_URL"; then
            echo -e "${GREEN}✓${NC} explorer-api has JSON_RPC_URL configured"
        else
            echo -e "${RED}✗${NC} explorer-api missing JSON_RPC_URL environment variable"
            ((ERRORS++))
        fi
        
        if grep -A 10 "explorer-api:" docker-compose.fork.yml | grep -q "8081:8081"; then
            echo -e "${GREEN}✓${NC} explorer-api port 8081 mapped"
        else
            echo -e "${YELLOW}⚠${NC} explorer-api port mapping may be non-standard"
            ((WARNINGS++))
        fi
    else
        echo -e "${RED}✗${NC} explorer-api service not found"
        ((ERRORS++))
    fi
    
    if grep -q "explorer-web:" docker-compose.fork.yml; then
        echo -e "${GREEN}✓${NC} explorer-web service defined"
        
        if grep -A 10 "explorer-web:" docker-compose.fork.yml | grep -q "NEXT_PUBLIC_API_BASE"; then
            echo -e "${GREEN}✓${NC} explorer-web has NEXT_PUBLIC_API_BASE configured"
        else
            echo -e "${YELLOW}⚠${NC} explorer-web missing NEXT_PUBLIC_API_BASE (may use defaults)"
            ((WARNINGS++))
        fi
    else
        echo -e "${RED}✗${NC} explorer-web service not found"
        ((ERRORS++))
    fi
    
    if grep -q "sourcify:" docker-compose.fork.yml; then
        echo -e "${GREEN}✓${NC} sourcify service defined"
    else
        echo -e "${YELLOW}⚠${NC} sourcify service not found (optional for basic testing)"
        ((WARNINGS++))
    fi
    
    if grep -q "explorer-data:" docker-compose.fork.yml; then
        echo -e "${GREEN}✓${NC} explorer-data volume defined"
    else
        echo -e "${YELLOW}⚠${NC} explorer-data volume not defined (data won't persist)"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗${NC} docker-compose.fork.yml not found"
    ((ERRORS++))
fi

echo ""
echo "Checking Dockerfiles..."
echo ""

# Check Explorer API Dockerfile
if [ -f "explorer-api/Dockerfile" ]; then
    echo -e "${GREEN}✓${NC} Explorer API Dockerfile exists"
    
    if grep -q "FROM node:" explorer-api/Dockerfile; then
        echo -e "${GREEN}✓${NC} Explorer API uses Node.js base image"
    else
        echo -e "${RED}✗${NC} Explorer API Dockerfile doesn't use Node.js"
        ((ERRORS++))
    fi
    
    if grep -q "npm" explorer-api/Dockerfile || grep -q "yarn" explorer-api/Dockerfile; then
        echo -e "${GREEN}✓${NC} Explorer API installs dependencies"
    else
        echo -e "${YELLOW}⚠${NC} Explorer API may not install dependencies"
        ((WARNINGS++))
    fi
    
    if grep -q "EXPOSE" explorer-api/Dockerfile; then
        echo -e "${GREEN}✓${NC} Explorer API exposes port"
    else
        echo -e "${YELLOW}⚠${NC} Explorer API doesn't explicitly expose port"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗${NC} Explorer API Dockerfile not found"
    ((ERRORS++))
fi

# Check Explorer Web Dockerfile
if [ -f "explorer-web/Dockerfile" ]; then
    echo -e "${GREEN}✓${NC} Explorer Web Dockerfile exists"
    
    if grep -q "FROM node:" explorer-web/Dockerfile; then
        echo -e "${GREEN}✓${NC} Explorer Web uses Node.js base image"
    else
        echo -e "${RED}✗${NC} Explorer Web Dockerfile doesn't use Node.js"
        ((ERRORS++))
    fi
    
    if grep -q "next build" explorer-web/Dockerfile; then
        echo -e "${GREEN}✓${NC} Explorer Web builds Next.js app"
    else
        echo -e "${YELLOW}⚠${NC} Explorer Web may not build Next.js app"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗${NC} Explorer Web Dockerfile not found"
    ((ERRORS++))
fi

echo ""
echo "Checking dependencies..."
echo ""

# Check Explorer API dependencies
if [ -f "explorer-api/package.json" ]; then
    REQUIRED_DEPS=("fastify" "better-sqlite3" "prom-client")
    for dep in "${REQUIRED_DEPS[@]}"; do
        if grep -q "\"$dep\"" explorer-api/package.json; then
            echo -e "${GREEN}✓${NC} Explorer API has $dep dependency"
        else
            echo -e "${RED}✗${NC} Explorer API missing $dep dependency"
            ((ERRORS++))
        fi
    done
fi

# Check Explorer Web dependencies
if [ -f "explorer-web/package.json" ]; then
    REQUIRED_DEPS=("next" "react" "react-dom")
    for dep in "${REQUIRED_DEPS[@]}"; do
        if grep -q "\"$dep\"" explorer-web/package.json; then
            echo -e "${GREEN}✓${NC} Explorer Web has $dep dependency"
        else
            echo -e "${RED}✗${NC} Explorer Web missing $dep dependency"
            ((ERRORS++))
        fi
    done
fi

# Summary
echo ""
echo "========================================"
echo "  Validation Summary"
echo "========================================"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "The code structure looks good. Next steps:"
    echo "  1. Start Docker Desktop"
    echo "  2. Run ./preflight_check.sh"
    echo "  3. Start services with docker compose"
    echo "  4. Run ./test_explorer.sh"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation completed with warnings${NC}"
    echo "  Warnings: $WARNINGS"
    echo ""
    echo "Code should work but please review warnings above."
    exit 0
else
    echo -e "${RED}✗ Validation failed${NC}"
    echo "  Errors: $ERRORS"
    echo "  Warnings: $WARNINGS"
    echo ""
    echo "Please fix the errors before proceeding."
    exit 1
fi

