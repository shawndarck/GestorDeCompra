import '../main.dart';

AuthSession? loadSavedAuthSession() => AuthSession(
  token: 'stub',
  expiresAt: DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
  user: const AuthUser(
    id: 1,
    username: 'test',
    email: 'test@pricesec.local',
    role: 'super_admin',
  ),
);

Future<bool> hasRegisteredUsers() async => false;

Future<AuthSession> registerAuthUser({
  required String username,
  required String email,
  required String password,
}) async {
  return AuthSession(
    token: 'stub',
    expiresAt: DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
    user: AuthUser(
      id: 1,
      username: username,
      email: email,
      role: 'super_admin',
    ),
  );
}

Future<AuthSession> loginAuthUser({
  required String username,
  required String password,
}) async {
  return AuthSession(
    token: 'stub',
    expiresAt: DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
    user: AuthUser(
      id: 1,
      username: username,
      email: 'local@pricesec.dev',
      role: 'super_admin',
    ),
  );
}

Future<void> requestPasswordResetCode({required String email}) async {}

Future<void> confirmPasswordResetCode({
  required String email,
  required String code,
  required String password,
}) async {}

void logoutAuthUser() {}

Future<List<PermissionInfo>> loadPermissions() async => const [
  PermissionInfo(key: 'view_sales', label: 'Ver ventas'),
  PermissionInfo(key: 'view_inventory', label: 'Consultar inventario'),
  PermissionInfo(key: 'manage_stores', label: 'Gestionar tiendas'),
  PermissionInfo(key: 'manage_collaborators', label: 'Gestionar colaboradores'),
];

Future<List<AuthUser>> loadPrincipalUsers() async => const [];

Future<AuthUser> createPrincipalUser({
  required String username,
  required String email,
  required String password,
  required String profileName,
  required String phone,
}) async {
  return AuthUser(
    id: DateTime.now().millisecondsSinceEpoch,
    username: username,
    email: email,
    role: 'owner',
    profileName: profileName,
    phone: phone,
  );
}

Future<AuthUser> updatePrincipalUser({
  required int id,
  required String profileName,
  required String phone,
  required String status,
}) async {
  return AuthUser(
    id: id,
    username: 'owner',
    email: 'owner@pricesec.local',
    role: 'owner',
    profileName: profileName,
    phone: phone,
    status: status,
  );
}

Future<List<AuthUser>> loadCollaborators() async => const [];

Future<AuthUser> createCollaborator({
  required String username,
  required String email,
  required String password,
  required String profileName,
  required List<String> permissions,
}) async {
  return AuthUser(
    id: DateTime.now().millisecondsSinceEpoch,
    username: username,
    email: email,
    role: 'collaborator',
    profileName: profileName,
    permissions: permissions,
  );
}

Future<AuthUser> updateCollaborator({
  required int id,
  required String profileName,
  required String status,
  required List<String> permissions,
}) async {
  return AuthUser(
    id: id,
    username: 'collaborator',
    email: 'collaborator@pricesec.local',
    role: 'collaborator',
    profileName: profileName,
    status: status,
    permissions: permissions,
  );
}

Future<List<MercadoLibreStore>> loadMercadoLibreStores() async => const [];

Future<MercadoLibreStore> saveMercadoLibreStore({
  int? id,
  required String name,
  required String storeUser,
  required String storeUrl,
  String status = 'active',
}) async {
  return MercadoLibreStore(
    id: id ?? DateTime.now().millisecondsSinceEpoch,
    name: name,
    storeUser: storeUser,
    storeUrl: storeUrl,
    status: status,
  );
}

Future<List<PurchaseRecord>> loadPurchases() async => const [];

Future<PurchaseRecord> savePurchase(PurchaseDraft draft, {int? id}) async {
  return PurchaseRecord.fromDraft(
    id ?? DateTime.now().millisecondsSinceEpoch,
    draft,
  );
}

Future<void> deletePurchase(int id) async {}

Future<List<AliExpressViabilityRecord>> loadAliExpressViabilities() async =>
    const [];

Future<AliExpressViabilityRecord> saveAliExpressViability(
  AliExpressViabilityDraft draft, {
  int? id,
}) async {
  return AliExpressViabilityRecord.fromDraft(
    id ?? DateTime.now().millisecondsSinceEpoch,
    draft,
  );
}

Future<void> deleteAliExpressViability(int id) async {}

Future<List<InventoryItemRecord>> loadInventoryItems() async => const [];

Future<InventoryItemRecord> saveInventoryItem(InventoryItemDraft draft) async {
  return InventoryItemRecord.fromDraft(
    DateTime.now().millisecondsSinceEpoch,
    draft,
  );
}

Future<void> deleteInventoryItem(int id) async {}

Future<List<SaleRecord>> loadSales() async => const [];

Future<SaleSaveResult> saveSale(SaleDraft draft) async {
  return SaleSaveResult(
    sale: SaleRecord.fromDraft(DateTime.now().millisecondsSinceEpoch, draft),
    lowStock: false,
  );
}

Future<double?> fetchCurrentTrm() async => null;
