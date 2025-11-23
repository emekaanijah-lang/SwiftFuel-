import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swift_fuel/main.dart';
import 'package:swift_fuel/firebase_options.dart';

// Helper to initialize firebase
Future<void> setupFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Already initialized
  }
}

void main() {
  // We need to initialize the binding and Firebase before the tests run.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await setupFirebase();
  });

  testWidgets('Welcome screen test', (WidgetTester tester) async {
    // Sign out any existing user to ensure a clean state for the test.
    await FirebaseAuth.instance.signOut();

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the welcome screen is displayed.
    expect(find.text('Welcome to SwiftFuel+'), findsOneWidget);
    expect(
        find.text(
            'The future of hassle-free fuel delivery is here. Sign up to get started!'),
        findsOneWidget);

    // Verify that the 'Get Started' button is present.
    expect(find.widgetWithText(ElevatedButton, 'Get Started'), findsOneWidget);
  });
}
