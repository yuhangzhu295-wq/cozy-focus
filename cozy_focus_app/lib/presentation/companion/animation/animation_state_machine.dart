import 'animation_state.dart';

/// Which posture an animation leaves the character in.
///
/// Posture is the animation layer's own bookkeeping — it is not business state
/// and not a pose. It exists so the machine can answer "do I need to sit down
/// before I can write?" without asking the behaviour layer, which has no
/// vocabulary for the question.
enum AnimationPosture {
  /// On all fours / standing. Reading, writing and crafting are not available.
  standing('standing'),

  /// At a desk or on a seat. The work states live here.
  seated('seated'),

  /// Lying down. Only sleep lives here.
  lying('lying');

  final String id;

  const AnimationPosture(this.id);

  static AnimationPosture? fromId(String? id) {
    if (id == null) return null;
    for (final posture in AnimationPosture.values) {
      if (posture.id == id) return posture;
    }
    return null;
  }
}

/// One posture-to-posture hop: what plays to get from [from] to [to].
class AnimationTransition {
  final AnimationPosture from;
  final AnimationPosture to;

  /// The state that plays for the hop. Always a transitional state: a hop is
  /// never a destination.
  final AnimationState state;

  const AnimationTransition({
    required this.from,
    required this.to,
    required this.state,
  });

  factory AnimationTransition.fromJson(Map<String, dynamic> json) {
    final from = AnimationPosture.fromId(json['from'] as String?);
    final to = AnimationPosture.fromId(json['to'] as String?);
    final state = AnimationState.fromId(json['state'] as String?);
    if (from == null || to == null || state == null) {
      throw FormatException(
        'animation transition: unknown id in $json',
      );
    }
    return AnimationTransition(from: from, to: to, state: state);
  }

  @override
  String toString() => 'AnimationTransition(${from.id} → ${to.id} '
      'via ${state.assetActionId})';
}

/// The animation state machine: postures, hops, durations and pose projections.
///
/// ## Why this is data and not code
///
/// Stage 1 shipped these as constants in the controller. That made adding a
/// transition a code edit, which is the thing the whole V4.2.1 runtime was built
/// to avoid: the behaviour recipes are data, the pose manifests are data, and a
/// fourth companion arrives as rows. The animation layer is no different —
/// `animation_states.json` is the authoring source and this class is its runtime
/// mirror.
///
/// ## It decides nothing about business
///
/// Its vocabulary is postures, states and milliseconds. There is no companion
/// id, no level, no session and no repository here, so a change to this data
/// cannot change what the user has earned.
class AnimationStateMachine {
  /// Which posture each animation state leaves the character in.
  final Map<AnimationState, AnimationPosture> postureOf;

  /// How long each transitional state holds, keyed by state.
  final Map<AnimationState, Duration> transitionDurations;

  /// The hop table, keyed for lookup.
  final List<AnimationTransition> transitions;

  /// pose id -> the sustained animation state a behaviour projects onto.
  final Map<String, AnimationState> poseProjections;

  const AnimationStateMachine({
    required this.postureOf,
    required this.transitionDurations,
    required this.transitions,
    required this.poseProjections,
  });

  /// The posture [state] leaves the character in.
  ///
  /// Falls back to `standing`, which is the character's rest posture: an
  /// unlisted state is one the author has not placed, and standing is the only
  /// safe guess because every other posture has a hop back out of it.
  AnimationPosture postureFor(AnimationState state) =>
      postureOf[state] ?? AnimationPosture.standing;

  /// The state that plays to get from [from] to [to], or `null` when they are
  /// the same posture.
  AnimationState? transitionBetween({
    required AnimationPosture from,
    required AnimationPosture to,
  }) {
    if (from == to) return null;
    for (final transition in transitions) {
      if (transition.from == from && transition.to == to) {
        return transition.state;
      }
    }
    return null;
  }

  /// How long [state] holds. Zero for a sustained state, which never hands over.
  Duration durationOf(AnimationState state) =>
      transitionDurations[state] ?? Duration.zero;

  /// The sustained animation a pose asks for.
  AnimationState? projectionFor(String poseId) => poseProjections[poseId];

  factory AnimationStateMachine.fromJson(Map<String, dynamic> json) {
    final postureRaw = (json['postureOf'] as Map?) ?? const {};
    final postureOf = <AnimationState, AnimationPosture>{};
    for (final entry in postureRaw.entries) {
      final state = AnimationState.fromId(entry.key as String?);
      final posture = AnimationPosture.fromId(entry.value as String?);
      if (state == null || posture == null) {
        throw FormatException('animation states: unknown id in postureOf '
            '(${entry.key} -> ${entry.value})');
      }
      postureOf[state] = posture;
    }

    final durationRaw = (json['transitionDurationsMs'] as Map?) ?? const {};
    final durations = <AnimationState, Duration>{};
    for (final entry in durationRaw.entries) {
      final state = AnimationState.fromId(entry.key as String?);
      final ms = (entry.value as num?)?.toInt();
      if (state == null || ms == null) {
        throw FormatException('animation states: bad duration for '
            '${entry.key}');
      }
      durations[state] = Duration(milliseconds: ms);
    }

    final hopRaw = (json['entryTransitions'] as List?) ?? const [];
    final transitions = [
      for (final entry in hopRaw)
        AnimationTransition.fromJson((entry as Map).cast<String, dynamic>()),
    ];

    final projectionRaw = (json['poseProjections'] as Map?) ?? const {};
    final projections = <String, AnimationState>{};
    for (final entry in projectionRaw.entries) {
      final state = AnimationState.fromId(entry.value as String?);
      if (state == null) {
        throw FormatException('animation states: unknown projection target '
            '${entry.value} for pose ${entry.key}');
      }
      projections[entry.key as String] = state;
    }

    return AnimationStateMachine(
      postureOf: Map.unmodifiable(postureOf),
      transitionDurations: Map.unmodifiable(durations),
      transitions: List.unmodifiable(transitions),
      poseProjections: Map.unmodifiable(projections),
    );
  }
}
