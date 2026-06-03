import 'package:flutter_test/flutter_test.dart';
import 'package:phantomvox_app/main.dart';

void main() {
  testWidgets('App renders without error', (tester) async {
    await tester.pumpWidget(const PhantomVoxApp());
    expect(find.text('PhantomVox AI'), findsOneWidget);
  });
}
