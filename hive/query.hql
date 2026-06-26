-- =============================================================================
--  پیادهٔ دومِ همان کوئریِ پروژه، این بار با HiveQL (SQL روی HDFS).
--  Hive این SELECT را به یک job از نوع MapReduce روی YARN کامپایل می‌کند.
--  نتیجه باید با MapReduceِ سفارشیِ .NET و مبنای SQL/Dapper یکسان باشد.
-- =============================================================================

DROP TABLE IF EXISTS events;

-- استفاده از تک‌کوت (') برای مقادیر متنی جهت عملکرد صحیح تنظیمات دایرکتوری در هایو
CREATE EXTERNAL TABLE events (
  event_time    STRING,
  event_type    STRING,
  product_id    STRING,
  category_id   STRING,
  category_code STRING,
  brand         STRING,
  price         STRING,
  user_id       STRING,
  user_session  STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
   'separatorChar' = ',',
   'quoteChar'     = '\"'
)
LOCATION '/data/ecommerce'
TBLPROPERTIES ('skip.header.line.count'='1');

-- دسته‌بندی یکپارچه با Subquery برای تجمیع کامل مقادیر خالی به یک ردیف single '(unknown)'
SELECT 
    t.category, 
    COUNT(*) AS cnt
FROM (
    SELECT 
        CASE 
            WHEN category_code IS NULL OR category_code = '' OR category_code = 'null' 
            THEN '(unknown)' 
            ELSE category_code 
        END AS category
    FROM events
) t
GROUP BY t.category
ORDER BY cnt DESC;