using System;

namespace HadoopDotNet.Common
{
    /// <summary>
    /// منطقِ مشترکِ استخراجِ «دسته» از یک خطِ CSV دیتاستِ
    /// mkechinov/ecommerce-behavior-data-from-multi-category-store.
    ///
    /// چیدمانِ ستون‌ها (۰-مبنا):
    ///   0=event_time, 1=event_type, 2=product_id, 3=category_id,
    ///   4=category_code, 5=brand, 6=price, 7=user_id, 8=user_session
    ///
    /// «category» موردِ نظرِ کوئریِ پروژه = ستونِ شمارهٔ ۴ (category_code).
    /// این کلاس عمداً از کتابخانه‌های سنگینِ CSV استفاده نمی‌کند؛ چون روی
    /// چند ده میلیون خط اجرا می‌شود و سرعتِ پارس مهم است (پارسِ دستی با اسکنِ کاراکتری).
    /// </summary>
    public static class CategoryParser
    {
        /// <summary>سنتینلِ مقادیرِ خالیِ category_code (هم در Mapper، هم در Validator یکسان).</summary>
        public const string Unknown = "(unknown)";

        /// <summary>جداکنندهٔ ستون‌ها در فایلِ ورودی.</summary>
        private const char Delimiter = ',';

        // ایندکسِ ستونِ هدف (category_code).
        private const int CategoryColumnIndex = 4;

        /// <summary>
        /// دسته را از یک خط برمی‌گرداند.
        /// خروجیِ null یعنی «این خط را نادیده بگیر» (خطِ هدر یا خطِ خالی/ناقص).
        /// خروجیِ غیرِnull یعنی دستهٔ نرمال‌شده (خالی → <see cref="Unknown"/>).
        /// </summary>
        public static string TryGetCategory(string line)
        {
            if (string.IsNullOrEmpty(line))
                return null;

            // ردکردنِ خطِ هدر: «event_time,event_type,...»
            // (با skip.header در Hive و skip در Validator هم‌خوان است)
            if (line[0] == 'e' && line.StartsWith("event_time", StringComparison.Ordinal))
                return null;

            // یافتنِ ابتدای ستونِ ۴ = موقعیتِ بعد از چهارمین کاما.
            int start = StartOfColumn(line, CategoryColumnIndex);
            if (start < 0)
                return null; // خطِ ناقص (کمتر از ۵ ستون) → نادیده

            // یافتنِ انتهای ستونِ ۴ = کامای بعدی (یا انتهای خط).
            int end = line.IndexOf(Delimiter, start);
            int len = (end < 0 ? line.Length : end) - start;

            // trim دستی (فضای ابتدا/انتها) بدون allocation اضافه.
            while (len > 0 && IsWhite(line[start])) { start++; len--; }
            while (len > 0 && IsWhite(line[start + len - 1])) { len--; }

            return len == 0 ? Unknown : line.Substring(start, len);
        }

        /// <summary>موقعیتِ شروعِ ستونِ شمارهٔ <paramref name="columnIndex"/> (۰-مبنا) را برمی‌گرداند.</summary>
        private static int StartOfColumn(string line, int columnIndex)
        {
            if (columnIndex == 0) return 0;
            int seen = 0;
            for (int i = 0; i < line.Length; i++)
            {
                if (line[i] == Delimiter)
                {
                    seen++;
                    if (seen == columnIndex) return i + 1;
                }
            }
            return -1;
        }

        private static bool IsWhite(char c) => c == ' ' || c == '\t' || c == '\r';
    }
}
