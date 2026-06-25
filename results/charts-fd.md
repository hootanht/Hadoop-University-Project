# نتایجِ بنچمارک (میانهٔ Wall-clock بر حسب ثانیه)

## جدولِ میانهٔ زمان (ثانیه)

| Nodes \ Split | 128MB | 256MB | 512MB |
|---|---:|---:|---:|
| **1** | 59.2 | 43.6 | 33.5 |
| **5** | 29.8 | 27.2 | 29.3 |
| **10** | 27.4 | 27.4 | 29.0 |

## نمودار ۱ — Execution Time vs Number of Nodes (split=256MB)

```mermaid
xychart-beta
    title "Execution Time vs Number of Nodes (split=256MB)"
    x-axis "NodeManagers" [1, 5, 10]
    y-axis "Wall-clock (s)" 0 --> 52
    line [43.6, 27.2, 27.4]
    bar [43.6, 27.2, 27.4]
```

## نمودار ۲ — Execution Time vs Split Size (nodes=10)

```mermaid
xychart-beta
    title "Execution Time vs Split Size (nodes=10)"
    x-axis "Split size (MB)" [128, 256, 512]
    y-axis "Wall-clock (s)" 0 --> 35
    line [27.4, 27.4, 29.0]
```
