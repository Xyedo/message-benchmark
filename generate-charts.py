#!/usr/bin/env python3
"""
Generate comparison charts from benchmark results
Compares NATS, Pulsar, and Pravega across different workloads
"""

import json
import sys
import os
from pathlib import Path
from typing import List, Dict, Any
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np

def load_results(results_dir: str) -> List[Dict[str, Any]]:
    """Load all JSON result files from directory"""
    results = []
    results_path = Path(results_dir)
    
    for json_file in results_path.glob("*.json"):
        try:
            with open(json_file, 'r') as f:
                data = json.load(f)
                # Extract driver and workload from filename or data
                filename = json_file.stem
                parts = filename.split('-')
                
                data['driver'] = data.get('driver', 'unknown')
                data['workload'] = data.get('workload', filename)
                results.append(data)
                print(f"Loaded: {json_file.name}")
        except Exception as e:
            print(f"Error loading {json_file}: {e}")
    
    return results

def group_by_workload(results: List[Dict[str, Any]]) -> Dict[str, List[Dict[str, Any]]]:
    """Group results by workload name"""
    grouped = {}
    for result in results:
        workload = result['workload']
        if workload not in grouped:
            grouped[workload] = []
        grouped[workload].append(result)
    return grouped

def create_throughput_chart(results: List[Dict[str, Any]], output_dir: str):
    """Create throughput comparison chart"""
    drivers = [r['driver'] for r in results]
    
    # Extract and aggregate rates (handle lists/arrays by taking mean)
    publish_rates = []
    consume_rates = []
    
    for r in results:
        pub_rate = r.get('publishRate', 0)
        if isinstance(pub_rate, (list, np.ndarray)):
            pub_rate = np.mean(pub_rate) if len(pub_rate) > 0 else 0
        publish_rates.append(float(pub_rate))
        
        cons_rate = r.get('consumeRate', 0)
        if isinstance(cons_rate, (list, np.ndarray)):
            cons_rate = np.mean(cons_rate) if len(cons_rate) > 0 else 0
        consume_rates.append(float(cons_rate))
    
    x = np.arange(len(drivers))
    width = 0.35
    
    fig, ax = plt.subplots(figsize=(12, 6))
    bars1 = ax.bar(x - width/2, publish_rates, width, label='Publish Rate', color='#2ecc71')
    bars2 = ax.bar(x + width/2, consume_rates, width, label='Consume Rate', color='#3498db')
    
    ax.set_xlabel('Driver', fontsize=12, fontweight='bold')
    ax.set_ylabel('Messages per Second', fontsize=12, fontweight='bold')
    ax.set_title('Throughput Comparison', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(drivers)
    ax.legend()
    ax.grid(axis='y', alpha=0.3)
    
    # Add value labels on bars
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                   f'{int(height):,}',
                   ha='center', va='bottom', fontsize=9)
    
    plt.tight_layout()
    plt.savefig(f"{output_dir}/throughput_comparison.png", dpi=300)
    print(f"Created: {output_dir}/throughput_comparison.png")
    plt.close()

def create_latency_chart(results: List[Dict[str, Any]], output_dir: str):
    """Create latency comparison chart"""
    drivers = [r['driver'] for r in results]
    
    # Extract and aggregate latencies (handle lists/arrays by taking mean)
    p50 = []
    p95 = []
    p99 = []
    
    for r in results:
        val = r.get('publishLatency50pct', 0)
        if isinstance(val, (list, np.ndarray)):
            val = np.mean(val) if len(val) > 0 else 0
        p50.append(float(val))
        
        val = r.get('publishLatency95pct', 0)
        if isinstance(val, (list, np.ndarray)):
            val = np.mean(val) if len(val) > 0 else 0
        p95.append(float(val))
        
        val = r.get('publishLatency99pct', 0)
        if isinstance(val, (list, np.ndarray)):
            val = np.mean(val) if len(val) > 0 else 0
        p99.append(float(val))
    
    x = np.arange(len(drivers))
    width = 0.25
    
    fig, ax = plt.subplots(figsize=(12, 6))
    bars1 = ax.bar(x - width, p50, width, label='P50', color='#2ecc71')
    bars2 = ax.bar(x, p95, width, label='P95', color='#f39c12')
    bars3 = ax.bar(x + width, p99, width, label='P99', color='#e74c3c')
    
    ax.set_xlabel('Driver', fontsize=12, fontweight='bold')
    ax.set_ylabel('Latency (ms)', fontsize=12, fontweight='bold')
    ax.set_title('Publish Latency Comparison', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(drivers)
    ax.legend()
    ax.grid(axis='y', alpha=0.3)
    
    # Add value labels on bars
    for bars in [bars1, bars2, bars3]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                   f'{height:.2f}',
                   ha='center', va='bottom', fontsize=8)
    
    plt.tight_layout()
    plt.savefig(f"{output_dir}/latency_comparison.png", dpi=300)
    print(f"Created: {output_dir}/latency_comparison.png")
    plt.close()

def create_end_to_end_latency_chart(results: List[Dict[str, Any]], output_dir: str):
    """Create end-to-end latency comparison chart"""
    drivers = [r['driver'] for r in results]
    
    # Extract and aggregate latencies (handle lists/arrays by taking mean)
    avg_latency = []
    p99_latency = []
    
    for r in results:
        val = r.get('endToEndLatencyAvg', 0)
        if isinstance(val, (list, np.ndarray)):
            val = np.mean(val) if len(val) > 0 else 0
        avg_latency.append(float(val))
        
        val = r.get('endToEndLatency99pct', 0)
        if isinstance(val, (list, np.ndarray)):
            val = np.mean(val) if len(val) > 0 else 0
        p99_latency.append(float(val))
    
    x = np.arange(len(drivers))
    width = 0.35
    
    fig, ax = plt.subplots(figsize=(12, 6))
    bars1 = ax.bar(x - width/2, avg_latency, width, label='Average', color='#3498db')
    bars2 = ax.bar(x + width/2, p99_latency, width, label='P99', color='#e74c3c')
    
    ax.set_xlabel('Driver', fontsize=12, fontweight='bold')
    ax.set_ylabel('Latency (ms)', fontsize=12, fontweight='bold')
    ax.set_title('End-to-End Latency Comparison', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(drivers)
    ax.legend()
    ax.grid(axis='y', alpha=0.3)
    
    # Add value labels on bars
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                   f'{height:.2f}',
                   ha='center', va='bottom', fontsize=9)
    
    plt.tight_layout()
    plt.savefig(f"{output_dir}/end_to_end_latency_comparison.png", dpi=300)
    print(f"Created: {output_dir}/end_to_end_latency_comparison.png")
    plt.close()

def create_summary_table(grouped_results: Dict[str, List[Dict[str, Any]]], output_dir: str):
    """Create summary table as text file"""
    with open(f"{output_dir}/summary.txt", 'w') as f:
        f.write("=" * 100 + "\n")
        f.write("BENCHMARK RESULTS SUMMARY\n")
        f.write("Vehicle IoT Streaming - 100k Vehicles\n")
        f.write("=" * 100 + "\n\n")
        
        for workload, results in grouped_results.items():
            f.write(f"\nWorkload: {workload}\n")
            f.write("-" * 100 + "\n")
            f.write(f"{'Driver':<15} {'Pub Rate':<15} {'Con Rate':<15} {'P50 Lat':<15} {'P99 Lat':<15} {'E2E Avg':<15}\n")
            f.write("-" * 100 + "\n")
            
            for result in results:
                driver = result.get('driver', 'unknown')
                
                # Extract and aggregate values (handle lists by taking mean)
                pub_rate = result.get('publishRate', 0)
                if isinstance(pub_rate, (list, np.ndarray)):
                    pub_rate = np.mean(pub_rate) if len(pub_rate) > 0 else 0
                
                con_rate = result.get('consumeRate', 0)
                if isinstance(con_rate, (list, np.ndarray)):
                    con_rate = np.mean(con_rate) if len(con_rate) > 0 else 0
                
                p50_lat = result.get('publishLatency50pct', 0)
                if isinstance(p50_lat, (list, np.ndarray)):
                    p50_lat = np.mean(p50_lat) if len(p50_lat) > 0 else 0
                
                p99_lat = result.get('publishLatency99pct', 0)
                if isinstance(p99_lat, (list, np.ndarray)):
                    p99_lat = np.mean(p99_lat) if len(p99_lat) > 0 else 0
                
                e2e_avg = result.get('endToEndLatencyAvg', 0)
                if isinstance(e2e_avg, (list, np.ndarray)):
                    e2e_avg = np.mean(e2e_avg) if len(e2e_avg) > 0 else 0
                
                f.write(f"{driver:<15} {float(pub_rate):<15.0f} {float(con_rate):<15.0f} "
                       f"{float(p50_lat):<15.2f} {float(p99_lat):<15.2f} {float(e2e_avg):<15.2f}\n")
            
            f.write("\n")
    
    print(f"Created: {output_dir}/summary.txt")

def create_comparison_report(grouped_results: Dict[str, List[Dict[str, Any]]], output_dir: str):
    """Create detailed comparison report"""
    with open(f"{output_dir}/comparison_report.md", 'w') as f:
        f.write("# Vehicle IoT Streaming Benchmark Results\n\n")
        f.write("## Overview\n\n")
        f.write("This report compares **NATS**, **Apache Pulsar**, and **Pravega** for a vehicle IoT streaming use case with 100,000 vehicles.\n\n")
        
        for workload, results in grouped_results.items():
            f.write(f"## {workload}\n\n")
            
            # Create table
            f.write("| Metric | " + " | ".join([r.get('driver', 'unknown') for r in results]) + " |\n")
            f.write("|--------|" + "|".join(["--------"] * len(results)) + "|\n")
            
            # Helper function to extract and aggregate
            def get_mean(val):
                if isinstance(val, (list, np.ndarray)):
                    return float(np.mean(val)) if len(val) > 0 else 0.0
                return float(val) if val else 0.0
            
            # Throughput
            f.write("| **Publish Rate (msg/s)** | ")
            f.write(" | ".join([f"{get_mean(r.get('publishRate', 0)):,.0f}" for r in results]) + " |\n")
            
            f.write("| **Consume Rate (msg/s)** | ")
            f.write(" | ".join([f"{get_mean(r.get('consumeRate', 0)):,.0f}" for r in results]) + " |\n")
            
            # Latency
            f.write("| **Publish P50 Latency (ms)** | ")
            f.write(" | ".join([f"{get_mean(r.get('publishLatency50pct', 0)):.2f}" for r in results]) + " |\n")
            
            f.write("| **Publish P99 Latency (ms)** | ")
            f.write(" | ".join([f"{get_mean(r.get('publishLatency99pct', 0)):.2f}" for r in results]) + " |\n")
            
            f.write("| **End-to-End Avg Latency (ms)** | ")
            f.write(" | ".join([f"{get_mean(r.get('endToEndLatencyAvg', 0)):.2f}" for r in results]) + " |\n")
            
            f.write("| **End-to-End P99 Latency (ms)** | ")
            f.write(" | ".join([f"{get_mean(r.get('endToEndLatency99pct', 0)):.2f}" for r in results]) + " |\n")
            
            f.write("\n")
            
            # Winner analysis
            f.write("### Analysis\n\n")
            
            # Find best throughput (extract means first)
            throughputs = [get_mean(r.get('publishRate', 0)) for r in results]
            best_throughput_idx = max(range(len(results)), key=lambda i: throughputs[i])
            f.write(f"- **Best Throughput**: {results[best_throughput_idx].get('driver', 'unknown')} ")
            f.write(f"({throughputs[best_throughput_idx]:,.0f} msg/s)\n")
            
            # Find best latency (extract means first)
            latencies = [get_mean(r.get('publishLatency99pct', float('inf'))) for r in results]
            best_latency_idx = min(range(len(results)), key=lambda i: latencies[i] if latencies[i] > 0 else float('inf'))
            f.write(f"- **Lowest P99 Latency**: {results[best_latency_idx].get('driver', 'unknown')} ")
            f.write(f"({latencies[best_latency_idx]:.2f} ms)\n")
            
            f.write("\n")
    
    print(f"Created: {output_dir}/comparison_report.md")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 generate-charts.py <results_directory>")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    
    if not os.path.exists(results_dir):
        print(f"Error: Directory {results_dir} does not exist")
        sys.exit(1)
    
    # Create charts directory
    charts_dir = f"{results_dir}/charts"
    os.makedirs(charts_dir, exist_ok=True)
    
    print(f"\nLoading results from: {results_dir}")
    results = load_results(results_dir)
    
    if not results:
        print("No results found!")
        sys.exit(1)
    
    print(f"\nFound {len(results)} result(s)")
    
    # Group by workload
    grouped_results = group_by_workload(results)
    
    print(f"\nGenerating charts in: {charts_dir}")
    
    # Generate charts for each workload
    for workload, workload_results in grouped_results.items():
        print(f"\nProcessing workload: {workload}")
        
        workload_dir = f"{charts_dir}/{workload}"
        os.makedirs(workload_dir, exist_ok=True)
        
        create_throughput_chart(workload_results, workload_dir)
        create_latency_chart(workload_results, workload_dir)
        create_end_to_end_latency_chart(workload_results, workload_dir)
    
    # Generate summary
    print("\nGenerating summary...")
    create_summary_table(grouped_results, charts_dir)
    create_comparison_report(grouped_results, charts_dir)
    
    print("\n" + "=" * 60)
    print("Charts generation complete!")
    print("=" * 60)
    print(f"\nCharts saved to: {charts_dir}/")
    print(f"Summary: {charts_dir}/summary.txt")
    print(f"Detailed report: {charts_dir}/comparison_report.md")
    print()

if __name__ == "__main__":
    # Check for matplotlib
    try:
        import matplotlib.pyplot as plt
        import matplotlib.patches as mpatches
    except ImportError:
        print("Error: matplotlib is required")
        print("Install it with: pip3 install matplotlib")
        sys.exit(1)
    
    main()
