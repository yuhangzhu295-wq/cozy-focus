
"""Generate the Dart action-manifest tables from the shipped JSON manifests.

The runtime needs the action packs *synchronously* (the first frame must be
correct without an await), so the JSON stays the authoring source and this
generator emits the Dart mirror. companion_action_manifest_parity_test.dart
fails if the two ever disagree.
"""
import json, os, sys

APP = r"C:\Users\zyu33\Documents\Codex\2026-09-07\new-chat\cozy_focus_app"
COMPANIONS = ["dog", "cat", "rabbit"]


def dart_str(s):
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def emit(companion):
    path = os.path.join(APP, "assets", "companions", companion, "manifest.json")
    if not os.path.exists(path):
        return None
    m = json.load(open(path, encoding="utf-8"))
    lines = []
    lines.append("    %s: CompanionActionManifest(" % dart_str(companion))
    lines.append("      companionId: %s," % dart_str(m["companionId"]))
    lines.append("      posePack: %s," % dart_str(m["posePack"]))
    lines.append("      canvasWidth: %d," % m["canvas"]["width"])
    lines.append("      canvasHeight: %d," % m["canvas"]["height"])
    lines.append("      groundBaseline: %d," % m["groundBaseline"])
    lines.append("      centerAnchor: %d," % m["centerAnchor"])
    lines.append("      actions: {")
    for action in sorted(m["actions"]):
        a = m["actions"][action]
        lines.append("        %s: CompanionActionSpec(" % dart_str(action))
        lines.append("          actionId: %s," % dart_str(action))
        lines.append("          frames: [")
        for f in a["frames"]:
            lines.append("            %s," % dart_str("assets/companions/%s/%s" % (companion, f)))
        lines.append("          ],")
        lines.append("          fps: %d," % a["fps"])
        lines.append("          loopMode: SpriteLoopMode.%s," % {"loop": "loop", "pingpong": "pingPong", "once": "once"}[a["loopMode"]])
        lines.append("          interruptible: %s," % ("true" if a["interruptible"] else "false"))
        lines.append("          reducedMotionFrames: [%s]," % ", ".join(str(x) for x in a["reducedMotionFrames"]))
        lines.append("          targetFrameCount: %d," % a["targetFrameCount"])
        lines.append("        ),")
    lines.append("      },")
    lines.append("      semanticFallback: {")
    for k in sorted(m.get("semanticFallback", {})):
        lines.append("        %s: %s," % (dart_str(k), dart_str(m["semanticFallback"][k])))
    lines.append("      },")
    lines.append("      drawAliases: {")
    for k in sorted(m.get("drawAliases", {})):
        lines.append("        %s: %s," % (dart_str(k), dart_str(m["drawAliases"][k])))
    lines.append("      },")
    lines.append("    ),")
    return "\n".join(lines)


body = []
for c in COMPANIONS:
    e = emit(c)
    if e:
        body.append(e)

header = '''import 'companion_action_manifest.dart';

/// The action packs the app ships, as Dart data.
///
/// ## Why this exists alongside the JSON
///
/// \`assets/companions/<companion>/manifest.json\` is the **authoring source**:
/// readable, diffable, and what the asset pipeline writes. The presentation layer
/// needs it *synchronously* — the first frame of a focus session must be the right
/// drawing without an \`await\` between app start and first paint.
///
/// So the same data is mirrored here, and
/// \`companion_action_manifest_parity_test.dart\` parses the shipped JSON and fails
/// if the two disagree in any field. Drift becomes a test failure rather than a
/// silently wrong animation.
///
/// ## It is still data
///
/// There is no species switch here. The engine reads these tables generically,
/// which is why a fourth companion is a row plus a frame set.
abstract final class CompanionActionManifestData {
  const CompanionActionManifestData._();

  /// \`companion id -> action pack\`.
  static const Map<String, CompanionActionManifest> manifests = {
'''

footer = '''  };

  /// The action pack for [companionId], or \`null\` when none ships.
  static CompanionActionManifest? forCompanion(String companionId) =>
      manifests[companionId];

  /// Every frame path the runtime may ask the bundle for.
  static List<String> get allFrames => [
        for (final manifest in manifests.values) ...manifest.allFrames,
      ];
}
'''

out = header + "\n".join(body) + "\n" + footer
dst = os.path.join(APP, "lib", "presentation", "companion", "runtime", "companion_action_manifest_data.dart")
open(dst, "w", encoding="utf-8").write(out)
print("wrote", dst, len(out), "bytes")
for c in COMPANIONS:
    m = Companion = json.load(open(os.path.join(APP, "assets", "companions", c, "manifest.json"), encoding="utf-8")) if os.path.exists(os.path.join(APP, "assets", "companions", c, "manifest.json")) else None
    if m:
        print(c, len(m["actions"]), "actions", sum(len(a["frames"]) for a in m["actions"].values()), "frames")

