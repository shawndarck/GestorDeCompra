// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import '../main.dart';

final _baseUrl = const String.fromEnvironment(
  'PRICESEC_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8768',
).replaceFirst(RegExp(r'/$'), '');

class ProductSearchException implements Exception {
  const ProductSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<List<ProductResult>> searchProducts({
  required String product,
  required SearchFilters filters,
}) async {
  final payload = jsonEncode({
    'product': product,
    'country': fixedMonitorConfig.country,
    'currency': fixedMonitorConfig.currency,
    'filters': {
      'minRating': filters.minRating,
      'minSales': filters.minSales,
      'shippingFilter': filters.shippingFilter.name,
      'stores': filters.stores.map((store) => store.name).toList(),
    },
  });
  final request = await _searchRequest(
    '$_baseUrl/search',
    payload,
  );

  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  if (request.status != 200) {
    throw ProductSearchException(
      (body['message'] as String?) ??
          'No pude conectar con el servicio local de busqueda.',
    );
  }

  final results = (body['results'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(ProductResult.fromJson)
      .toList();

  if (results.isEmpty) {
    throw ProductSearchException(
      (body['message'] as String?) ??
          'No encontre resultados. Si la tienda pide login, inicia sesion y vuelve a intentar.',
    );
  }

  return results;
}

Future<html.HttpRequest> _searchRequest(String url, String payload) async {
  final session = _savedSessionToken();
  final request = html.HttpRequest();
  final completer = Completer<html.HttpRequest>();
  request
    ..open('POST', url, async: true)
    ..setRequestHeader('Content-Type', 'application/json');
  if (session != null) {
    request.setRequestHeader('Authorization', 'Bearer $session');
  }
  request.onLoadEnd.first.then((_) {
    if (!completer.isCompleted) completer.complete(request);
  });
  request.onError.first.then((_) {
    if (!completer.isCompleted) {
      completer.completeError(
        const ProductSearchException(
          'No pude comunicarme con el backend local. Verifica que PriceSec este activo.',
        ),
      );
    }
  });
  request.send(payload);
  try {
    return await completer.future.timeout(const Duration(seconds: 90));
  } on TimeoutException {
    throw const ProductSearchException(
      'La busqueda tardo demasiado. Revisa la ventana de Chrome de PriceSec y vuelve a intentar.',
    );
  }
}

String? _savedSessionToken() {
  final raw = html.window.localStorage['pricesec_auth_session'];
  if (raw == null || raw.isEmpty) return null;
  try {
    final body = jsonDecode(raw) as Map<String, dynamic>;
    final token = body['token'] as String?;
    return token == null || token.isEmpty ? null : token;
  } catch (_) {
    return null;
  }
}
