# Message Streaming Benchmark - Vehicle IoT Use Case

This project benchmarks **NATS**, **Apache Pulsar**, and **Pravega** using the OpenMessaging Benchmark framework for a vehicle IoT scenario.

## Use Case: 100k Vehicles with Ordered Streaming

### Requirements
- **100,000 vehicles** continuously sending data
- **Message ordering** per vehicle (each vehicle is a partition key)
- **3 payload types** with different sizes:
  - **Location data**: ~200 bytes (GPS coordinates, timestamp, speed)
  - **Sensor data**: ~1KB (temperature, pressure, battery, fuel, etc.)
  - **Video metadata**: ~10KB (video stream metadata, thumbnail info)
- **Scalability**: Easy to scale up/down based on load

### Architecture

Each vehicle ID acts as a **partition key** to ensure ordering:
- Messages from the same vehicle always go to the same partition
- Supports parallel processing across different vehicles
- Maintains strict ordering within each vehicle's message stream

## Project Structure

```
message-benchmark/
├── README.md                          # This file
├── setup.sh                           # Setup script
├── run-benchmark.sh                   # Benchmark execution script
├── drivers/                           # Driver configurations
│   ├── nats.yaml
│   ├── pulsar.yaml
│   └── pravega.yaml
├── workloads/                         # Workload definitions
│   ├── vehicles-location-100k.yaml    # 100k vehicles, location data
│   ├── vehicles-sensor-100k.yaml      # 100k vehicles, sensor data
│   ├── vehicles-video-100k.yaml       # 100k vehicles, video metadata
│   ├── vehicles-mixed-100k.yaml       # Mixed payload types
│   └── vehicles-scale-test.yaml       # Scalability test (10k -> 100k)
└── docs/                              # Documentation
    ├── deployment-guide.md
    ├── results-analysis.md
    └── tuning-guide.md
```

## Quick Start

### Prerequisites

- Java 11 or later
- Maven 3.6+
- Docker and Docker Compose (for local testing)
- Access to NATS, Pulsar, and Pravega clusters (or use deployment guide)

### 1. Clone and Setup

```bash
# Clone the openmessaging-benchmark repository
git clone https://github.com/pravega/openmessaging-benchmark.git
cd openmessaging-benchmark

# Build the benchmark framework
mvn clean install -DskipTests

# Return to this directory
cd /home/hafidmahdi/personal/message-benchmark
```

### 2. Deploy Messaging Systems

Choose your deployment option:

#### Option A: Local Docker Deployment (Development)

```bash
# Deploy all systems locally with Docker Compose
./setup.sh --mode local

# This will start:
# - NATS cluster (3 nodes)
# - Pulsar cluster (3 brokers + ZooKeeper)
# - Pravega cluster (3 segment stores + controller)
```

#### Option B: Kubernetes Deployment (Production)

```bash
# Deploy to Kubernetes
./setup.sh --mode k8s --namespace benchmark

# Or follow the detailed guide
cat docs/deployment-guide.md
```

### 3. Run Benchmarks

```bash
# Run all vehicle workloads for all drivers
./run-benchmark.sh --all

# Run specific workload
./run-benchmark.sh --workload vehicles-location-100k --driver pulsar

# Run scalability test
./run-benchmark.sh --workload vehicles-scale-test --drivers nats,pulsar,pravega

# Run with custom duration
./run-benchmark.sh --workload vehicles-mixed-100k --driver nats --duration 30
```

### 4. View Results

Results are saved in JSON format with timestamp:
```bash
ls -lh results/
# vehicles-location-100k-nats-2025-11-10-143022.json
# vehicles-location-100k-pulsar-2025-11-10-144533.json
# vehicles-location-100k-pravega-2025-11-10-150044.json
```

Generate comparison charts:
```bash
python3 generate-charts.py results/
```

## Workload Descriptions

### 1. Location Data (vehicles-location-100k.yaml)
- **Scenario**: GPS location updates every 5 seconds
- **Topics**: 100 topics (1000 vehicles per topic)
- **Partitions**: 1000 per topic (1 vehicle = 1 partition)
- **Message Size**: 200 bytes
- **Rate**: ~20,000 messages/sec (100k vehicles / 5 sec)
- **Test Duration**: 15 minutes

### 2. Sensor Data (vehicles-sensor-100k.yaml)
- **Scenario**: Engine and environmental sensors every 10 seconds
- **Topics**: 100 topics
- **Partitions**: 1000 per topic
- **Message Size**: 1KB
- **Rate**: ~10,000 messages/sec
- **Test Duration**: 15 minutes

### 3. Video Metadata (vehicles-video-100k.yaml)
- **Scenario**: Video stream metadata every 30 seconds
- **Topics**: 100 topics
- **Partitions**: 1000 per topic
- **Message Size**: 10KB
- **Rate**: ~3,333 messages/sec
- **Test Duration**: 15 minutes

### 4. Mixed Payload (vehicles-mixed-100k.yaml)
- **Scenario**: All three payload types mixed
- **Topics**: 100 topics
- **Partitions**: 1000 per topic
- **Message Sizes**: 200B, 1KB, 10KB mixed
- **Rate**: Variable (simulates realistic traffic)
- **Test Duration**: 30 minutes

### 5. Scale Test (vehicles-scale-test.yaml)
- **Scenario**: Gradually scale from 10k to 100k vehicles
- **Purpose**: Test system behavior under increasing load
- **Test Duration**: 30 minutes

## Key Metrics Compared

The benchmark measures and compares:

1. **Throughput**
   - Messages per second (publish/consume)
   - MB/s (data throughput)

2. **Latency**
   - Publish latency (50th, 95th, 99th percentile)
   - End-to-end latency
   - Latency under load

3. **Ordering Guarantee**
   - Per-vehicle message ordering verification
   - Out-of-order message detection

4. **Scalability**
   - Linear scaling with partition count
   - Resource utilization at scale

5. **Availability**
   - Behavior during node failures
   - Recovery time

6. **Resource Usage**
   - CPU utilization
   - Memory footprint
   - Network bandwidth
   - Storage requirements

## Driver-Specific Features

### NATS
- **Ordering**: Ensured through subject-based routing
- **Partitioning**: Using JetStream with stream per topic
- **Scaling**: Horizontal scaling with clustered NATS servers

### Apache Pulsar
- **Ordering**: Per-partition ordering with keyed messages
- **Partitioning**: Native partitioned topics (1000 partitions)
- **Scaling**: Automatic load balancing across brokers

### Pravega
- **Ordering**: Per-routing-key ordering (vehicle ID as routing key)
- **Partitioning**: Dynamic stream segmentation (auto-scaling)
- **Scaling**: Elastic scaling with segment-based architecture

## Expected Results

Based on the use case characteristics:

| Metric | NATS | Pulsar | Pravega |
|--------|------|--------|---------|
| Max Throughput | 500K+ msg/s | 300K+ msg/s | 250K+ msg/s |
| p99 Latency (normal load) | <10ms | <20ms | <30ms |
| Ordering Guarantee | ✅ Strong | ✅ Strong | ✅ Strong |
| Auto-scaling | Manual | ✅ Good | ✅ Excellent |
| Storage Efficiency | ✅ Excellent | Good | ✅ Excellent |

## Customization

### Adjust Vehicle Count

Edit workload files to change vehicle count:
```yaml
# workloads/vehicles-location-100k.yaml
topics: 50                    # Reduce to 50 topics for 50k vehicles
partitionsPerTopic: 1000      # Keep 1000 partitions per topic
```

### Adjust Message Rates

```yaml
producerRate: 10000  # Messages per second (0 = max throughput)
```

### Adjust Test Duration

```yaml
testDurationMinutes: 15  # Duration in minutes
```

## Troubleshooting

### Out of Memory Errors

```bash
# Increase Java heap size
export JAVA_OPTS="-Xmx8g -Xms8g"
./run-benchmark.sh --workload vehicles-location-100k
```

### Connection Timeouts

Check driver configuration URLs in `drivers/*.yaml` files and ensure services are accessible.

### Slow Performance

Review the tuning guide:
```bash
cat docs/tuning-guide.md
```

## Contributing

To add new workloads or modify existing ones:

1. Create a new YAML file in `workloads/`
2. Follow the schema from existing workloads
3. Test with a single driver first
4. Document the scenario in this README

## References

- [OpenMessaging Benchmark Framework](https://github.com/pravega/openmessaging-benchmark)
- [NATS Documentation](https://docs.nats.io/)
- [Apache Pulsar Documentation](https://pulsar.apache.org/docs/)
- [Pravega Documentation](https://pravega.io/docs/)

## License

This benchmark configuration is provided as-is under Apache 2.0 License.
