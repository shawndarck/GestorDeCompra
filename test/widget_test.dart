import 'package:pricesec/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the product monitor screen with editable filters', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1500));
    await tester.pumpWidget(const PriceScoutApp());

    expect(find.text('PriceSec'), findsOneWidget);
    expect(find.text('Filtros de busqueda'), findsOneWidget);
    expect(find.text('Pais: '), findsOneWidget);
    expect(find.text('Colombia'), findsWidgets);
    expect(find.text('Moneda: '), findsOneWidget);
    expect(find.text('COP'), findsWidgets);
    expect(find.text('Rating minimo: '), findsOneWidget);
    expect(find.text('4.5+ estrellas'), findsOneWidget);
    expect(find.text('Envio incluido: '), findsOneWidget);
    expect(find.text('Si'), findsOneWidget);
    expect(find.text('Tiendas a comparar'), findsOneWidget);
    expect(find.text('AliExpress'), findsWidgets);
    expect(find.text('Temu'), findsWidgets);
    expect(find.text('Shein'), findsOneWidget);
    expect(find.text('Amazon'), findsOneWidget);
    expect(find.text('Entrega: '), findsNothing);
  });

  testWidgets('changes rating from the dropdown', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1500));
    await tester.pumpWidget(const PriceScoutApp());

    await tester.tap(find.text('4.5+ estrellas'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('3.5+ estrellas').last);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('3.5+ estrellas'), findsOneWidget);
  });

  testWidgets('changes shipping filter to both options', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1500));
    await tester.pumpWidget(const PriceScoutApp());

    await tester.tap(find.text('Si'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Ambos').last);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Ambos'), findsOneWidget);
  });

  testWidgets('runs a comparison from the main button', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1500));
    await tester.pumpWidget(const PriceScoutApp());

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre del producto'),
      'audifonos bluetooth',
    );
    await tester.tap(find.text('Comparar ahora'));
    await tester.pump();

    expect(
      find.text('Ejecutando busqueda para "audifonos bluetooth"...'),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('Mejor opcion: AliExpress por \$89.900 COP'),
      findsOneWidget,
    );
    expect(find.textContaining('AliExpress'), findsWidgets);
    expect(find.textContaining('Temu'), findsWidgets);
  });

  test('filters products using selected criteria', () {
    const filters = SearchFilters(
      minRating: 4.5,
      minSales: 100,
      shippingFilter: ShippingFilter.included,
      stores: {StoreOption.aliexpress, StoreOption.temu},
    );
    const lowRated = ProductResult(
      store: StoreOption.temu,
      title: 'Producto barato',
      totalPrice: 30000,
      rating: 4.2,
      sales: 900,
      shippingIncluded: true,
      deliveryDays: 10,
      listingUrl: 'https://example.com/low-rated',
    );

    const trusted = ProductResult(
      store: StoreOption.aliexpress,
      title: 'Producto confiable',
      totalPrice: 65000,
      rating: 4.8,
      sales: 320,
      shippingIncluded: true,
      deliveryDays: 15,
      listingUrl: 'https://example.com/trusted',
    );

    expect(lowRated.isValid(filters), isFalse);
    expect(trusted.isValid(filters), isTrue);
  });

  test('both shipping filter accepts included and not included shipping', () {
    const filters = SearchFilters(
      minRating: 4.5,
      minSales: 100,
      shippingFilter: ShippingFilter.any,
      stores: {StoreOption.aliexpress},
    );
    const noShippingIncluded = ProductResult(
      store: StoreOption.aliexpress,
      title: 'Producto sin envio incluido',
      totalPrice: 65000,
      rating: 4.8,
      sales: 320,
      shippingIncluded: false,
      deliveryDays: 15,
      listingUrl: 'https://example.com/no-shipping',
    );

    expect(noShippingIncluded.isValid(filters), isTrue);
  });

  test('store filter excludes unselected stores', () {
    const filters = SearchFilters(
      minRating: 4.5,
      minSales: 100,
      shippingFilter: ShippingFilter.any,
      stores: {StoreOption.amazon},
    );
    const sheinResult = ProductResult(
      store: StoreOption.shein,
      title: 'Producto Shein',
      totalPrice: 65000,
      rating: 4.8,
      sales: 320,
      shippingIncluded: true,
      deliveryDays: 15,
      listingUrl: 'https://example.com/shein',
    );

    expect(sheinResult.isValid(filters), isFalse);
  });

  testWidgets('purchase tab validates required fields before saving', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1500));
    await tester.pumpWidget(const PriceScoutApp());

    await tester.tap(find.text('Comparador'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Registrar compra'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Debes ingresar este dato.'), findsWidgets);
    expect(find.text('Aun no hay compras registradas.'), findsNothing);
  });

  testWidgets('saved purchases live in an independent tab', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1500));
    await tester.pumpWidget(const PriceScoutApp());

    await tester.tap(find.text('Comparador'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Compras guardadas'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Compras guardadas'), findsWidgets);
    expect(find.text('Aun no hay compras registradas.'), findsOneWidget);
  });

  testWidgets('module selector exposes inventory and sales modules', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1500));
    await tester.pumpWidget(const PriceScoutApp());

    await tester.tap(find.text('Comparador'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Sistema de Gestion'), findsOneWidget);
    expect(find.text('Registrar ventas'), findsOneWidget);
  });

  test('purchase calculations read Colombian TRM separators correctly', () {
    expect(parseLocalizedNumber('3.800'), 3800);
    expect(parseLocalizedNumber('3,800'), 3800);
    expect(parseLocalizedNumber('5.35'), 5.35);
    expect(parseLocalizedNumber('5,35'), 5.35);

    const draft = PurchaseDraft(
      productName: 'Carro a control remoto',
      priceUsd: 5.35,
      trm: 3800,
      quantity: 1,
      originShippingUsd: 0,
      cardCommissionRate: 0,
      heightCm: 0,
      widthCm: 0,
      lengthCm: 0,
      boxCount: 0,
      cbmRate: 0,
      nationalFreight: 0,
      mercadoLibrePrice: 0,
      mercadoLibreCommissionRate: 0,
    );

    final calculations = PurchaseCalculations.fromDraft(draft);
    expect(calculations.priceCop, 20330);
  });
}
