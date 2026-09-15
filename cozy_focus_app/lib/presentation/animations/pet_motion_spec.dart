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
}
