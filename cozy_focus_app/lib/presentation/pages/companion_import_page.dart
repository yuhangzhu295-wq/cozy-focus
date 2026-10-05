import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../companion/companion_selection.dart';
import '../companion/pack/companion_pack_import.dart';
import '../companion/pack/companion_pack_install_plan.dart';
import '../companion/pack/companion_pack_picker.dart';
import '../companion/pack/companion_pack_validator.dart';
import '../companion/pack/installed_pack_profiles.dart';
import '../companion/pack/installed_packs_provider.dart';
import '../companion/runtime/companion_id.dart';
import '../companion/runtime/companion_manifest_data.dart';
import '../theme/app_theme.dart';

/// Screen: import a `.cozy_pet` companion pack.
///
/// ## What this screen is allowed to decide
///
/// Nothing. Every rule about whether a pack may be installed lives in the pack
/// engine, and this screen asks it and then reports the answer. That is
/// deliberate: a rule that exists in two places is a rule that will disagree with
/// itself, and the copy in the UI would be the one with no tests.
///
/// The two things this screen *does* own are the ones only a person can answer:
/// what to call the companion, and what animal it is. The format treats both as
/// optional — the shipped packs carry neither, because their name lives in the
/// app's own profile table — so a user's pack that omits them is completed here
/// rather than by the app guessing.
class CompanionImportPage extends ConsumerStatefulWidget {
  const CompanionImportPage({super.key});

  @override
  ConsumerState<CompanionImportPage> createState() =>
      _CompanionImportPageState();
}

enum _Stage { choose, preview, refused, done }

class _CompanionImportPageState extends ConsumerState<CompanionImportPage> {
  final TextEditingController _name = TextEditingController();

  _Stage _stage = _Stage.choose;
  bool _busy = false;
  CompanionPackPreview? _preview;
  PackValidationResult _refusals = const PackValidationResult([]);
  String? _species;

  /// The companion installed by this screen, so the last step can offer to use it.
  String? _installedId;
  String? _installedName;

  /// A plain-language note about what happened when it was not a clean install.
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  CompanionPackPicker get _picker => ref.read(companionPackPickerProvider);

  InstalledPacksController get _packs =>
      ref.read(installedPacksProvider.notifier);

  /// The built-in ids, which a pack may not claim.
  Set<String> get _builtInIds =>
      CompanionManifestData.profiles.keys.map((id) => id.value).toSet();

  /// The pack root, or null when the app has not resolved one.
  Directory? get _installRoot {
    final root = ref.read(companionPackRootProvider);
    return root == null ? null : Directory(root);
  }

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _notice = null;
    });

    try {
      final picked = await _picker.pick();
      if (picked == null) {
        // The user closed the picker. Not an error, and not worth a message.
        if (mounted) setState(() => _busy = false);
        return;
      }

      final preview = CompanionPackImporter.inspect(picked.bytes);
      if (!mounted) return;

      setState(() {
        _busy = false;
        _preview = preview;
        _refusals = preview.validation;
        if (preview.ok) {
          _stage = _Stage.preview;
          _name.text = preview.suggestedName;
          _species = preview.declaredSpecies != null &&
                  CompanionPackInstallRules.species
                      .contains(preview.declaredSpecies)
              ? preview.declaredSpecies
              : null;
        } else {
          _stage = _Stage.refused;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = _Stage.refused;
        _refusals = PackValidationResult([
          PackViolation('pick_failed', '$error'),
        ]);
      });
    }
  }

  Future<void> _install() async {
    final preview = _preview;
    final species = _species;
    final root = _installRoot;
    if (preview == null || species == null) return;

    if (root == null) {
      setState(() {
        _stage = _Stage.refused;
        _refusals = const PackValidationResult([
          PackViolation(
              'pack_root_unavailable',
              'the app has not resolved where packs are kept, so nothing can be '
                  'installed yet'),
        ]);
      });
      return;
    }

    setState(() {
      _busy = true;
      _notice = null;
    });

    final report = await CompanionPackImporter.install(
      preview: preview,
      displayName: _name.text,
      speciesId: species,
      installRoot: root,
      packs: _packs,
      builtInIds: _builtInIds,
    );

    if (!mounted) return;

    setState(() {
      _busy = false;
      switch (report.status) {
        case CompanionPackImportStatus.installed:
          _stage = _Stage.done;
          _installedId = report.pack!.packId;
          _installedName = report.pack!.displayName;
        case CompanionPackImportStatus.alreadyInstalled:
          _stage = _Stage.done;
          _installedId = preview.packId;
          _installedName = report.pack?.displayName ?? preview.suggestedName;
          _notice = '这个伙伴已经在你的收藏里了，不用再装一次。';
        case CompanionPackImportStatus.conflict:
          _stage = _Stage.refused;
          _refusals = const PackValidationResult([
            PackViolation('pack_already_installed',
                'this id is already taken by a different pack'),
          ]);
        case CompanionPackImportStatus.refused:
          _stage = _Stage.refused;
          _refusals = report.validation;
      }
    });
  }

  Future<void> _useIt() async {
    final id = _installedId;
    if (id == null) return;
    await ref.read(companionSelectionProvider.notifier).select(CompanionId(id));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWarm,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundWarm,
        elevation: 0,
        title: const Text(
          '导入宠物包',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        top: false,
        child: switch (_stage) {
          _Stage.choose => _ChooseView(busy: _busy, onPick: _pick),
          _Stage.preview => _PreviewView(
              preview: _preview!,
              nameController: _name,
              species: _species,
              busy: _busy,
              onSpecies: (s) => setState(() => _species = s),
              onNameChanged: () => setState(() {}),
              onInstall: _install,
              onRepick: _pick,
            ),
          _Stage.refused => _RefusedView(
              refusals: _refusals,
              onRetry: _pick,
            ),
          _Stage.done => _DoneView(
              name: _installedName ?? '',
              notice: _notice,
              onUse: _installedId == null ? null : _useIt,
              onDone: () => context.pop(),
            ),
        },
      ),
    );
  }
}

// ─────────────────────────────── stage views ────────────────────────────────

class _ChooseView extends StatelessWidget {
  final bool busy;
  final VoidCallback onPick;

  const _ChooseView({required this.busy, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '把你的伙伴带进来 🧺',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '选一个 .cozy_pet 宠物包文件，确认之后它会出现在伙伴列表里，'
                  '和内置的伙伴一样陪你专注。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 14),
                _Bullet(text: '只读取包里的伙伴数据，不会碰你的专注记录'),
                _Bullet(text: '安装前会先检查包是否完整、是否安全'),
                _Bullet(text: '不喜欢随时可以在伙伴列表里删除'),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: busy ? null : onPick,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primarySage,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textLight,
                      ),
                    )
                  : const Icon(Icons.folder_open_rounded),
              label: Text(
                busy ? '正在读取…' : '选择宠物包文件',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: AppColors.primarySage),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewView extends StatelessWidget {
  final CompanionPackPreview preview;
  final TextEditingController nameController;
  final String? species;
  final bool busy;
  final ValueChanged<String> onSpecies;
  final VoidCallback onNameChanged;
  final VoidCallback onInstall;
  final VoidCallback onRepick;

  const _PreviewView({
    required this.preview,
    required this.nameController,
    required this.species,
    required this.busy,
    required this.onSpecies,
    required this.onNameChanged,
    required this.onInstall,
    required this.onRepick,
  });

  @override
  Widget build(BuildContext context) {
    final nameOk = nameController.text.trim().isNotEmpty;
    final canInstall = nameOk && species != null && !busy;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              if (preview.idleFrame != null)
                SizedBox(
                  width: 132,
                  height: 132,
                  child: Image.memory(
                    preview.idleFrame!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                )
              else
                const Icon(Icons.pets, size: 64, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(
                preview.packId ?? '',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _Fact(label: '动作', value: '${preview.actionIds.length}'),
                  _Fact(label: '帧', value: '${preview.frameCount}'),
                  if (preview.canvasWidth != null)
                    _Fact(
                        label: '画布',
                        value:
                            '${preview.canvasWidth}×${preview.canvasHeight}'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('给它起个名字'),
        const SizedBox(height: 8),
        TextField(
          controller: nameController,
          onChanged: (_) => onNameChanged(),
          maxLength: 24,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.surface,
            hintText: '例如：小豆',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _FieldLabel('它是什么动物'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            for (final s in CompanionPackInstallRules.species)
              _SpeciesChip(
                species: s,
                selected: species == s,
                onTap: () => onSpecies(s),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '动作和走路的节奏会按这个来安排，所以这里要选对。',
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: canInstall ? onInstall : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primarySage,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textLight,
                    ),
                  )
                : const Text(
                    '安装这个伙伴',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: busy ? null : onRepick,
          child: const Text('换一个文件'),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;

  const _Fact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _SpeciesChip extends StatelessWidget {
  final String species;
  final bool selected;
  final VoidCallback onTap;

  const _SpeciesChip({
    required this.species,
    required this.selected,
    required this.onTap,
  });

  static const Map<String, String> _labels = {
    'dog': '狗狗',
    'cat': '猫咪',
    'rabbit': '兔子',
  };

  @override
  Widget build(BuildContext context) {
    final label = _labels[species] ?? species;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primarySage : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _RefusedView extends StatelessWidget {
  final PackValidationResult refusals;
  final VoidCallback onRetry;

  const _RefusedView({required this.refusals, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.accentPeach),
                  SizedBox(width: 8),
                  Text(
                    '这个文件装不了',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '没有写入任何东西。下面是具体原因：',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              for (final violation in refusals.violations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 7),
                        child: Icon(Icons.circle,
                            size: 5, color: AppColors.accentPeach),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          describePackRefusal(violation),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primarySage,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text(
              '换一个文件',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _DoneView extends StatelessWidget {
  final String name;
  final String? notice;
  final VoidCallback? onUse;
  final VoidCallback onDone;

  const _DoneView({
    required this.name,
    required this.notice,
    required this.onUse,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.check_circle_rounded,
              size: 64, color: AppColors.primarySage),
          const SizedBox(height: 16),
          Text(
            notice ?? '$name 已经住进来啦 🌱',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            notice == null ? '它现在出现在伙伴列表里，可以随时切换。' : '你可以直接开始使用它。',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          if (onUse != null)
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: onUse,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primarySage,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  '现在就换成它',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: onDone,
              child: const Text('返回伙伴列表'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── refusal, in plain words ────────────────────────

/// A refusal code, said in the language the rest of the app speaks.
///
/// The codes are stable and the details are English diagnostics, which is right
/// for a log and wrong for a person. An unrecognised code falls through to the
/// code and its detail rather than to a vague apology: a message that says
/// nothing is worse than one the user has to look up, and a code is at least
/// something to search for.
String describePackRefusal(PackViolation violation) {
  switch (violation.code) {
    case 'unreadable_archive':
      return '这个文件打不开，可能不是宠物包，或者文件在传输时损坏了。';
    case 'empty_archive':
      return '这个包是空的，里面什么都没有。';
    case 'no_manifest':
    case 'no_manifest_on_disk':
      return '这个包里没有 manifest.json，看不出它是什么伙伴。';
    case 'unreadable_manifest':
      return '包里的 manifest.json 读不出来，文件可能损坏了。';
    case 'duplicate_manifest':
      return '这个包里有不止一个 manifest.json，分不清哪个才算数。';
    case 'unsafe_entry_path':
    case 'unsafe_frame_path':
      return '这个包里有文件想写到包外面去，为了安全不能安装。';
    case 'non_regular_entry':
      return '这个包里有不是普通文件的条目，为了安全不能安装。';
    case 'duplicate_entry':
      return '这个包里有重名的文件，装出来会是哪一个说不准。';
    case 'too_many_entries':
    case 'entry_too_large':
    case 'archive_too_large':
    case 'expansion_ratio_bomb':
      return '这个包大得不像一个伙伴，超出能接受的范围。';
    case 'disallowed_file_type':
      return '这个包里除了 manifest.json 和 PNG 之外还有别的东西，宠物包只放这两类。';
    case 'missing_companion_id':
      return '包里没写这个伙伴叫什么 id。';
    case 'companion_id_mismatch':
      return '包里写的 id 和实际安装的名字对不上。';
    case 'unsafe_pack_id':
      return '这个伙伴的 id 不能用作目录名，装不了。';
    case 'pack_id_reserved':
      return '这个 id 是内置伙伴的名字，自定义的包不能用。';
    case 'pack_already_installed':
      return '已经有一个同名的伙伴了。想换的话，先去伙伴列表把它删掉。';
    case 'missing_canvas':
    case 'canvas_too_small':
      return '包里没有写清楚画布大小，或者画布太小了。';
    case 'missing_anchors':
    case 'baseline_out_of_canvas':
    case 'centre_out_of_canvas':
      return '包里的落脚点、中心点位置不对，伙伴会站不稳。';
    case 'no_actions':
      return '这个包里一个动作都没有。';
    case 'action_without_frames':
    case 'action_too_short':
      return '有动作只有一张图。静止的图不算动画，至少要有两张。';
    case 'missing_frame_file':
      return '动作里提到的图片，包里找不到。';
    case 'frame_not_a_png':
      return '这个包里有张图其实不是图片文件，装进来会显示不出来。';
    case 'duplicate_frame':
      return '同一个动作里重复用了同一张图。';
    case 'invalid_fps':
      return '动作的播放速度不对。';
    case 'unknown_loop_mode':
      return '动作的循环方式看不懂，装进来会不知道该怎么播。';
    case 'no_idle':
    case 'idle_too_short':
      return '这个包缺少 idle（待机）动作，伙伴站着不动时就没东西可放。';
    case 'dangling_semanticFallback':
    case 'dangling_drawAliases':
      return '包里说某个动作可以顶替另一个，但被顶替的那个动作并不存在。';
    case 'unsupported_species':
      return '这个伙伴的动物种类不在支持范围内。';
    case 'empty_display_name':
      return '还没给它起名字。';
    case 'pack_root_unavailable':
      return 'App 还没准备好存放宠物包的目录，稍后再试一次。';
    default:
      return '${violation.code}：${violation.detail}';
  }
}
