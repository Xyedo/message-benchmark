# Vehicle IoT Streaming Benchmark Results

## Overview

This report compares **NATS**, **Apache Pulsar**, and **Pravega** for a vehicle IoT streaming use case with 100,000 vehicles.

## vehicles-location-100k-pravega-single-stream

| Metric | NATS | Pulsar | Pravega |
|--------|--------|--------|--------|
| **Publish Rate (msg/s)** | 10,017 | 10,017 | 10,022 |
| **Consume Rate (msg/s)** | 10,017 | 10,017 | 10,022 |
| **Publish P50 Latency (ms)** | 60.36 | 3.72 | 0.10 |
| **Publish P99 Latency (ms)** | 840.39 | 11.24 | 5.72 |
| **End-to-End Avg Latency (ms)** | 196.85 | 8.15 | 2.09 |
| **End-to-End P99 Latency (ms)** | 855.34 | 20.00 | 10.50 |

### Analysis

- **Best Throughput**: Pravega (10,022 msg/s)
- **Lowest P99 Latency**: Pravega (5.72 ms)

