using System.Data;
using System.Diagnostics;
using System.Globalization;
using System.Text;
using Dapper;
using HadoopDotNet.Common;
using Microsoft.Data.SqlClient;

namespace HadoopDotNet.Validator;

/// <summary>
/// نقطهٔ ورودِ صحت‌سنجی.
/// نمونهٔ اجرا:
///   Validator --csv D:\...\2019-Oct.csv --mr D:\...\mr_out.txt ^
///             --sql-conn "Server=localhost,1433;User Id=sa;Password=...;TrustServerCertificate=True;Encrypt=False" ^
///             --reset-table --csharp-baseline --report results\validation.md
/// </summary>
internal static class Program
{
    private static async Task<int> Main(string[] args)
    {
        var opt = Options.Parse(args);
        Console.OutputEncoding = Encoding.UTF8;

        Console.WriteLine("==================================================================");
        Console.WriteLine("  Validator — مقایسهٔ صحتِ MapReduce با مبنای تک‌رشته‌ایِ SQL/Dapper");
        Console.WriteLine("==================================================================");

        Dictionary<string, long>? mr = null;
        Dictionary<string, long>? sql = null;
        Dictionary<string, long>? csharp = null;

        // ── (۱) خروجیِ MapReduce ─────────────────────────────────────────────
        if (opt.MrPath is not null)
        {
            Console.WriteLine($"\n[MR ] خواندنِ خروجیِ MapReduce از: {opt.MrPath}");
            mr = ReadKeyCountFile(opt.MrPath);
            Console.WriteLine($"[MR ] تعداد دسته‌ها = {mr.Count:N0} ، مجموعِ رکوردها = {mr.Values.Sum():N0}");
        }

        // ── (۲) شمارشِ تک‌رشته‌ایِ C# (اختیاری، با همان CategoryParser) ─────────
        if (opt.CSharpBaseline && opt.CsvPath is not null)
        {
            Console.WriteLine($"\n[C#  ] شمارشِ تک‌رشته‌ای از CSV با CategoryParser مشترک …");
            var sw = Stopwatch.StartNew();
            csharp = CSharpStreamingCount(opt.CsvPath);
            sw.Stop();
            Console.WriteLine($"[C#  ] دسته‌ها = {csharp.Count:N0} ، رکوردها = {csharp.Values.Sum():N0} ، زمان = {sw.Elapsed.TotalSeconds:F1}s");
        }

        // ── (۳) مبنای SQL با Dapper ──────────────────────────────────────────
        if (opt.SqlConn is not null && opt.CsvPath is not null)
        {
            sql = await RunSqlBaselineAsync(opt);
        }
        else if (opt.SqlConn is not null)
        {
            Console.WriteLine("\n[SQL ] connection داده شد اما --csv نه؛ از بارگذاری صرفِ‌نظر شد.");
        }

        // ── (۴) مقایسه‌ها ────────────────────────────────────────────────────
        Console.WriteLine("\n------------------------------ نتیجهٔ مقایسه ------------------------------");
        bool allMatch = true;
        allMatch &= Compare("MapReduce", mr, "SQL/Dapper", sql);
        allMatch &= Compare("MapReduce", mr, "C#-تک‌رشته‌ای", csharp);
        allMatch &= Compare("SQL/Dapper", sql, "C#-تک‌رشته‌ای", csharp);

        // گزارشِ مارک‌داون (برای REPORT)
        if (opt.ReportPath is not null)
        {
            WriteMarkdownReport(opt.ReportPath, mr, sql, csharp);
            Console.WriteLine($"\n[DOC ] گزارشِ صحت‌سنجی نوشته شد: {opt.ReportPath}");
        }

        Console.WriteLine("\n==================================================================");
        if (allMatch)
        {
            Console.WriteLine("  ✓ نتیجه: همهٔ مبناهای موجود کاملاً یکسان‌اند (Correctness تأیید شد).");
            return 0;
        }
        Console.WriteLine("  ✗ نتیجه: اختلاف پیدا شد — جزئیات بالا. ExitCode=1");
        return 1;
    }

    // ───────────────────────────── SQL / Dapper ─────────────────────────────

    private static async Task<Dictionary<string, long>> RunSqlBaselineAsync(Options opt)
    {
        const string dbName = "validation";
        const string table = "dbo.events";

        // (الف) ساختِ پایگاه‌داده در صورتِ نبود.
        var masterCsb = new SqlConnectionStringBuilder(opt.SqlConn!) { InitialCatalog = "master" };
        await using (var master = new SqlConnection(masterCsb.ConnectionString))
        {
            await master.OpenAsync();
            await master.ExecuteAsync(
                $"IF DB_ID(N'{dbName}') IS NULL CREATE DATABASE [{dbName}];");
        }

        var dbCsb = new SqlConnectionStringBuilder(opt.SqlConn!) { InitialCatalog = dbName };
        await using var conn = new SqlConnection(dbCsb.ConnectionString);
        await conn.OpenAsync();

        // (ب) جدول.
        if (opt.ResetTable)
            await conn.ExecuteAsync($"IF OBJECT_ID(N'{table}') IS NOT NULL DROP TABLE {table};");
        await conn.ExecuteAsync(
            $"IF OBJECT_ID(N'{table}') IS NULL CREATE TABLE {table} (category NVARCHAR(256) NOT NULL);");

        long existing = await conn.ExecuteScalarAsync<long>($"SELECT COUNT_BIG(*) FROM {table};");
        if (existing > 0 && !opt.ResetTable)
        {
            Console.WriteLine($"\n[SQL ] جدول از قبل {existing:N0} رکورد دارد؛ از بارگذاریِ مجدد صرف‌نظر شد (برای بارگذاریِ تازه از --reset-table استفاده کنید).");
        }
        else
        {
            Console.WriteLine($"\n[SQL ] بارگذاریِ category از CSV به {table} با SqlBulkCopy …");
            var swLoad = Stopwatch.StartNew();
            long rows = await BulkLoadAsync(dbCsb.ConnectionString, table, opt.CsvPath!);
            swLoad.Stop();
            Console.WriteLine($"[SQL ] {rows:N0} رکورد در {swLoad.Elapsed.TotalSeconds:F1}s بارگذاری شد " +
                              $"({rows / Math.Max(1, swLoad.Elapsed.TotalSeconds):N0} ردیف/ثانیه).");
        }

        // (ج) کوئریِ مبنا — دقیقاً معادلِ SELECT category, COUNT(*) GROUP BY category،
        //     تک‌رشته‌ای (MAXDOP 1) تا «حالتِ تک‌هسته‌ای» باشد، اجرا با Dapper.
        const string groupBySql =
            "SELECT category AS Category, COUNT_BIG(*) AS Cnt " +
            "FROM dbo.events GROUP BY category OPTION (MAXDOP 1);";

        Console.WriteLine("[SQL ] اجرای GROUP BY تک‌رشته‌ای با Dapper …");
        var swQ = Stopwatch.StartNew();
        var rowsResult = (await conn.QueryAsync<CatCount>(new CommandDefinition(groupBySql, commandTimeout: 0))).ToList();
        swQ.Stop();

        var dict = new Dictionary<string, long>(StringComparer.Ordinal);
        foreach (var r in rowsResult)
            dict[r.Category] = r.Cnt;

        Console.WriteLine($"[SQL ] دسته‌ها = {dict.Count:N0} ، رکوردها = {dict.Values.Sum():N0} ، زمانِ کوئری = {swQ.Elapsed.TotalSeconds:F2}s");
        return dict;
    }

    /// <summary>بارگذاریِ استریمیِ ستونِ category با SqlBulkCopy (کم‌حافظه).</summary>
    private static async Task<long> BulkLoadAsync(string connString, string table, string csvPath)
    {
        await using var conn = new SqlConnection(connString);
        await conn.OpenAsync();

        using var reader = new CategoryCsvDataReader(csvPath);
        using var bulk = new SqlBulkCopy(conn)
        {
            DestinationTableName = table,
            BulkCopyTimeout = 0,
            BatchSize = 100_000,
            EnableStreaming = true,
        };
        bulk.ColumnMappings.Add(0, "category");
        await bulk.WriteToServerAsync(reader);
        return reader.RowsRead;
    }

    private sealed record CatCount(string Category, long Cnt);

    // ─────────────────────────── شمارشِ C# و فایلِ MR ───────────────────────

    private static Dictionary<string, long> CSharpStreamingCount(string csvPath)
    {
        var dict = new Dictionary<string, long>(StringComparer.Ordinal);
        using var reader = new StreamReader(csvPath, Encoding.UTF8, true, 1 << 20);
        string? line;
        while ((line = reader.ReadLine()) is not null)
        {
            var cat = CategoryParser.TryGetCategory(line);
            if (cat is null) continue;
            dict.TryGetValue(cat, out long c);
            dict[cat] = c + 1;
        }
        return dict;
    }

    /// <summary>خواندنِ خروجیِ «key&lt;TAB&gt;count» از یک فایل یا یک پوشه (part-*).</summary>
    private static Dictionary<string, long> ReadKeyCountFile(string path)
    {
        var dict = new Dictionary<string, long>(StringComparer.Ordinal);
        IEnumerable<string> files = Directory.Exists(path)
            ? Directory.EnumerateFiles(path, "*").Where(f => !Path.GetFileName(f).StartsWith("_"))
            : new[] { path };

        foreach (var f in files)
        {
            using var reader = new StreamReader(f, Encoding.UTF8, true, 1 << 20);
            string? line;
            while ((line = reader.ReadLine()) is not null)
            {
                if (line.Length == 0) continue;
                int tab = line.IndexOf('\t');
                if (tab < 0) continue;
                string key = line[..tab];
                if (!long.TryParse(line.AsSpan(tab + 1), NumberStyles.Integer, CultureInfo.InvariantCulture, out long val))
                    continue;
                dict.TryGetValue(key, out long c);
                dict[key] = c + val;
            }
        }
        return dict;
    }

    // ───────────────────────────── مقایسه و گزارش ───────────────────────────

    private static bool Compare(string nameA, Dictionary<string, long>? a, string nameB, Dictionary<string, long>? b)
    {
        if (a is null || b is null) return true; // یکی موجود نیست → از این مقایسه عبور

        var keys = new HashSet<string>(a.Keys, StringComparer.Ordinal);
        keys.UnionWith(b.Keys);

        int diffs = 0;
        long sumA = a.Values.Sum(), sumB = b.Values.Sum();
        foreach (var k in keys.OrderBy(x => x, StringComparer.Ordinal))
        {
            a.TryGetValue(k, out long va);
            b.TryGetValue(k, out long vb);
            if (va != vb)
            {
                if (diffs < 20)
                    Console.WriteLine($"   ✗ اختلاف در «{k}»: {nameA}={va:N0} ، {nameB}={vb:N0}");
                diffs++;
            }
        }

        if (diffs == 0)
            Console.WriteLine($"✓ {nameA} == {nameB}  (دسته‌ها={a.Count:N0}, مجموع={sumA:N0})");
        else
            Console.WriteLine($"✗ {nameA} vs {nameB}: {diffs:N0} اختلاف ؛ مجموع‌ها: {nameA}={sumA:N0} ، {nameB}={sumB:N0}");
        return diffs == 0;
    }

    private static void WriteMarkdownReport(string path, Dictionary<string, long>? mr,
        Dictionary<string, long>? sql, Dictionary<string, long>? csharp)
    {
        var primary = mr ?? sql ?? csharp;
        if (primary is null) return;

        var sb = new StringBuilder();
        sb.AppendLine("# نتیجهٔ صحت‌سنجی (Validation)\n");
        sb.AppendLine($"- تعدادِ دسته‌ها: **{primary.Count:N0}**");
        sb.AppendLine($"- مجموعِ کلِ رکوردها: **{primary.Values.Sum():N0}**");
        bool m1 = mr is not null && sql is not null && DictEquals(mr, sql);
        bool m2 = mr is not null && csharp is not null && DictEquals(mr, csharp);
        if (mr is not null && sql is not null) sb.AppendLine($"- تطابقِ MapReduce == SQL/Dapper: **{(m1 ? "✓ بله" : "✗ خیر")}**");
        if (mr is not null && csharp is not null) sb.AppendLine($"- تطابقِ MapReduce == C#: **{(m2 ? "✓ بله" : "✗ خیر")}**");
        sb.AppendLine("\n## ۲۰ دستهٔ پرتکرار\n");
        sb.AppendLine("| دسته (category_code) | تعداد |");
        sb.AppendLine("|---|---:|");
        foreach (var kv in primary.OrderByDescending(k => k.Value).Take(20))
            sb.AppendLine($"| `{kv.Key}` | {kv.Value:N0} |");

        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        File.WriteAllText(path, sb.ToString(), new UTF8Encoding(false));
    }

    private static bool DictEquals(Dictionary<string, long> a, Dictionary<string, long> b)
    {
        if (a.Count != b.Count) return false;
        foreach (var kv in a)
            if (!b.TryGetValue(kv.Key, out long v) || v != kv.Value) return false;
        return true;
    }

    // ───────────────────────────── آرگومان‌ها ──────────────────────────────

    private sealed class Options
    {
        public string? CsvPath;
        public string? MrPath;
        public string? SqlConn;
        public bool ResetTable;
        public bool CSharpBaseline;
        public string? ReportPath;

        public static Options Parse(string[] a)
        {
            var o = new Options();
            for (int i = 0; i < a.Length; i++)
            {
                switch (a[i])
                {
                    case "--csv": o.CsvPath = a[++i]; break;
                    case "--mr": o.MrPath = a[++i]; break;
                    case "--sql-conn": o.SqlConn = a[++i]; break;
                    case "--reset-table": o.ResetTable = true; break;
                    case "--csharp-baseline": o.CSharpBaseline = true; break;
                    case "--report": o.ReportPath = a[++i]; break;
                    default: Console.Error.WriteLine($"آرگومانِ ناشناخته: {a[i]}"); break;
                }
            }
            return o;
        }
    }
}

/// <summary>
/// یک IDataReader سبک که فقط ستونِ «category» را به‌صورتِ استریمی از CSV
/// به SqlBulkCopy می‌دهد (بدون نگه‌داشتنِ کلِ فایل در حافظه).
/// از همان CategoryParser مشترک استفاده می‌کند تا با Mapper یکی باشد.
/// </summary>
internal sealed class CategoryCsvDataReader : IDataReader
{
    private readonly StreamReader _reader;
    private string _current = string.Empty;
    public long RowsRead { get; private set; }

    public CategoryCsvDataReader(string path)
        => _reader = new StreamReader(path, Encoding.UTF8, true, 1 << 20);

    public bool Read()
    {
        string? line;
        while ((line = _reader.ReadLine()) is not null)
        {
            var cat = CategoryParser.TryGetCategory(line);
            if (cat is null) continue;
            _current = cat;
            RowsRead++;
            return true;
        }
        return false;
    }

    public object GetValue(int i) => _current;
    public int FieldCount => 1;
    public object this[int i] => _current;
    public object this[string name] => _current;
    public string GetName(int i) => "category";
    public int GetOrdinal(string name) => 0;
    public Type GetFieldType(int i) => typeof(string);
    public string GetDataTypeName(int i) => "nvarchar";
    public bool IsDBNull(int i) => false;

    public void Dispose() => _reader.Dispose();
    public void Close() => _reader.Dispose();
    public bool NextResult() => false;
    public int Depth => 0;
    public bool IsClosed => false;
    public int RecordsAffected => -1;

    // اعضای استفاده‌نشدهٔ IDataReader (SqlBulkCopy فقط به موارد بالا نیاز دارد).
    public bool GetBoolean(int i) => throw new NotSupportedException();
    public byte GetByte(int i) => throw new NotSupportedException();
    public long GetBytes(int i, long o, byte[]? b, int bo, int len) => throw new NotSupportedException();
    public char GetChar(int i) => throw new NotSupportedException();
    public long GetChars(int i, long o, char[]? b, int bo, int len) => throw new NotSupportedException();
    public IDataReader GetData(int i) => throw new NotSupportedException();
    public DateTime GetDateTime(int i) => throw new NotSupportedException();
    public decimal GetDecimal(int i) => throw new NotSupportedException();
    public double GetDouble(int i) => throw new NotSupportedException();
    public float GetFloat(int i) => throw new NotSupportedException();
    public Guid GetGuid(int i) => throw new NotSupportedException();
    public short GetInt16(int i) => throw new NotSupportedException();
    public int GetInt32(int i) => throw new NotSupportedException();
    public long GetInt64(int i) => throw new NotSupportedException();
    public string GetString(int i) => _current;
    public int GetValues(object[] values) { values[0] = _current; return 1; }
    public DataTable GetSchemaTable() => throw new NotSupportedException();
}
