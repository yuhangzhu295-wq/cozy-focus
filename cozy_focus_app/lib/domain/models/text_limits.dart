/// Truncation that cannot produce a broken string.
library;

/// The first [max] code points of [text], or [text] when it already fits.
///
/// Code points rather than code units, because `substring` on a string ending in
/// an emoji cuts through the middle of a surrogate pair and returns a broken
/// character rather than a shorter string. It does not split grapheme clusters
/// (an emoji with a modifier or a ZWJ sequence counts as several), which is
/// enough here: the risk being avoided is producing invalid text, not producing
/// a slightly different count from a field's counter.
String truncateToCodePoints(String text, int max) {
  if (max <= 0) return '';
  final runes = text.runes;
  if (runes.length <= max) return text;
  return String.fromCharCodes(runes.take(max));
}
