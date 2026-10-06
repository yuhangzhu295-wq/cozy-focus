import '../../domain/services/duration_text.dart';

/// How long something is, written the way the designs write it.
///
/// The implementation lives in the domain, because the timeline projection builds
/// its own detail lines and would otherwise need a second copy. This is the name
/// the presentation layer uses.
String formatTaskDuration(int seconds) => formatDurationText(seconds);
