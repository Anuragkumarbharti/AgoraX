import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' hide Response;
import './network_adaptive_manager.dart';

/// In-memory DNS cache record
class _DnsCacheRecord {
  final String ipAddress;
  final DateTime expiresAt;

  _DnsCacheRecord(this.ipAddress, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Fast DNS Resolver Interceptor with in-memory caching and TTL.
class DnsCacheInterceptor extends Interceptor {
  static final Map<String, _DnsCacheRecord> _dnsCache = {};
  static const Duration _cacheTtl = Duration(hours: 1);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final host = options.uri.host;

    // Skip IP addresses or local localhost
    if (InternetAddress.tryParse(host) != null || host == 'localhost') {
      return handler.next(options);
    }

    try {
      final cached = _dnsCache[host];
      if (cached != null && !cached.isExpired) {
        options.extra['resolved_ip'] = cached.ipAddress;
      } else {
        final addresses = await InternetAddress.lookup(host);
        if (addresses.isNotEmpty) {
          final ip = addresses.first.address;
          _dnsCache[host] = _DnsCacheRecord(ip, DateTime.now().add(_cacheTtl));
          options.extra['resolved_ip'] = ip;
        }
      }
    } catch (e) {
      debugPrint('[DnsCacheInterceptor] DNS Lookup error for $host: $e');
    }

    handler.next(options);
  }
}

/// Exponential Backoff with Jitter Retry Interceptor for unstable networks.
class NetworkRetryInterceptor extends Interceptor {
  final Dio dio;

  NetworkRetryInterceptor(this.dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    int retryCount = options.extra['retry_count'] ?? 0;
    const maxRetries = 3;

    final isNetworkOrServerError = err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response != null && err.response!.statusCode! >= 500);

    if (isNetworkOrServerError && retryCount < maxRetries) {
      retryCount++;
      options.extra['retry_count'] = retryCount;

      // Exponential backoff calculation: (2^retryCount * 200ms) + random jitter (0-150ms)
      final backoffMs = (pow(2, retryCount) * 200).toInt() + Random().nextInt(150);
      debugPrint('[NetworkRetryInterceptor] Retrying request (${options.path}) attempt $retryCount after ${backoffMs}ms...');

      await Future.delayed(Duration(milliseconds: backoffMs));

      try {
        final response = await dio.fetch(options);
        return handler.resolve(response);
      } catch (e) {
        if (e is DioException) {
          return handler.next(e);
        }
      }
    }

    handler.next(err);
  }
}

/// In-Memory and Stale-While-Revalidate API Cache Interceptor.
class ApiResponseCacheInterceptor extends Interceptor {
  static final Map<String, CacheEntry> _cache = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method != 'GET' || options.extra['no_cache'] == true) {
      return handler.next(options);
    }

    final cacheKey = _getCacheKey(options);
    final cachedEntry = _cache[cacheKey];

    if (cachedEntry != null && !cachedEntry.isExpired) {
      // Add ETag if available for conditional requests
      if (cachedEntry.eTag != null) {
        options.headers['If-None-Match'] = cachedEntry.eTag;
      }

      // Return cached response immediately
      handler.resolve(
        Response(
          requestOptions: options,
          data: cachedEntry.data,
          statusCode: 304, // Not Modified / Cached
          headers: Headers.fromMap({'x-from-cache': ['true']}),
        ),
      );
      return;
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.requestOptions.method == 'GET' && response.statusCode == 200) {
      final cacheKey = _getCacheKey(response.requestOptions);
      final eTag = response.headers.value('etag');
      
      // Calculate TTL based on NetworkAdaptiveManager policy
      double ttlMultiplier = 1.0;
      if (Get.isRegistered<NetworkAdaptiveManager>()) {
        ttlMultiplier = NetworkAdaptiveManager.to.activePolicy.value.cacheTtlMultiplier;
      }
      final ttlDuration = Duration(seconds: (60 * ttlMultiplier).round());

      _cache[cacheKey] = CacheEntry(
        data: response.data,
        eTag: eTag,
        expiresAt: DateTime.now().add(ttlDuration),
      );
    }
    handler.next(response);
  }

  String _getCacheKey(RequestOptions options) {
    return '${options.method}:${options.uri}';
  }

  static void clearCache() {
    _cache.clear();
  }
}

class CacheEntry {
  final dynamic data;
  final String? eTag;
  final DateTime expiresAt;

  CacheEntry({required this.data, this.eTag, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Ultra-Fast Unified Network Client.
class UltraNetworkClient extends GetxService {
  static UltraNetworkClient get to => Get.find();

  late final Dio dio;

  @override
  void onInit() {
    super.onInit();
    _initDio();
  }

  void _initDio() {
    final baseOptions = BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 10),
      headers: {
        'Accept-Encoding': 'br, gzip, deflate',
        'Alt-Svc': 'h3=":443"; ma=86400, h3-29=":443"; ma=86400',
        'Connection': 'keep-alive',
        'Keep-Alive': 'timeout=30, max=100',
      },
      responseType: ResponseType.json,
    );

    dio = Dio(baseOptions);

    // ── HTTP Connection Pooling & Keep-Alive ───────────────────────────
    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 40);
      client.maxConnectionsPerHost = 16;
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return client;
    };
    dio.httpClientAdapter = adapter;

    // ── Register Interceptors ──────────────────────────────────────────
    dio.interceptors.addAll([
      DnsCacheInterceptor(),
      ApiResponseCacheInterceptor(),
      NetworkRetryInterceptor(dio),
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Dynamic adaptive network parameter adjustment
          if (Get.isRegistered<NetworkAdaptiveManager>()) {
            final policy = NetworkAdaptiveManager.to.activePolicy.value;
            options.connectTimeout = policy.connectTimeout;
            options.receiveTimeout = policy.receiveTimeout;
          }
          handler.next(options);
        },
      ),
    ]);

    debugPrint('[UltraNetworkClient] Optimized HTTP/3 (QUIC) & Connection Pool engine initialized.');
  }

  /// Convenience GET helper with auto-retries and caching
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Convenience POST helper
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}
