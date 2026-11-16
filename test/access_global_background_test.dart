import 'package:access_mobile/mobile_app/widgets/access_global_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AccessGlobalBackground paints the registered asset behind child',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AccessGlobalBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: Text('Foreground')),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Foreground'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, same(AccessGlobalBackground.imageProvider));
    expect(image.fit, BoxFit.cover);
  });

  test('asset path matches pubspec registration', () {
    expect(
      AccessGlobalBackground.assetPath,
      'assets/images/access_global_background.png',
    );
  });
}
