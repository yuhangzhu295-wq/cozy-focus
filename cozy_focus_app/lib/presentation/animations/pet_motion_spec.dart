class PetMotionSpec {
  const PetMotionSpec._();

  // Idle Breathe
  static const Duration breatheCycle = Duration(milliseconds: 3200);
  static const double breatheScaleMin = 1.0;
  static const double breatheScaleMax = 1.018;
  static const double breatheDyMax = -2.0;
  static const double breatheReducedDyMax = -1.0;

  // Idle Sway
  static const Duration swayCycle = Duration(milliseconds: 3000);
  static const double swayAngleDegrees = 2.0;

  // Blink
  static const Duration blinkDuration = Duration(milliseconds: 140);
  static const Duration minBlinkInterval = Duration(milliseconds: 2500);
  static const Duration maxBlinkInterval = Duration(milliseconds: 5500);

  // Ear Twitch
  static const Duration earTwitchDuration = Duration(milliseconds: 220);
  static const Duration minEarTwitchInterval = Duration(milliseconds: 4500);
  static const Duration maxEarTwitchInterval = Duration(milliseconds: 7500);
  static const double earTwitchAngleDegrees = 3.0;

  // Tail Wag / Tail Idle
  static const Duration tailCycle = Duration(milliseconds: 2400);
  static const double tailIdleAngleDegrees = 5.0;

  // --- Phase 6B: Focus Work ---
  static const Duration focusWorkCycle = Duration(milliseconds: 4500);
  static const double focusBreatheDyMax = -1.5;
  static const double focusScaleMax = 1.012;
  static const double focusWorkMicroAngleDegrees = 0.8;

  // --- Phase 6B: Pause ---
  static const Duration pauseTransitionDuration = Duration(milliseconds: 350);
  static const Duration pauseBreatheCycle = Duration(milliseconds: 4000);
  static const double pauseBreatheDyMax = -0.8;

  // --- Phase 6B: Sleep ---
  static const Duration sleepBreatheCycle = Duration(milliseconds: 3500);
  static const double sleepBreatheDyMax = -2.5;
  static const double sleepZzzDyMax = -4.0;

  // --- Phase 6C: Celebrate ---
  static const Duration celebrateCycle = Duration(milliseconds: 1200);
  static const double celebrateBounceDyMax = -6.0;
  static const double celebrateScaleMax = 1.04;
  static const double celebrateAngleDegrees = 3.0;

  // --- Phase 6C: Craft ---
  static const Duration craftCycle = Duration(milliseconds: 1800);
  static const double craftBreatheDyMax = -1.2;
  static const double craftScaleMax = 1.015;
  static const double craftTiltAngleDegrees = 1.8;

  // --- Phase 6C: Greeting ---
  static const Duration greetingCycle = Duration(milliseconds: 1500);
  static const double greetingBounceDyMax = -3.0;
  static const double greetingScaleMax = 1.02;
  static const double greetingTiltAngleDegrees = 2.5;

  // --- Phase 6D: Interact ---
  static const Duration interactDuration = Duration(milliseconds: 750);
  static const double interactBounceDyMax = -8.0;
  static const double interactScaleMax = 1.06;
  static const double interactTiltDeg = 4.0;
  static const double interactEarTiltDeg = 6.0;
  static const double interactTailTiltDeg = 5.0;
  static const double interactEyeSquintMin = 0.55;
  static const Duration interactCooldown = Duration(milliseconds: 1500);

  // --- Ambient micro-motion layer ---
  //
  // V4.1 `reference/02_动效架构.md` declares the *Micro* channels
  // (Breathe / Sway / Blink / Ear Twitch / Tail Wag) as the layer beneath every
  // base state (Idle / Focus / Craft / Pause / Celebrate / Sleep / Greeting /
  // Interact). Base states therefore do not own the micro channels; they only
  // scale how strongly the micro layer reads.
  //
  // A live companion that freezes its ears, tail and eyes for the whole length
  // of a 25-minute focus session or a multi-minute craft job is not alive, so
  // the part-level micro channels stay engaged in every ambient base state and
  // are damped (never disabled) per state.
  static const double idlePartMotionFactor = 1.0;
  static const double focusPartMotionFactor = 0.6;
  static const double pausePartMotionFactor = 0.5;
  static const double craftPartMotionFactor = 0.75;

  // --- Progress binding ---
  //
  // V4.1 binds `focusProgress` / `craftProgress` into the engine. They are
  // expressed as *motion intensity*: the delta of every transform away from the
  // neutral pose is scaled by this factor, so the pet starts a session calm and
  // grows more animated as it approaches completion. The neutral pose itself is
  // never moved, which keeps the binding free of visual drift.
  static const double progressIntensityMin = 0.55;
  static const double progressIntensityMax = 1.0;

  // --- Delayed head response ---
  //
  // The head counter-rotates against the body sway and carries its own, longer
  // oscillation, so it drifts in and out of phase with the body instead of
  // moving rigidly with it. This is the "head slight delayed response" channel.
  static const Duration headLagCycle = Duration(milliseconds: 3400);
  static const double headLagAngleDegrees = 0.9;
  static const double headLagFactor = 0.55;
}
