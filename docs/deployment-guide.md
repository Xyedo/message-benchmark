# Deployment Guide

This guide provides detailed instructions for deploying the messaging systems for benchmarking.

## Prerequisites

- **Hardware**:
  - Minimum: 16 GB RAM, 8 CPU cores, 100 GB disk
  - Recommended: 32 GB RAM, 16 CPU cores, 500 GB SSD
  
- **Software**:
  - Java 11 or later
  - Maven 3.6+
  - Docker and Docker Compose (for local deployment)
  - kubectl and Helm (for Kubernetes deployment)
  - Python 3.7+ with matplotlib (for chart generation)

## Deployment Options

### Option 1: Local Docker Deployment (Development/Testing)

Best for: Development, testing, small-scale benchmarks

```bash
# Run the setup script
./setup.sh --mode local

# This will start:
# - NATS cluster (3 nodes with JetStream)
# - Pulsar standalone (includes broker and bookkeeper)
# - Pravega (controller + segment store + HDFS)
# - ZooKeeper (shared by Pulsar and Pravega)
```

**Services will be available at:**
- NATS: `nats://localhost:4222`
- NATS Monitoring: `http://localhost:8222`
- Pulsar: `pulsar://localhost:6650`
- Pulsar Admin: `http://localhost:8080`
- Pravega Controller: `tcp://localhost:9090`
- Pravega REST: `http://localhost:10080`

**To check status:**
```bash
docker-compose ps
```

**To view logs:**
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f nats-1
docker-compose logs -f pulsar
docker-compose logs -f pravega-controller
```

**To stop services:**
```bash
docker-compose down

# To remove volumes as well
docker-compose down -v
```

### Option 2: Kubernetes Deployment (Production)

Best for: Production-like testing, large-scale benchmarks

```bash
# Deploy to Kubernetes
./setup.sh --mode k8s --namespace benchmark

# This will install using Helm:
# - NATS Operator with 3-node cluster
# - Apache Pulsar with separate components
# - Pravega with BookKeeper backend
```

**Check deployment status:**
```bash
# Check all pods
kubectl get pods -n benchmark

# Check services
kubectl get svc -n benchmark

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod --all -n benchmark --timeout=600s
```

**Access services:**

Using port-forwarding:

```bash
# NATS
kubectl port-forward -n benchmark svc/nats 4222:4222 &

# Pulsar
kubectl port-forward -n benchmark svc/pulsar-broker 6650:6650 8080:8080 &

# Pravega
kubectl port-forward -n benchmark svc/pravega-controller 9090:9090 10080:10080 &
```

**Update driver configurations:**

Edit the driver YAML files to use the appropriate URLs:

```yaml
# drivers/nats.yaml
natsUrl: nats://nats.benchmark.svc.cluster.local:4222

# drivers/pulsar.yaml
client:
  serviceUrl: pulsar://pulsar-broker.benchmark.svc.cluster.local:6650
  httpUrl: http://pulsar-broker.benchmark.svc.cluster.local:8080

# drivers/pravega.yaml
client:
  controllerURI: tcp://pravega-controller.benchmark.svc.cluster.local:9090
```

### Option 3: Cloud Deployment (AWS/GCP/Azure)

#### AWS Deployment

**Prerequisites:**
- AWS CLI configured
- kubectl configured for EKS
- Helm 3.x installed

**1. Create EKS Cluster:**
```bash
eksctl create cluster \
  --name message-benchmark \
  --region us-west-2 \
  --nodegroup-name standard-workers \
  --node-type m5.2xlarge \
  --nodes 5 \
  --nodes-min 3 \
  --nodes-max 10 \
  --managed
```

**2. Install Storage Class:**
```bash
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
volumeBindingMode: WaitForFirstConsumer
EOF
```

**3. Deploy messaging systems:**
```bash
./setup.sh --mode k8s --namespace benchmark
```

**4. Scale if needed:**
```bash
# Scale NATS
helm upgrade nats nats/nats \
  --namespace benchmark \
  --set cluster.replicas=5

# Scale Pulsar
helm upgrade pulsar apache/pulsar \
  --namespace benchmark \
  --set broker.replicaCount=5 \
  --set bookkeeper.replicaCount=5

# Scale Pravega
helm upgrade pravega pravega/pravega \
  --namespace benchmark \
  --set pravega.segmentStoreReplicas=5 \
  --set bookkeeper.replicas=5
```

## Configuration for 100k Vehicles

### NATS Configuration

For 100k vehicles with ordering requirements:

```yaml
# Recommended JetStream configuration
jetstream:
  maxMemoryStore: 10Gi
  maxFileStore: 100Gi
  
# Stream configuration per topic
stream:
  replicas: 3  # For HA
  retention: limits
  maxAge: 24h
  maxBytes: 10GB
```

### Pulsar Configuration

For 100k partitions:

```yaml
# Broker configuration
broker:
  replicaCount: 5
  resources:
    requests:
      memory: 8Gi
      cpu: 4
    limits:
      memory: 16Gi
      cpu: 8

# BookKeeper configuration
bookkeeper:
  replicaCount: 5
  resources:
    requests:
      memory: 8Gi
      cpu: 4
    limits:
      memory: 16Gi
      cpu: 8
  
  # Journal and ledger storage
  journal:
    volumeClaimTemplate:
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 50Gi
  
  ledgers:
    volumeClaimTemplate:
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 500Gi
```

### Pravega Configuration

For 100k vehicles with auto-scaling:

```yaml
# Segment Store configuration
segmentStore:
  replicas: 5
  resources:
    requests:
      memory: 8Gi
      cpu: 4
    limits:
      memory: 16Gi
      cpu: 8
  
  # Storage configuration
  storage:
    className: fast-ssd
    size: 500Gi

# Controller configuration
controller:
  replicas: 3
  resources:
    requests:
      memory: 2Gi
      cpu: 1
    limits:
      memory: 4Gi
      cpu: 2
```

## Resource Requirements

### Minimum Configuration (10k vehicles)

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| NATS | 2 cores | 4 GB | 20 GB |
| Pulsar | 4 cores | 8 GB | 50 GB |
| Pravega | 4 cores | 8 GB | 50 GB |
| **Total** | **10 cores** | **20 GB** | **120 GB** |

### Recommended Configuration (100k vehicles)

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| NATS | 8 cores | 16 GB | 100 GB |
| Pulsar | 16 cores | 32 GB | 500 GB |
| Pravega | 16 cores | 32 GB | 500 GB |
| **Total** | **40 cores** | **80 GB** | **1.1 TB** |

## Network Configuration

### Firewall Rules

Required ports:

**NATS:**
- 4222: Client connections
- 6222: Cluster routing
- 8222: Monitoring/HTTP

**Pulsar:**
- 6650: Broker service (binary protocol)
- 8080: HTTP admin API
- 6651: Broker service (TLS, if enabled)

**Pravega:**
- 9090: Controller
- 12345: Segment Store
- 10080: REST API

### Bandwidth Requirements

For 100k vehicles:

- **Location updates** (200B @ 5s): ~4 MB/s
- **Sensor data** (1KB @ 10s): ~10 MB/s
- **Video metadata** (10KB @ 30s): ~33 MB/s

**Total estimated bandwidth**: ~50 MB/s (400 Mbps)

**Recommended**: 1 Gbps network

## Monitoring Setup

### Prometheus and Grafana

```bash
# Install Prometheus
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

# Configure scraping for messaging systems
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceMonitor
metadata:
  name: nats-metrics
  namespace: benchmark
spec:
  selector:
    matchLabels:
      app: nats
  endpoints:
  - port: metrics
    interval: 30s
EOF
```

### Dashboards

Import pre-built dashboards:
- NATS: https://grafana.com/grafana/dashboards/2279
- Pulsar: https://grafana.com/grafana/dashboards/10150
- Pravega: https://grafana.com/grafana/dashboards/13996

## Troubleshooting

### NATS Issues

**Problem**: JetStream not available
```bash
# Check JetStream status
nats server info

# Enable JetStream
nats server jetstream enable
```

### Pulsar Issues

**Problem**: Topics not creating
```bash
# Check broker logs
kubectl logs -n benchmark pulsar-broker-0

# Manually create namespace
bin/pulsar-admin namespaces create public/vehicles
```

**Problem**: High latency
```bash
# Check BookKeeper status
bin/bookkeeper shell bookiesanity
```

### Pravega Issues

**Problem**: Streams not scaling
```bash
# Check controller logs
kubectl logs -n benchmark pravega-controller-0

# Check segment store status
kubectl logs -n benchmark pravega-segmentstore-0
```

## Security Considerations

### Enable TLS/SSL

**NATS:**
```yaml
nats:
  tls:
    enabled: true
    cert: /path/to/cert
    key: /path/to/key
    ca: /path/to/ca
```

**Pulsar:**
```yaml
broker:
  tls:
    enabled: true
    certSecretName: pulsar-tls
```

**Pravega:**
```yaml
controller:
  security:
    tls:
      enabled: true
```

### Enable Authentication

Refer to individual system documentation for authentication setup.

## Next Steps

After deployment:

1. Verify all services are running
2. Update driver configuration files with correct URLs
3. Run a small test workload to verify connectivity
4. Proceed with full benchmark suite

```bash
# Quick connectivity test
./run-benchmark.sh --workload vehicles-location-100k --driver nats --duration 1
```
