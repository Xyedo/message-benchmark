# Performance Tuning Guide

This guide provides recommendations for optimizing NATS, Pulsar, and Pravega for the vehicle IoT use case.

## General Principles

1. **Understand your workload**: 100k vehicles, ordered messages, mixed payload sizes
2. **Start with defaults**: Establish baseline performance
3. **Change one parameter at a time**: Measure impact
4. **Monitor everything**: CPU, memory, disk I/O, network
5. **Test at scale**: 10k → 50k → 100k vehicles

## NATS Tuning

### JetStream Configuration

```yaml
# server.conf
jetstream {
    max_memory_store: 10GB
    max_file_store: 100GB
    store_dir: /data/jetstream
    
    # Increase limits for high throughput
    max_outstanding_catchup: 16MB
}
```

### Stream Configuration

For vehicle streams with ordering:

```bash
nats stream add VEHICLES \
  --subjects "vehicles.>" \
  --storage file \
  --retention limits \
  --max-age 24h \
  --max-bytes 10GB \
  --replicas 3 \
  --discard old \
  --max-msg-size 1MB
```

### Consumer Configuration

```bash
nats consumer add VEHICLES CONSUMER \
  --ack explicit \
  --max-deliver 5 \
  --max-pending 10000 \
  --max-ack-pending 1000
```

### Performance Tips

1. **Use file storage** for durability (not memory)
2. **Set appropriate max-age**: Balance retention vs storage
3. **Tune max-ack-pending**: Higher = more throughput, more memory
4. **Enable compression** at client level for large payloads
5. **Use dedicated JetStream server** for heavy workloads

### NATS Server Limits

```yaml
# server.conf
max_connections: 10000
max_control_line: 4096
max_payload: 1048576  # 1MB
write_deadline: "10s"

# Clustering
cluster {
    compression: enabled
    compression_level: 6  # 1-9, higher = better compression
}
```

## Apache Pulsar Tuning

### Broker Configuration

```properties
# broker.conf

# Memory settings
managedLedgerMaxEntriesPerLedger=50000
managedLedgerMinLedgerRolloverTimeMinutes=10
managedLedgerMaxLedgerRolloverTimeMinutes=240

# Cache settings
managedLedgerCacheSizeMB=2048
managedLedgerCacheEvictionWatermark=0.9

# Batching
maxMessageSize=5242880  # 5MB
maxPublishRate=100000   # Per producer

# Thread pools
numIOThreads=8
numWorkerThreads=8

# Load balancing
loadBalancerAutoBundleSplitEnabled=true
loadBalancerAutoUnloadSplitBundlesEnabled=true
```

### BookKeeper Configuration

```properties
# bookkeeper.conf

# Journal
journalMaxSizeMB=2048
journalMaxBackups=5
journalFlushWhenQueueEmpty=false
journalAdaptiveGroupWrites=true

# Write performance
journalWriteBufferSizeKB=256
journalPreAllocSizeMB=16

# Read performance
readBufferSizeBytes=4096
numAddWorkerThreads=8
numReadWorkerThreads=8

# Storage
ledgerStorageClass=org.apache.bookkeeper.bookie.storage.ldb.DbLedgerStorage
dbStorage_writeCacheMaxSizeMb=512
dbStorage_readAheadCacheMaxSizeMb=512
```

### Topic Configuration

For vehicle topics (100 topics × 1000 partitions):

```bash
# Create namespace with policies
bin/pulsar-admin namespaces create public/vehicles

# Set retention
bin/pulsar-admin namespaces set-retention public/vehicles \
  --size 100G --time 168h

# Set message TTL
bin/pulsar-admin namespaces set-message-ttl public/vehicles \
  --messageTTL 604800  # 7 days

# Enable deduplication
bin/pulsar-admin namespaces set-deduplication public/vehicles \
  --enable

# Set max unacked messages
bin/pulsar-admin namespaces set-max-unacked-messages-per-consumer \
  public/vehicles -m 50000
```

### Producer Configuration

```java
// Java client example
Producer<byte[]> producer = client.newProducer()
    .topic("vehicles-location")
    .enableBatching(true)
    .batchingMaxMessages(1000)
    .batchingMaxPublishDelay(10, TimeUnit.MILLISECONDS)
    .compressionType(CompressionType.LZ4)
    .blockIfQueueFull(true)
    .maxPendingMessages(10000)
    .sendTimeout(30, TimeUnit.SECONDS)
    .create();
```

### Consumer Configuration

```java
// Key_Shared subscription for ordered parallel processing
Consumer<byte[]> consumer = client.newConsumer()
    .topic("vehicles-location")
    .subscriptionName("fleet-monitor")
    .subscriptionType(SubscriptionType.Key_Shared)
    .receiverQueueSize(1000)
    .ackTimeout(30, TimeUnit.SECONDS)
    .negativeAckRedeliveryDelay(60, TimeUnit.SECONDS)
    .subscribe();
```

### JVM Tuning

```bash
# Broker JVM settings
PULSAR_MEM="-Xms8g -Xmx8g -XX:MaxDirectMemorySize=8g"
PULSAR_GC="-XX:+UseG1GC -XX:MaxGCPauseMillis=10"

# BookKeeper JVM settings
BOOKIE_MEM="-Xms8g -Xmx8g -XX:MaxDirectMemorySize=8g"
BOOKIE_GC="-XX:+UseG1GC -XX:MaxGCPauseMillis=10"
```

## Pravega Tuning

### Controller Configuration

```properties
# controller.conf

# Thread pools
controller.container.count=16
controller.async.taskPool.size=20

# Transaction settings (if using transactions)
controller.transaction.maxLeaseValue=120000
controller.transaction.ttl.hours=24

# Auto-scaling
controller.retention.frequencyMinutes=30
controller.scale.stream.periodicProcessing=true
```

### Segment Store Configuration

```properties
# segmentstore.conf

# Cache settings
pravegaservice.cachePolicy.maxSize=1073741824  # 1GB
pravegaservice.cachePolicy.maxTime=300000      # 5 minutes

# Thread pools
pravegaservice.storageThreadPool.size=20
pravegaservice.coreThreadPool.size=20

# Write settings
writer.maxItemsToReadAtOnce=1000
writer.maxItemsPerBatch=100
writer.maxTimePerBatch.millis=100
writer.flushThresholdBytes=4194304  # 4MB
writer.flushThresholdMillis=30000   # 30 seconds

# Read settings
reader.maxItemsAtOnce=1000

# Tier 1 (cache) settings
storageLayout.rollingPolicy.maxLength=536870912  # 512MB
storageLayout.rollingPolicy.maxDuration=3600000  # 1 hour
```

### Stream Configuration

```yaml
# Auto-scaling configuration for vehicle streams
stream:
  scalingPolicy:
    type: BY_RATE_PER_PARTITION
    targetRate: 1000  # events/sec per segment
    scaleFactor: 2
    minSegments: 10
```

### Writer Configuration

```java
// Java client example
EventStreamClientFactory clientFactory = EventStreamClientFactory
    .withScope("vehicles", clientConfig);

EventStreamWriter<VehicleData> writer = clientFactory
    .createEventWriter(
        "location-stream",
        new JavaSerializer<VehicleData>(),
        EventWriterConfig.builder()
            .enableConnectionPooling(true)
            .automaticallyNoteTime(true)
            .build()
    );
```

### Reader Configuration

```java
// Reader group configuration for ordered processing
ReaderGroupConfig readerGroupConfig = ReaderGroupConfig.builder()
    .stream("vehicles/location-stream")
    .automaticCheckpointIntervalMillis(30000)  # 30 seconds
    .maxOutstandingCheckpointRequest(5)
    .build();
```

### JVM Tuning

```bash
# Segment Store JVM
JAVA_OPTS="-Xmx8g -Xms8g \
  -XX:MaxDirectMemorySize=8g \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=25 \
  -XX:+ParallelRefProcEnabled"

# Controller JVM
CONTROLLER_JAVA_OPTS="-Xmx2g -Xms2g \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=10"
```

## Operating System Tuning

### Linux Kernel Parameters

```bash
# /etc/sysctl.conf

# Network
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 134217728
net.ipv4.tcp_wmem=4096 65536 134217728
net.core.netdev_max_backlog=5000
net.ipv4.tcp_max_syn_backlog=8192

# File descriptors
fs.file-max=1000000

# Swap
vm.swappiness=1
```

Apply changes:
```bash
sudo sysctl -p
```

### File Descriptor Limits

```bash
# /etc/security/limits.conf
*  soft  nofile  1000000
*  hard  nofile  1000000
*  soft  nproc   unlimited
*  hard  nproc   unlimited
```

### Disk I/O Scheduling

For SSDs:
```bash
echo noop | sudo tee /sys/block/nvme0n1/queue/scheduler
```

For HDDs:
```bash
echo deadline | sudo tee /sys/block/sda/queue/scheduler
```

## Storage Optimization

### SSD vs HDD

| Use Case | NATS | Pulsar | Pravega |
|----------|------|--------|---------|
| Journal/WAL | **SSD Required** | **SSD Required** | **SSD Required** |
| Data Storage | SSD Recommended | SSD Recommended | SSD Recommended |
| Archive | HDD Acceptable | HDD Acceptable | HDD Acceptable |

### RAID Configuration

- **RAID 10**: Best for write-heavy workloads (journals)
- **RAID 5/6**: Acceptable for data storage
- **No RAID**: If using cloud provider replication

### Mount Options

```bash
# /etc/fstab
/dev/nvme0n1 /data xfs noatime,nodiratime,nobarrier 0 0
```

## Monitoring and Metrics

### Key Metrics to Monitor

**NATS:**
- Messages in/out per second
- JetStream memory/file usage
- Consumer lag
- Acknowledgment rate

**Pulsar:**
- Publish/consume rate
- Backlog size
- Broker CPU/memory
- BookKeeper write latency

**Pravega:**
- Event rate per stream
- Segment count
- Cache hit ratio
- Storage throughput

### Prometheus Queries

```promql
# Publish rate
rate(pulsar_msg_in_total[5m])

# Consumer lag
pulsar_subscription_back_log

# End-to-end latency
histogram_quantile(0.99, 
  rate(pulsar_consumer_msg_ack_send_time_bucket[5m])
)
```

## Load Testing Best Practices

1. **Warm up**: Run for 5-10 minutes before measuring
2. **Steady state**: Measure during stable operation
3. **Failure scenarios**: Test with node failures
4. **Gradual scaling**: Increase load slowly
5. **Long duration**: Run for hours to catch memory leaks

## Common Performance Issues

### High Latency

**Symptoms**: P99 latency > 100ms

**Causes & Solutions:**
1. **Network**: Check for packet loss, increase MTU
2. **GC pauses**: Tune JVM, increase heap size
3. **Disk I/O**: Move to SSDs, check IOPS limits
4. **Batching**: Tune batch size and delay

### Low Throughput

**Symptoms**: Can't achieve target message rate

**Causes & Solutions:**
1. **Producer/consumer count**: Increase parallelism
2. **Partition count**: More partitions = more parallelism
3. **Batch settings**: Larger batches = higher throughput
4. **Network bandwidth**: Upgrade network
5. **CPU bottleneck**: Scale horizontally

### Memory Issues

**Symptoms**: OOM errors, high GC time

**Causes & Solutions:**
1. **Heap too small**: Increase Xmx
2. **Off-heap memory**: Increase MaxDirectMemorySize
3. **Cache too large**: Reduce cache sizes
4. **Memory leak**: Check for unclosed resources

## Benchmark Optimization

### For Maximum Throughput

1. Disable synchronous flush
2. Increase batch sizes
3. Use multiple producers/consumers
4. Disable compression (if network isn't bottleneck)
5. Increase partition count

### For Minimum Latency

1. Reduce batch delay to 1ms
2. Use dedicated threads
3. Enable busy-wait (NATS)
4. Use direct I/O
5. Pin processes to CPU cores

### For Realistic Mixed Workload

1. Use production-like batching (10-20ms)
2. Enable compression
3. Mix message sizes
4. Include consumer lag scenarios
5. Test failure recovery

## Scaling Guidelines

### Horizontal Scaling

**When to scale out:**
- CPU usage > 70%
- Network bandwidth > 70%
- Storage IOPS at limit

**NATS:** Add more servers to cluster
**Pulsar:** Add more brokers and bookies
**Pravega:** Add more segment stores

### Vertical Scaling

**When to scale up:**
- Memory pressure
- Single-threaded bottlenecks
- Storage throughput limits

**Recommended instance types:**
- Development: 4 cores, 8 GB RAM
- Testing: 8 cores, 16 GB RAM
- Production: 16 cores, 32 GB RAM

## Pre-flight Checklist

Before running benchmarks:

- [ ] All services healthy and stable
- [ ] Monitoring configured
- [ ] Baseline metrics captured
- [ ] Network bandwidth sufficient
- [ ] Storage has adequate space
- [ ] JVM tuning applied
- [ ] OS limits increased
- [ ] Warm-up completed
- [ ] Test plan documented
