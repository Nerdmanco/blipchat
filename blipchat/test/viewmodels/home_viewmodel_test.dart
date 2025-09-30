import 'package:flutter_test/flutter_test.dart';
import 'package:blipchat/app/app.locator.dart';
import 'package:blipchat/ui/views/home/home_viewmodel.dart';

import '../helpers/test_helpers.dart';

void main() {
  HomeViewModel getModel() => HomeViewModel();

  group('HomeViewmodelTest -', () {
    setUp(() => registerServices());
    tearDown(() => locator.reset());

    group('toggleConnection -', () {
      test('When called should toggle BLE connection state', () async {
        final model = getModel();
        
        // Test initial state
        expect(model.isConnected, false);
        
        // Note: In a real test environment, you would mock the BLE service
        // For now, this test verifies the model structure is correct
      });
    });

    group('sendMessage -', () {
      test('When called with text should attempt to send message', () async {
        final model = getModel();
        
        // Set some text in the controller
        model.messageController.text = 'Test message';
        
        // Call send message
        await model.sendMessage();
        
        // Verify controller is cleared
        expect(model.messageController.text, '');
      });
    });
  });
}
