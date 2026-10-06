import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/enums.dart';
import '../controllers/rest_controller.dart';

/// What the new phases add to the companion's state, or null for nothing.
///
/// ## The one direction the animation layer is allowed to be driven
///
/// The brief's rule is absolute: the animation layer must never write business
/// data, and business state is expressed through the existing chain rather than by
/// inventing new animations. This provider is the whole of that direction — a
/// function from facts the app already holds to one of the [PetVisualState] values
/// the app already has. Nothing here is stored and nothing here is a new drawing.
///
/// ## Why it returns null rather than a state
///
/// `CompanionAvatar` already has a precedence for the states it can see for
/// itself: an explicit page override, then a live focus session, then a live craft
/// job, then idle. Re-deciding the session and craft cases here would be a second
/// copy of that order, and two copies is how the badge and the behaviour end up
/// disagreeing. This returns null for everything except a rest, which is the one
/// fact the avatar cannot see — it lives in a controller the avatar does not
/// watch.
final companionBusinessStateOverrideProvider = Provider<PetVisualState?>((ref) {
  final rest = ref.watch(restControllerProvider);
  // A rest is a rest even if a focus session is somehow still open: the user is on
  // the rest screen, and that is what the pet should be doing.
  return rest.isResting ? PetVisualState.sleep : null;
});
