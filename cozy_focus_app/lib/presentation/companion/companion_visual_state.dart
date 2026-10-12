import '../../domain/models/enums.dart';
import 'runtime/companion_context.dart';
import 'runtime/companion_presentation_intent.dart';

/// The legacy renderer state for an intent.
///
/// ## Why this is one function and not two
///
/// The mapping from a companion's situation to the renderer's `PetVisualState`
/// existed twice - once in `CompanionAvatar`, which pushes it into the motion
/// controller, and once in `MochiVisualProvider`, which passes it to the widget.
/// They were kept in step by hand, and the completion fix went into one of them:
/// the rig reads the *controller's* state, so it never saw the change and stood
/// still in a one-shot state while the other copy said the companion had settled.
///
/// Two copies of one mapping is how that happens, so there is now one.
///
/// ## The completion is the one case that is not just the base context
///
/// `celebrate` is a **one-shot** rig state: a rig mounted in it never becomes
/// ambient - it logs `ambient=false timers=0 breathe=false` and stands perfectly
/// still. The completion context lasts as long as the page is open, so mapping it
/// to `celebrate` unconditionally meant the rig was frozen from the moment the
/// celebration handed over. The director already knows when the moment is over -
/// it moves the macro on - so the state follows it: `celebrate` while the
/// celebration is running, the ordinary idle once it has handed over.
PetVisualState companionVisualStateFor(CompanionPresentationIntent intent) {
  if (intent.baseContext == CompanionBaseContext.complete &&
      intent.macroBehavior != CompanionMacroBehavior.celebrate) {
    return PetVisualState.idle;
  }
  return _baseStateFor(intent.baseContext);
}

PetVisualState _baseStateFor(CompanionBaseContext context) {
  switch (context) {
    case CompanionBaseContext.home:
    case CompanionBaseContext.room:
      return PetVisualState.idle;
    case CompanionBaseContext.focus:
      return PetVisualState.focus;
    case CompanionBaseContext.pause:
      return PetVisualState.pause;
    case CompanionBaseContext.complete:
      return PetVisualState.celebrate;
    case CompanionBaseContext.craft:
      return PetVisualState.craft;
    case CompanionBaseContext.sleep:
      return PetVisualState.sleep;
  }
}
