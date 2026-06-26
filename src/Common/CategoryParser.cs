using System;

namespace HadoopDotNet.Common
{
    /// <summary>
    /// Shared logic for extracting the "category" from a CSV line of the
    /// mkechinov/ecommerce-behavior-data-from-multi-category-store dataset.
    ///
    /// Column layout (0-based):
    ///   0=event_time, 1=event_type, 2=product_id, 3=category_id,
    ///   4=category_code, 5=brand, 6=price, 7=user_id, 8=user_session
    ///
    /// The "category" targeted by the project query = column 4 (category_code).
    /// This class intentionally avoids heavy CSV libraries because it runs over
    /// tens of millions of lines and parse speed matters (manual character-scan).
    /// </summary>
    public static class CategoryParser
    {
        /// <summary>Sentinel for empty category_code values (consistent across Mapper and Validator).</summary>
        public const string Unknown = "(unknown)";

        /// <summary>Column delimiter in the input file.</summary>
        private const char Delimiter = ',';

        // ایندکسِ ستونِ هدف (category_code).
        private const int CategoryColumnIndex = 4;

        /// <summary>
        /// Returns the category from a line.
        /// A null return means "skip this line" (header, empty, or incomplete line).
        /// A non-null return is the normalised category (empty → <see cref="Unknown"/>).
        /// </summary>
        public static string TryGetCategory(string line)
        {
            if (string.IsNullOrEmpty(line))
                return null;

            // Skip header line: "event_time,event_type,..."
            // (consistent with skip.header in Hive and skip in Validator)
            if (line[0] == 'e' && line.StartsWith("event_time", StringComparison.Ordinal))
                return null;

            // Find the start of column 4 = position after the fourth comma.
            int start = StartOfColumn(line, CategoryColumnIndex);
            if (start < 0)
                return null; // incomplete line (fewer than 5 columns) → skip

            // Find the end of column 4 = next comma (or end of line).
            int end = line.IndexOf(Delimiter, start);
            int len = (end < 0 ? line.Length : end) - start;

            // Manual trim (leading/trailing whitespace) without extra allocation.
            while (len > 0 && IsWhite(line[start])) { start++; len--; }
            while (len > 0 && IsWhite(line[start + len - 1])) { len--; }

            return len == 0 ? Unknown : line.Substring(start, len);
        }

        /// <summary>Returns the start position of column <paramref name="columnIndex"/> (0-based).</summary>
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
