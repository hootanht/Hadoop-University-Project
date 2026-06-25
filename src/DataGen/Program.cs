using System.Diagnostics;
using System.Globalization;
using System.Text;

namespace HadoopDotNet.DataGen;

/// <summary>
/// تولیدِ CSV هم‌شکل با دیتاستِ
/// mkechinov/ecommerce-behavior-data-from-multi-category-store.
/// نمونهٔ اجرا:
///   DataGen --out sample.csv --size-mb 50
///   DataGen --out big.csv    --size-gb 5
/// </summary>
internal static class Program
{
    // فهرستِ دسته‌ها (category_code) با وزن‌های نسبی — شبیهِ توزیعِ واقعی.
    // وزنِ آخر (رشتهٔ خالی) سهمِ رکوردهای بدونِ دسته را می‌سازد → در شمارش به «(unknown)» می‌رود.
    private static readonly (string Code, int Weight)[] Categories =
    {
        ("electronics.smartphone", 220),
        ("electronics.clocks", 35),
        ("electronics.audio.headphone", 60),
        ("electronics.video.tv", 45),
        ("computers.notebook", 70),
        ("computers.peripherals.mouse", 25),
        ("appliances.kitchen.refrigerators", 55),
        ("appliances.kitchen.washer", 40),
        ("appliances.environment.vacuum", 30),
        ("apparel.shoes", 90),
        ("apparel.tshirt", 50),
        ("furniture.living_room.sofa", 20),
        ("furniture.bedroom.bed", 18),
        ("kids.toys", 33),
        ("auto.accessories.player", 22),
        ("sport.bicycle", 15),
        ("construction.tools.light", 12),
        ("", 130), // بدونِ category_code → (unknown)
    };

    private static readonly string[] EventTypes = { "view", "view", "view", "cart", "purchase" };
    private static readonly string[] Brands =
        { "samsung", "apple", "xiaomi", "huawei", "lg", "sony", "bosch", "nike", "adidas", "", "lenovo", "hp" };

    private const string Header =
        "event_time,event_type,product_id,category_id,category_code,brand,price,user_id,user_session";

    private static int Main(string[] args)
    {
        string? outPath = null;
        long targetBytes = 0;
        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--out": outPath = args[++i]; break;
                case "--size-mb": targetBytes = long.Parse(args[++i]) * 1024L * 1024L; break;
                case "--size-gb": targetBytes = (long)(double.Parse(args[++i], CultureInfo.InvariantCulture) * 1024 * 1024 * 1024); break;
                case "--rows": targetBytes = -long.Parse(args[++i]); break; // منفی = حالتِ تعدادِ ردیف
            }
        }
        if (outPath is null || targetBytes == 0)
        {
            Console.Error.WriteLine("استفاده: DataGen --out <path> (--size-mb N | --size-gb N | --rows N)");
            return 2;
        }

        // جدولِ تجمعیِ وزن‌ها برای انتخابِ سریعِ دسته.
        int totalWeight = Categories.Sum(c => c.Weight);
        var cumulative = new int[Categories.Length];
        int acc = 0;
        for (int i = 0; i < Categories.Length; i++) { acc += Categories[i].Weight; cumulative[i] = acc; }

        var rng = new Random(12345); // seed ثابت → تکرارپذیری
        var sw = Stopwatch.StartNew();
        long rows = 0;
        bool rowMode = targetBytes < 0;
        long targetRows = rowMode ? -targetBytes : 0;

        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outPath))!);
        using (var fs = new FileStream(outPath, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20))
        using (var w = new StreamWriter(fs, new UTF8Encoding(false), 1 << 20))
        {
            w.Write(Header);
            w.Write('\n');

            var sb = new StringBuilder(160);
            while (true)
            {
                if (rowMode) { if (rows >= targetRows) break; }
                else if (fs.Position >= targetBytes) break;

                string cat = PickCategory(rng, cumulative, totalWeight);
                string evt = EventTypes[rng.Next(EventTypes.Length)];
                string brand = Brands[rng.Next(Brands.Length)];
                long productId = 1_000_000 + rng.Next(9_000_000);
                long categoryId = 2_000_000_000_000_000_000L + rng.Next(1_000_000);
                double price = Math.Round(rng.NextDouble() * 2000.0, 2);
                long userId = 500_000_000 + rng.Next(40_000_000);

                sb.Clear();
                sb.Append("2019-10-01 ").Append((rows % 24).ToString("D2")).Append(":00:00 UTC,");
                sb.Append(evt).Append(',');
                sb.Append(productId).Append(',');
                sb.Append(categoryId).Append(',');
                sb.Append(cat).Append(',');
                sb.Append(brand).Append(',');
                sb.Append(price.ToString("0.00", CultureInfo.InvariantCulture)).Append(',');
                sb.Append(userId).Append(',');
                AppendSession(sb, rng);
                sb.Append('\n');

                w.Write(sb);
                rows++;
                if ((rows & 0xFFFFF) == 0 && !rowMode)
                {
                    // گزارشِ پیشرفت تقریبی
                    Console.Write($"\r  … {fs.Position / (1024.0 * 1024.0):F0} MB / {targetBytes / (1024.0 * 1024.0):F0} MB");
                }
            }
        }
        sw.Stop();
        var info = new FileInfo(outPath);
        Console.WriteLine($"\n✓ ساخته شد: {outPath}");
        Console.WriteLine($"  ردیف‌ها = {rows:N0} ، حجم = {info.Length / (1024.0 * 1024.0):F1} MB ، زمان = {sw.Elapsed.TotalSeconds:F1}s");
        return 0;
    }

    private static string PickCategory(Random rng, int[] cumulative, int total)
    {
        int r = rng.Next(total);
        for (int i = 0; i < cumulative.Length; i++)
            if (r < cumulative[i]) return Categories[i].Code;
        return Categories[^1].Code;
    }

    private static void AppendSession(StringBuilder sb, Random rng)
    {
        // شبه-UUID (برای حجم و شکلِ واقع‌گرایانه؛ تصادفی‌بودنِ دقیقش مهم نیست).
        const string hex = "0123456789abcdef";
        for (int i = 0; i < 8; i++) sb.Append(hex[rng.Next(16)]);
        sb.Append('-');
        for (int i = 0; i < 4; i++) sb.Append(hex[rng.Next(16)]);
        sb.Append("-4");
        for (int i = 0; i < 3; i++) sb.Append(hex[rng.Next(16)]);
        sb.Append('-');
        for (int i = 0; i < 4; i++) sb.Append(hex[rng.Next(16)]);
        sb.Append('-');
        for (int i = 0; i < 12; i++) sb.Append(hex[rng.Next(16)]);
    }
}
