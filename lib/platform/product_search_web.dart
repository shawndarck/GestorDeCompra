// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import '../main.dart';

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
  final request = await html.HttpRequest.request(
    'http://localhost:8768/search',
    method: 'POST',
    requestHeaders: {'Content-Type': 'application/json'},
    sendData: jsonEncode({
      'product': product,
      'country': fixedMonitorConfig.country,
      'currency': fixedMonitorConfig.currency,
      'filters': {
        'minRating': filters.minRating,
        'minSales': filters.minSales,
        'shippingFilter': filters.shippingFilter.name,
        'stores': filters.stores.map((store) => store.name).toList(),
      },
    }),
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
