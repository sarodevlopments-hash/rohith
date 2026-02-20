#!/bin/bash
# Check Integration Test Status Script
# This script helps you monitor if integration tests are running or completed

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}🔍 Checking Integration Test Status...${NC}"
echo ""

# Check if Flutter/Dart processes are running
DART_PROCESSES=$(ps aux | grep -i "dart" | grep -v grep | grep -v "check_test_status")
FLUTTER_PROCESSES=$(ps aux | grep -i "flutter" | grep -v grep | grep -v "check_test_status")

if [ -n "$DART_PROCESSES" ] || [ -n "$FLUTTER_PROCESSES" ]; then
    echo -e "${YELLOW}⏳ Tests are RUNNING...${NC}"
    echo ""
    
    if [ -n "$DART_PROCESSES" ]; then
        echo -e "${CYAN}📊 Dart processes found:${NC}"
        echo "$DART_PROCESSES" | while read line; do
            echo -e "${GRAY}  - $line${NC}"
        done
    fi
    
    if [ -n "$FLUTTER_PROCESSES" ]; then
        echo -e "${CYAN}📊 Flutter processes found:${NC}"
        echo "$FLUTTER_PROCESSES" | while read line; do
            echo -e "${GRAY}  - $line${NC}"
        done
    fi
    
    echo ""
    echo -e "${GRAY}💡 To see live test output, check the terminal where you ran the tests${NC}"
    echo -e "${GRAY}💡 Or run: flutter test integration_test/ -d <device_id> --reporter expanded${NC}"
else
    echo -e "${GREEN}✅ No test processes running - Tests are COMPLETED or NOT STARTED${NC}"
    echo ""
    
    # Check for test results
    if [ -d "test_reports" ]; then
        echo -e "${CYAN}📊 Test reports found in test_reports/${NC}"
        ls -lh test_reports/*.json 2>/dev/null | while read line; do
            echo -e "${GRAY}  - $line${NC}"
        done
    fi
    
    echo ""
    echo -e "${CYAN}💡 To run tests:${NC}"
    echo -e "${GRAY}   flutter test integration_test/ -d <device_id>${NC}"
fi

echo ""
echo -e "${CYAN}📱 Checking emulator status...${NC}"
DEVICES=$(flutter devices 2>&1 | grep -i "emulator")
if [ -n "$DEVICES" ]; then
    echo -e "${GREEN}✅ Emulator is running${NC}"
    echo "$DEVICES" | while read line; do
        echo -e "${GRAY}   $line${NC}"
    done
else
    echo -e "${YELLOW}⚠️  No emulator detected. Start one with: flutter emulators --launch <emulator_id>${NC}"
fi

echo ""
echo -e "${CYAN}📦 Checking APK status...${NC}"
if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    APK_SIZE=$(du -h "build/app/outputs/flutter-apk/app-debug.apk" | cut -f1)
    echo -e "${GREEN}✅ APK ready: $APK_SIZE${NC}"
else
    echo -e "${YELLOW}⚠️  APK not found. Run: ./scripts/fix_apk_location.sh${NC}"
fi

