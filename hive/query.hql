-- =============================================================================
--  پیادهٔ دومِ همان کوئریِ پروژه، این بار با HiveQL (SQL روی HDFS).
--  Hive این SELECT را به یک job از نوع MapReduce روی YARN کامپایل می‌کند.
--  نتیجه باید با MapReduceِ سفارشیِ .NET و مبنای SQL/Dapper یکسان باشد.
-- =============================================================================

DROP TABLE IF EXISTS events;

-- جدولِ EXTERNAL روی همان پوشهٔ HDFS که داده را در آن put کردیم.
CREATE EXTERNAL TABLE events (
  event_time    STRING,
  event_type    STRING,
  product_id    BIGINT,
  category_id   BIGINT,
  category_code STRING,
  brand         STRING,
  price         DOUBLE,
  user_id       BIGINT,
  user_session  STRING
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/data/ecommerce'
TBLPROPERTIES ('skip.header.line.count'='1');

-- SELECT category, COUNT(*) ... GROUP BY category
-- نرمال‌سازیِ مقدارِ خالی به «(unknown)» — دقیقاً مثلِ Mapper و Validator.
SELECT
  CASE WHEN category_code IS NULL OR category_code = '' THEN '(unknown)' ELSE category_code END AS category,
  COUNT(*) AS cnt
FROM events
GROUP BY CASE WHEN category_code IS NULL OR category_code = '' THEN '(unknown)' ELSE category_code END
ORDER BY cnt DESC;
