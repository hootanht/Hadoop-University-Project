# Distributed Hadoop Analytics Pipeline — Execution Flow

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Execution Flow](#execution-flow)
- [Component Interactions](#component-interactions)
- [Data Flow](#data-flow)
- [Validation & Benchmarking](#validation--benchmarking)
- [فارسی - جریان اجرای پایپ‌لاین تجزیه‌و‌تحلیل توزیع‌شدهٔ Hadoop](#فارسی---جریان-اجرای-پایپ‌لاین-تجزیه‌و‌تحلیل-توزیع‌شدهٔ-hadoop)

---

## Overview

This document provides a comprehensive, step-by-step explanation of the **Distributed Hadoop Analytics Pipeline**. The project implements a distributed data processing system using:

- **Hadoop 2.7.4** for distributed computing
- **.NET (C#)** for MapReduce components and orchestration
- **SQL Server + Dapper** for validation
- **Apache Hive** for comparative SQL analytics
- **Docker Compose** for infrastructure abstraction

The pipeline processes large datasets through multiple processing stages, validates results, and benchmarks performance across different node configurations.

---

## System Architecture

### High-Level Infrastructure

```mermaid
graph TB
    subgraph Host["Windows Host / Docker Desktop"]
        PowerShell["PowerShell Orchestration<br/>(Scripts 00-08)"]
        Bench["Benchmark Orchestrator<br/>(.NET 10)"]
        Validator["Validator Service<br/>(.NET 10 + Dapper)"]
    end
    
    subgraph Docker["Docker Compose Environment"]
        subgraph Hadoop["Hadoop 2.7.4 Cluster"]
            NN["NameNode<br/>(HDFS Controller)"]
            RM["ResourceManager<br/>(YARN Scheduler)"]
            DN1["DataNode 1<br/>(Data Block Storage)"]
            DN2["DataNode 2<br/>(Data Block Storage)"]
            NM1["NodeManager 1<br/>(.NET 3.1 Runtime)"]
            NM2["NodeManager 2<br/>(.NET 3.1 Runtime)"]
        end
        
        subgraph Support["Support Services"]
            Hive["HiveServer2<br/>(SQL Analytics)"]
            MSSQL["SQL Server 2022<br/>(Validation DB)"]
        end
    end
    
    PowerShell -->|Deploy & Control| Docker
    PowerShell -->|Monitor| Bench
    Bench -->|Query Results| Hadoop
    Validator -->|Bulk Load & Query| MSSQL
    Hadoop -->|Process Data| NN
    NN -->|Coordinate| RM
    RM -->|Schedule Tasks| NM1
    RM -->|Schedule Tasks| NM2
    NM1 -->|Store Blocks| DN1
    NM2 -->|Store Blocks| DN2
    Hive -->|Query| NN
    Validator -->|Fetch Results| Hadoop
```

### Component Roles

| Component | Role | Technology | Version |
|-----------|------|-----------|---------|
| **Mapper** | Transforms input records into key-value pairs | .NET Core | 3.1 |
| **Reducer** | Aggregates values for each key | .NET Core | 3.1 |
| **Validator** | Verifies results using SQL Server | .NET / Dapper | 10 |
| **Benchmark** | Measures performance across configurations | .NET | 10 |
| **DataGen** | Generates synthetic test datasets | .NET | 10 |
| **HDFS** | Distributed file storage | Hadoop | 2.7.4 |
| **YARN** | Resource scheduling | Hadoop | 2.7.4 |
| **Hive** | SQL query execution | Apache Hive | 2.3.2 |
| **SQL Server** | Validation database | Microsoft SQL Server | 2022 |

---

## Execution Flow

### Complete Pipeline Workflow

```mermaid
flowchart TD
    A["Step 00: Prerequisites Check<br/>• Verify Docker is running<br/>• Check .NET SDK version<br/>• Validate PowerShell execution policy"]
    
    B["Step 01: Build Projects<br/>• Compile all .NET projects<br/>• Generate Linux self-contained binaries<br/>• Create Docker images"]
    
    C["Step 02: Deploy Hadoop Cluster<br/>• Start NameNode + ResourceManager<br/>• Start DataNodes (configurable count)<br/>• Start NodeManagers with .NET 3.1 runtime<br/>• Wait for cluster readiness"]
    
    D["Step 03: Fetch Dataset<br/>• Download from Kaggle<br/>• Or use pre-cached data"]
    
    E["Step 04: Ingest Data to HDFS<br/>• Copy data files to NameNode<br/>• Distribute blocks across DataNodes<br/>• Verify block replication"]
    
    F["Step 05: Execute MapReduce<br/>• Submit job to ResourceManager<br/>• Distribute input splits to NodeManagers<br/>• Execute Mapper on each split<br/>• Shuffle & Sort intermediate data<br/>• Execute Reducer on grouped data<br/>• Write results to HDFS"]
    
    G["Step 06: Execute Hive Query<br/>• Connect to HiveServer2<br/>• Parse HiveQL command<br/>• Optimize query execution plan<br/>• Execute on HDFS data<br/>• Store comparison results"]
    
    H["Step 07: Validate Results<br/>• Load input data to SQL Server<br/>• Execute SQL aggregation query<br/>• Compare with MapReduce output<br/>• Generate validation report"]
    
    I["Step 08: Benchmark Performance<br/>• Iterate with variable parameters<br/>• Measure execution times<br/>• Collect resource metrics<br/>• Generate performance charts"]
    
    J["Artifacts Generated<br/>• MapReduce output in HDFS<br/>• Validation report<br/>• Benchmark charts<br/>• Performance comparison"]
    
    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    E --> G
    F --> H
    G --> H
    H --> I
    I --> J
    
    style A fill:#e1f5ff
    style B fill:#fff3e0
    style C fill:#fff3e0
    style D fill:#f3e5f5
    style E fill:#f3e5f5
    style F fill:#c8e6c9
    style G fill:#c8e6c9
    style H fill:#ffe0b2
    style I fill:#f8bbd0
    style J fill:#d1c4e9
```

### MapReduce Job Execution Detail

```mermaid
flowchart TD
    A["1. Input Submission<br/>Raw Data in HDFS"] 
    
    B["2. Input Split Planning<br/>Calculate optimal split size<br/>Determine task count"]
    
    C["3. Task Assignment<br/>Assign splits to NodeManagers<br/>Localize data blocks"]
    
    D["4. Map Phase<br/>Each NodeManager runs Mapper<br/>Processes assigned split<br/>Outputs: key↦value pairs"]
    
    E["5. Partition & Sort<br/>Group records by key<br/>Sort within each partition<br/>Buffer in local memory"]
    
    F["6. Shuffle & Transfer<br/>Send partitions to Reduce nodes<br/>Network I/O between nodes<br/>Intermediate data storage"]
    
    G["7. Reduce Phase<br/>Each NodeManager runs Reducer<br/>Processes grouped key-value pairs<br/>Aggregates values per key"]
    
    H["8. Output Storage<br/>Write final results to HDFS<br/>Replicate across nodes<br/>Generate output path"]
    
    I["MapReduce Complete<br/>Results in HDFS"] 
    
    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    G --> H
    H --> I
    
    style A fill:#e3f2fd
    style B fill:#e8f5e9
    style C fill:#fff3e0
    style D fill:#f3e5f5
    style E fill:#fce4ec
    style F fill:#e0f2f1
    style G fill:#f3e5f5
    style H fill:#fff9c4
    style I fill:#c8e6c9
```

---

## Component Interactions

### Data Processing Pipeline Sequence

```mermaid
sequenceDiagram
    participant Client as PowerShell Client
    participant RM as ResourceManager
    participant NM as NodeManager
    participant DN as DataNode
    participant Mapper
    participant Reducer
    participant HDFS as HDFS Output
    
    Client->>RM: 1. Submit MapReduce Job
    RM->>RM: Analyze input splits
    
    loop For Each Input Split
        RM->>NM: Schedule Map Task
        NM->>DN: Request data block
        DN-->>NM: Stream data
        NM->>Mapper: Execute with split
        Mapper->>Mapper: Process each record
        Mapper-->>NM: Emit key↦value pairs
        NM->>NM: Buffer & partition
    end
    
    NM->>NM: Sort partitions
    
    loop For Each Partition
        RM->>NM: Schedule Reduce Task
        NM->>NM: Receive shuffled data
        NM->>Reducer: Execute with partition
        Reducer->>Reducer: Aggregate by key
        Reducer-->>NM: Emit aggregated results
    end
    
    NM->>HDFS: Write final output
    HDFS-->>Client: Job Complete
    
    Note over RM,HDFS: Total time includes:<br/>Task startup overhead<br/>Data transfer latency<br/>I/O operations
```

### Validation Workflow

```mermaid
sequenceDiagram
    participant Client as Validator (.NET)
    participant HDFS as Hadoop HDFS
    participant SQL as SQL Server
    participant MR as MapReduce Output
    
    Client->>HDFS: 1. Download input dataset
    HDFS-->>Client: Dataset loaded
    
    Client->>SQL: 2. Bulk insert dataset
    SQL->>SQL: Create temp table
    SQL->>SQL: Load data rows
    SQL-->>Client: Insert complete
    
    Client->>SQL: 3. Execute SQL aggregation
    SQL->>SQL: GROUP BY category<br/>COUNT(*) per group
    SQL-->>Client: SQL results
    
    Client->>HDFS: 4. Download MapReduce output
    HDFS-->>Client: MR output loaded
    
    Client->>MR: 5. Parse MapReduce results
    MR->>MR: Extract key-count pairs
    
    Client->>Client: 6. Compare outputs
    Client->>Client: SQL results vs MR results
    
    Client-->>Client: 7. Generate report
    alt Results Match
        Client-->>Client: ✓ Validation PASSED
    else Results Differ
        Client-->>Client: ✗ Validation FAILED
    end
```

---

## Data Flow

### End-to-End Data Journey

```mermaid
flowchart LR
    A["Source Dataset<br/>CSV File<br/>~5GB"]
    
    B["Data Ingestion<br/>→ HDFS<br/>Distributed blocks<br/>3x replication"]
    
    C["MapReduce Processing<br/>Map: Category extraction<br/>Reduce: Count aggregation"]
    
    D["MR Output<br/>key ↦ count<br/>In HDFS"]
    
    E["Hive Query<br/>SELECT category,<br/>COUNT(*) FROM data<br/>GROUP BY category"]
    
    F["Hive Output<br/>Category aggregates<br/>In HDFS"]
    
    G["SQL Server<br/>BULK INSERT<br/>Table creation"]
    
    H["SQL Aggregation<br/>SELECT category,<br/>COUNT(*) FROM table<br/>GROUP BY category"]
    
    I["Validation<br/>Compare MR vs SQL<br/>Generate report"]
    
    A --> B
    B --> C
    B --> E
    B --> G
    C --> D
    E --> F
    G --> H
    D --> I
    F --> I
    H --> I
    
    style A fill:#e3f2fd
    style B fill:#bbdefb
    style C fill:#81c784
    style D fill:#a5d6a7
    style E fill:#4fc3f7
    style F fill:#4fc3f7
    style G fill:#ffb74d
    style H fill:#ffb74d
    style I fill:#ce93d8
```

---

## Validation & Benchmarking

### Validation Comparison Matrix

```mermaid
flowchart TB
    A["Input Dataset<br/>ecommerce_data.csv<br/>Records: ~6.8M"]
    
    B["Three Processing Paths"]
    
    C["MapReduce<br/>via Hadoop"]
    D["Hive Query<br/>via HiveServer2"]
    E["SQL Server<br/>via Dapper"]
    
    F["Output Validation<br/>Compare results"]
    
    G["Correctness Verification<br/>✓ All three methods produce<br/>identical category counts"]
    
    A --> B
    B --> C
    B --> D
    B --> E
    C --> F
    D --> F
    E --> F
    F --> G
    
    style A fill:#fff3e0
    style C fill:#81c784
    style D fill:#4fc3f7
    style E fill:#ffb74d
    style G fill:#ce93d8
```

### Performance Benchmark Metrics

```mermaid
graph TD
    Metrics["Measured Metrics"]
    
    Metrics --> M1["Execution Time<br/>(seconds)<br/>Total wall-clock time"]
    Metrics --> M2["Data Volume<br/>(GB)<br/>Input size<br/>Output size"]
    Metrics --> M3["Node Count<br/>(variable)<br/>1-4 nodes<br/>Impact analysis"]
    Metrics --> M4["Split Size<br/>(configurable)<br/>64MB / 128MB / 256MB<br/>Throughput impact"]
    
    M1 --> Analysis["Analysis"]
    M2 --> Analysis
    M3 --> Analysis
    M4 --> Analysis
    
    Analysis --> R1["Diminishing Returns<br/>Peak performance at 2-3 nodes<br/>Additional nodes minimal gain"]
    Analysis --> R2["Overhead Analysis<br/>Task startup dominates<br/>for small split sizes"]
    Analysis --> R3["Recommendations<br/>Optimal config: 2 nodes<br/>128MB split size"]
    
    style Metrics fill:#e1f5ff
    style M1 fill:#b3e5fc
    style M2 fill:#b3e5fc
    style M3 fill:#b3e5fc
    style M4 fill:#b3e5fc
    style Analysis fill:#fff3e0
    style R1 fill:#c8e6c9
    style R2 fill:#c8e6c9
    style R3 fill:#c8e6c9
```

---

# فارسی — جریان اجرای پایپ‌لاین تجزیه‌و‌تحلیل توزیع‌شدهٔ Hadoop

## خلاصه کلی

این سند توضیح جامع و مرحله‌به‌مرحله **جریان اجرای پایپ‌لاین تجزیه‌و‌تحلیل توزیع‌شده** را ارائه می‌دهد. این پروژه سیستم پردازش داده توزیع‌شده را پیاده‌سازی می‌کند و از:

- **Hadoop 2.7.4** برای محاسبات توزیع‌شده
- **.NET (C#)** برای اجزای MapReduce و هماهنگی
- **SQL Server + Dapper** برای اعتبارسنجی
- **Apache Hive** برای تجزیه‌و‌تحلیل SQL مقایسه‌ای
- **Docker Compose** برای انتزاع زیرساخت

استفاده می‌کند.

---

## معماری سیستم (فارسی)

### زیرساخت سطح بالا

```mermaid
graph TB
    subgraph میزبان["میزبان Windows / Docker Desktop"]
        PowerShell["هماهنگی PowerShell<br/>(اسکریپت‌های 00-08)"]
        Bench["ارکستراتور بنچمارک<br/>(.NET 10)"]
        Validator["سرویس اعتبارسنجی<br/>(.NET 10 + Dapper)"]
    end
    
    subgraph Docker["محیط Docker Compose"]
        subgraph Hadoop["خوشه Hadoop 2.7.4"]
            NN["NameNode<br/>(کنترل‌کننده HDFS)"]
            RM["ResourceManager<br/>(برنامه‌ریز YARN)"]
            DN1["DataNode 1<br/>(ذخیره‌سازی بلاک‌های داده)"]
            DN2["DataNode 2<br/>(ذخیره‌سازی بلاک‌های داده)"]
            NM1["NodeManager 1<br/>(.NET 3.1 Runtime)"]
            NM2["NodeManager 2<br/>(.NET 3.1 Runtime)"]
        end
        
        subgraph پشتیبانی["سرویس‌های پشتیبانی"]
            Hive["HiveServer2<br/>(تجزیه‌و‌تحلیل SQL)"]
            MSSQL["SQL Server 2022<br/>(پایگاه‌داده اعتبارسنجی)"]
        end
    end
    
    PowerShell -->|استقرار و کنترل| Docker
    PowerShell -->|نظارت| Bench
    Bench -->|نتایج پرسمان| Hadoop
    Validator -->|بارگذاری دسته‌ای و پرسمان| MSSQL
    Hadoop -->|پردازش داده| NN
    NN -->|هماهنگی| RM
    RM -->|برنامه‌ریزی وظایف| NM1
    RM -->|برنامه‌ریزی وظایف| NM2
    NM1 -->|ذخیره بلاک‌ها| DN1
    NM2 -->|ذخیره بلاک‌ها| DN2
    Hive -->|پرسمان| NN
    Validator -->|دریافت نتایج| Hadoop
```

---

## جریان اجرا (فارسی)

### جریان کاری کامل پایپ‌لاین

```mermaid
flowchart TD
    A["مرحله 00: بررسی پیش‌نیازها<br/>• تأیید اجرای Docker<br/>• بررسی نسخه SDK .NET<br/>• اعتبارسنجی خط‌مشی اجرای PowerShell"]
    
    B["مرحله 01: ساخت پروژه‌ها<br/>• کامپایل تمامی پروژه‌های .NET<br/>• تولید فایل‌های Linux self-contained<br/>• ایجاد تصاویر Docker"]
    
    C["مرحله 02: استقرار خوشه Hadoop<br/>• شروع NameNode + ResourceManager<br/>• شروع DataNode‌ها (تعداد قابل‌تنظیم)<br/>• شروع NodeManager‌ها با runtime .NET 3.1<br/>• انتظار برای آماده‌سازی خوشه"]
    
    D["مرحله 03: دریافت مجموعه‌داده<br/>• دانلود از Kaggle<br/>• یا استفاده از داده‌های کش‌شده"]
    
    E["مرحله 04: بارگذاری داده‌ها به HDFS<br/>• کپی فایل‌های داده به NameNode<br/>• توزیع بلاک‌ها در سراسر DataNode‌ها<br/>• تأیید تکرار بلاک"]
    
    F["مرحله 05: اجرای MapReduce<br/>• ارسال کار به ResourceManager<br/>• توزیع input split‌ها به NodeManager‌ها<br/>• اجرای Mapper روی هر split<br/>• shuffle و sort داده‌های میانی<br/>• اجرای Reducer روی داده‌های گروه‌بندی‌شده<br/>• نوشتن نتایج به HDFS"]
    
    G["مرحله 06: اجرای پرسمان Hive<br/>• اتصال به HiveServer2<br/>• تجزیه فرمان HiveQL<br/>• بهینه‌سازی طرح اجرای پرسمان<br/>• اجرا روی داده‌های HDFS<br/>• ذخیره‌سازی نتایج مقایسه"]
    
    H["مرحله 07: اعتبارسنجی نتایج<br/>• بارگذاری داده‌های ورودی به SQL Server<br/>• اجرای پرسمان تجمیع SQL<br/>• مقایسه با خروجی MapReduce<br/>• تولید گزارش اعتبارسنجی"]
    
    I["مرحله 08: بنچمارک کارایی<br/>• تکرار با پارامترهای متغیر<br/>• اندازه‌گیری زمان اجرا<br/>• جمع‌آوری معیارهای منبع<br/>• تولید نمودارهای کارایی"]
    
    J["آرتیفکت‌های تولیدشده<br/>• خروجی MapReduce در HDFS<br/>• گزارش اعتبارسنجی<br/>• نمودارهای بنچمارک<br/>• مقایسه کارایی"]
    
    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    E --> G
    F --> H
    G --> H
    H --> I
    I --> J
    
    style A fill:#e1f5ff
    style B fill:#fff3e0
    style C fill:#fff3e0
    style D fill:#f3e5f5
    style E fill:#f3e5f5
    style F fill:#c8e6c9
    style G fill:#c8e6c9
    style H fill:#ffe0b2
    style I fill:#f8bbd0
    style J fill:#d1c4e9
```

---

## جریان اعتبارسنجی (فارسی)

### ماتریس مقایسه اعتبارسنجی

```mermaid
flowchart TB
    A["مجموعه‌داده ورودی<br/>ecommerce_data.csv<br/>رکوردها: ~6.8M"]
    
    B["سه مسیر پردازش"]
    
    C["MapReduce<br/>از طریق Hadoop"]
    D["پرسمان Hive<br/>از طریق HiveServer2"]
    E["SQL Server<br/>از طریق Dapper"]
    
    F["اعتبارسنجی خروجی<br/>مقایسه نتایج"]
    
    G["تأیید صحت<br/>✓ هر سه روش<br/>شمارش دسته‌های یکسان تولید می‌کنند"]
    
    A --> B
    B --> C
    B --> D
    B --> E
    C --> F
    D --> F
    E --> F
    F --> G
    
    style A fill:#fff3e0
    style C fill:#81c784
    style D fill:#4fc3f7
    style E fill:#ffb74d
    style G fill:#ce93d8
```

---

**نسخه:** 1.0  
**تاریخ آخرین به‌روزرسانی:** 2026-06-25  
**نویسنده:** Technical Documentation Team
