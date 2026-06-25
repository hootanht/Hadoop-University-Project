using System;
using System.IO;
using System.Text;

namespace HadoopDotNet.Reducer
{
    /// <summary>
    /// فازِ Reduce (و Combine) در Hadoop Streaming.
    ///
    /// ورودی: خطوطِ «key<TAB>value» که Hadoop آن‌ها را *مرتب‌شده بر اساس key* تحویل می‌دهد
    /// (شرطِ کلیدیِ قراردادِ streaming). بنابراین کافی است تا وقتی key ثابت است value ها
    /// را جمع بزنیم و در لحظهٔ تغییرِ key، نتیجهٔ گروهِ قبلی را چاپ کنیم.
    ///
    /// چون value را به‌صورت عدد می‌خوانیم، این برنامه هم برای Reduce (value=۱ یا جمعِ جزئی)
    /// و هم برای Combine کار می‌کند.
    ///
    /// خروجی: category<TAB>count
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
                        continue; // خطِ بدشکل

                    long value = ParseLong(line, tab + 1);

                    if (currentKey == null)
                    {
                        // اولین گروه
                        currentKey = line.Substring(0, tab);
                        currentCount = value;
                    }
                    else if (SameKey(line, tab, currentKey))
                    {
                        // همان گروه → جمع
                        currentCount += value;
                    }
                    else
                    {
                        // گروه عوض شد → نتیجهٔ گروهِ قبل را چاپ کن
                        Emit(writer, currentKey, currentCount);
                        currentKey = line.Substring(0, tab);
                        currentCount = value;
                    }
                }

                // آخرین گروه
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

        /// <summary>مقایسهٔ key خطِ جاری با key گروهِ فعلی، بدونِ allocation اضافه.</summary>
        private static bool SameKey(string line, int tab, string key)
        {
            if (key.Length != tab)
                return false;
            for (int i = 0; i < tab; i++)
                if (line[i] != key[i])
                    return false;
            return true;
        }

        /// <summary>پارسِ عددِ صحیح از موقعیتِ start تا اولین کاراکترِ غیرعددی، بدونِ Substring.</summary>
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
