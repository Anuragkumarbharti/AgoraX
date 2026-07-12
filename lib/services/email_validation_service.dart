import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EmailValidationService {
  static final EmailValidationService _instance = EmailValidationService._internal();
  factory EmailValidationService() => _instance;
  EmailValidationService._internal();

  // Quick offline list of common disposable email domains
  final Set<String> _localTempDomains = {
    'tempmail.com', '10minutemail.com', 'guerrillamail.com', 'yopmail.com',
    'mailinator.com', 'temp-mail.org', 'fakeinbox.com', 'throwawaymail.com',
    'dispostable.com', 'getairmail.com', 'maildrop.cc', 'tempmailaddress.com'
  };

  Set<String> _cachedTempDomains = {};
  bool _isInitialized = false;

  /// Initialize and load blocklist from cache, and trigger background fetch
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_disposable_domains');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        _cachedTempDomains = Set<String>.from(json.decode(cachedStr));
      }
    } catch (_) {}
    _isInitialized = true;
    
    // Fetch fresh domains list from GitHub in the background
    _fetchBlocklistBackground();
  }

  /// Format validation (Regex check)
  bool isValidFormat(String email) {
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
    );
    return emailRegex.hasMatch(email);
  }

  /// Disposable/Temporary Email Check
  Future<bool> isDisposable(String email) async {
    await init();
    final parts = email.split('@');
    if (parts.length < 2) return true;
    final domain = parts[1].trim().toLowerCase();

    // Check local list first
    if (_localTempDomains.contains(domain) || _cachedTempDomains.contains(domain)) {
      return true;
    }
    
    // Check subdomains too
    for (final blockDomain in _localTempDomains) {
      if (domain.endsWith('.' + blockDomain)) return true;
    }
    for (final blockDomain in _cachedTempDomains) {
      if (domain.endsWith('.' + blockDomain)) return true;
    }

    return false;
  }

  /// Deliverability check: Domain check & MX records check via Google DNS HTTPS API
  Future<bool> isDeliverable(String email) async {
    final parts = email.split('@');
    if (parts.length < 2) return false;
    final domain = parts[1].trim().toLowerCase();

    try {
      // 1. Basic A/AAAA Lookup to ensure domain resolves
      final result = await InternetAddress.lookup(domain).timeout(const Duration(seconds: 4));
      if (result.isEmpty || result[0].rawAddress.isEmpty) {
        return false;
      }
    } catch (e) {
      debugPrint('Domain resolve failed: $e');
      return false; // Domain does not exist
    }

    // 2. Query MX records via Google DNS HTTPS API
    try {
      final url = Uri.parse('https://dns.google/resolve?name=$domain&type=MX');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic>? answer = data['Answer'];
        if (answer != null && answer.isNotEmpty) {
          return true;
        }
      }
    } catch (e) {
      debugPrint('MX lookup query failed: $e');
    }

    return true; 
  }

  /// Role-based email verification
  bool isRoleBased(String email) {
    final parts = email.split('@');
    if (parts.isEmpty) return false;
    final username = parts[0].trim().toLowerCase();
    
    final roles = {'admin', 'support', 'info', 'contact', 'sales', 'jobs', 'marketing', 'billing', 'help'};
    return roles.contains(username);
  }

  /// Abuse prevention: Limit OTP requests per hour (Max 5)
  Future<bool> checkOtpLimitExceeded(String emailOrPhone) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final keyCount = 'otp_count_$emailOrPhone';
    final keyTime = 'otp_time_$emailOrPhone';

    final count = prefs.getInt(keyCount) ?? 0;
    final firstRequestTime = prefs.getInt(keyTime) ?? 0;

    if (firstRequestTime == 0 || now - firstRequestTime > 3600000) {
      await prefs.setInt(keyCount, 1);
      await prefs.setInt(keyTime, now);
      return false;
    }

    if (count >= 5) {
      return true; // Limit exceeded
    }

    await prefs.setInt(keyCount, count + 1);
    return false;
  }

  /// Abuse prevention: Limit signup attempts per hour per device (Max 10)
  Future<bool> checkSignupLimitExceeded() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    const keyCount = 'signup_attempts_count';
    const keyTime = 'signup_attempts_time';

    final count = prefs.getInt(keyCount) ?? 0;
    final firstRequestTime = prefs.getInt(keyTime) ?? 0;

    if (firstRequestTime == 0 || now - firstRequestTime > 3600000) {
      await prefs.setInt(keyCount, 1);
      await prefs.setInt(keyTime, now);
      return false;
    }

    if (count >= 10) {
      return true;
    }

    await prefs.setInt(keyCount, count + 1);
    return false;
  }

  /// Cooldown after repeated validation failures
  Future<void> logFailure() async {
    final prefs = await SharedPreferences.getInstance();
    final failures = (prefs.getInt('validation_failures_count') ?? 0) + 1;
    await prefs.setInt('validation_failures_count', failures);
    await prefs.setInt('last_validation_failure_time', DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> isCoolingDown() async {
    final prefs = await SharedPreferences.getInstance();
    final failures = prefs.getInt('validation_failures_count') ?? 0;
    if (failures < 3) return false;

    final lastTime = prefs.getInt('last_validation_failure_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cooldownPeriod = 300000; // 5 mins

    if (now - lastTime < cooldownPeriod) {
      return true;
    } else {
      await prefs.setInt('validation_failures_count', 0);
      return false;
    }
  }

  /// Fetch updated list from disposable-email-domains GitHub repo
  void _fetchBlocklistBackground() async {
    try {
      final url = Uri.parse('https://raw.githubusercontent.com/disposable-email-domains/disposable-email-domains/master/disposable_email_blocklist.conf');
      final res = await http.get(url).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final List<String> domains = LineSplitter.split(res.body)
            .map((line) => line.trim().toLowerCase())
            .where((line) => line.isNotEmpty && !line.startsWith('#'))
            .toList();

        if (domains.isNotEmpty) {
          _cachedTempDomains = Set<String>.from(domains);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_disposable_domains', json.encode(domains));
        }
      }
    } catch (_) {}
  }
}
