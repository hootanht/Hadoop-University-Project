using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace HadoopDotNet.Benchmark;

/// <summary>
/// ارکستراتورِ بنچمارک. نمونهٔ اجرا:
///   Benchmark --nodes 1,5,10 --splits 64,128,256 --repeats 3 \
///             --input /data/ecommerce/2019-Oct.csv --out results\results.csv
/// </summary>
internal static class Program
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(10) };
    private static int _jobSeq = 0;

    private static async Task<int> Main(string[] args)
    {
        Console.OutputEncoding = Encoding.UTF8;
        var o = Options.Parse(args);

        Console.WriteLine("=== Benchmark: Execution Time vs (Nodes × Split Size) ===");
        Console.WriteLine($"nodes={string.Join(',', o.Nodes)} splits={string.Join(',', o.Splits)}MB " +
                          $"repeats={o.Repeats} reduces={o.Reduces}\ninput={o.Input}\n");

        var results = new List<Result>();

        // گره‌ها را صعودی پیمایش می‌کنیم (scale-up) تا گره‌های LOST سر-و-صدا نسازند.
        foreach (int n in o.Nodes.OrderBy(x => x))
        {
            Console.WriteLine($"\n########## مقیاسِ کلاستر به {n} عددNodeManager ##########");
            if (!o.SkipScale)
            {
                Scale(o.ComposeFile, n, o.Datanodes);
                int active = await WaitForNodesAsync(n, TimeSpan.FromSeconds(180));
                Console.WriteLine($"  NodeManagerهای فعال طبق YARN: {active}/{n}");
            }

            foreach (int splitMb in o.Splits)
            {
                for (int r = 1; r <= o.Repeats; r++)
                {
                    var res = await RunOnceAsync(o, n, splitMb, r);
                    results.Add(res);
                    Console.WriteLine($"  [n={n} split={splitMb}MB run={r}] " +
                                      $"wall={res.WallSec:F1}s yarn={(res.YarnSec is { } y ? $"{y:F1}s" : "—")} " +
                                      $"splits={(res.MapSplits?.ToString() ?? "—")} exit={res.Exit}");
                    AppendCsv(o.OutCsv, res);
                }
            }
        }

        WriteCharts(o.ChartsMd, results, o);
        Console.WriteLine($"\n✓ نتایج: {o.OutCsv}\n✓ نمودارها: {o.ChartsMd}");
        return results.All(r => r.Exit == 0) ? 0 : 1;
    }

    // ─────────────────────────── یک اجرای منفرد ────────────────────────────

    private static async Task<Result> RunOnceAsync(Options o, int nodes, int splitMb, int run)
    {
        long splitBytes = (long)splitMb * 1024 * 1024;
        int seq = Interlocked.Increment(ref _jobSeq);
        string jobName = $"bench_n{nodes}_s{splitMb}_r{run}_{seq}";
        string outDir = $"{o.OutBase}/{jobName}";

        // فرمانِ Hadoop Streaming با باینری‌های .NET (که در ایمیجِ nodemanager بِیک شده‌اند).
        string cmd =
            $"hadoop jar {o.StreamingJar} " +
            $"-D mapreduce.job.reduces={o.Reduces} " +
            $"-D mapreduce.input.fileinputformat.split.maxsize={splitBytes} " +
            $"-D mapreduce.input.fileinputformat.split.minsize={splitBytes} " +
            $"-D mapreduce.job.name={jobName} " +
            $"-input {o.Input} -output {outDir} " +
            $"-mapper /opt/dotnet-mr/Mapper/Mapper " +
            $"-combiner /opt/dotnet-mr/Reducer/Reducer " +
            $"-reducer /opt/dotnet-mr/Reducer/Reducer";

        var sw = Stopwatch.StartNew();
        var (exit, _, stderr) = RunProcess("docker",
            new[] { "exec", o.Namenode, "bash", "-c", cmd }, o.JobTimeout);
        sw.Stop();

        int? splits = TryParseSplits(stderr);
        double? yarn = await TryGetYarnElapsedAsync(jobName);

        // پاک‌سازیِ خروجی برای صرفه‌جوییِ دیسک.
        RunProcess("docker", new[] { "exec", o.Namenode, "bash", "-c",
            $"hdfs dfs -rm -r -skipTrash {outDir} >/dev/null 2>&1 || true" }, TimeSpan.FromSeconds(60));

        return new Result(nodes, splitMb, run, Math.Round(sw.Elapsed.TotalSeconds, 2), yarn, splits, exit);
    }

    // ──────────────────────────── کنترلِ کلاستر ────────────────────────────

    private static void Scale(string composeFile, int n, int datanodes)
    {
        // datanode را هم صریحاً تثبیت می‌کنیم تا compose آن را به ۱ کاهش ندهد.
        var (exit, _, err) = RunProcess("docker",
            new[] { "compose", "-f", composeFile, "up", "-d", "--no-recreate",
                    "--scale", $"datanode={datanodes}", "--scale", $"nodemanager={n}" },
            TimeSpan.FromMinutes(5));
        if (exit != 0)
            Console.Error.WriteLine($"  هشدار: scale خطا داد:\n{Trunc(err)}");
    }

    /// <summary>صبر تا وقتی تعدادِ گره‌های RUNNING در YARN ≥ n شود.</summary>
    private static async Task<int> WaitForNodesAsync(int n, TimeSpan timeout)
    {
        var sw = Stopwatch.StartNew();
        int last = -1;
        while (sw.Elapsed < timeout)
        {
            int running = await CountRunningNodesAsync();
            if (running != last) { Console.Write($"\r  انتظار برای ثبتِ گره‌ها: {running}/{n}   "); last = running; }
            // برابریِ دقیق: هنگامِ scale-down باید صبر کنیم تا NodeManagerهای حذف‌شده
            // از RM خارج شوند، وگرنه job روی کلاستری با اندازهٔ اشتباه سنجیده می‌شود.
            if (running == n)
            {
                await Task.Delay(4000); // مکثِ ته‌نشینی تا زمان‌بندی پایدار شود
                Console.WriteLine();
                return running;
            }
            await Task.Delay(2000);
        }
        Console.WriteLine();
        return last < 0 ? 0 : last;
    }

    private static async Task<int> CountRunningNodesAsync()
    {
        try
        {
            string json = await Http.GetStringAsync("http://localhost:8088/ws/v1/cluster/nodes");
            using var doc = JsonDocument.Parse(json);
            if (!doc.RootElement.TryGetProperty("nodes", out var nodes) ||
                !nodes.TryGetProperty("node", out var arr)) return 0;
            int c = 0;
            foreach (var node in arr.EnumerateArray())
                if (node.TryGetProperty("state", out var st) && st.GetString() == "RUNNING") c++;
            return c;
        }
        catch { return 0; }
    }

    private static async Task<double?> TryGetYarnElapsedAsync(string jobName)
    {
        try
        {
            string json = await Http.GetStringAsync(
                "http://localhost:8088/ws/v1/cluster/apps?limit=40");
            using var doc = JsonDocument.Parse(json);
            if (!doc.RootElement.TryGetProperty("apps", out var apps) ||
                apps.ValueKind == JsonValueKind.Null ||
                !apps.TryGetProperty("app", out var arr)) return null;
            foreach (var app in arr.EnumerateArray())
                if (app.TryGetProperty("name", out var nm) && nm.GetString() == jobName &&
                    app.TryGetProperty("elapsedTime", out var el))
                    return el.GetInt64() / 1000.0;
            return null;
        }
        catch { return null; }
    }

    private static int? TryParseSplits(string stderr)
    {
        var m = Regex.Match(stderr, @"number of splits[:\s]+(\d+)", RegexOptions.IgnoreCase);
        return m.Success ? int.Parse(m.Groups[1].Value) : null;
    }

    // ───────────────────────────── خروجی‌ها ────────────────────────────────

    private static void AppendCsv(string path, Result r)
    {
        bool isNew = !File.Exists(path);
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        using var w = new StreamWriter(path, append: true, new UTF8Encoding(false));
        if (isNew) w.WriteLine("nodes,split_mb,run,wallclock_sec,yarn_elapsed_sec,map_splits,exit_code");
        w.WriteLine(string.Join(',', new[]
        {
            r.Nodes.ToString(), r.SplitMb.ToString(), r.Run.ToString(),
            r.WallSec.ToString("F2", CultureInfo.InvariantCulture),
            r.YarnSec?.ToString("F2", CultureInfo.InvariantCulture) ?? "",
            r.MapSplits?.ToString() ?? "", r.Exit.ToString()
        }));
    }

    private static void WriteCharts(string path, List<Result> all, Options o)
    {
        // میانه‌ها (median) برای هر (nodes, split).
        double Median(IEnumerable<double> xs)
        {
            var s = xs.OrderBy(x => x).ToArray();
            if (s.Length == 0) return 0;
            return s.Length % 2 == 1 ? s[s.Length / 2] : (s[s.Length / 2 - 1] + s[s.Length / 2]) / 2.0;
        }

        var nodes = o.Nodes.OrderBy(x => x).ToArray();
        var splits = o.Splits.ToArray();
        double med(int n, int s) =>
            Median(all.Where(r => r.Nodes == n && r.SplitMb == s && r.Exit == 0).Select(r => r.WallSec));

        var sb = new StringBuilder();
        sb.AppendLine("# نتایجِ بنچمارک (میانهٔ Wall-clock بر حسب ثانیه)\n");

        // جدولِ کامل
        sb.AppendLine("## جدولِ میانهٔ زمان (ثانیه)\n");
        sb.Append("| Nodes \\ Split |");
        foreach (var s in splits) sb.Append($" {s}MB |");
        sb.AppendLine();
        sb.Append("|---|");
        foreach (var _ in splits) sb.Append("---:|");
        sb.AppendLine();
        foreach (var n in nodes)
        {
            sb.Append($"| **{n}** |");
            foreach (var s in splits) sb.Append($" {med(n, s):F1} |");
            sb.AppendLine();
        }
        sb.AppendLine();

        // نمودار ۱: زمان بر حسب تعدادِ گره (به‌ازای split میانی)
        int midSplit = splits[splits.Length / 2];
        var seriesNodes = nodes.Select(n => med(n, midSplit)).ToArray();
        double yMax1 = Math.Max(1, seriesNodes.DefaultIfEmpty(1).Max()) * 1.2;
        sb.AppendLine($"## نمودار ۱ — Execution Time vs Number of Nodes (split={midSplit}MB)\n");
        sb.AppendLine("```mermaid");
        sb.AppendLine("xychart-beta");
        sb.AppendLine($"    title \"Execution Time vs Number of Nodes (split={midSplit}MB)\"");
        sb.AppendLine($"    x-axis \"NodeManagers\" [{string.Join(", ", nodes)}]");
        sb.AppendLine($"    y-axis \"Wall-clock (s)\" 0 --> {yMax1:F0}");
        sb.AppendLine($"    line [{string.Join(", ", seriesNodes.Select(v => v.ToString("F1", CultureInfo.InvariantCulture)))}]");
        sb.AppendLine($"    bar [{string.Join(", ", seriesNodes.Select(v => v.ToString("F1", CultureInfo.InvariantCulture)))}]");
        sb.AppendLine("```\n");

        // نمودار ۲: زمان بر حسب اندازهٔ Split (به‌ازای بیشترین گره)
        int maxNode = nodes[^1];
        var seriesSplit = splits.Select(s => med(maxNode, s)).ToArray();
        double yMax2 = Math.Max(1, seriesSplit.DefaultIfEmpty(1).Max()) * 1.2;
        sb.AppendLine($"## نمودار ۲ — Execution Time vs Split Size (nodes={maxNode})\n");
        sb.AppendLine("```mermaid");
        sb.AppendLine("xychart-beta");
        sb.AppendLine($"    title \"Execution Time vs Split Size (nodes={maxNode})\"");
        sb.AppendLine($"    x-axis \"Split size (MB)\" [{string.Join(", ", splits)}]");
        sb.AppendLine($"    y-axis \"Wall-clock (s)\" 0 --> {yMax2:F0}");
        sb.AppendLine($"    line [{string.Join(", ", seriesSplit.Select(v => v.ToString("F1", CultureInfo.InvariantCulture)))}]");
        sb.AppendLine("```");

        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        File.WriteAllText(path, sb.ToString(), new UTF8Encoding(false));
    }

    // ───────────────────────────── کمک‌ها ──────────────────────────────────

    private static (int exit, string stdout, string stderr) RunProcess(string file, string[] args, TimeSpan timeout)
    {
        var psi = new ProcessStartInfo(file)
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true,
        };
        foreach (var a in args) psi.ArgumentList.Add(a);

        using var p = new Process { StartInfo = psi };
        var so = new StringBuilder();
        var se = new StringBuilder();
        p.OutputDataReceived += (_, e) => { if (e.Data != null) so.AppendLine(e.Data); };
        p.ErrorDataReceived += (_, e) => { if (e.Data != null) se.AppendLine(e.Data); };
        p.Start();
        p.BeginOutputReadLine();
        p.BeginErrorReadLine();
        if (!p.WaitForExit((int)timeout.TotalMilliseconds))
        {
            try { p.Kill(true); } catch { /* ignore */ }
            return (-1, so.ToString(), se.ToString() + "\n[TIMEOUT]");
        }
        p.WaitForExit();
        return (p.ExitCode, so.ToString(), se.ToString());
    }

    private static string Trunc(string s, int max = 800) => s.Length <= max ? s : s[^max..];

    private sealed record Result(int Nodes, int SplitMb, int Run, double WallSec,
        double? YarnSec, int? MapSplits, int Exit);

    private sealed class Options
    {
        public int[] Nodes = { 1, 5, 10 };
        // Hadoop Streaming از API قدیمیِ mapred استفاده می‌کند که split.maxsize را نادیده می‌گیرد؛
        // عملاً split.minsize تعیین‌کننده است و فقط وقتی ≥ اندازهٔ بلاک (۱۲۸MB) باشد تعدادِ split را تغییر می‌دهد.
        // پس مقادیر ≥۱۲۸ انتخاب شده‌اند → روی فایلِ ۱ گیگ به‌ترتیب ۸/۴/۲ split.
        public int[] Splits = { 128, 256, 512 };
        public int Repeats = 3;
        public int Reduces = 1;
        public int Datanodes = 2;
        public string Input = "/data/ecommerce/2019-Oct.csv";
        public string OutBase = "/out";
        public string Namenode = "namenode";
        public string ComposeFile = "docker/docker-compose.yml";
        public string StreamingJar = "/opt/hadoop-2.7.4/share/hadoop/tools/lib/hadoop-streaming-2.7.4.jar";
        public string OutCsv = "results/results.csv";
        public string ChartsMd = "results/charts.md";
        public bool SkipScale = false;
        public TimeSpan JobTimeout = TimeSpan.FromHours(1);

        public static Options Parse(string[] a)
        {
            var o = new Options();
            for (int i = 0; i < a.Length; i++)
            {
                switch (a[i])
                {
                    case "--nodes": o.Nodes = ParseInts(a[++i]); break;
                    case "--splits": o.Splits = ParseInts(a[++i]); break;
                    case "--repeats": o.Repeats = int.Parse(a[++i]); break;
                    case "--reduces": o.Reduces = int.Parse(a[++i]); break;
                    case "--datanodes": o.Datanodes = int.Parse(a[++i]); break;
                    case "--input": o.Input = a[++i]; break;
                    case "--out-base": o.OutBase = a[++i]; break;
                    case "--namenode": o.Namenode = a[++i]; break;
                    case "--compose": o.ComposeFile = a[++i]; break;
                    case "--streaming-jar": o.StreamingJar = a[++i]; break;
                    case "--out": o.OutCsv = a[++i]; break;
                    case "--charts": o.ChartsMd = a[++i]; break;
                    case "--skip-scale": o.SkipScale = true; break;
                    case "--job-timeout-min": o.JobTimeout = TimeSpan.FromMinutes(int.Parse(a[++i])); break;
                }
            }
            return o;
        }

        private static int[] ParseInts(string s) =>
            s.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
             .Select(int.Parse).ToArray();
    }
}
