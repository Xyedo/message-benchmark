#!/bin/bash

# Setup script for Message Streaming Benchmark
# Deploys NATS, Pulsar, and Pravega for benchmarking

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
MODE="local"
NAMESPACE="benchmark"
BENCHMARK_REPO="https://github.com/pravega/openmessaging-benchmark.git"
BENCHMARK_DIR="openmessaging-benchmark"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --mode [local|k8s]      Deployment mode (default: local)"
            echo "  --namespace NAME        Kubernetes namespace (default: benchmark)"
            echo "  --help                  Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}Message Streaming Benchmark Setup${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""
echo -e "Mode: ${YELLOW}$MODE${NC}"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command_exists java; then
    echo -e "${RED}Error: Java is not installed${NC}"
    echo "Please install Java 11 or later"
    exit 1
fi

if ! command_exists mvn; then
    echo -e "${RED}Error: Maven is not installed${NC}"
    echo "Please install Maven 3.6 or later"
    exit 1
fi

echo -e "${GREEN}✓ Java and Maven found${NC}"

# Clone and build benchmark framework if not exists
if [ ! -d "$BENCHMARK_DIR" ]; then
    echo -e "${YELLOW}Cloning OpenMessaging Benchmark framework...${NC}"
    git clone $BENCHMARK_REPO $BENCHMARK_DIR
fi

cd $BENCHMARK_DIR
echo -e "${YELLOW}Building benchmark framework...${NC}"
# Skip tests and license checks to avoid build failures
mvn clean install -DskipTests -Dlicense.skip=true
echo -e "${GREEN}✓ Benchmark framework built${NC}"
cd - > /dev/null

# Create payload data files
echo -e "${YELLOW}Creating payload data files...${NC}"
mkdir -p payload

# Location data (200 bytes)
dd if=/dev/urandom of=payload/location-200b.data bs=200 count=1 2>/dev/null
echo -e "${GREEN}✓ Created location-200b.data${NC}"

# Sensor data (1KB)
dd if=/dev/urandom of=payload/sensor-1kb.data bs=1024 count=1 2>/dev/null
echo -e "${GREEN}✓ Created sensor-1kb.data${NC}"

# Video metadata (10KB)
dd if=/dev/urandom of=payload/video-10kb.data bs=10240 count=1 2>/dev/null
echo -e "${GREEN}✓ Created video-10kb.data${NC}"

# Mixed payload (1.5KB)
dd if=/dev/urandom of=payload/mixed-1.5kb.data bs=1536 count=1 2>/dev/null
echo -e "${GREEN}✓ Created mixed-1.5kb.data${NC}"

# Deploy based on mode
if [ "$MODE" == "local" ]; then
    echo ""
    echo -e "${YELLOW}=====================================${NC}"
    echo -e "${YELLOW}Local Docker Deployment${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    echo ""
    
    if ! command_exists docker; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        exit 1
    fi
    
    if ! command_exists docker compose; then
        echo -e "${RED}Error: docker compose is not installed${NC}"
        exit 1
    fi
    
    # Create docker-compose file
    cat > docker-compose.yml <<'EOF'
services:
  # NATS Cluster
  nats-1:
    image: nats:latest
    ports:
      - "4222:4222"
      - "8222:8222"
    command: "--cluster_name NATS --cluster nats://0.0.0.0:6222 --http_port 8222 -js"
    networks:
      - benchmark-net
  
  nats-2:
    image: nats:latest
    command: "--cluster_name NATS --cluster nats://0.0.0.0:6222 --routes=nats://nats-1:6222 -js"
    networks:
      - benchmark-net
    depends_on:
      - nats-1
  
  nats-3:
    image: nats:latest
    command: "--cluster_name NATS --cluster nats://0.0.0.0:6222 --routes=nats://nats-1:6222 -js"
    networks:
      - benchmark-net
    depends_on:
      - nats-1
  
  # ZooKeeper for Pulsar and Pravega
  zookeeper:
    image: zookeeper:3.8
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    networks:
      - benchmark-net
  
  # Pulsar Standalone (includes broker and bookie)
  pulsar:
    image: apachepulsar/pulsar:latest
    ports:
      - "6650:6650"
      - "8080:8080"
    environment:
      PULSAR_MEM: "-Xmx2g -Xms2g"
    command: bin/pulsar standalone
    networks:
      - benchmark-net
    depends_on:
      - zookeeper
  
  # Pravega Controller
  pravega-controller:
    image: pravega/pravega:latest
    ports:
      - "9090:9090"
      - "10080:10080"
    environment:
      WAIT_FOR: zookeeper:2181
    command: controller
    networks:
      - benchmark-net
    depends_on:
      - zookeeper
  
  # Pravega Segment Store
  pravega-segmentstore:
    image: pravega/pravega:latest
    ports:
      - "12345:12345"
    environment:
      WAIT_FOR: pravega-controller:9090,zookeeper:2181
      HDFS_URL: hdfs://hdfs:9000
    command: segmentstore
    networks:
      - benchmark-net
    depends_on:
      - pravega-controller
      - zookeeper
      - hdfs
  
  # HDFS for Pravega storage
  hdfs:
    image: bde2020/hadoop-namenode:2.0.0-hadoop3.2.1-java8
    ports:
      - "9000:9000"
      - "9870:9870"
    environment:
      CLUSTER_NAME: pravega-cluster
      CORE_CONF_fs_defaultFS: hdfs://hdfs:9000
    volumes:
      - hdfs-data:/hadoop/dfs/name
    networks:
      - benchmark-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9870"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  hdfs-data:

networks:
  benchmark-net:
    driver: bridge
EOF
    
    echo -e "${YELLOW}Starting services with docker compose...${NC}"
    docker compose up -d
    
    echo ""
    echo -e "${GREEN}✓ All services started${NC}"
    echo ""
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"
    sleep 30
    
    echo ""
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}=====================================${NC}"
    echo ""
    echo "Service URLs:"
    echo -e "  NATS: ${YELLOW}nats://localhost:4222${NC}"
    echo -e "  Pulsar: ${YELLOW}pulsar://localhost:6650${NC}"
    echo -e "  Pravega Controller: ${YELLOW}tcp://localhost:9090${NC}"
    echo ""
    echo "To view logs:"
    echo -e "  ${YELLOW}docker-compose logs -f [service-name]${NC}"
    echo ""
    echo "To stop services:"
    echo -e "  ${YELLOW}docker-compose down${NC}"
    echo ""
    
elif [ "$MODE" == "k8s" ]; then
    echo ""
    echo -e "${YELLOW}=====================================${NC}"
    echo -e "${YELLOW}Kubernetes Deployment${NC}"
    echo -e "${YELLOW}=====================================${NC}"
    echo ""
    
    if ! command_exists kubectl; then
        echo -e "${RED}Error: kubectl is not installed${NC}"
        exit 1
    fi
    
    if ! command_exists helm; then
        echo -e "${RED}Error: Helm is not installed${NC}"
        exit 1
    fi
    
    # Create namespace
    echo -e "${YELLOW}Creating namespace: $NAMESPACE${NC}"
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Install NATS
    echo -e "${YELLOW}Installing NATS...${NC}"
    helm repo add nats https://nats-io.github.io/k8s/helm/charts/
    helm repo update
    helm upgrade --install nats nats/nats \
        --namespace $NAMESPACE \
        --set cluster.enabled=true \
        --set cluster.replicas=3 \
        --set nats.jetstream.enabled=true \
        --set nats.jetstream.memStorage.enabled=true \
        --set nats.jetstream.memStorage.size=2Gi \
        --set nats.jetstream.fileStorage.enabled=true \
        --set nats.jetstream.fileStorage.size=10Gi
    
    # Install Pulsar
    echo -e "${YELLOW}Installing Apache Pulsar...${NC}"
    helm repo add apache https://pulsar.apache.org/charts
    helm repo update
    helm upgrade --install pulsar apache/pulsar \
        --namespace $NAMESPACE \
        --set volumes.persistence.default.size=10Gi \
        --set zookeeper.replicaCount=3 \
        --set bookkeeper.replicaCount=3 \
        --set broker.replicaCount=3
    
    # Install Pravega
    echo -e "${YELLOW}Installing Pravega...${NC}"
    helm repo add pravega https://charts.pravega.io
    helm repo update
    helm upgrade --install pravega pravega/pravega \
        --namespace $NAMESPACE \
        --set zookeeper.replicas=3 \
        --set bookkeeper.replicas=3 \
        --set pravega.segmentStoreReplicas=3
    
    echo ""
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}=====================================${NC}"
    echo ""
    echo "To check pod status:"
    echo -e "  ${YELLOW}kubectl get pods -n $NAMESPACE${NC}"
    echo ""
    echo "To access services, use port-forwarding:"
    echo -e "  NATS: ${YELLOW}kubectl port-forward -n $NAMESPACE svc/nats 4222:4222${NC}"
    echo -e "  Pulsar: ${YELLOW}kubectl port-forward -n $NAMESPACE svc/pulsar-broker 6650:6650${NC}"
    echo -e "  Pravega: ${YELLOW}kubectl port-forward -n $NAMESPACE svc/pravega-controller 9090:9090${NC}"
    echo ""
else
    echo -e "${RED}Unknown mode: $MODE${NC}"
    exit 1
fi

echo -e "${GREEN}Setup complete! You can now run benchmarks with:${NC}"
echo -e "  ${YELLOW}./run-benchmark.sh --all${NC}"
echo ""
