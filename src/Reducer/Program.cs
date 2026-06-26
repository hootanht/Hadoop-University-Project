using System;
using System.IO;
using System.Text;

namespace HadoopDotNet.Reducer
{
    /// <summary>
    /// Reduce (and Combine) phase in Hadoop Streaming.
    ///
    /// Input: lines of "key<TAB>value" delivered by Hadoop *sorted by key*
    /// (the key contract of the streaming protocol). It is therefore sufficient
    /// to accumulate values while the key stays the same and emit the previous
    /// group's result the moment the key changes.
    ///
    /// Because values are read as numbers, this program works both as a Reducer
    /// (value=1 or partial sum) and as a Combiner.
    ///
    /// Output: category<TAB>count
    /// </summary>
    internal static class Program
    {
        private const int BufferSize = 1 << 20;

        private static int Main()
        {
            var stdin = Console.OpenStandardInput();
            var stdout = Console.OpenStandardOutput();

            using (var reader = new StreamReader(stdin, new UTF8Encoding(false), false, BufferSize))
            using (var writer = new StreamWriter(stdout, new UTF8Encoding(false), BufferSize))
            {
                string currentKey = null;
                long currentCount = 0;

                string line;
                while ((line = reader.ReadLine()) != null)
                {
                    int tab = line.IndexOf('\t');
                    if (tab < 0)
                        continue; // malformed line

                    long value = ParseLong(line, tab + 1);

                    if (currentKey == null)
                    {
                        // First group
                        currentKey = line.Substring(0, tab);
                        currentCount = value;
                    }
                    else if (SameKey(line, tab, currentKey))
                    {
                        // Same group → accumulate
                        currentCount += value;
                    }
                    else
                    {
                        // Group changed → emit previous group
                        Emit(writer, currentKey, currentCount);
                        currentKey = line.Substring(0, tab);
                        currentCount = value;
                    }
                }

                // Last group
                if (currentKey != null)
                    Emit(writer, currentKey, currentCount);

                writer.Flush();
            }
            return 0;
        }

        private static void Emit(StreamWriter writer, string key, long count)
        {
            writer.Write(key);
            writer.Write('\t');
            writer.Write(count.ToString(System.Globalization.CultureInfo.InvariantCulture));
            writer.Write('\n');
        }

        /// <summary>Compare the current line's key with the current group key, without extra allocation.</summary>
        private static bool SameKey(string line, int tab, string key)
        {
            if (key.Length != tab)
                return false;
            for (int i = 0; i < tab; i++)
                if (line[i] != key[i])
                    return false;
            return true;
        }

        /// <summary>Parse an integer from position start to the first non-digit character, without Substring.</summary>
        private static long ParseLong(string s, int start)
        {
            long v = 0;
            for (int i = start; i < s.Length; i++)
            {
                char c = s[i];
                if (c < '0' || c > '9')
                    break;
                v = v * 10 + (c - '0');
            }
            return v;
        }
    }
}
