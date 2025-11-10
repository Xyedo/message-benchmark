# Quick Start Guide

Get up and running with the vehicle IoT streaming benchmark in under 30 minutes.

## 1. Prerequisites (5 minutes)

### Install Java and Maven

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y openjdk-11-jdk maven

# macOS
brew install openjdk@11 maven

# Verify installation
java -version
mvn -version
```

### Install Docker and Docker Compose

```bash
# Ubuntu/Debian
sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect

# macOS
brew install docker docker-compose

# Verify installation
docker --version
docker-compose --version
```

### Install Python and matplotlib

```bash
# Ubuntu/Debian
sudo apt install -y python3 python3-pip
pip3 install matplotlib numpy

# macOS
brew install python3
pip3 install matplotlib numpy

# Verify installation
python3 --version
```

## 2. Setup (10 minutes)

### Clone and Setup

```bash
# Navigate to your workspace
cd /home/hafidmahdi/personal/message-benchmark

# Run setup script (this will take ~10 minutes)
./setup.sh --mode local
```

This will:
- Clone and build the OpenMessaging benchmark framework
- Create test payload files
- Start NATS, Pulsar, and Pravega with Docker Compose
- Wait for services to be ready

### Verify Services

```bash
# Check Docker containers
docker-compose ps

# All containers should show "Up" status
# If any are unhealthy, check logs:
docker-compose logs [service-name]
```

### Test Connectivity

```bash
# Quick smoke test
./run-benchmark.sh \
  --workload vehicles-location-100k \
  --driver nats \
  --duration 1
```

## 3. Run Your First Benchmark (5 minutes)

### Option A: Single Workload, Single Driver

```bash
# Test location data workload on NATS
./run-benchmark.sh \
  --workload vehicles-location-100k \
  --driver nats
```

### Option B: Single Workload, All Drivers

```bash
# Compare all three systems with location data
./run-benchmark.sh \
  --workload vehicles-location-100k \
  --drivers nats,pulsar,pravega
```

### Option C: All Workloads, All Drivers (Full Suite)

```bash
# Run complete benchmark suite (~2-3 hours)
./run-benchmark.sh --all
```

## 4. View Results (5 minutes)

### Generate Charts

```bash
# Generate comparison charts
python3 generate-charts.py results/
```

### View Summary

```bash
# Text summary
cat results/charts/summary.txt

# Detailed markdown report
cat results/charts/comparison_report.md
```

### View Charts

Charts are saved in `results/charts/[workload-name]/`:
- `throughput_comparison.png` - Messages per second
- `latency_comparison.png` - P50, P95, P99 latencies
- `end_to_end_latency_comparison.png` - End-to-end latencies

## 5. Customize (Optional)

### Adjust Vehicle Count

Edit workload files to test with different scales:

```yaml
# workloads/vehicles-location-100k.yaml
topics: 50                    # 50k vehicles (from 100)
partitionsPerTopic: 1000      # Keep same partitioning
producerRate: 10000           # Adjust rate accordingly
```

### Adjust Message Rates

```yaml
# For max throughput test
producerRate: 0  # 0 = discover maximum sustainable rate

# For specific rate
producerRate: 50000  # 50k messages/second
```

### Adjust Test Duration

```bash
# Use command line
./run-benchmark.sh \
  --workload vehicles-location-100k \
  --duration 5  # 5 minutes instead of default

# Or edit workload file
testDurationMinutes: 5
```

## Common Commands

```bash
# View running services
docker-compose ps

# View service logs
docker-compose logs -f nats-1
docker-compose logs -f pulsar
docker-compose logs -f pravega-controller

# Restart a service
docker-compose restart nats-1

# Stop all services
docker-compose down

# Start services again
docker-compose up -d

# Remove all data and restart fresh
docker-compose down -v
./setup.sh --mode local
```

## Troubleshooting

### Services Not Starting

```bash
# Check Docker logs
docker-compose logs

# Restart services
docker-compose down
docker-compose up -d

# Wait 30 seconds
sleep 30
docker-compose ps
```

### Benchmark Fails to Connect

```bash
# Check driver configuration
cat drivers/nats.yaml
cat drivers/pulsar.yaml
cat drivers/pravega.yaml

# Ensure URLs match your deployment
# For local Docker: localhost
# For remote: update to actual IP/hostname
```

### Out of Memory

```bash
# Increase Docker memory limit
# Docker Desktop: Settings → Resources → Memory → 8 GB+

# Or reduce workload scale
# Edit workload YAML: reduce topics or producerRate
```

### Slow Performance

```bash
# Check system resources
docker stats

# Ensure sufficient resources:
# - CPU: 8+ cores recommended
# - RAM: 16+ GB recommended
# - Disk: SSD strongly recommended

# Review tuning guide
cat docs/tuning-guide.md
```

## Next Steps

### For Development/Testing

1. Run quick tests with reduced scale:
   ```bash
   ./run-benchmark.sh \
     --workload vehicles-location-100k \
     --duration 5 \
     --driver nats
   ```

2. Iterate on configurations
3. Compare results

### For Production Evaluation

1. Deploy to Kubernetes:
   ```bash
   ./setup.sh --mode k8s --namespace benchmark
   ```

2. Run full benchmark suite:
   ```bash
   ./run-benchmark.sh --all
   ```

3. Analyze results and make decision

4. Review deployment guide:
   ```bash
   cat docs/deployment-guide.md
   ```

### For Optimization

1. Run baseline benchmarks
2. Review tuning guide
3. Apply optimizations one at a time
4. Re-run benchmarks
5. Compare before/after results

## Example Workflow

```bash
# 1. Setup (one time)
./setup.sh --mode local

# 2. Run quick test
./run-benchmark.sh \
  --workload vehicles-location-100k \
  --drivers nats,pulsar,pravega \
  --duration 5

# 3. Generate charts
python3 generate-charts.py results/

# 4. View results
cat results/charts/summary.txt
open results/charts/vehicles-location-100k/throughput_comparison.png

# 5. Run full suite (when ready)
./run-benchmark.sh --all

# 6. Generate final report
python3 generate-charts.py results/
cat results/charts/comparison_report.md
```

## Tips for Best Results

1. **Close other applications** to free up resources
2. **Use SSD** for storage if possible
3. **Warm up** - First run may be slower
4. **Run multiple times** - Average results for accuracy
5. **Monitor resources** - Watch CPU, memory, disk I/O
6. **Check logs** - Look for errors or warnings
7. **Start small** - Test with 10k vehicles first
8. **Scale gradually** - 10k → 50k → 100k

## Getting Help

- Check the main [README.md](../README.md)
- Review [deployment-guide.md](deployment-guide.md)
- Read [tuning-guide.md](tuning-guide.md)
- Examine workload YAML files in `workloads/`
- Check driver configurations in `drivers/`
- Look at OpenMessaging Benchmark docs: https://github.com/pravega/openmessaging-benchmark

## Success Checklist

- [ ] Java, Maven, Docker installed
- [ ] Setup script completed successfully
- [ ] All services running (docker-compose ps)
- [ ] Connectivity test passed
- [ ] First benchmark completed
- [ ] Results generated
- [ ] Charts created
- [ ] Ready for full evaluation!

Congratulations! You're ready to benchmark NATS, Pulsar, and Pravega for your vehicle IoT use case.
