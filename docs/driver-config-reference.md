# Driver Configuration Reference

This document explains the correct driver configuration format for the OpenMessaging Benchmark framework.

## Overview

The benchmark framework expects specific configuration properties for each driver. The original configurations were too complex and included properties not supported by the drivers.

## Fixed Configurations

### NATS Driver

**File**: `drivers/nats.yaml`

**Minimal Working Configuration**:
```yaml
name: NATS
driverClass: io.openmessaging.benchmark.driver.nats.NatsBenchmarkDriver
natsHostUrl: nats://localhost:4222
```

**Key Points**:
- Only `natsHostUrl` is required
- For clustered NATS, use comma-separated URLs: `nats://host1:4222,host2:4222,host3:4222`
- JetStream features are configured on the NATS server, not in the driver config

### Pulsar Driver

**File**: `drivers/pulsar.yaml`

**Minimal Working Configuration**:
```yaml
name: Pulsar
driverClass: io.openmessaging.benchmark.driver.pulsar.PulsarBenchmarkDriver

client:
  serviceUrl: pulsar://localhost:6650
  httpUrl: http://localhost:8080
  ioThreads: 8
  connectionsPerBroker: 8
  clusterName: standalone
  namespacePrefix: public/vehicles
  topicType: persistent
  persistence:
    ensembleSize: 3
    writeQuorum: 3
    ackQuorum: 2
    deduplicationEnabled: false

producer:
  batchingEnabled: true
  batchingMaxPublishDelayMs: 10
  blockIfQueueFull: true
  pendingQueueSize: 10000
```

**Key Points**:
- Requires nested `client` and `producer` sections
- `namespacePrefix` format: `tenant/namespace`
- `topicType` can be `persistent` or `non-persistent`
- Batching is crucial for throughput

### Pravega Driver

**File**: `drivers/pravega.yaml`

**Minimal Working Configuration**:
```yaml
name: Pravega
driverClass: io.openmessaging.benchmark.driver.pravega.PravegaBenchmarkDriver

client:
  controllerURI: tcp://localhost:9090
  scopeName: vehicles

writer:
  enableConnectionPooling: true

includeTimestampInEvent: true
enableStreamAutoScaling: true
eventsPerSecond: 10000
customPayload: true
```

**Key Points**:
- `controllerURI` uses `tcp://` protocol
- `scopeName` is the Pravega scope for all streams
- `enableStreamAutoScaling` enables elastic scaling
- `eventsPerSecond` threshold for auto-scaling triggers

## Common Issues

### 1. NullPointerException in Consumer Creation

**Error**:
```
java.lang.NullPointerException: Cannot invoke "java.util.concurrent.CompletableFuture.join()" because "f" is null
```

**Cause**: Driver configuration properties don't match expected Java class fields

**Solution**: Use only the properties defined in the driver's Config class

### 2. Unknown Configuration Properties

**Cause**: Extra properties in YAML that don't map to Java class fields

**Solution**: Remove all properties not defined in the driver's source code

### 3. Wrong Property Format

**Cause**: Flat structure when nested is required (e.g., Pulsar client config)

**Solution**: Use proper nesting as shown in driver examples

## How to Verify Configurations

1. **Check Driver Source Code**:
   ```bash
   # Find the Config class
   find ../openmessaging-benchmark/driver-{name} -name "*Config.java"
   
   # Read the Config class
   cat path/to/Config.java
   ```

2. **Look for Example Configs**:
   ```bash
   find ../openmessaging-benchmark/driver-{name} -name "*.yaml"
   ```

3. **Test with Short Duration**:
   ```bash
   ./run-benchmark.sh --workload vehicles-location-100k --driver nats --duration 1
   ```

## Backup Files

Original configurations have been backed up:
- `drivers/nats.yaml.bak` (if exists)
- `drivers/pulsar.yaml.bak`
- `drivers/pravega.yaml.bak`

These can be used as reference for advanced features but should not be used directly with the benchmark framework.

## References

- [OpenMessaging Benchmark GitHub](https://github.com/pravega/openmessaging-benchmark)
- Driver source: `openmessaging-benchmark/driver-*/src/main/java/`
- Example configs: `openmessaging-benchmark/driver-*/deploy/`
