import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:creania/services/email_validation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EmailValidationService validator;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    validator = EmailValidationService();
    await validator.init();
  });

  group('Email Format Validation Tests', () {
    test('Valid email formats should pass', () {
      expect(validator.isValidFormat('user@gmail.com'), isTrue);
      expect(validator.isValidFormat('student.one@creania.edu.in'), isTrue);
      expect(validator.isValidFormat('my-name_123@domain.org'), isTrue);
    });

    test('Invalid email formats should fail', () {
      expect(validator.isValidFormat('abc'), isFalse);
      expect(validator.isValidFormat('test@'), isFalse);
      expect(validator.isValidFormat('@gmail.com'), isFalse);
      expect(validator.isValidFormat('abc@gmail'), isFalse);
    });
  });

  group('Disposable Email Blocklist Tests', () {
    test('Common temp email domains should be detected as disposable', () async {
      expect(await validator.isDisposable('test@tempmail.com'), isTrue);
      expect(await validator.isDisposable('hello@10minutemail.com'), isTrue);
      expect(await validator.isDisposable('fake@yopmail.com'), isTrue);
    });

    test('Real email domains should NOT be detected as disposable', () async {
      expect(await validator.isDisposable('anurag@gmail.com'), isFalse);
      expect(await validator.isDisposable('student@yahoo.co.in'), isFalse);
      expect(await validator.isDisposable('developer@creania.com'), isFalse);
    });
  });

  group('Role-Based Email Check Tests', () {
    test('Role emails should be classified as business/roles', () {
      expect(validator.isRoleBased('admin@creania.com'), isTrue);
      expect(validator.isRoleBased('support@creania.com'), isTrue);
      expect(validator.isRoleBased('info@creania.com'), isTrue);
    });

    test('Standard student emails should NOT be classified as roles', () {
      expect(validator.isRoleBased('anurag@creania.com'), isFalse);
      expect(validator.isRoleBased('student123@gmail.com'), isFalse);
    });
  });

  group('Rate Limiting & Cooldown Tests', () {
    test('Verify OTP limit of 5 requests per hour', () async {
      final target = 'test@example.com';
      for (int i = 0; i < 5; i++) {
        expect(await validator.checkOtpLimitExceeded(target), isFalse);
      }
      expect(await validator.checkOtpLimitExceeded(target), isTrue);
    });

    test('Verify signup attempt limit of 10 requests per hour', () async {
      for (int i = 0; i < 10; i++) {
        expect(await validator.checkSignupLimitExceeded(), isFalse);
      }
      expect(await validator.checkSignupLimitExceeded(), isTrue);
    });

    test('Failure cooldown activation after 3 consecutive failures', () async {
      expect(await validator.isCoolingDown(), isFalse);
      await validator.logFailure(); // 1
      await validator.logFailure(); // 2
      await validator.logFailure(); // 3
      expect(await validator.isCoolingDown(), isTrue);
    });
  });
}
