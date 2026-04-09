import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uemsi_htv_hd_express_app/src/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Landing shows live video and gallery actions', (tester) async {
    await tester.pumpWidget(const UemsiHtvApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('View Live Video'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
  });
}
