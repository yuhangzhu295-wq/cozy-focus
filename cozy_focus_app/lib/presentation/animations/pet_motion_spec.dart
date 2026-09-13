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
}
