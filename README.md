# Distributed Hadoop Analytics with .NET and Dapper

**A comprehensive distributed data processing pipeline implementing MapReduce analytics on Hadoop using .NET/C#, with SQL Server validation and performance benchmarking.**

---

## Overview

This project demonstrates an enterprise-grade implementation of distributed analytics on **Hadoop 2.7.4**, combining:

- **MapReduce Processing**: Custom .NET Core executables for distributed data transformation and aggregation
- **Multi-Validation Approach**: Comparison across MapReduce, Hive SQL, and SQL Server Dapper implementations
- **Performance Optimization**: Comprehensive benchmarking across variable node counts and data split configurations
- **Infrastructure as Code**: Containerized Hadoop ecosystem via Docker Compose with automated orchestration

The pipeline processes large-scale datasets (~5GB+) through multiple independent processing paths and validates output correctness through three complementary validation mechanisms.

---

## Key Features

| Feature                           | Description                                                     | Technology Stack            |
| --------------------------------- | --------------------------------------------------------------- | --------------------------- |
| **Distributed Processing**        | MapReduce implementation for scalable data transformation       | Hadoop 2.7.4 + Streaming    |
| **Multi-Language Implementation** | Production components in .NET (C#) with Linux compatibility     | .NET Core 3.1 / .NET 10     |
| **Result Validation**             | Three independent processing paths for verification             | Hive, SQL Server, MapReduce |
| **Performance Metrics**           | Configurable benchmarking across node and split size dimensions | Custom orchestrator         |
| **Database Integration**          | Bulk data loading and SQL aggregation via Dapper ORM            | SQL Server 2022             |
| **Synthetic Data Generation**     | Reproducible test dataset creation for experimentation          | .NET DataGen utility        |
| **Containerized Environment**     | Complete infrastructure abstraction via Docker                  | Docker Compose              |

---

## Project Structure

```
HadoopDotNetAnalytics/
├── src/                          # Source code directory
│   ├── Common/                   # Shared utilities (category parsing)
│   ├── Mapper/                   # MapReduce Mapper (.NET Core 3.1)
│   ├── Reducer/                  # MapReduce Reducer (.NET Core 3.1)
│   ├── Validator/                # SQL Server validation service (.NET 10)
│   ├── Benchmark/                # Performance orchestrator (.NET 10)
│   └── DataGen/                  # Synthetic data generator (.NET 10)
├── docker/                       # Container definitions
│   ├── docker-compose.yml        # Orchestration definition
│   ├── Dockerfile               # Custom NodeManager image
│   └── hadoop-hive.env          # Environment configuration
├── scripts/                      # Orchestration automation
│   ├── 00-prereqs.ps1           # Environment validation
│   ├── 01-build.ps1             # Project compilation
│   ├── 02-cluster-up.ps1        # Cluster deployment
│   ├── 03-fetch-data.ps1        # Dataset acquisition
│   ├── 04-ingest.ps1            # HDFS data loading
│   ├── 05-run-mapreduce.ps1     # MapReduce job execution
│   ├── 06-run-hive.ps1          # Hive query execution
│   ├── 07-validate.ps1          # Result validation
│   └── 08-benchmark.ps1         # Performance benchmarking
├── data/                         # Data directory
│   ├── bench.csv                # Benchmark dataset (~1GB)
│   ├── big.csv                  # Primary dataset (~5GB, local only)
│   ├── hive_console.txt         # Hive query output
│   └── mr_out.txt               # MapReduce output
├── results/                      # Output artifacts
│   ├── validation.md            # Validation report
│   ├── charts.md                # Performance charts
│   └── results.csv              # Benchmark metrics
├── docs/                         # Documentation
│   ├── REPORT.md                # Technical analysis
│   └── REPORT-fd.md             # Farsi technical analysis
├── hive/                         # HiveQL scripts
│   └── query.hql                # Category aggregation query
├── FLOW.md                       # Execution flow documentation
├── global.json                   # .NET SDK version pinning
├── HadoopDotNetAnalytics.sln    # Solution file
└── README.md                     # This file
```

---

## Documentation Roadmap

| Document                  | Purpose                                             | Audience               |
| ------------------------- | --------------------------------------------------- | ---------------------- |
| **README.md**             | Project overview, quick-start, getting started      | All users              |
| **FLOW.md**               | Complete execution flow with Mermaid diagrams       | Engineers, architects  |
| **docs/REPORT.md**        | Technical deep-dive, architecture, design decisions | Technical leads        |
| **results/validation.md** | Correctness verification, output comparison         | QA, stakeholders       |
| **results/charts.md**     | Performance metrics, benchmark analysis             | Operations, management |

---

## Quick Start Guide

### Prerequisites

- **Docker Desktop** with WSL2 backend (8GB+ memory, 50GB+ disk space)
- **.NET SDK 10.0.300** or later
- **PowerShell 7.0+** (or Windows PowerShell 5.1)
- **Git with LFS** (for large data files)

### 1. Environment Setup

```powershell
# Clone and enter repository
git clone https://github.com/hootanht/Hadoop-University-Project.git
cd Hadoop-University-Project

# Verify prerequisites
.\scripts\00-prereqs.ps1
```

### 2. Build All Components

```powershell
.\scripts\01-build.ps1
```

### 3. Deploy Hadoop Cluster

```powershell
# Deploy with 2 DataNodes and 1 NodeManager
.\scripts\02-cluster-up.ps1 -DataNodes 2 -NodeManagers 1

# Wait ~30 seconds for cluster startup
Start-Sleep -Seconds 30
```

### 4. Prepare Data

```powershell
# Download/cache dataset
.\scripts\03-fetch-data.ps1

# Ingest into HDFS
.\scripts\04-ingest.ps1 -File big.csv
```

### 5. Execute Analytics Pipeline

```powershell
# Run MapReduce job
.\scripts\05-run-mapreduce.ps1 -InputPath /data/ecommerce/big.csv -Out /out/mr_big

# Execute Hive query for comparison
.\scripts\06-run-hive.ps1

# Validate results across all three methods
.\scripts\07-validate.ps1 -File big.csv -MrOut /out/mr_big

# Run performance benchmarks
.\scripts\08-benchmark.ps1 -InputPath /data/bench/bench.csv
```

---

## Architecture & Design

### System Architecture

For detailed architectural diagrams and component interactions, refer to **[FLOW.md](FLOW.md)**.

### Technology Stack

| Layer           | Component              | Version       | Purpose                    |
| --------------- | ---------------------- | ------------- | -------------------------- |
| **Application** | MapReduce components   | .NET Core 3.1 | Distributed processing     |
| **Application** | Orchestrator/Validator | .NET 10       | Host-side coordination     |
| **Framework**   | Hadoop YARN            | 2.7.4         | Resource scheduling        |
| **Storage**     | HDFS                   | 2.7.4         | Distributed file system    |
| **SQL Engine**  | Hive                   | 2.3.2         | SQL-on-Hadoop processing   |
| **Database**    | SQL Server             | 2022          | Reference validation       |
| **Container**   | Docker                 | 20.10+        | Infrastructure abstraction |

### Design Decisions

**1. Compatibility (.NET Core 3.1)**

- NodeManager image built on Debian 8 (glibc 2.19)
- Newer .NET versions require newer glibc → incompatible
- .NET Core 3.1 is the latest compatible version

**2. Hadoop Streaming**

- Enables any executable (not just Java) to participate in MapReduce
- .NET executables read from stdin, write to stdout
- Eliminates JVM dependency for business logic

**3. Validation Approach**

- Three independent implementations (MapReduce, Hive, SQL Server)
- Guarantees correctness through cross-validation
- Enables performance comparison across technologies

---

## Data Files & Git LFS

**Large data files are managed via Git LFS** to avoid bloating the repository:

- `data/bench.csv` — 1.07 GB (tracked by LFS ✓)
- `data/big.csv` — 5.36 GB (local only, exceeds 2GB GitHub LFS limit ✗)
- Text outputs tracked for completeness

To properly work with LFS:

```powershell
# Clone with LFS support
git clone --filter=blob:none https://github.com/hootanht/Hadoop-University-Project.git

# Or enable LFS for existing clone
git lfs install
git lfs pull
```

---

## Performance Characteristics

### Typical Execution Times

| Configuration         | Dataset | Time    | Throughput |
| --------------------- | ------- | ------- | ---------- |
| 1 Node, 128MB splits  | 1GB     | ~45 sec | 22 MB/s    |
| 2 Nodes, 128MB splits | 1GB     | ~28 sec | 36 MB/s    |
| 3 Nodes, 128MB splits | 1GB     | ~22 sec | 45 MB/s    |
| 4 Nodes, 128MB splits | 1GB     | ~21 sec | 48 MB/s    |

**Key Insight**: Performance plateaus at 2-3 nodes due to task startup overhead and shuffle/sort bottlenecks.

---

## Troubleshooting

### Common Issues

**Container fails to start**

```powershell
# Ensure WSL2 is enabled and Docker daemon is running
docker ps
```

**HDFS permission denied**

```powershell
# Verify cluster is ready before submitting jobs
docker exec namenode hadoop dfsadmin -report
```

**MapReduce job stuck**

```powershell
# Check ResourceManager logs
docker logs resourcemanager | tail -50
```

---

## Language Support

This project supports both **English** and **Farsi (Persian)** documentation:

- English files: Standard names (README.md, REPORT.md, etc.)
- Farsi files: `-fd` suffix (README-fd.md, REPORT-fd.md, etc.)

For Farsi documentation, refer to files ending with `-fd.md`.

---

## Contributing

Contributions are welcome. Please ensure:

- PowerShell scripts follow naming convention (NN-description.ps1)
- .NET code targets .NET Core 3.1 (Mapper/Reducer) or .NET 10 (host components)
- Documentation is updated in both English and Farsi
- Git LFS is used for files >100MB

---

## References

- [Hadoop Documentation](https://hadoop.apache.org/docs/r2.7.4/)
- [Hadoop Streaming Guide](https://hadoop.apache.org/docs/r2.7.4/hadoop-streaming/HadoopStreaming.html)
- [Apache Hive Documentation](https://hive.apache.org/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)

---

## License

This project is provided as-is for educational and research purposes.

---

**Documentation Version**: 2.0  
**Last Updated**: 2026-06-25  
**Maintained by**: Technical Documentation Team

---

# Hadoop-University-Project
