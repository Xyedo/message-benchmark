#!/bin/bash

# Benchmark execution script for vehicle IoT streaming
# Runs benchmarks against NATS, Pulsar, and Pravega

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BENCHMARK_DIR="openmessaging-benchmark"
WORKLOAD=""
DRIVERS="nats,pulsar,pravega"
DURATION=""
ALL_WORKLOADS=false
RESULTS_DIR="results"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --workload)
            WORKLOAD="$2"
            shift 2
            ;;
        --driver|--drivers)
            DRIVERS="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --all)
            ALL_WORKLOADS=true
            shift
            ;;
        --results-dir)
            RESULTS_DIR="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --workload NAME         Run specific workload (e.g., vehicles-location-100k)"
            echo "  --driver(s) LIST        Comma-separated list of drivers (default: nats,pulsar,pravega)"
            echo "  --duration MINUTES      Override test duration"
            echo "  --all                   Run all workloads"
            echo "  --results-dir DIR       Results directory (default: results)"
            echo "  --help                  Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --workload vehicles-location-100k --driver pulsar"
            echo "  $0 --all --drivers nats,pulsar"
            echo "  $0 --workload vehicles-mixed-100k --duration 10"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Validate benchmark directory exists
if [ ! -d "$BENCHMARK_DIR" ]; then
    echo -e "${RED}Error: Benchmark framework not found at $BENCHMARK_DIR${NC}"
    echo "Please run ./setup.sh first"
    exit 1
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

# Get absolute paths
CURRENT_DIR="$(pwd)"
ABS_RESULTS_DIR="$(cd "$RESULTS_DIR" && pwd)"
ABS_DRIVERS_DIR="$CURRENT_DIR/drivers"
ABS_WORKLOADS_DIR="$CURRENT_DIR/workloads"

# Convert comma-separated drivers to array
IFS=',' read -ra DRIVER_ARRAY <<< "$DRIVERS"

# Function to run a single benchmark
run_benchmark() {
    local workload_file="$1"
    local driver_file="$2"
    local workload_name=$(basename "$workload_file" .yaml)
    local driver_name=$(basename "$driver_file" .yaml)
    
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Running: ${workload_name} on ${driver_name}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Modify workload duration if specified
    local temp_workload="$workload_file"
    if [ -n "$DURATION" ]; then
        temp_workload="/tmp/workload-${workload_name}-${RANDOM}.yaml"
        sed "s/testDurationMinutes:.*/testDurationMinutes: $DURATION/" "$workload_file" > "$temp_workload"
        echo -e "${YELLOW}Using custom duration: $DURATION minutes${NC}"
    fi
    
    # Run benchmark
    cd "$BENCHMARK_DIR"
    
    # Set heap options and log4j2 configuration for ERROR-only logging
    export HEAP_OPTS="-Xmx8g -Xms8g -Dlog4j2.configurationFile=file:$PWD/log4j2.xml"
    
    # Execute benchmark command
    if ! sudo -E bin/benchmark \
        --drivers "$driver_file" \
        "$temp_workload" 2>&1 | tee "$ABS_RESULTS_DIR/${workload_name}-${driver_name}.log"; then
        echo -e "${RED}Benchmark failed!${NC}"
        cd "$CURRENT_DIR"
        [ -n "$DURATION" ] && rm -f "$temp_workload"
        return 1
    fi
    
    # Move result JSON to results directory
    local result_json=$(ls -t ${workload_name}-*.json 2>/dev/null | head -1)
    if [ -n "$result_json" ]; then
        mv "$result_json" "$ABS_RESULTS_DIR/"
        echo -e "${GREEN}✓ Results saved to: $ABS_RESULTS_DIR/$result_json${NC}"
    fi
    
    cd "$CURRENT_DIR"
    [ -n "$DURATION" ] && rm -f "$temp_workload"
    
    echo ""
    echo -e "${GREEN}✓ Benchmark completed: ${workload_name} on ${driver_name}${NC}"
    echo ""
}

# Print configuration
echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Vehicle IoT Streaming Benchmark${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "Drivers: ${YELLOW}${DRIVERS}${NC}"
echo -e "Results directory: ${YELLOW}${RESULTS_DIR}${NC}"

if [ "$ALL_WORKLOADS" = true ]; then
    echo -e "Mode: ${YELLOW}All workloads${NC}"
else
    echo -e "Workload: ${YELLOW}${WORKLOAD}${NC}"
fi

if [ -n "$DURATION" ]; then
    echo -e "Custom duration: ${YELLOW}${DURATION} minutes${NC}"
fi

echo ""

# Validate inputs
if [ "$ALL_WORKLOADS" = false ] && [ -z "$WORKLOAD" ]; then
    echo -e "${RED}Error: Either --workload or --all must be specified${NC}"
    exit 1
fi

# Build workload list
WORKLOAD_FILES=()
if [ "$ALL_WORKLOADS" = true ]; then
    for wl in "$ABS_WORKLOADS_DIR"/*.yaml; do
        WORKLOAD_FILES+=("$wl")
    done
else
    workload_path="$ABS_WORKLOADS_DIR/${WORKLOAD}.yaml"
    if [ ! -f "$workload_path" ]; then
        echo -e "${RED}Error: Workload file not found: $workload_path${NC}"
        exit 1
    fi
    WORKLOAD_FILES+=("$workload_path")
fi

# Validate driver files exist
for driver in "${DRIVER_ARRAY[@]}"; do
    driver_path="$ABS_DRIVERS_DIR/${driver}.yaml"
    if [ ! -f "$driver_path" ]; then
        echo -e "${RED}Error: Driver file not found: $driver_path${NC}"
        exit 1
    fi
done

# Run benchmarks
total_benchmarks=$((${#WORKLOAD_FILES[@]} * ${#DRIVER_ARRAY[@]}))
current=0

echo -e "${YELLOW}Running $total_benchmarks benchmark(s)...${NC}"
echo ""

start_time=$(date +%s)

for workload_file in "${WORKLOAD_FILES[@]}"; do
    for driver in "${DRIVER_ARRAY[@]}"; do
        current=$((current + 1))
        driver_path="$ABS_DRIVERS_DIR/${driver}.yaml"
        
        echo -e "${YELLOW}Progress: $current/$total_benchmarks${NC}"
        
        if ! run_benchmark "$workload_file" "$driver_path"; then
            echo -e "${RED}Warning: Benchmark failed, continuing...${NC}"
        fi
        
        # Add delay between benchmarks to let systems settle
        if [ $current -lt $total_benchmarks ]; then
            echo -e "${YELLOW}Waiting 30 seconds before next benchmark...${NC}"
            sleep 30
        fi
    done
done

end_time=$(date +%s)
duration=$((end_time - start_time))
duration_min=$((duration / 60))
duration_sec=$((duration % 60))

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All Benchmarks Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Total duration: ${YELLOW}${duration_min}m ${duration_sec}s${NC}"
echo -e "Results saved to: ${YELLOW}${ABS_RESULTS_DIR}/${NC}"
echo ""

# List result files
echo -e "${YELLOW}Result files:${NC}"
ls -lh "$ABS_RESULTS_DIR"/*.json 2>/dev/null || echo "No JSON results found"

echo ""
echo -e "${GREEN}To generate comparison charts, run:${NC}"
echo -e "  ${YELLOW}python3 generate-charts.py $RESULTS_DIR/${NC}"
echo ""
