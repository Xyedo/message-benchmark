# Project Summary

## Overview

This project provides a comprehensive benchmarking framework for comparing **NATS**, **Apache Pulsar**, and **Pravega** streaming platforms using a realistic **vehicle IoT use case** with **100,000 vehicles**.

## What's Been Created

### ✅ Complete Benchmark Suite

1. **6 Workload Configurations** (`workloads/`)
   - `vehicles-location-100k.yaml` - GPS location updates (200B, 5s interval)
   - `vehicles-sensor-100k.yaml` - Sensor data (1KB, 10s interval)
   - `vehicles-video-100k.yaml` - Video metadata (10KB, 30s interval)
   - `vehicles-mixed-100k.yaml` - Mixed payload types (realistic scenario)
   - `vehicles-scale-test.yaml` - Maximum throughput discovery
   - `vehicles-backlog-test.yaml` - Consumer lag/recovery testing

2. **3 Driver Configurations** (`drivers/`)
   - `nats.yaml` - NATS with JetStream for ordered messaging
   - `pulsar.yaml` - Pulsar with Key_Shared subscription for parallel ordered processing
   - `pravega.yaml` - Pravega with auto-scaling segments and routing keys

3. **Automation Scripts**
   - `setup.sh` - One-command deployment (Docker or Kubernetes)
   - `run-benchmark.sh` - Flexible benchmark execution
   - `generate-charts.py` - Automated visualization and reporting

4. **Documentation** (`docs/`)
   - `quick-start.md` - Get running in 30 minutes
   - `deployment-guide.md` - Detailed deployment for all environments
   - `tuning-guide.md` - Performance optimization recommendations

## Key Features

### 🎯 Realistic Use Case
- **100,000 vehicles** sending ordered data
- **3 payload types** (location, sensor, video)
- **Partition-based ordering** (vehicle ID as key)
- **Mixed workload** simulating real-world traffic
- **Scalability testing** from 10k to 100k vehicles

### 📊 Comprehensive Metrics
- **Throughput**: Publish/consume rates
- **Latency**: P50, P95, P99, end-to-end
- **Ordering**: Per-vehicle message ordering
- **Scalability**: Linear scaling verification
- **Availability**: Failure recovery behavior

### 🚀 Easy to Use
- **Single command** deployment
- **Flexible execution** (single or all workloads)
- **Automated visualization** (charts and reports)
- **Multiple environments** (local, K8s, cloud)

### 🔧 Highly Configurable
- Adjust vehicle count
- Modify message rates
- Change test duration
- Customize payload sizes
- Fine-tune system parameters

## Architecture

```
Vehicle Fleet (100k vehicles)
     │
     ├─ Location Updates (200B @ 5s)  ──┐
     ├─ Sensor Data (1KB @ 10s)        ├─> Messaging System
     └─ Video Metadata (10KB @ 30s)    ─┘      (NATS/Pulsar/Pravega)
                                                      │
                                                      ├─> Consumer Group 1
                                                      ├─> Consumer Group 2
                                                      └─> Consumer Group N
```

## Directory Structure

```
message-benchmark/
├── README.md                          # Main documentation
├── setup.sh                           # Deployment script
├── run-benchmark.sh                   # Benchmark execution
├── generate-charts.py                 # Results visualization
├── .gitignore                         # Git ignore rules
│
├── workloads/                         # Workload definitions
│   ├── vehicles-location-100k.yaml
│   ├── vehicles-sensor-100k.yaml
│   ├── vehicles-video-100k.yaml
│   ├── vehicles-mixed-100k.yaml
│   ├── vehicles-scale-test.yaml
│   └── vehicles-backlog-test.yaml
│
├── drivers/                           # Driver configurations
│   ├── nats.yaml
│   ├── pulsar.yaml
│   └── pravega.yaml
│
└── docs/                              # Documentation
    ├── quick-start.md
    ├── deployment-guide.md
    └── tuning-guide.md
```

## Quick Start

```bash
# 1. Setup (10 minutes)
./setup.sh --mode local

# 2. Run benchmark (15 minutes)
./run-benchmark.sh \
  --workload vehicles-location-100k \
  --drivers nats,pulsar,pravega

# 3. Generate charts (1 minute)
python3 generate-charts.py results/

# 4. View results
cat results/charts/comparison_report.md
```

## Expected Results

Based on the use case characteristics:

### Throughput
- **NATS**: 500K+ msg/s (best for small messages)
- **Pulsar**: 300K+ msg/s (balanced)
- **Pravega**: 250K+ msg/s (best for large messages)

### Latency (P99)
- **NATS**: <10ms (lowest latency)
- **Pulsar**: <20ms (good balance)
- **Pravega**: <30ms (acceptable with benefits)

### Ordering
- **All three**: ✅ Strong ordering guarantee per vehicle

### Scalability
- **NATS**: Manual scaling, horizontal
- **Pulsar**: Good auto-balancing
- **Pravega**: ✅ Excellent auto-scaling

### Storage Efficiency
- **NATS**: ✅ Excellent (JetStream)
- **Pulsar**: Good (tiered storage)
- **Pravega**: ✅ Excellent (tiered, indexed)

## Use Case Requirements

✅ **100,000 vehicles** - Supported via partitioning strategy
✅ **Ordered messaging** - Vehicle ID as partition/routing key
✅ **Location payload** - 200B messages @ 5s interval
✅ **Sensor payload** - 1KB messages @ 10s interval
✅ **Video payload** - 10KB messages @ 30s interval
✅ **Easy scaling** - Horizontal and vertical scaling supported

## Next Steps

### For Quick Evaluation (1 hour)
1. Run `./setup.sh --mode local`
2. Run `./run-benchmark.sh --workload vehicles-location-100k --drivers nats,pulsar,pravega --duration 5`
3. Generate and review charts

### For Thorough Evaluation (1 day)
1. Deploy to Kubernetes: `./setup.sh --mode k8s`
2. Run full suite: `./run-benchmark.sh --all`
3. Review all workloads and metrics
4. Apply tuning recommendations
5. Re-run and compare

### For Production Decision (1 week)
1. Set up production-like environment
2. Run extended tests (24+ hours)
3. Test failure scenarios
4. Evaluate operational complexity
5. Consider total cost of ownership
6. Make informed decision

## System Comparison Summary

| Feature | NATS | Pulsar | Pravega |
|---------|------|--------|---------|
| **Throughput** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Latency** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| **Ordering** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Auto-scaling** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Storage** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Ops Simplicity** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Ecosystem** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

### Best For...

**NATS**: 
- Lowest latency requirements
- Simpler operational model
- Smaller message sizes
- Cloud-native deployments

**Pulsar**:
- Balanced requirements
- Large ecosystem/tooling
- Multi-tenancy needs
- Geo-replication

**Pravega**:
- Best auto-scaling
- Long-term storage
- Stream processing integration
- Exactly-once semantics

## Technical Highlights

### Message Ordering
All three systems guarantee ordering per key (vehicle ID):
- **NATS**: Subject-based routing
- **Pulsar**: Key_Shared subscriptions
- **Pravega**: Routing key to segment mapping

### Partitioning Strategy
- **100 topics** × **1,000 partitions** = 100,000 vehicles
- Each vehicle = 1 partition = Ordering guarantee
- Allows parallel processing across vehicles

### Performance Optimization
- Batching for throughput
- Compression for bandwidth
- Caching for read performance
- Auto-scaling for elasticity

## Resources

- **Main README**: [README.md](../README.md)
- **Quick Start**: [docs/quick-start.md](quick-start.md)
- **Deployment**: [docs/deployment-guide.md](deployment-guide.md)
- **Tuning**: [docs/tuning-guide.md](tuning-guide.md)
- **OpenMessaging Benchmark**: https://github.com/pravega/openmessaging-benchmark
- **NATS**: https://docs.nats.io/
- **Pulsar**: https://pulsar.apache.org/docs/
- **Pravega**: https://pravega.io/docs/

## Support

For issues or questions:
1. Check the documentation in `docs/`
2. Review workload YAML files for configuration examples
3. Check driver YAML files for system-specific settings
4. Consult the OpenMessaging Benchmark documentation
5. Review individual system documentation

## License

Apache 2.0 License

---

**Created**: November 2025  
**Use Case**: Vehicle IoT Streaming with 100k Vehicles  
**Systems**: NATS, Apache Pulsar, Pravega  
**Framework**: OpenMessaging Benchmark
