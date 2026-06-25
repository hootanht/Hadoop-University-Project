using System;
using System.IO;
using System.Text;
using HadoopDotNet.Common;

namespace HadoopDotNet.Mapper
{
    /// <summary>
    /// فازِ Map در Hadoop Streaming.
    ///
    /// قرارداد: هر خطِ ورودی از stdin خوانده می‌شود و برای هر رکوردِ معتبر،
    /// یک جفتِ «key<TAB>value» به stdout نوشته می‌شود:
    ///     category \t 1
    /// مقدارِ ۱ یعنی «یک بار دیده شد». جمع‌بستن در Reducer/Combiner انجام می‌شود.
    ///
    /// این دقیقاً معادلِ SELECT category, COUNT(*) ... GROUP BY category است:
    /// Map = ساختنِ کلیدِ گروه‌بندی، Reduce = COUNT روی هر گروه.
    /// </summary>
    internal static class Program
    {
        private const int BufferSize = 1 << 20; // 1MB I/O buffer برای کارایی روی ورودیِ حجیم

        private static int Main()
        {
            // stdin/stdout خام؛ UTF-8 بدون BOM؛ بافرِ بزرگ.
            var stdin = Console.OpenStandardInput();
            var stdout = Console.OpenStandardOutput();

            using (var reader = new StreamReader(stdin, new UTF8Encoding(false), false, BufferSize))
            using (var writer = new StreamWriter(stdout, new UTF8Encoding(false), BufferSize))
            {
                string line;
                while ((line = reader.ReadLine()) != null)
                {
                    string category = CategoryParser.TryGetCategory(line);
                    if (category == null)
                        continue; // خطِ هدر/خالی/ناقص

                    // خروجی: category \t 1 \n
                    writer.Write(category);
                    writer.Write('\t');
                    writer.Write('1');
                    writer.Write('\n');
                }
                writer.Flush();
            }
            return 0;
        }
    }
}
