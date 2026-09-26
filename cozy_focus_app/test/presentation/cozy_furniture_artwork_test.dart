import 'package:cozy_focus_app/presentation/widgets/cozy_furniture_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders native artwork for every supported furniture item',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Wrap(
          children: [
            for (final itemId in CozyFurnitureArtwork.supportedItemIds)
              CozyFurnitureArtwork(itemId: itemId),
          ],
        ),
      ),
    );

    for (final itemId in CozyFurnitureArtwork.supportedItemIds) {
      expect(find.byKey(Key('cozy-furniture-$itemId')), findsOneWidget);
    }
    expect(find.textContaining('🛋'), findsNothing);
    expect(find.textContaining('📦'), findsNothing);
  });

  testWidgets('renders collection-only artwork without generic icon text',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Row(
        children: [
          CozyFurnitureArtwork(itemId: 'plant_succulent'),
          CozyFurnitureArtwork(itemId: 'special_trophy'),
        ],
      ),
    ));

    expect(find.byKey(const Key('cozy-furniture-plant_succulent')),
        findsOneWidget);
    expect(
        find.byKey(const Key('cozy-furniture-special_trophy')), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('uses a safe native fallback for an unknown furniture item',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: CozyFurnitureArtwork(itemId: 'unknown-furniture'),
    ));

    expect(find.byKey(const Key('cozy-furniture-unknown-furniture')),
        findsOneWidget);
    expect(find.textContaining('📦'), findsNothing);
  });
}
