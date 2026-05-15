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
  return [
    ProductResult(
      store: StoreOption.aliexpress,
      title: '$product - vendedor destacado',
      totalPrice: 89900,
      rating: 4.8,
      sales: 1240,
      shippingIncluded: true,
      deliveryDays: 18,
      listingUrl: 'https://www.aliexpress.com/wholesale?SearchText=$product',
    ),
    ProductResult(
      store: StoreOption.temu,
      title: '$product - opcion economica',
      totalPrice: 76900,
      rating: 4.3,
      sales: 460,
      shippingIncluded: false,
      deliveryDays: 15,
      listingUrl: 'https://www.temu.com/search_result.html?search_key=$product',
    ),
  ].where((result) => filters.stores.contains(result.store)).toList();
}
