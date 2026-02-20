#!/bin/bash

# Flutter Integration Test Runner Script
# This script runs integration tests on an emulator/device

set -e

echo "🚀 Starting Flutter Integration Tests..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter is not installed. Please install Flutter first.${NC}"
    exit 1
fi

# Get available devices
echo -e "${YELLOW}📱 Checking available devices...${NC}"
flutter devices

# Ask user to select device or use default
DEVICE_ID=""
if [ -z "$1" ]; then
    echo -e "${YELLOW}Select device (press Enter for default):${NC}"
    read -r DEVICE_ID
fi

# Install dependencies
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
flutter pub get

# Fix APK location if needed
echo -e "${YELLOW}🔧 Checking APK location...${NC}"
bash "$(dirname "$0")/fix_apk_location.sh"

# Run tests
echo -e "${GREEN}🧪 Running integration tests...${NC}"

if [ -z "$DEVICE_ID" ]; then
    flutter test integration_test/ --reporter expanded
else
    flutter test integration_test/ -d "$DEVICE_ID" --reporter expanded
fi

# Check exit code
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Tests failed!${NC}"
    exit 1
fi

