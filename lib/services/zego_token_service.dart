import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'zego_config.dart';

/// Generates ZEGO Token04 locally without a server-side Edge Function.
/// Algorithm mirrors the TypeScript edge function in supabase/functions/zego-token/index.ts.
/// This avoids any Supabase Edge Function dependency — works 100% offline.
class ZegoTokenService {
  static final ZegoTokenService _instance = ZegoTokenService._internal();
  factory ZegoTokenService() => _instance;
  ZegoTokenService._internal();

  String? _cachedToken;
  int? _cachedExpireTimestamp; // Unix seconds
  String? _cachedUserId;

  /// Returns a valid ZEGO token for [userId].
  /// Uses in-memory cache; refreshes when < 5 minutes remain.
  Future<String> getToken(String userId, {bool forceRefresh = false}) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // Return cached token if still has 5+ minutes
    if (!forceRefresh &&
        _cachedToken != null &&
        _cachedUserId == userId &&
        _cachedExpireTimestamp != null &&
        (_cachedExpireTimestamp! - nowSeconds) > 300) {
      debugPrint('⚡ Returning cached ZEGO token '
          '(expires in ${_cachedExpireTimestamp! - nowSeconds}s)');
      return _cachedToken!;
    }

    debugPrint('🔑 Generating ZEGO token locally for userId: $userId');

    const effectiveTime = 7200; // 2 hours
    final expire = nowSeconds + effectiveTime;

    final token = _generateToken04(
      appId: ZegoConfig.appId,
      userId: userId,
      serverSecret: ZegoConfig.serverSecret,
      effectiveTimeInSeconds: effectiveTime,
    );

    _cachedToken = token;
    _cachedExpireTimestamp = expire;
    _cachedUserId = userId;

    debugPrint('✅ ZEGO token generated locally (expires at $expire)');
    return token;
  }

  void clearCache() {
    _cachedToken = null;
    _cachedExpireTimestamp = null;
    _cachedUserId = null;
  }

  // ── Token04 generation (mirrors the TypeScript edge function) ──────────────

  String _generateToken04({
    required int appId,
    required String userId,
    required String serverSecret,
    required int effectiveTimeInSeconds,
    String payload = '',
  }) {
    assert(serverSecret.length == 32, 'serverSecret must be 32 bytes');
    assert(userId.isNotEmpty && userId.length <= 64, 'userId invalid');
    assert(effectiveTimeInSeconds > 0, 'effectiveTimeInSeconds must be > 0');

    final createTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expire = createTime + effectiveTimeInSeconds;

    // Random signed 32-bit nonce
    final rng = Random.secure();
    final nonce = rng.nextInt(0xFFFFFFFF) - 0x7FFFFFFF; // signed range

    final tokenInfo = {
      'app_id': appId,
      'user_id': userId,
      'nonce': nonce,
      'ctime': createTime,
      'expire': expire,
      'payload': payload,
    };

    final plainText = jsonEncode(tokenInfo);

    // AES-256-GCM encryption
    final keyBytes = Uint8List.fromList(utf8.encode(serverSecret));
    final key = enc.Key(keyBytes);

    // Random 12-byte IV
    final ivBytes = Uint8List(12);
    for (int i = 0; i < 12; i++) {
      ivBytes[i] = rng.nextInt(256);
    }
    final iv = enc.IV(ivBytes);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // encrypted.bytes contains ciphertext + 16-byte GCM auth tag
    final cipherWithTag = encrypted.bytes;

    // Build buffer: Expire(8) + IVLen(2) + IV(12) + CipherLen(2) + Cipher+Tag + Mode(1)
    final expireBytes = _int64BigEndian(expire);
    final ivLenBytes = _uint16BigEndian(ivBytes.length);
    final cipherLenBytes = _uint16BigEndian(cipherWithTag.length);
    const encryptMode = 1; // AesEncryptMode.GCM

    final buf = Uint8List.fromList([
      ...expireBytes,
      ...ivLenBytes,
      ...ivBytes,
      ...cipherLenBytes,
      ...cipherWithTag,
      encryptMode,
    ]);

    return '04${base64.encode(buf)}';
  }

  /// Encode [value] as big-endian Int64 (8 bytes).
  List<int> _int64BigEndian(int value) {
    final bd = ByteData(8);
    // Dart integers are 64-bit; split into high and low 32-bit halves
    bd.setUint32(0, (value >> 32) & 0xFFFFFFFF, Endian.big);
    bd.setUint32(4, value & 0xFFFFFFFF, Endian.big);
    return bd.buffer.asUint8List();
  }

  /// Encode [value] as big-endian Uint16 (2 bytes).
  List<int> _uint16BigEndian(int value) {
    final bd = ByteData(2);
    bd.setUint16(0, value, Endian.big);
    return bd.buffer.asUint8List();
  }
}
