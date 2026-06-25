# Validation Results

This document summarizes the validation of the Hadoop MapReduce output against the SQL Server / Dapper baseline.

## Validation Summary

- Category count match: **18 distinct categories**
- Total record count: **39,240,488**
- MapReduce output matches SQL Server / Dapper output: **Yes**
- Validation status: **Passed**

## Top Categories by Frequency

| Category Code                      |     Count |
| ---------------------------------- | --------: |
| `electronics.smartphone`           | 8,903,840 |
| `(unknown)`                        | 5,258,964 |
| `apparel.shoes`                    | 3,640,420 |
| `computers.notebook`               | 2,830,965 |
| `electronics.audio.headphone`      | 2,428,003 |
| `appliances.kitchen.refrigerators` | 2,223,481 |
| `apparel.tshirt`                   | 2,022,849 |
| `electronics.video.tv`             | 1,820,746 |
| `appliances.kitchen.washer`        | 1,618,124 |
| `electronics.clocks`               | 1,415,245 |

## Notes

- Validation is performed by loading the dataset into SQL Server using `SqlBulkCopy` and running a grouped aggregation query.
- The Hadoop MapReduce results are compared line-by-line with the SQL Server output to ensure exact agreement.
- This confirms that the .NET-based Mapper and Reducer produce the correct aggregated category counts.
