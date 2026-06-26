using System;
using System.IO;
using System.Text;
using HadoopDotNet.Common;

namespace HadoopDotNet.Mapper
{
    /// <summary>
    /// Map phase in Hadoop Streaming.
    ///
    /// Contract: each input line is read from stdin and for every valid record
    /// a "key<TAB>value" pair is written to stdout:
    ///     category \t 1
    /// The value 1 means "seen once". Summing is done in the Reducer/Combiner.
    ///
    /// This is exactly equivalent to SELECT category, COUNT(*) ... GROUP BY category:
    /// Map = build the grouping key, Reduce = COUNT per group.
    /// </summary>
    internal static class Program
    {
        private const int BufferSize = 1 << 20; // 1MB I/O buffer for performance on large input

        private static int Main()
        {
            // Raw stdin/stdout; UTF-8 without BOM; large buffer.
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
                        continue; // header / empty / incomplete line

                    // Output: category \t 1 \n
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
