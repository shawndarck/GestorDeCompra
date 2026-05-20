// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, unused_element

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import '../main.dart';

const _baseUrl = 'http://127.0.0.1:8768';
const _requestTimeout = Duration(seconds: 12);
const _localStorageKey = 'pricesec_purchases_backup';
const _viabilityLocalStorageKey = 'pricesec_aliexpress_viability_backup';
const _authStorageKey = 'pricesec_auth_session';

AuthSession? loadSavedAuthSession() {
  final raw = html.window.localStorage[_authStorageKey];
  if (raw == null || raw.isEmpty) return null;
  try {
    return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    html.window.localStorage.remove(_authStorageKey);
    return null;
  }
}

Future<bool> hasRegisteredUsers() async {
  final request = await _request('$_baseUrl/auth/status', includeAuth: false);
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  return body['hasUsers'] == true;
}

Future<AuthSession> registerAuthUser({
  required String username,
  required String email,
  required String password,
}) async {
  final session = await _authRequest('$_baseUrl/auth/register', {
    'username': username,
    'email': email,
    'password': password,
  });
  _saveAuthSession(session);
  return session;
}

Future<AuthSession> loginAuthUser({
  required String username,
  required String password,
}) async {
  final session = await _authRequest('$_baseUrl/auth/login', {
    'username': username,
    'password': password,
  });
  _saveAuthSession(session);
  return session;
}

Future<void> requestPasswordResetCode({required String email}) async {
  final request = await _request(
    '$_baseUrl/auth/reset/request',
    method: 'POST',
    requestHeaders: {'Content-Type': 'application/json'},
    sendData: jsonEncode({'email': email}),
    includeAuth: false,
  );
  if (request.status != 200) {
    final body =
        jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
    throw Exception(body['message'] as String? ?? 'No pude enviar codigo.');
  }
}

Future<void> confirmPasswordResetCode({
  required String email,
  required String code,
  required String password,
}) async {
  final request = await _request(
    '$_baseUrl/auth/reset/confirm',
    method: 'POST',
    requestHeaders: {'Content-Type': 'application/json'},
    sendData: jsonEncode({'email': email, 'code': code, 'password': password}),
    includeAuth: false,
  );
  if (request.status != 200) {
    final body =
        jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
    throw Exception(body['message'] as String? ?? 'No pude restablecer.');
  }
}

Future<List<PermissionInfo>> loadPermissions() async {
  final request = await _request('$_baseUrl/permissions');
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  return (body['permissions'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(PermissionInfo.fromJson)
      .toList();
}

Future<List<AuthUser>> loadPrincipalUsers() async {
  final request = await _request('$_baseUrl/admin/principal-users');
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  return (body['users'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(AuthUser.fromJson)
      .toList();
}

Future<AuthUser> createPrincipalUser({
  required String username,
  required String email,
  required String password,
  required String profileName,
  required String phone,
}) async {
  final request = await _request(
    '$_baseUrl/admin/principal-users',
    method: 'POST',
    requestHeaders: {'Content-Type': 'application/json'},
    sendData: jsonEncode({
      'username': username,
      'email': email,
      'password': password,
      'profileName': profileName,
      'phone': phone,
    }),
  );
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  if (request.status != 200) {
    throw Exception(body['message'] as String? ?? 'No pude crear usuario.');
  }
  return AuthUser.fromJson(body['user'] as Map<String, dynamic>);
}

Future<AuthUser> updatePrincipalUser({
  required int id,
  required String profileName,
  required String phone,
  required String status,
}) async {
  final request = await _request(
    '$_baseUrl/admin/principal-users/$id',
    method: 'PUT',
    requestHeaders: {'Content-Type': 'application/json'},
    sendData: jsonEncode({
      'profileName': profileName,
      'phone': phone,
      'status': status,
    }),
  );
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  if (request.status != 200) {
    throw Exception(
      body['message'] as String? ?? 'No pude actualizar usuario.',
    );
  }
  return AuthUser.fromJson(body['user'] as Map<String, dynamic>);
}

Future<List<AuthUser>> loadCollaborators() async {
  final request = await _request('$_baseUrl/collaborators');
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  return (body['collaborators'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(AuthUser.fromJson)
      .toList();
}

Future<AuthUser> createCollaborator({
  required String username,
  required String email,
  required String password,
  required String profileName,
  required List<String> permissions,
}) async {
  final request = await _request(
    '$_baseUrl/collaborators',
    method: 'POST',
    requestHeaders: {'Content-Type': 'application/json'},
    sendData: jsonEncode({
      'username': username,
      'email': email,
      'password': password,
      'profileName': profileName,
      'permissions': permissions,
    }),
  );
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  if (request.status != 200) {
    throw Exception(body['message'] as String? ?? 'No pude crear colaborador.');
  }
  return AuthUser.fromJson(body['collaborator'] as Map<String, dynamic>);
}

Future<AuthUser> updateCollaborator({
  required int id,
  required String profileName,
  required String status,
  required List<String> permissions,
}) async {
  final request = await _request(
    '$_baseUrl/collaborators/$id',
    method: 'PUT',
    requestHeaders: {'Content-Type': 'application/json'},
    sendData: jsonEncode({
      'profileName': profileName,
      'status': status,
      'permissions': permissions,
    }),
  );
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  if (request.status != 200) {
    throw Exception(
      body['message'] as String? ?? 'No pude actualizar colaborador.',
    );
  }
  return AuthUser.fromJson(body['collaborator'] as Map<String, dynamic>);
}

Future<List<MercadoLibreStore>> loadMercadoLibreStores() async {
  final request = await _request('$_baseUrl/mercado-libre-stores');
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  return (body['stores'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(MercadoLibreStore.fromJson)
      .toList();
}

Future<MercadoLibreStore> saveMercadoLibreStore({
  int? id,
  required String name,
  required String storeUser,
  required String storeUrl,
  String status = 'active',
}) async {
  final request = await _request(
    id == null
        ? '$_baseUrl/mercado-libre-stores'
        : '$_baseUrl/mercado-libre-stores/$id',
    method: id == null ? 'POST' : 'PUT',
    requestHeaders: {'Content-Type': 'application/json'},
    sendData: jsonEncode({
      'name': name,
      'storeUser': storeUser,
      'storeUrl': storeUrl,
      'status': status,
    }),
  );
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  if (request.status != 200) {
    throw Exception(body['message'] as String? ?? 'No pude guardar tienda.');
  }
  return MercadoLibreStore.fromJson(body['store'] as Map<String, dynamic>);
}

void logoutAuthUser() {
  html.window.localStorage.remove(_authStorageKey);
}

Future<List<PurchaseRecord>> loadPurchases() async {
  final localPurchases = _loadLocalPurchases();
  try {
    final request = await _request('$_baseUrl/purchases');
    final body =
        jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
    final remotePurchases = (body['purchases'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PurchaseRecord.fromJson)
        .toList();
    return [...localPurchases, ...remotePurchases];
  } catch (_) {
    return localPurchases;
  }
}

Future<PurchaseRecord> savePurchase(PurchaseDraft draft, {int? id}) async {
  try {
    final request = await _request(
      id == null ? '$_baseUrl/purchases' : '$_baseUrl/purchases/$id',
      method: id == null ? 'POST' : 'PUT',
      requestHeaders: {'Content-Type': 'application/json'},
      sendData: jsonEncode(draft.toJson()),
    );
    final body =
        jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
    if (request.status != 200) {
      throw Exception(
        body['message'] as String? ?? 'No pude guardar la compra.',
      );
    }
    return PurchaseRecord.fromJson(body['purchase'] as Map<String, dynamic>);
  } catch (_) {
    return _saveLocalPurchase(draft, id: id);
  }
}

Future<void> deletePurchase(int id) async {
  _deleteLocalPurchase(id);
  if (id > 0) {
    try {
      final request = await _request(
        '$_baseUrl/purchases/$id',
        method: 'DELETE',
      );
      if (request.status != 200) {
        final body =
            jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
        throw Exception(
          body['message'] as String? ?? 'No pude eliminar la compra.',
        );
      }
    } catch (_) {
      return;
    }
  }
}

Future<List<AliExpressViabilityRecord>> loadAliExpressViabilities() async {
  final localRecords = _loadLocalViabilities();
  try {
    final request = await _request('$_baseUrl/aliexpress-viabilities');
    final body =
        jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
    final remoteRecords = (body['records'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AliExpressViabilityRecord.fromJson)
        .toList();
    return [...localRecords, ...remoteRecords];
  } catch (_) {
    return localRecords;
  }
}

Future<AliExpressViabilityRecord> saveAliExpressViability(
  AliExpressViabilityDraft draft, {
  int? id,
}) async {
  try {
    final request = await _request(
      id == null
          ? '$_baseUrl/aliexpress-viabilities'
          : '$_baseUrl/aliexpress-viabilities/$id',
      method: id == null ? 'POST' : 'PUT',
      requestHeaders: {'Content-Type': 'application/json'},
      sendData: jsonEncode(draft.toJson()),
    );
    final body =
        jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
    if (request.status != 200) {
      throw Exception(
        body['message'] as String? ?? 'No pude guardar la viabilidad.',
      );
    }
    return AliExpressViabilityRecord.fromJson(
      body['record'] as Map<String, dynamic>,
    );
  } catch (error) {
    throw Exception(error.toString());
  }
}

Future<InventoryItemRecord> markViabilityPurchased(int id) async {
  final request = await _request(
    '$_baseUrl/aliexpress-viabilities/$id/purchase',
    method: 'POST',
  );
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  if (request.status != 200) {
    throw Exception(body['message'] as String? ?? 'No pude marcar comprado.');
  }
  return InventoryItemRecord.fromJson(body['item'] as Map<String, dynamic>);
}

Future<void> deleteAliExpressViability(int id) async {
  _deleteLocalViability(id);
  if (id > 0) {
    try {
      final request = await _request(
        '$_baseUrl/aliexpress-viabilities/$id',
        method: 'DELETE',
      );
      if (request.status != 200) {
        final body =
            jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
        throw Exception(
          body['message'] as String? ?? 'No pude eliminar la viabilidad.',
        );
      }
    } catch (_) {
      return;
    }
  }
}

Future<List<InventoryItemRecord>> loadInventoryItems() async {
  final request = await _request('$_baseUrl/inventory');
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  return (body['items'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(InventoryItemRecord.fromJson)
      .toList();
}

Future<InventoryItemRecord> saveInventoryItem(InventoryItemDraft draft) async {
  final request = await _request(
    '$_baseUrl/inventory',
    method: 'POST',
    requestHeaders: {'Content-Type': 'application/json'},
    sendData: jsonEncode(draft.toJson()),
  );
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  if (request.status != 200) {
    throw Exception(
      body['message'] as String? ?? 'No pude guardar inventario.',
    );
  }
  return InventoryItemRecord.fromJson(body['item'] as Map<String, dynamic>);
}

Future<InventoryItemRecord> receiveInventoryItem(int id, String warehouse) async {
  final request = await _request(
    '$_baseUrl/inventory/$id/receive',
    method: 'POST',
    requestHeaders: {'Content-Type': 'application/json'},
    sendData: jsonEncode({'warehouse': warehouse}),
  );
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  if (request.status != 200) {
    throw Exception(body['message'] as String? ?? 'No pude recibir inventario.');
  }
  return InventoryItemRecord.fromJson(body['item'] as Map<String, dynamic>);
}

Future<List<String>> loadWarehouses() async {
  final request = await _request('$_baseUrl/warehouses');
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  return (body['warehouses'] as List<dynamic>? ?? const [])
      .whereType<String>()
      .toList();
}

Future<void> deleteInventoryItem(int id) async {
  final request = await _request('$_baseUrl/inventory/$id', method: 'DELETE');
  if (request.status != 200) {
    final body =
        jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
    throw Exception(
      body['message'] as String? ?? 'No pude eliminar inventario.',
    );
  }
}

Future<List<SaleRecord>> loadSales() async {
  final request = await _request('$_baseUrl/sales');
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  return (body['sales'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(SaleRecord.fromJson)
      .toList();
}

Future<SaleSaveResult> saveSale(SaleDraft draft) async {
  final request = await _request(
    '$_baseUrl/sales',
    method: 'POST',
    requestHeaders: {'Content-Type': 'application/json'},
    sendData: jsonEncode(draft.toJson()),
  );
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  if (request.status != 200) {
    throw Exception(
      body['message'] as String? ?? 'No pude registrar la venta.',
    );
  }
  return SaleSaveResult(
    sale: SaleRecord.fromJson(body['sale'] as Map<String, dynamic>),
    lowStock: body['lowStock'] == true,
  );
}

Future<double?> fetchCurrentTrm() async {
  final request = await _request('$_baseUrl/trm');
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  if (request.status != 200) return null;
  return (body['rate'] as num?)?.toDouble();
}

Future<html.HttpRequest> _request(
  String url, {
  String? method,
  Map<String, String>? requestHeaders,
  Object? sendData,
  bool includeAuth = true,
}) async {
  final headers = {...?requestHeaders};
  final session = includeAuth ? loadSavedAuthSession() : null;
  if (session != null) headers['Authorization'] = 'Bearer ${session.token}';
  final request = html.HttpRequest();
  final completer = Completer<html.HttpRequest>();
  request
    ..open(method ?? 'GET', url, async: true)
    ..onLoadEnd.first.then((_) {
      if (!completer.isCompleted) completer.complete(request);
    })
    ..onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception(
            'No pude comunicarme con el backend local. Verifica http://127.0.0.1:8768/health y vuelve a intentar.',
          ),
        );
      }
    });
  headers.forEach(request.setRequestHeader);
  request.send(sendData);
  try {
    return await completer.future.timeout(_requestTimeout);
  } on TimeoutException {
    throw Exception(
      'No pude comunicarme con el backend local. Verifica http://127.0.0.1:8768/health y vuelve a intentar.',
    );
  }
}

Future<AuthSession> _authRequest(
  String url,
  Map<String, dynamic> payload,
) async {
  final request = await _request(
    url,
    method: 'POST',
    requestHeaders: {'Content-Type': 'application/json'},
    sendData: jsonEncode(payload),
    includeAuth: false,
  );
  final body = jsonDecode(request.responseText ?? '{}') as Map<String, dynamic>;
  if (request.status != 200) {
    throw Exception(body['message'] as String? ?? 'No pude autenticar.');
  }
  return AuthSession.fromJson(body);
}

void _saveAuthSession(AuthSession session) {
  html.window.localStorage[_authStorageKey] = jsonEncode(session.toJson());
}

List<PurchaseRecord> _loadLocalPurchases() {
  final raw = html.window.localStorage[_localStorageKey];
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(PurchaseRecord.fromJson)
        .toList();
  } catch (_) {
    return const [];
  }
}

PurchaseRecord _saveLocalPurchase(PurchaseDraft draft, {int? id}) {
  final purchases = _loadLocalPurchases();
  final now = DateTime.now().toIso8601String();
  final localId = id ?? -DateTime.now().millisecondsSinceEpoch;
  final payload = {
    ...draft.toJson(),
    'id': localId,
    'productName': draft.productName,
    'createdAt': now,
    'updatedAt': now,
  };
  final next = [
    payload,
    ...purchases.where((purchase) => purchase.id != localId).map(_recordToJson),
  ];
  html.window.localStorage[_localStorageKey] = jsonEncode(next);
  return PurchaseRecord.fromJson(payload);
}

void _deleteLocalPurchase(int id) {
  final next = _loadLocalPurchases()
      .where((purchase) => purchase.id != id)
      .map(_recordToJson)
      .toList();
  html.window.localStorage[_localStorageKey] = jsonEncode(next);
}

Map<String, dynamic> _recordToJson(PurchaseRecord record) => {
  ...record.draft.toJson(),
  'id': record.id,
  'productName': record.productName,
  'createdAt': record.createdAt,
  'updatedAt': record.updatedAt,
};

List<AliExpressViabilityRecord> _loadLocalViabilities() {
  final raw = html.window.localStorage[_viabilityLocalStorageKey];
  if (raw == null || raw.isEmpty) return const [];
  try {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(AliExpressViabilityRecord.fromJson)
        .toList();
  } catch (_) {
    return const [];
  }
}

AliExpressViabilityRecord _saveLocalViability(
  AliExpressViabilityDraft draft, {
  int? id,
}) {
  final records = _loadLocalViabilities();
  final now = DateTime.now().toIso8601String();
  final localId = id ?? -DateTime.now().millisecondsSinceEpoch;
  final payload = {
    ...draft.toJson(),
    ...AliExpressViabilityCalculations.fromDraft(draft).toJson(),
    'id': localId,
    'productName': draft.productName,
    'createdAt': now,
    'updatedAt': now,
  };
  final next = [
    payload,
    ...records.where((record) => record.id != localId).map(_viabilityToJson),
  ];
  html.window.localStorage[_viabilityLocalStorageKey] = jsonEncode(next);
  return AliExpressViabilityRecord.fromJson(payload);
}

void _deleteLocalViability(int id) {
  final next = _loadLocalViabilities()
      .where((record) => record.id != id)
      .map(_viabilityToJson)
      .toList();
  html.window.localStorage[_viabilityLocalStorageKey] = jsonEncode(next);
}

Map<String, dynamic> _viabilityToJson(AliExpressViabilityRecord record) => {
  ...record.draft.toJson(),
  ...record.calculations.toJson(),
  'id': record.id,
  'productName': record.productName,
  'createdAt': record.createdAt,
  'updatedAt': record.updatedAt,
};
