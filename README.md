# Distributed Hadoop Analytics with .NET and Dapper

This repository demonstrates a complete distributed analytics pipeline on Hadoop using .NET executables for MapReduce and Dapper for validation.

The solution runs a Hadoop 2.7.4 cluster inside Docker Compose and uses Hadoop Streaming to execute .NET MapReduce components written in C#.

Key features:

- .NET-based MapReduce implementation using Hadoop Streaming
- Validator service using SQL Server and Dapper
- Performance benchmarking with variable node counts and split sizes
- Hive comparison for parallel SQL execution
- Support for both real Kaggle data and synthetic dataset generation

## Project Structure

- `src/Common` — shared .NET library for category parsing and normalization
- `src/Mapper` — .NET Core 3.1 Linux self-contained Mapper executable
- `src/Reducer` — .NET Core 3.1 Linux self-contained Reducer executable
- `src/Validator` — .NET 10 service validating results via SQL Server + Dapper
- `src/Benchmark` — .NET 10 benchmark orchestrator for execution timing
- `src/DataGen` — .NET 10 synthetic dataset generator
- `docker` — Docker Compose definitions for Hadoop, Hive, SQL Server, and NodeManagers
- `scripts` — PowerShell scripts to build, deploy, ingest, run jobs, validate, and benchmark
- `results` — output and benchmark documentation
- `docs` — technical report and project analysis

## Documentation

- `README.md` — English default project overview and usage guidance
- `docs/REPORT.md` — English technical report covering architecture, design decisions, and results
- `results/validation.md` — English validation results summary
- `results/charts.md` — English benchmark results and charts

## Getting Started

Use the provided scripts to prepare the environment and run the pipeline:

```powershell
./scripts/00-prereqs.ps1
./scripts/01-build.ps1
./scripts/02-cluster-up.ps1 -DataNodes 2 -NodeManagers 1
./scripts/03-fetch-data.ps1
./scripts/04-ingest.ps1 -File big.csv
./scripts/05-run-mapreduce.ps1 -InputPath /data/ecommerce/big.csv -Out /out/mr_big
./scripts/06-run-hive.ps1
./scripts/07-validate.ps1 -File big.csv -MrOut /out/mr_big
./scripts/08-benchmark.ps1 -InputPath /data/bench/bench.csv
```

## Notes

- The project default documentation is in English. Persian/Farsi versions are available with `-fd` suffix.
- Mapper and Reducer are intentionally built with .NET Core 3.1 for compatibility with the Hadoop node manager image.
- Host-side components use .NET 10.
# Hadoop-University-Project
