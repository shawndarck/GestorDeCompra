import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'platform/product_search.dart';
import 'platform/purchase_api.dart';
import 'platform/url_opener.dart';

void main() {
  runApp(const PriceScoutApp());
}

class PriceScoutApp extends StatelessWidget {
  const PriceScoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PriceSec',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _CyberColors.primary,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: _CyberColors.bgDark,
        fontFamily: 'Arial',
      ),
      home: const PriceMonitorPage(),
    );
  }
}

class FixedMonitorConfig {
  const FixedMonitorConfig({
    required this.country,
    required this.currency,
    required this.frequency,
  });

  final String country;
  final String currency;
  final String frequency;
}

class SearchFilters {
  const SearchFilters({
    required this.minRating,
    required this.minSales,
    required this.shippingFilter,
    required this.stores,
  });

  final double minRating;
  final int minSales;
  final ShippingFilter shippingFilter;
  final Set<StoreOption> stores;
}

enum ShippingFilter {
  included('Si'),
  notIncluded('No'),
  any('Ambos');

  const ShippingFilter(this.label);

  final String label;
}

enum StoreOption {
  aliexpress('AliExpress', Icons.travel_explore, Color(0xffef2b00)),
  temu('Temu', Icons.shopping_bag, Color(0xffff6a00)),
  shein('Shein', Icons.checkroom, Color(0xff111827)),
  amazon('Amazon', Icons.shopping_cart, Color(0xffff9900));

  const StoreOption(this.label, this.icon, this.brandColor);

  final String label;
  final IconData icon;
  final Color brandColor;
}

enum _VisualSkin {
  cyber('Cyber UI', Icons.memory),
  neumorphic('Neo UI', Icons.blur_on);

  const _VisualSkin(this.label, this.icon);

  final String label;
  final IconData icon;
}

_VisualSkin _activeVisualSkin = _VisualSkin.cyber;

bool get _isNeoSkin => _activeVisualSkin == _VisualSkin.neumorphic;

const fixedMonitorConfig = FixedMonitorConfig(
  country: 'Colombia',
  currency: 'COP',
  frequency: 'Cada 6 horas',
);

class _CyberColors {
  static const primary = Color(0xff00ff88);
  static const secondary = Color(0xff00d4ff);
  static const accent = Color(0xffff6b6b);
  static const bgDark = Color(0xff0a0e1a);
  static const bgDarker = Color(0xff050810);
  static const card = Color(0xff0f1419);
  static const border = Color(0xff1e293b);
  static const textPrimary = Color(0xffe2e8f0);
  static const textSecondary = Color(0xff94a3b8);
}

class _NeoColors {
  static const bg = Color(0xffe0e5ec);
  static const surface = Color(0xffe0e5ec);
  static const shadowDark = Color(0xffa3b1c6);
  static const shadowLight = Color(0xffffffff);
  static const primary = Color(0xff6366f1);
  static const success = Color(0xff22c55e);
  static const textPrimary = Color(0xff111827);
  static const textSecondary = Color(0xff475569);
  static const lightEdge = Color(0xffd6dde7);
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.tenantId,
    this.parentUserId,
    this.status = 'active',
    this.profileName = '',
    this.phone = '',
    this.avatarData = '',
    this.permissions = const [],
    this.stores = const [],
  });

  final int id;
  final String username;
  final String email;
  final String role;
  final int? tenantId;
  final int? parentUserId;
  final String status;
  final String profileName;
  final String phone;
  final String avatarData;
  final List<String> permissions;
  final List<MercadoLibreStore> stores;

  bool get isSuperAdmin => role == 'super_admin';
  bool get isOwner => role == 'owner';

  bool can(String permission) {
    return isSuperAdmin || isOwner || permissions.contains(permission);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'tenantId': tenantId,
      'parentUserId': parentUserId,
      'status': status,
      'profileName': profileName,
      'phone': phone,
      'avatarData': avatarData,
      'permissions': permissions,
      'stores': stores.map((store) => store.toJson()).toList(),
    };
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num? ?? 0).round(),
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      tenantId: (json['tenantId'] as num?)?.round(),
      parentUserId: (json['parentUserId'] as num?)?.round(),
      status: json['status'] as String? ?? 'active',
      profileName: json['profileName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      avatarData: json['avatarData'] as String? ?? '',
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      stores: (json['stores'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MercadoLibreStore.fromJson)
          .toList(),
    );
  }
}

class PermissionInfo {
  const PermissionInfo({required this.key, required this.label});

  final String key;
  final String label;

  factory PermissionInfo.fromJson(Map<String, dynamic> json) {
    return PermissionInfo(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

class MercadoLibreStore {
  const MercadoLibreStore({
    required this.id,
    required this.name,
    required this.storeUser,
    required this.storeUrl,
    required this.status,
  });

  final int id;
  final String name;
  final String storeUser;
  final String storeUrl;
  final String status;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'storeUser': storeUser,
      'storeUrl': storeUrl,
      'status': status,
    };
  }

  factory MercadoLibreStore.fromJson(Map<String, dynamic> json) {
    return MercadoLibreStore(
      id: (json['id'] as num? ?? 0).round(),
      name: json['name'] as String? ?? '',
      storeUser: json['storeUser'] as String? ?? '',
      storeUrl: json['storeUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.expiresAt,
    required this.user,
  });

  final String token;
  final String expiresAt;
  final AuthUser user;

  Map<String, dynamic> toJson() {
    return {'token': token, 'expiresAt': expiresAt, 'user': user.toJson()};
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String? ?? '',
      expiresAt: json['expiresAt'] as String? ?? '',
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class PriceMonitorPage extends StatefulWidget {
  const PriceMonitorPage({super.key});

  @override
  State<PriceMonitorPage> createState() => _PriceMonitorPageState();
}

class _PriceMonitorPageState extends State<PriceMonitorPage> {
  static const List<double> _ratingOptions = [3, 3.5, 4, 4.5, 5];
  static const List<int> _salesOptions = [100, 200, 300, 500, 600];

  final TextEditingController _productController = TextEditingController();
  AuthSession? _authSession;
  bool _isCheckingAuth = true;
  bool _isRunning = false;
  double _minRating = 4.5;
  int _minSales = 100;
  ShippingFilter _shippingFilter = ShippingFilter.included;
  Set<StoreOption> _selectedStores = {
    StoreOption.aliexpress,
    StoreOption.temu,
    StoreOption.shein,
  };
  ProductResult? _bestResult;
  List<ProductResult> _results = const [];
  List<PurchaseRecord> _purchases = const [];
  List<AliExpressViabilityRecord> _viabilityRecords = const [];
  List<InventoryItemRecord> _inventoryItems = const [];
  List<SaleRecord> _sales = const [];
  List<AuthUser> _principalUsers = const [];
  List<AuthUser> _collaborators = const [];
  List<PermissionInfo> _permissions = const [];
  List<MercadoLibreStore> _mercadoLibreStores = const [];
  String? _statusMessage;
  String? _purchaseMessage;
  String? _viabilityMessage;
  String? _inventoryMessage;
  String? _salesMessage;
  String? _adminMessage;
  String? _collaboratorMessage;
  String? _storeMessage;
  int? _editingPurchaseId;
  int? _editingViabilityId;
  int _activeTab = 0;
  _VisualSkin _visualSkin = _VisualSkin.cyber;
  double? _currentTrm;
  bool _isLoadingCurrentTrm = false;
  int _trmRevision = 0;
  List<String> _warehouseOptions = const [];

  SearchFilters get _filters => SearchFilters(
    minRating: _minRating,
    minSales: _minSales,
    shippingFilter: _shippingFilter,
    stores: _selectedStores,
  );

  List<_ModuleOption> get _availableModules {
    final user = _authSession?.user;
    if (user == null) return const [];
    return [
      for (final option in _moduleOptions)
        if (_canOpenModule(user, option.index)) option,
    ];
  }

  bool _canOpenModule(AuthUser user, int index) {
    return switch (index) {
      0 => user.can('create_publications'),
      1 => user.can('create_publications'),
      2 => user.can('view_reports'),
      3 => user.can('create_publications'),
      4 => user.can('view_reports'),
      5 => user.can('view_inventory') || user.can('modify_inventory'),
      6 => user.can('view_sales'),
      7 => user.isSuperAdmin,
      8 => user.can('manage_collaborators'),
      9 => user.can('manage_stores'),
      10 => user.can('view_inventory'),
      _ => false,
    };
  }

  @override
  void dispose() {
    _productController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedSession();
  }

  @override
  Widget build(BuildContext context) {
    _activeVisualSkin = _visualSkin;
    if (_isCheckingAuth) {
      return const Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: _CyberBackground()),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      );
    }
    if (_authSession == null) {
      return _AuthGate(onAuthenticated: _handleAuthenticated);
    }
    final modules = _availableModules;
    if (modules.isNotEmpty &&
        !modules.any((option) => option.index == _activeTab)) {
      _activeTab = modules.first.index;
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _visualSkin == _VisualSkin.neumorphic
                ? const _NeumorphicBackground()
                : const _CyberBackground(),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeaderBar(
                        onRun: _runComparison,
                        isRunning: _isRunning,
                        session: _authSession!,
                        onLogout: _logout,
                        visualSkin: _visualSkin,
                        onToggleSkin: _toggleVisualSkin,
                        onProfileUpdated: _handleProfileUpdated,
                      ),
                      const SizedBox(height: 28),
                      _ModuleSelector(
                        activeIndex: _activeTab,
                        options: modules,
                        onChanged: _changeTab,
                      ),
                      const SizedBox(height: 18),
                      if (_activeTab == 0) ...[
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 920;
                            final search = _SearchPanel(
                              controller: _productController,
                              onRun: _runComparison,
                              isRunning: _isRunning,
                            );
                            final filters = _CriteriaPanel(
                              ratingOptions: _ratingOptions,
                              salesOptions: _salesOptions,
                              minRating: _minRating,
                              minSales: _minSales,
                              shippingFilter: _shippingFilter,
                              selectedStores: _selectedStores,
                              onRatingChanged: (value) {
                                if (value == null) return;
                                setState(() => _minRating = value);
                              },
                              onSalesChanged: (value) {
                                if (value == null) return;
                                setState(() => _minSales = value);
                              },
                              onShippingFilterChanged: (value) {
                                if (value == null) return;
                                setState(() => _shippingFilter = value);
                              },
                              onStoreToggled: _toggleStore,
                            );
                            if (!wide) {
                              return Column(
                                children: [
                                  search,
                                  const SizedBox(height: 18),
                                  filters,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: search),
                                const SizedBox(width: 24),
                                Expanded(flex: 5, child: filters),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        _ResultsPanel(
                          statusMessage: _statusMessage,
                          bestResult: _bestResult,
                          results: _results,
                          filters: _filters,
                        ),
                      ] else if (_activeTab == 1)
                        _PurchaseSection(
                          purchases: _purchases,
                          message: _purchaseMessage,
                          editingId: _editingPurchaseId,
                          initialTrm: _currentTrm,
                          trmRevision: _trmRevision,
                          onSave: _savePurchase,
                          onCancelEdit: _cancelEditPurchase,
                        )
                      else if (_activeTab == 2)
                        _SavedPurchasesSection(
                          purchases: _purchases,
                          message: _purchaseMessage,
                          onEdit: _startEditPurchase,
                          onDelete: _deletePurchase,
                        )
                      else if (_activeTab == 3)
                        _AliExpressViabilitySection(
                          records: _viabilityRecords,
                          message: _viabilityMessage,
                          editingId: _editingViabilityId,
                          onSave: _saveAliExpressViability,
                          onCancelEdit: _cancelEditViability,
                        )
                      else if (_activeTab == 4)
                        _SavedViabilitiesSection(
                          records: _viabilityRecords,
                          message: _viabilityMessage,
                          onEdit: _startEditViability,
                          onDelete: _deleteAliExpressViability,
                          onMarkPurchased: _markViabilityPurchased,
                        )
                      else if (_activeTab == 5)
                        _InventorySection(
                          items: _inventoryItems,
                          warehouses: _warehouseOptions,
                          message: _inventoryMessage,
                          onSave: _saveInventoryItem,
                          onDelete: _deleteInventoryItem,
                          onReceive: _receiveInventoryItem,
                        )
                      else if (_activeTab == 6)
                        _SalesSection(
                          inventoryItems: _inventoryItems,
                          sales: _sales,
                          message: _salesMessage,
                          onSave: _saveSale,
                        )
                      else if (_activeTab == 10)
                        _InventorySummarySection(items: _inventoryItems)
                      else if (_activeTab == 7)
                        _PrincipalUsersSection(
                          users: _principalUsers,
                          message: _adminMessage,
                          onCreate: _createPrincipalUser,
                          onUpdate: _updatePrincipalUser,
                        )
                      else if (_activeTab == 8)
                        _CollaboratorsSection(
                          collaborators: _collaborators,
                          permissions: _permissions,
                          message: _collaboratorMessage,
                          onCreate: _createCollaborator,
                          onUpdate: _updateCollaborator,
                        )
                      else
                        _MercadoLibreStoresSection(
                          stores: _mercadoLibreStores,
                          message: _storeMessage,
                          onSave: _saveMercadoLibreStore,
                        ),
                      const SizedBox(height: 22),
                      const _OwnershipFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadSavedSession() async {
    final session = loadSavedAuthSession();
    setState(() {
      _authSession = session;
      _isCheckingAuth = false;
    });
    if (session != null) {
      await _loadPurchases();
      await _loadAliExpressViabilities();
      await _loadInventoryItems();
      await _loadSales();
      await _loadAccessManagement();
      await _loadCurrentTrmSuggestion();
    }
  }

  Future<void> _handleAuthenticated(AuthSession session) async {
    setState(() => _authSession = session);
    await _loadPurchases();
    await _loadAliExpressViabilities();
    await _loadInventoryItems();
    await _loadSales();
    await _loadAccessManagement();
    await _loadCurrentTrmSuggestion();
  }

  void _handleProfileUpdated(AuthSession session) {
    setState(() => _authSession = session);
  }

  void _logout() {
    logoutAuthUser();
    setState(() {
      _authSession = null;
      _purchases = const [];
      _viabilityRecords = const [];
      _inventoryItems = const [];
      _sales = const [];
      _principalUsers = const [];
      _collaborators = const [];
      _permissions = const [];
      _mercadoLibreStores = const [];
      _editingPurchaseId = null;
      _editingViabilityId = null;
      _activeTab = 0;
    });
  }

  Future<void> _runComparison() async {
    final product = _productController.text.trim();
    if (product.isEmpty || _isRunning) return;

    setState(() {
      _isRunning = true;
      _bestResult = null;
      _results = const [];
      _statusMessage = 'Ejecutando busqueda para "$product"...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));

    try {
      final rawResults = await searchProducts(
        product: product,
        filters: _filters,
      );
      final validResults =
          rawResults.where((result) => result.isValid(_filters)).toList()
            ..sort((a, b) => b.score(_filters).compareTo(a.score(_filters)));

      setState(() {
        _results = validResults;
        _bestResult = validResults.isEmpty ? null : validResults.first;
        _statusMessage = validResults.isEmpty
            ? 'No encontre opciones que pasen los filtros actuales.'
            : 'Comparacion real lista. Mostrando solo publicaciones que pasan tus filtros.';
        _isRunning = false;
      });
    } on ProductSearchException catch (error) {
      setState(() {
        _results = const [];
        _bestResult = null;
        _statusMessage = error.message;
        _isRunning = false;
      });
    } catch (error) {
      setState(() {
        _results = const [];
        _bestResult = null;
        _statusMessage =
            'No pude completar la comparacion. Verifica tu sesion y el backend local.';
        _isRunning = false;
      });
    }
  }

  void _toggleStore(StoreOption store) {
    setState(() {
      final stores = Set<StoreOption>.from(_selectedStores);
      if (stores.contains(store)) {
        if (stores.length == 1) return;
        stores.remove(store);
      } else {
        if (stores.length >= 3) {
          _statusMessage =
              'Puedes comparar maximo 3 tiendas a la vez. Desmarca una para elegir otra.';
          return;
        }
        stores.add(store);
      }
      _selectedStores = stores;
    });
  }

  void _changeTab(int index) {
    setState(() => _activeTab = index);
    if (index == 1) _loadCurrentTrmSuggestion();
    if (index == 2) _loadPurchases();
    if (index == 4) _loadAliExpressViabilities();
    if (index == 5) _loadInventoryItems();
    if (index == 6) {
      _loadInventoryItems();
      _loadSales();
    }
    if (index == 10) _loadInventoryItems();
    if (index == 7) _loadPrincipalUsers();
    if (index == 8) _loadCollaboratorPanel();
    if (index == 9) _loadMercadoLibreStores();
  }

  void _toggleVisualSkin() {
    setState(() {
      _visualSkin = _visualSkin == _VisualSkin.cyber
          ? _VisualSkin.neumorphic
          : _VisualSkin.cyber;
      _activeVisualSkin = _visualSkin;
    });
  }

  Future<void> _loadCurrentTrmSuggestion() async {
    if (_isLoadingCurrentTrm) return;
    _isLoadingCurrentTrm = true;
    try {
      final trm = await fetchCurrentTrm();
      if (!mounted) return;
      if (trm != null && trm > 0) {
        setState(() {
          _currentTrm = trm;
          _trmRevision++;
        });
      }
    } finally {
      _isLoadingCurrentTrm = false;
    }
  }

  Future<void> _loadPurchases() async {
    try {
      final purchases = await loadPurchases();
      if (!mounted) return;
      setState(() => _purchases = purchases);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _purchaseMessage =
            'Inicia el servicio local PriceSec para cargar la base de datos.';
      });
    }
  }

  Future<void> _loadAliExpressViabilities() async {
    try {
      final records = await loadAliExpressViabilities();
      if (!mounted) return;
      setState(() => _viabilityRecords = records);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _viabilityMessage =
            'Inicia el servicio local PriceSec para cargar la base de datos.';
      });
    }
  }

  Future<void> _loadInventoryItems() async {
    try {
      final items = await loadInventoryItems();
      final warehouses = await loadWarehouses();
      if (!mounted) return;
      setState(() {
        _inventoryItems = items;
        _warehouseOptions = warehouses;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _inventoryMessage = _cleanError(error));
    }
  }

  Future<void> _loadSales() async {
    try {
      final sales = await loadSales();
      if (!mounted) return;
      setState(() => _sales = sales);
    } catch (error) {
      if (!mounted) return;
      setState(() => _salesMessage = _cleanError(error));
    }
  }

  Future<void> _loadAccessManagement() async {
    final user = _authSession?.user;
    if (user == null) return;
    if (user.isSuperAdmin) await _loadPrincipalUsers();
    if (user.can('manage_collaborators')) await _loadCollaboratorPanel();
    if (user.can('manage_stores')) await _loadMercadoLibreStores();
  }

  Future<void> _loadPrincipalUsers() async {
    try {
      final users = await loadPrincipalUsers();
      if (!mounted) return;
      setState(() => _principalUsers = users);
    } catch (error) {
      if (!mounted) return;
      setState(() => _adminMessage = _cleanError(error));
    }
  }

  Future<void> _loadCollaboratorPanel() async {
    try {
      final permissions = await loadPermissions();
      final collaborators = await loadCollaborators();
      if (!mounted) return;
      setState(() {
        _permissions = permissions;
        _collaborators = collaborators;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _collaboratorMessage = _cleanError(error));
    }
  }

  Future<void> _loadMercadoLibreStores() async {
    try {
      final stores = await loadMercadoLibreStores();
      if (!mounted) return;
      setState(() => _mercadoLibreStores = stores);
    } catch (error) {
      if (!mounted) return;
      setState(() => _storeMessage = _cleanError(error));
    }
  }

  Future<bool> _savePurchase(PurchaseDraft draft) async {
    try {
      await savePurchase(draft, id: _editingPurchaseId);
      final purchases = await loadPurchases();
      if (!mounted) return false;
      setState(() {
        _purchases = purchases;
        _editingPurchaseId = null;
        _purchaseMessage = 'Compra guardada correctamente.';
        _activeTab = 2;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _purchaseMessage = _cleanError(error));
      return false;
    }
  }

  Future<bool> _saveAliExpressViability(AliExpressViabilityDraft draft) async {
    try {
      final viability = AliExpressViabilityCalculations.fromDraft(
        draft,
      ).viability;
      if (viability < 2) {
        throw Exception(
          'No se puede guardar: el puntaje de viabilidad es menor a 2 y no es un producto viable para compra.',
        );
      }
      await saveAliExpressViability(draft, id: _editingViabilityId);
      final records = await loadAliExpressViabilities();
      if (!mounted) return false;
      setState(() {
        _viabilityRecords = records;
        _editingViabilityId = null;
        _viabilityMessage = 'Viabilidad guardada correctamente.';
        _activeTab = 4;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _viabilityMessage = _cleanError(error));
      return false;
    }
  }

  Future<bool> _saveInventoryItem(InventoryItemDraft draft) async {
    try {
      await saveInventoryItem(draft);
      final items = await loadInventoryItems();
      if (!mounted) return false;
      setState(() {
        _inventoryItems = items;
        _inventoryMessage = 'Inventario guardado correctamente.';
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _inventoryMessage = _cleanError(error));
      return false;
    }
  }

  Future<bool> _createPrincipalUser(PrincipalUserDraft draft) async {
    try {
      final passwordError = _passwordValidationError(draft.password);
      if (passwordError != null) throw Exception(passwordError);
      await createPrincipalUser(
        username: draft.username,
        email: draft.email,
        password: draft.password,
        profileName: draft.profileName,
        phone: draft.phone,
      );
      final users = await loadPrincipalUsers();
      if (!mounted) return false;
      setState(() {
        _principalUsers = users;
        _adminMessage = 'Usuario principal creado con tenant independiente.';
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _adminMessage = _cleanError(error));
      return false;
    }
  }

  Future<void> _updatePrincipalUser(AuthUser user, String status) async {
    try {
      await updatePrincipalUser(
        id: user.id,
        profileName: user.profileName.isEmpty
            ? user.username
            : user.profileName,
        phone: user.phone,
        status: status,
      );
      await _loadPrincipalUsers();
      if (!mounted) return;
      setState(() => _adminMessage = 'Usuario actualizado.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _adminMessage = _cleanError(error));
    }
  }

  Future<bool> _createCollaborator(CollaboratorDraft draft) async {
    try {
      final passwordError = _passwordValidationError(draft.password);
      if (passwordError != null) throw Exception(passwordError);
      await createCollaborator(
        username: draft.username,
        email: draft.email,
        password: draft.password,
        profileName: draft.profileName,
        permissions: draft.permissions,
      );
      await _loadCollaboratorPanel();
      if (!mounted) return false;
      setState(() => _collaboratorMessage = 'Colaborador creado.');
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _collaboratorMessage = _cleanError(error));
      return false;
    }
  }

  Future<void> _updateCollaborator(
    AuthUser user,
    List<String> permissions,
  ) async {
    try {
      await updateCollaborator(
        id: user.id,
        profileName: user.profileName.isEmpty
            ? user.username
            : user.profileName,
        status: user.status,
        permissions: permissions,
      );
      await _loadCollaboratorPanel();
      if (!mounted) return;
      setState(() => _collaboratorMessage = 'Permisos actualizados.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _collaboratorMessage = _cleanError(error));
    }
  }

  Future<bool> _saveMercadoLibreStore(MercadoLibreStoreDraft draft) async {
    try {
      await saveMercadoLibreStore(
        name: draft.name,
        storeUser: draft.storeUser,
        storeUrl: draft.storeUrl,
      );
      await _loadMercadoLibreStores();
      if (!mounted) return false;
      setState(() => _storeMessage = 'Tienda guardada.');
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _storeMessage = _cleanError(error));
      return false;
    }
  }

  Future<bool> _saveSale(SaleDraft draft) async {
    try {
      final result = await saveSale(draft);
      final items = await loadInventoryItems();
      final sales = await loadSales();
      if (!mounted) return false;
      setState(() {
        _inventoryItems = items;
        _sales = sales;
        _salesMessage = result.lowStock
            ? 'Venta registrada. Alerta: ${result.sale.productName} queda con ${_formatInputNumber(result.sale.remainingQuantity)} unidades en ${result.sale.warehouse}.'
            : 'Venta registrada correctamente.';
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _salesMessage = _cleanError(error));
      return false;
    }
  }

  void _startEditPurchase(PurchaseRecord purchase) {
    setState(() {
      _editingPurchaseId = purchase.id;
      _purchaseMessage = 'Editando: ${purchase.productName}';
      _activeTab = 1;
    });
  }

  void _cancelEditPurchase() {
    setState(() {
      _editingPurchaseId = null;
      _purchaseMessage = null;
    });
  }

  Future<void> _deletePurchase(int id) async {
    try {
      await deletePurchase(id);
      final purchases = await loadPurchases();
      if (!mounted) return;
      setState(() {
        _purchases = purchases;
        if (_editingPurchaseId == id) _editingPurchaseId = null;
        _purchaseMessage = 'Compra eliminada.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _purchaseMessage = _cleanError(error));
    }
  }

  void _startEditViability(AliExpressViabilityRecord record) {
    setState(() {
      _editingViabilityId = record.id;
      _viabilityMessage = 'Editando: ${record.productName}';
      _activeTab = 3;
    });
  }

  void _cancelEditViability() {
    setState(() {
      _editingViabilityId = null;
      _viabilityMessage = null;
    });
  }

  Future<void> _deleteAliExpressViability(int id) async {
    try {
      await deleteAliExpressViability(id);
      final records = await loadAliExpressViabilities();
      if (!mounted) return;
      setState(() {
        _viabilityRecords = records;
        if (_editingViabilityId == id) _editingViabilityId = null;
        _viabilityMessage = 'Viabilidad eliminada.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _viabilityMessage = _cleanError(error));
    }
  }

  Future<void> _markViabilityPurchased(AliExpressViabilityRecord record) async {
    try {
      await markViabilityPurchased(record.id);
      final records = await loadAliExpressViabilities();
      final items = await loadInventoryItems();
      if (!mounted) return;
      setState(() {
        _viabilityRecords = records;
        _inventoryItems = items;
        _viabilityMessage =
            'Producto marcado como comprado y enviado al inventario en transito.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _viabilityMessage = _cleanError(error));
    }
  }

  Future<void> _receiveInventoryItem(
    InventoryItemRecord item,
    String warehouse,
  ) async {
    try {
      await receiveInventoryItem(item.id, warehouse);
      final items = await loadInventoryItems();
      if (!mounted) return;
      setState(() {
        _inventoryItems = items;
        _inventoryMessage = 'Producto recibido en $warehouse.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _inventoryMessage = _cleanError(error));
    }
  }

  Future<void> _deleteInventoryItem(int id) async {
    try {
      await deleteInventoryItem(id);
      final items = await loadInventoryItems();
      if (!mounted) return;
      setState(() {
        _inventoryItems = items;
        _inventoryMessage = 'Inventario eliminado.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _inventoryMessage = _cleanError(error));
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.onRun,
    required this.isRunning,
    required this.session,
    required this.onLogout,
    required this.visualSkin,
    required this.onToggleSkin,
    required this.onProfileUpdated,
  });

  final VoidCallback onRun;
  final bool isRunning;
  final AuthSession session;
  final VoidCallback onLogout;
  final _VisualSkin visualSkin;
  final VoidCallback onToggleSkin;
  final ValueChanged<AuthSession> onProfileUpdated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: _cyberPanelDecoration(radius: 20, glow: true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final brand = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shield_outlined,
                color: _isNeoSkin ? _NeoColors.primary : _CyberColors.primary,
                size: 34,
              ),
              const SizedBox(width: 10),
              Text(
                'PriceSec',
                style: TextStyle(
                  color: _isNeoSkin
                      ? _NeoColors.textPrimary
                      : _CyberColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _HeaderPill(
                icon: Icons.public,
                label: fixedMonitorConfig.country,
              ),
              _HeaderPill(
                icon: Icons.payments,
                label: fixedMonitorConfig.currency,
              ),
              _ProfileHeaderButton(
                user: session.user,
                onUpdated: onProfileUpdated,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isNeoSkin
                      ? _NeoColors.primary
                      : _CyberColors.textPrimary,
                  side: BorderSide(
                    color: _isNeoSkin
                        ? _NeoColors.lightEdge
                        : _CyberColors.border,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_isNeoSkin ? 12 : 8),
                  ),
                ),
                onPressed: onToggleSkin,
                icon: Icon(visualSkin.icon),
                label: Text(
                  visualSkin == _VisualSkin.neumorphic
                      ? 'Vista Cyber'
                      : 'Vista Neo',
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _isNeoSkin
                      ? _NeoColors.primary
                      : _CyberColors.primary,
                  foregroundColor: _isNeoSkin
                      ? Colors.white
                      : _CyberColors.bgDarker,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_isNeoSkin ? 12 : 8),
                  ),
                ),
                onPressed: isRunning ? null : onRun,
                icon: Icon(isRunning ? Icons.hourglass_top : Icons.play_arrow),
                label: Text(isRunning ? 'Ejecutando' : 'Ejecutar'),
              ),
              OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Salir'),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [brand, const SizedBox(height: 14), actions],
            );
          }

          return Row(
            children: [
              brand,
              const Spacer(),
              Flexible(
                child: Align(alignment: Alignment.centerRight, child: actions),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _isNeoSkin
            ? _NeoColors.bg
            : _CyberColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(_isNeoSkin ? 12 : 8),
        border: Border.all(
          color: _isNeoSkin
              ? Colors.transparent
              : _CyberColors.primary.withValues(alpha: 0.28),
        ),
        boxShadow: _isNeoSkin
            ? const [
                BoxShadow(
                  color: _NeoColors.shadowDark,
                  blurRadius: 8,
                  offset: Offset(3, 3),
                ),
                BoxShadow(
                  color: _NeoColors.shadowLight,
                  blurRadius: 8,
                  offset: Offset(-3, -3),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: _isNeoSkin ? _NeoColors.primary : _CyberColors.secondary,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: _isNeoSkin
                  ? _NeoColors.textPrimary
                  : _CyberColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderButton extends StatelessWidget {
  const _ProfileHeaderButton({required this.user, required this.onUpdated});

  final AuthUser user;
  final ValueChanged<AuthSession> onUpdated;

  @override
  Widget build(BuildContext context) {
    final displayName = user.profileName.trim().isNotEmpty
        ? user.profileName.trim()
        : user.username;
    return InkWell(
      borderRadius: BorderRadius.circular(_isNeoSkin ? 16 : 8),
      onTap: () => _showProfileDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: _isNeoSkin ? _appleCardDecoration() : _fieldDecoration(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProfileAvatar(user: user, radius: 18),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: _isNeoSkin
                        ? _NeoColors.textPrimary
                        : _CyberColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  user.role == 'super_admin' ? 'Super admin' : user.username,
                  style: TextStyle(
                    color: _isNeoSkin
                        ? _NeoColors.primary
                        : _CyberColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _ProfileDialog(user: user, onUpdated: onUpdated),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.user, this.radius = 22});

  final AuthUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bytes = _avatarBytes(user.avatarData);
    final initials =
        (user.profileName.trim().isNotEmpty
                ? user.profileName.trim()
                : user.username)
            .characters
            .take(2)
            .toString()
            .toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: (_isNeoSkin ? _NeoColors.primary : _CyberColors.primary)
          .withValues(alpha: 0.16),
      backgroundImage: bytes == null ? null : MemoryImage(bytes),
      child: bytes != null
          ? null
          : Text(
              initials.isEmpty ? 'U' : initials,
              style: TextStyle(
                color: _isNeoSkin ? _NeoColors.primary : _CyberColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.user, required this.onUpdated});

  final AuthUser user;
  final ValueChanged<AuthSession> onUpdated;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _passwordController;
  late String _avatarData;
  bool _saving = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.user.profileName.trim().isEmpty
          ? widget.user.username
          : widget.user.profileName,
    );
    _passwordController = TextEditingController();
    _avatarData = widget.user.avatarData;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dialogUser = AuthUser(
      id: widget.user.id,
      username: widget.user.username,
      email: widget.user.email,
      role: widget.user.role,
      profileName: _nameController.text.trim(),
      avatarData: _avatarData,
    );
    return AlertDialog(
      backgroundColor: _isNeoSkin ? const Color(0xfff7f9fc) : _CyberColors.card,
      title: Text(
        'Actualizar perfil',
        style: TextStyle(
          color: _isNeoSkin ? _NeoColors.textPrimary : _CyberColors.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProfileAvatar(user: dialogUser, radius: 42),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickAvatar,
              icon: const Icon(Icons.photo_camera),
              label: const Text('Cargar foto'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: _inputDecoration(
                label: 'Nombre visible',
                hint: 'Nombre de perfil',
                icon: Icons.badge,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: _inputDecoration(
                label: 'Nueva contrasena',
                hint: 'Opcional: letras, numeros y caracter especial',
                icon: Icons.lock_reset,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'La contrasena debe tener minimo 8 caracteres e incluir letras, numeros y un caracter especial.',
              style: TextStyle(
                color: _isNeoSkin
                    ? _NeoColors.textSecondary
                    : _CyberColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _CyberColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: Icon(_saving ? Icons.hourglass_top : Icons.save),
          label: Text(_saving ? 'Guardando' : 'Guardar'),
        ),
      ],
    );
  }

  Future<void> _pickAvatar() async {
    final data = await pickProfileImageDataUrl();
    if (!mounted || data == null || data.isEmpty) return;
    setState(() => _avatarData = data);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    final passwordError = _passwordValidationError(password, allowEmpty: true);
    if (name.length < 2 || passwordError != null) {
      setState(() {
        _message = name.length < 2
            ? 'Escribe un nombre de perfil valido.'
            : passwordError;
      });
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final session = await updateAuthProfile(
        profileName: name,
        password: password,
        avatarData: _avatarData,
      );
      if (!mounted) return;
      widget.onUpdated(session);
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _message = error.toString().replaceFirst(
          RegExp(r'^Exception:\s*'),
          '',
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

enum _AuthMode { login, signup, resetRequest, resetConfirm }

class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.onAuthenticated});

  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  bool _hasUsers = true;
  bool _isBusy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadAuthStatus();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _CyberBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _AuthRing(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_needsUsername)
                        _authField(
                          controller: _usernameController,
                          hint: 'Username',
                          icon: Icons.person,
                        ),
                      if (_needsEmail)
                        _authField(
                          controller: _emailController,
                          hint: 'Email',
                          icon: Icons.email,
                        ),
                      if (_mode == _AuthMode.resetConfirm)
                        _authField(
                          controller: _codeController,
                          hint: 'Security code',
                          icon: Icons.pin,
                        ),
                      if (_needsPassword)
                        _authField(
                          controller: _passwordController,
                          hint: 'Password',
                          icon: Icons.lock,
                          obscure: true,
                        ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: _CyberColors.bgDarker,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                            ),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: _isBusy ? null : _submit,
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xffff357a), Color(0xfffff172)],
                              ),
                              borderRadius: BorderRadius.circular(40),
                            ),
                            child: Center(
                              child: Text(
                                _isBusy ? 'Procesando...' : _buttonLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _CyberColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _authLinks(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _title {
    return switch (_mode) {
      _AuthMode.login => 'Login',
      _AuthMode.signup => _hasUsers ? 'Signup' : 'Super Admin',
      _AuthMode.resetRequest => 'Reset',
      _AuthMode.resetConfirm => 'Security Code',
    };
  }

  String get _buttonLabel {
    return switch (_mode) {
      _AuthMode.login => 'Sign in',
      _AuthMode.signup => _hasUsers ? 'Create user' : 'Create super admin',
      _AuthMode.resetRequest => 'Send code',
      _AuthMode.resetConfirm => 'Reset password',
    };
  }

  bool get _needsUsername =>
      _mode == _AuthMode.login || _mode == _AuthMode.signup;
  bool get _needsEmail =>
      _mode == _AuthMode.signup ||
      _mode == _AuthMode.resetRequest ||
      _mode == _AuthMode.resetConfirm;
  bool get _needsPassword =>
      _mode == _AuthMode.login ||
      _mode == _AuthMode.signup ||
      _mode == _AuthMode.resetConfirm;

  Widget _authField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white70),
          filled: false,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(40),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(40),
            borderSide: const BorderSide(color: Colors.white, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(40),
            borderSide: const BorderSide(color: Color(0xff00ff0a), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _authLinks() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 4,
      children: [
        TextButton(
          onPressed: _mode == _AuthMode.resetConfirm
              ? () => _setMode(_AuthMode.resetRequest)
              : () => _setMode(_AuthMode.resetRequest),
          child: const Text('Forget Password'),
        ),
        TextButton(
          onPressed: _mode == _AuthMode.signup
              ? () => _setMode(_AuthMode.login)
              : () => _setMode(_AuthMode.signup),
          child: Text(_mode == _AuthMode.signup ? 'Login' : 'Signup'),
        ),
      ],
    );
  }

  Future<void> _loadAuthStatus() async {
    try {
      final hasUsers = await hasRegisteredUsers();
      if (!mounted) return;
      setState(() {
        _hasUsers = hasUsers;
        if (!hasUsers) _mode = _AuthMode.signup;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message = 'Inicia el backend local PriceSec para autenticarte.';
      });
    }
  }

  void _setMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _message = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      switch (_mode) {
        case _AuthMode.login:
          final session = await loginAuthUser(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );
          widget.onAuthenticated(session);
        case _AuthMode.signup:
          final passwordError = _passwordValidationError(
            _passwordController.text,
          );
          if (passwordError != null) throw Exception(passwordError);
          final session = await registerAuthUser(
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          widget.onAuthenticated(session);
        case _AuthMode.resetRequest:
          await requestPasswordResetCode(email: _emailController.text.trim());
          setState(() {
            _mode = _AuthMode.resetConfirm;
            _message =
                'Codigo enviado al correo registrado. En local tambien queda en auth_email_outbox.';
          });
        case _AuthMode.resetConfirm:
          final passwordError = _passwordValidationError(
            _passwordController.text,
          );
          if (passwordError != null) throw Exception(passwordError);
          await confirmPasswordResetCode(
            email: _emailController.text.trim(),
            code: _codeController.text.trim(),
            password: _passwordController.text,
          );
          setState(() {
            _mode = _AuthMode.login;
            _message = 'Contraseña actualizada. Ya puedes iniciar sesion.';
          });
      }
    } catch (error) {
      setState(() => _message = _cleanAuthError(error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _cleanAuthError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }
}

class _AuthRing extends StatefulWidget {
  const _AuthRing({required this.child});

  final Widget child;

  @override
  State<_AuthRing> createState() => _AuthRingState();
}

class _AuthRingState extends State<_AuthRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 520,
      height: 520,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: const Size.square(500),
                painter: _AuthRingPainter(_controller.value),
              );
            },
          ),
          SizedBox(width: 310, child: widget.child),
        ],
      ),
    );
  }
}

class _AuthRingPainter extends CustomPainter {
  const _AuthRingPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final colors = [
      const Color(0xff00ff0a),
      const Color(0xffff0057),
      const Color(0xfffffd44),
    ];
    final rotations = [t * math.pi * 2, t * math.pi * 3, -t * math.pi * 1.4];
    for (var index = 0; index < colors.length; index++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotations[index]);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: 430.0 - index * 18,
        height: 500.0 - index * 22,
      );
      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + index;
      final glow = Paint()
        ..color = colors[index].withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
      final radius = switch (index) {
        0 => const BorderRadius.only(
          topLeft: Radius.circular(190),
          topRight: Radius.circular(310),
          bottomRight: Radius.circular(170),
          bottomLeft: Radius.circular(250),
        ),
        1 => const BorderRadius.only(
          topLeft: Radius.circular(240),
          topRight: Radius.circular(180),
          bottomRight: Radius.circular(290),
          bottomLeft: Radius.circular(190),
        ),
        _ => const BorderRadius.only(
          topLeft: Radius.circular(210),
          topRight: Radius.circular(270),
          bottomRight: Radius.circular(230),
          bottomLeft: Radius.circular(175),
        ),
      };
      final rrect = radius.toRRect(rect);
      canvas.drawRRect(rrect, glow);
      canvas.drawRRect(rrect, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _AuthRingPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

class _ModuleOption {
  const _ModuleOption(this.index, this.icon, this.label, this.description);

  final int index;
  final IconData icon;
  final String label;
  final String description;
}

class _ModuleCategory {
  const _ModuleCategory(this.title, this.icon, this.description, this.indices);

  final String title;
  final IconData icon;
  final String description;
  final List<int> indices;
}

const _moduleOptions = [
  _ModuleOption(
    0,
    Icons.compare_arrows,
    'Comparador',
    'Busca mejores precios entre tiendas.',
  ),
  _ModuleOption(
    1,
    Icons.inventory_2,
    'Registrar compra',
    'Registra compras e importaciones.',
  ),
  _ModuleOption(
    2,
    Icons.list_alt,
    'Compras guardadas',
    'Consulta y edita compras registradas.',
  ),
  _ModuleOption(
    3,
    Icons.fact_check,
    'Viabilidad AliExpress',
    'Calcula si un producto es viable.',
  ),
  _ModuleOption(
    4,
    Icons.table_rows,
    'Viabilidades guardadas',
    'Revisa estudios guardados.',
  ),
  _ModuleOption(
    5,
    Icons.dashboard_customize,
    'Sistema de Gestion',
    'Ingresa productos y movimientos.',
  ),
  _ModuleOption(
    6,
    Icons.point_of_sale,
    'Registrar ventas',
    'Registra ventas y descuenta stock.',
  ),
  _ModuleOption(
    10,
    Icons.inventory,
    'Inventario general',
    'Consulta inventario agrupado.',
  ),
  _ModuleOption(
    7,
    Icons.admin_panel_settings,
    'Usuarios principales',
    'Administra usuarios principales.',
  ),
  _ModuleOption(
    8,
    Icons.group_add,
    'Colaboradores',
    'Gestiona permisos y accesos.',
  ),
  _ModuleOption(
    9,
    Icons.storefront,
    'Tiendas Mercado Libre',
    'Conecta y consulta tiendas.',
  ),
];

const _moduleCategories = [
  _ModuleCategory(
    'Inicio',
    Icons.home,
    'Accede al modulo principal del comparador.',
    [0],
  ),
  _ModuleCategory(
    'Inventario',
    Icons.inventory_2,
    'Gestiona y consulta tu inventario de productos.',
    [10, 5],
  ),
  _ModuleCategory(
    'Ventas',
    Icons.shopping_cart,
    'Registra y administra tus ventas realizadas.',
    [6],
  ),
  _ModuleCategory(
    'Compras',
    Icons.business_center,
    'Administra tus compras, viabilidades y proveedores.',
    [1, 2, 3, 4],
  ),
  _ModuleCategory(
    'Integraciones',
    Icons.link,
    'Conecta tu tienda con plataformas externas.',
    [9],
  ),
  _ModuleCategory(
    'Configuracion',
    Icons.settings,
    'Administra usuarios y permisos del sistema.',
    [7, 8],
  ),
];

class _ModuleSelector extends StatefulWidget {
  const _ModuleSelector({
    required this.activeIndex,
    required this.options,
    required this.onChanged,
  });

  final int activeIndex;
  final List<_ModuleOption> options;
  final ValueChanged<int> onChanged;

  @override
  State<_ModuleSelector> createState() => _ModuleSelectorState();
}

class _ModuleSelectorState extends State<_ModuleSelector> {
  final _searchController = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.options.firstWhere(
      (option) => option.index == widget.activeIndex,
      orElse: () => widget.options.first,
    );
    final query = _searchController.text;
    final filtered = [
      for (final option in widget.options)
        if (_smartMatches(query, [option.label])) option,
    ];
    final textPrimary = _isNeoSkin
        ? _NeoColors.textPrimary
        : _CyberColors.textPrimary;
    final textSecondary = _isNeoSkin
        ? _NeoColors.textSecondary
        : _CyberColors.textSecondary;
    final accent = _isNeoSkin ? _NeoColors.primary : _CyberColors.primary;

    final showDashboard =
        _open || widget.activeIndex == 5 || query.trim().isNotEmpty;
    return Container(
      padding: EdgeInsets.all(_isNeoSkin ? 22 : 20),
      decoration: _isNeoSkin
          ? BoxDecoration(
              color: const Color(0xfffbfcff),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xffe2e8f0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 16),
                ),
              ],
            )
          : _cyberPanelDecoration(radius: 14, glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _isNeoSkin ? 54 : 52,
                height: _isNeoSkin ? 54 : 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(_isNeoSkin ? 16 : 14),
                  boxShadow: _isNeoSkin
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.12),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ]
                      : null,
                ),
                child: Icon(Icons.store_mall_directory, color: accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _open = !_open),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gestion de inventario',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: _isNeoSkin ? 20 : 19,
                        ),
                      ),
                      Text(
                        'Activo: ${active.label}',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: math.min(420, MediaQuery.sizeOf(context).width * 0.48),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() => _open = true),
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _inputDecoration(
                    label: 'Buscar modulo',
                    hint: 'Compras, ventas, inventario...',
                    icon: Icons.search,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: _open ? 'Cerrar menu' : 'Abrir menu',
                    onPressed: () => setState(() => _open = !_open),
                    icon: Icon(
                      showDashboard
                          ? Icons.notifications_none
                          : Icons.expand_more,
                    ),
                    color: textPrimary,
                  ),
                  if (showDashboard)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 0,
            runSpacing: 10,
            children: [
              for (final option in _primaryOptions(widget.options))
                Padding(
                  padding: const EdgeInsets.only(right: 0),
                  child: SizedBox(
                    width: _isNeoSkin ? 206 : 190,
                    child: _ModuleOptionButton(
                      icon: option.icon,
                      label: option.label,
                      selected: widget.activeIndex == option.index,
                      onTap: () {
                        widget.onChanged(option.index);
                        if (option.index == 5) {
                          setState(() => _open = true);
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: !showDashboard
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: query.trim().isNotEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: _isNeoSkin
                                ? _appleCardDecoration()
                                : _fieldDecoration(),
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final option in filtered)
                                  _ModuleOptionButton(
                                    icon: option.icon,
                                    label: option.label,
                                    selected:
                                        widget.activeIndex == option.index,
                                    onTap: () {
                                      widget.onChanged(option.index);
                                      setState(() => _open = false);
                                    },
                                  ),
                                if (filtered.isEmpty)
                                  Text(
                                    'No encontre modulos relacionados.',
                                    style: _supportTextStyle(),
                                  ),
                              ],
                            ),
                          )
                        : _MegaMenuGrid(
                            options: widget.options,
                            activeIndex: widget.activeIndex,
                            onChanged: (index) {
                              widget.onChanged(index);
                              setState(() => _open = index == 5);
                            },
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            accent: accent,
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  List<_ModuleOption> _primaryOptions(List<_ModuleOption> options) {
    const primary = [0, 10, 5, 6, 1, 2];
    return [
      for (final index in primary)
        for (final option in options)
          if (option.index == index) option,
    ];
  }
}

class _MegaMenuGrid extends StatelessWidget {
  const _MegaMenuGrid({
    required this.options,
    required this.activeIndex,
    required this.onChanged,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  final List<_ModuleOption> options;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final visibleCategories = [
      for (final category in _moduleCategories)
        if (_categoryOptions(category).isNotEmpty) category,
    ];
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _isNeoSkin
          ? BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xffe2e8f0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            )
          : BoxDecoration(
              color: _CyberColors.bgDarker.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _CyberColors.border.withValues(alpha: 0.75),
              ),
            ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 720 ? 2 : 3;
          return GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: constraints.maxWidth < 720 ? 1.25 : 1.46,
            children: [
              for (final category in visibleCategories)
                _MegaMenuCategory(
                  category: category,
                  options: options,
                  activeIndex: activeIndex,
                  onChanged: onChanged,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  accent: accent,
                ),
            ],
          );
        },
      ),
    );
  }

  List<_ModuleOption> _categoryOptions(_ModuleCategory category) {
    return [
      for (final index in category.indices)
        for (final option in options)
          if (option.index == index) option,
    ];
  }
}

class _MegaMenuCategory extends StatelessWidget {
  const _MegaMenuCategory({
    required this.category,
    required this.options,
    required this.activeIndex,
    required this.onChanged,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  final _ModuleCategory category;
  final List<_ModuleOption> options;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final categoryOptions = [
      for (final index in category.indices)
        for (final option in options)
          if (option.index == index) option,
    ];
    if (categoryOptions.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _isNeoSkin
            ? Colors.white
            : _CyberColors.bgDarker.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(_isNeoSkin ? 18 : 12),
        border: Border.all(
          color: _isNeoSkin
              ? const Color(0xffe2e8f0)
              : _CyberColors.border.withValues(alpha: 0.8),
        ),
        boxShadow: _isNeoSkin
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: _isNeoSkin ? 0.1 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(category.icon, color: accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(
            color: _isNeoSkin
                ? const Color(0xffe2e8f0)
                : _CyberColors.border.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final option in categoryOptions)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onChanged(option.index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: activeIndex == option.index
                            ? accent.withValues(alpha: 0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            option.icon,
                            size: 18,
                            color: activeIndex == option.index
                                ? accent
                                : textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option.label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: activeIndex == option.index
                                    ? accent
                                    : textPrimary,
                                fontWeight: activeIndex == option.index
                                    ? FontWeight.w900
                                    : FontWeight.w800,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: activeIndex == option.index
                                ? accent
                                : textSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleOptionButton extends StatelessWidget {
  const _ModuleOptionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected
        ? (_isNeoSkin ? _NeoColors.primary : _CyberColors.primary)
        : (_isNeoSkin ? const Color(0xffedf1f7) : Colors.transparent);
    final fg = selected
        ? (_isNeoSkin ? Colors.white : _CyberColors.bgDarker)
        : (_isNeoSkin ? _NeoColors.textPrimary : _CyberColors.textPrimary);
    return DecoratedBox(
      decoration: _isNeoSkin && !selected
          ? const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              boxShadow: [
                BoxShadow(
                  color: _NeoColors.shadowDark,
                  blurRadius: 10,
                  offset: Offset(4, 4),
                ),
                BoxShadow(
                  color: _NeoColors.shadowLight,
                  blurRadius: 10,
                  offset: Offset(-4, -4),
                ),
              ],
            )
          : const BoxDecoration(),
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          side: BorderSide(
            color: selected
                ? (_isNeoSkin ? _NeoColors.primary : _CyberColors.primary)
                : (_isNeoSkin ? _NeoColors.lightEdge : _CyberColors.border),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_isNeoSkin ? 12 : 8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _OwnershipFooter extends StatelessWidget {
  const _OwnershipFooter();

  @override
  Widget build(BuildContext context) {
    final accent = _isNeoSkin ? _NeoColors.primary : _CyberColors.primary;
    final textColor = _isNeoSkin
        ? _NeoColors.textSecondary
        : _CyberColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _isNeoSkin
            ? Colors.white.withValues(alpha: 0.68)
            : _CyberColors.bgDarker.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(_isNeoSkin ? 18 : 12),
        border: Border.all(
          color: _isNeoSkin
              ? const Color(0xffe2e8f0)
              : _CyberColors.border.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified_user_outlined, color: accent, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Este programa es propiedad de JULIAN C. PAREDES (SHAWNDARCK)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PrincipalUserDraft {
  const PrincipalUserDraft({
    required this.username,
    required this.email,
    required this.password,
    required this.profileName,
    required this.phone,
  });

  final String username;
  final String email;
  final String password;
  final String profileName;
  final String phone;
}

class CollaboratorDraft {
  const CollaboratorDraft({
    required this.username,
    required this.email,
    required this.password,
    required this.profileName,
    required this.permissions,
  });

  final String username;
  final String email;
  final String password;
  final String profileName;
  final List<String> permissions;
}

class MercadoLibreStoreDraft {
  const MercadoLibreStoreDraft({
    required this.name,
    required this.storeUser,
    required this.storeUrl,
  });

  final String name;
  final String storeUser;
  final String storeUrl;
}

class _PrincipalUsersSection extends StatefulWidget {
  const _PrincipalUsersSection({
    required this.users,
    required this.message,
    required this.onCreate,
    required this.onUpdate,
  });

  final List<AuthUser> users;
  final String? message;
  final Future<bool> Function(PrincipalUserDraft draft) onCreate;
  final Future<void> Function(AuthUser user, String status) onUpdate;

  @override
  State<_PrincipalUsersSection> createState() => _PrincipalUsersSectionState();
}

class _PrincipalUsersSectionState extends State<_PrincipalUsersSection> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _profileName = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _profileName.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cyberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            number: 'SA',
            title: 'Administracion de usuarios principales',
          ),
          const SizedBox(height: 16),
          _AdminTextField(
            controller: _username,
            label: 'Usuario',
            icon: Icons.person,
          ),
          const SizedBox(height: 12),
          _AdminTextField(
            controller: _email,
            label: 'Correo',
            icon: Icons.email,
          ),
          const SizedBox(height: 12),
          _AdminTextField(
            controller: _password,
            label: 'Contrasena inicial',
            icon: Icons.lock,
            obscure: true,
          ),
          const SizedBox(height: 12),
          _AdminTextField(
            controller: _profileName,
            label: 'Nombre de perfil o cliente',
            icon: Icons.badge,
          ),
          const SizedBox(height: 12),
          _AdminTextField(
            controller: _phone,
            label: 'Telefono',
            icon: Icons.phone,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final saved = await widget.onCreate(
                PrincipalUserDraft(
                  username: _username.text.trim(),
                  email: _email.text.trim(),
                  password: _password.text,
                  profileName: _profileName.text.trim(),
                  phone: _phone.text.trim(),
                ),
              );
              if (!saved) return;
              _username.clear();
              _email.clear();
              _password.clear();
              _profileName.clear();
              _phone.clear();
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Crear usuario principal'),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 12),
            _PurchaseMessage(message: widget.message!),
          ],
          const SizedBox(height: 20),
          for (final user in widget.users)
            _UserAccessTile(user: user, onUpdate: widget.onUpdate),
        ],
      ),
    );
  }
}

class _CollaboratorsSection extends StatefulWidget {
  const _CollaboratorsSection({
    required this.collaborators,
    required this.permissions,
    required this.message,
    required this.onCreate,
    required this.onUpdate,
  });

  final List<AuthUser> collaborators;
  final List<PermissionInfo> permissions;
  final String? message;
  final Future<bool> Function(CollaboratorDraft draft) onCreate;
  final Future<void> Function(AuthUser user, List<String> permissions) onUpdate;

  @override
  State<_CollaboratorsSection> createState() => _CollaboratorsSectionState();
}

class _CollaboratorsSectionState extends State<_CollaboratorsSection> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _profileName = TextEditingController();
  final Set<String> _selectedPermissions = {};

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _profileName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cyberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(number: 'CO', title: 'Colaboradores y permisos'),
          const SizedBox(height: 16),
          _AdminTextField(
            controller: _username,
            label: 'Usuario colaborador',
            icon: Icons.person,
          ),
          const SizedBox(height: 12),
          _AdminTextField(
            controller: _email,
            label: 'Correo',
            icon: Icons.email,
          ),
          const SizedBox(height: 12),
          _AdminTextField(
            controller: _password,
            label: 'Contrasena inicial',
            icon: Icons.lock,
            obscure: true,
          ),
          const SizedBox(height: 12),
          _AdminTextField(
            controller: _profileName,
            label: 'Nombre de perfil',
            icon: Icons.badge,
          ),
          const SizedBox(height: 14),
          _PermissionWrap(
            permissions: widget.permissions,
            selected: _selectedPermissions,
            onChanged: (key, value) {
              setState(() {
                if (value) {
                  _selectedPermissions.add(key);
                } else {
                  _selectedPermissions.remove(key);
                }
              });
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final saved = await widget.onCreate(
                CollaboratorDraft(
                  username: _username.text.trim(),
                  email: _email.text.trim(),
                  password: _password.text,
                  profileName: _profileName.text.trim(),
                  permissions: _selectedPermissions.toList(),
                ),
              );
              if (!saved) return;
              _username.clear();
              _email.clear();
              _password.clear();
              _profileName.clear();
              setState(_selectedPermissions.clear);
            },
            icon: const Icon(Icons.group_add),
            label: const Text('Crear colaborador'),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 12),
            _PurchaseMessage(message: widget.message!),
          ],
          const SizedBox(height: 20),
          for (final collaborator in widget.collaborators)
            _CollaboratorTile(
              user: collaborator,
              permissions: widget.permissions,
              onUpdate: widget.onUpdate,
            ),
        ],
      ),
    );
  }
}

class _MercadoLibreStoresSection extends StatefulWidget {
  const _MercadoLibreStoresSection({
    required this.stores,
    required this.message,
    required this.onSave,
  });

  final List<MercadoLibreStore> stores;
  final String? message;
  final Future<bool> Function(MercadoLibreStoreDraft draft) onSave;

  @override
  State<_MercadoLibreStoresSection> createState() =>
      _MercadoLibreStoresSectionState();
}

class _MercadoLibreStoresSectionState
    extends State<_MercadoLibreStoresSection> {
  final _name = TextEditingController();
  final _storeUser = TextEditingController();
  final _storeUrl = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _storeUser.dispose();
    _storeUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _cyberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(number: 'ML', title: 'Tiendas Mercado Libre'),
          const SizedBox(height: 16),
          _AdminTextField(
            controller: _name,
            label: 'Nombre de tienda',
            icon: Icons.storefront,
          ),
          const SizedBox(height: 12),
          _AdminTextField(
            controller: _storeUser,
            label: 'Usuario o alias en Mercado Libre',
            icon: Icons.alternate_email,
          ),
          const SizedBox(height: 12),
          _AdminTextField(
            controller: _storeUrl,
            label: 'URL de la tienda',
            icon: Icons.link,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final saved = await widget.onSave(
                MercadoLibreStoreDraft(
                  name: _name.text.trim(),
                  storeUser: _storeUser.text.trim(),
                  storeUrl: _storeUrl.text.trim(),
                ),
              );
              if (!saved) return;
              _name.clear();
              _storeUser.clear();
              _storeUrl.clear();
            },
            icon: const Icon(Icons.add_business),
            label: const Text('Guardar tienda'),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 12),
            _PurchaseMessage(message: widget.message!),
          ],
          const SizedBox(height: 20),
          for (final store in widget.stores)
            _SimpleInfoTile(
              icon: Icons.store,
              title: store.name,
              subtitle:
                  '${store.storeUser} - ${store.status} - ${store.storeUrl}',
            ),
        ],
      ),
    );
  }
}

class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(
        color: _isNeoSkin ? _NeoColors.textPrimary : _CyberColors.textPrimary,
      ),
      decoration: _inputDecoration(label: label, hint: label, icon: icon),
    );
  }
}

class _PermissionWrap extends StatelessWidget {
  const _PermissionWrap({
    required this.permissions,
    required this.selected,
    required this.onChanged,
  });

  final List<PermissionInfo> permissions;
  final Set<String> selected;
  final void Function(String key, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final permission in permissions)
          FilterChip(
            selected: selected.contains(permission.key),
            label: Text(permission.label),
            showCheckmark: true,
            selectedColor:
                (_isNeoSkin ? _NeoColors.primary : _CyberColors.primary)
                    .withValues(alpha: _isNeoSkin ? 0.18 : 1),
            backgroundColor: _isNeoSkin
                ? const Color(0xffedf1f7)
                : _CyberColors.bgDarker,
            side: BorderSide(
              color: selected.contains(permission.key)
                  ? (_isNeoSkin ? _NeoColors.primary : _CyberColors.primary)
                  : (_isNeoSkin ? _NeoColors.shadowDark : _CyberColors.border),
              width: _isNeoSkin ? 1.4 : 1,
            ),
            labelStyle: TextStyle(
              color: _isNeoSkin
                  ? _NeoColors.textPrimary
                  : _CyberColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
            onSelected: (value) => onChanged(permission.key, value),
          ),
      ],
    );
  }
}

class _UserAccessTile extends StatelessWidget {
  const _UserAccessTile({required this.user, required this.onUpdate});

  final AuthUser user;
  final Future<void> Function(AuthUser user, String status) onUpdate;

  @override
  Widget build(BuildContext context) {
    final nextStatus = user.status == 'active' ? 'inactive' : 'active';
    return _SimpleInfoTile(
      icon: Icons.account_circle,
      title: '${user.username} - ${user.status}',
      subtitle: '${user.email} - tenant ${user.tenantId ?? '-'}',
      trailing: OutlinedButton(
        onPressed: () => onUpdate(user, nextStatus),
        child: Text(user.status == 'active' ? 'Inactivar' : 'Activar'),
      ),
    );
  }
}

class _CollaboratorTile extends StatefulWidget {
  const _CollaboratorTile({
    required this.user,
    required this.permissions,
    required this.onUpdate,
  });

  final AuthUser user;
  final List<PermissionInfo> permissions;
  final Future<void> Function(AuthUser user, List<String> permissions) onUpdate;

  @override
  State<_CollaboratorTile> createState() => _CollaboratorTileState();
}

class _CollaboratorTileState extends State<_CollaboratorTile> {
  late final Set<String> _selected = {...widget.user.permissions};

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _fieldDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.user.username} - ${widget.user.status}',
            style: TextStyle(
              color: _isNeoSkin
                  ? _NeoColors.textPrimary
                  : _CyberColors.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.user.email,
            style: TextStyle(
              color: _isNeoSkin
                  ? _NeoColors.textSecondary
                  : _CyberColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _PermissionWrap(
            permissions: widget.permissions,
            selected: _selected,
            onChanged: (key, value) {
              setState(() {
                if (value) {
                  _selected.add(key);
                } else {
                  _selected.remove(key);
                }
              });
            },
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => widget.onUpdate(widget.user, _selected.toList()),
            icon: const Icon(Icons.save),
            label: const Text('Guardar permisos'),
          ),
        ],
      ),
    );
  }
}

class _SimpleInfoTile extends StatelessWidget {
  const _SimpleInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _fieldDecoration(),
      child: Row(
        children: [
          Icon(
            icon,
            color: _isNeoSkin ? _NeoColors.primary : _CyberColors.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _isNeoSkin
                        ? _NeoColors.textPrimary
                        : _CyberColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _isNeoSkin
                        ? _NeoColors.textSecondary
                        : _CyberColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.onRun,
    required this.isRunning,
  });

  final TextEditingController controller;
  final VoidCallback onRun;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return _isNeoSkin
        ? _NeoSearchPanel(
            controller: controller,
            onRun: onRun,
            isRunning: isRunning,
          )
        : _CyberSearchPanel(
            controller: controller,
            onRun: onRun,
            isRunning: isRunning,
          );
  }
}

class _NeoSearchPanel extends StatelessWidget {
  const _NeoSearchPanel({
    required this.controller,
    required this.onRun,
    required this.isRunning,
  });

  final TextEditingController controller;
  final VoidCallback onRun;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xffe2e8f0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 34,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff7c3aed), Color(0xff38bdf8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: _NeoColors.primary.withValues(alpha: 0.2),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.sell_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                'Comparador de precios',
                style: _strongTextStyle(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 42),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Encuentra el mejor precio',
                      style: TextStyle(
                        color: _NeoColors.textPrimary,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Busca, filtra y compara productos entre las mejores tiendas online.',
                      style: _supportTextStyle(fontSize: 18, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              const _StoreVsGraphic(compact: false),
            ],
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _appleCardDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onSubmitted: (_) => onRun(),
                    style: _inputTextStyle(),
                    decoration: _inputDecoration(
                      label: 'Que producto estas buscando?',
                      hint: 'Ej: audifonos bluetooth, teclado mecanico...',
                      icon: Icons.search,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 58,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _NeoColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: isRunning ? null : onRun,
                    icon: Icon(isRunning ? Icons.sync : Icons.search),
                    label: Text(
                      isRunning ? 'Comparando' : 'Comparar ahora',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 34),
          const Row(
            children: [
              Expanded(
                child: _ComparatorBenefit(
                  icon: Icons.sell_outlined,
                  title: 'Compara precios',
                  body: 'Encuentra la mejor opcion entre diferentes tiendas.',
                ),
              ),
              Expanded(
                child: _ComparatorBenefit(
                  icon: Icons.verified_user_outlined,
                  title: 'Compra seguro',
                  body: 'Verifica reputacion y calificaciones de tiendas.',
                ),
              ),
              Expanded(
                child: _ComparatorBenefit(
                  icon: Icons.local_shipping_outlined,
                  title: 'Envios confiables',
                  body: 'Filtra por envio incluido y tiempos de entrega.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text('Busquedas populares', style: _strongTextStyle(fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (final label in const [
                'audifonos',
                'reloj inteligente',
                'mochila',
                'aspiradora',
                'teclado mecanico',
              ])
                ActionChip(
                  avatar: const Icon(Icons.search, size: 16),
                  label: Text(label),
                  onPressed: () {
                    controller.text = label;
                    onRun();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CyberSearchPanel extends StatelessWidget {
  const _CyberSearchPanel({
    required this.controller,
    required this.onRun,
    required this.isRunning,
  });

  final TextEditingController controller;
  final VoidCallback onRun;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _cyberPanelDecoration(glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CyberBadge(label: 'COMPARADOR DE PRECIO'),
          const SizedBox(height: 34),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Encuentra el\nmejor precio',
                  style: const TextStyle(
                    color: _CyberColors.textPrimary,
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    height: 1.06,
                  ),
                ),
              ),
              const _StoreVsGraphic(compact: false),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Busca el producto, aplica tus filtros y compara por precio total, reputacion y envio.',
            style: _supportTextStyle(fontSize: 16, height: 1.65),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: controller,
            onSubmitted: (_) => onRun(),
            style: _inputTextStyle(),
            decoration: _inputDecoration(
              label: 'Nombre del producto',
              hint: 'Ej: audifonos bluetooth, teclado mecanico...',
              icon: Icons.search,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _CyberColors.primary,
                foregroundColor: _CyberColors.bgDarker,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isRunning ? null : onRun,
              icon: Icon(isRunning ? Icons.sync : Icons.compare_arrows),
              label: Text(isRunning ? 'Analizando ofertas' : 'Comparar ahora'),
            ),
          ),
          const SizedBox(height: 34),
          Divider(color: _CyberColors.border.withValues(alpha: 0.8)),
          const SizedBox(height: 28),
          const Row(
            children: [
              Expanded(
                child: _ComparatorBenefit(
                  icon: Icons.sell_outlined,
                  title: 'Compara precios',
                  body: 'Encuentra la mejor opcion entre varias plataformas.',
                ),
              ),
              Expanded(
                child: _ComparatorBenefit(
                  icon: Icons.verified_user_outlined,
                  title: 'Compra seguro',
                  body: 'Verifica reputacion y calificaciones de tiendas.',
                ),
              ),
              Expanded(
                child: _ComparatorBenefit(
                  icon: Icons.local_shipping_outlined,
                  title: 'Envios confiables',
                  body: 'Filtra por envio incluido y tiempos de entrega.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoreVsGraphic extends StatelessWidget {
  const _StoreVsGraphic({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 150.0 : 230.0;
    return SizedBox(
      width: size,
      height: size * 0.78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _OrbitPainter(
                color: _isNeoSkin
                    ? _NeoColors.primary.withValues(alpha: 0.12)
                    : _CyberColors.primary.withValues(alpha: 0.24),
              ),
            ),
          ),
          Positioned(
            left: size * 0.18,
            top: size * 0.18,
            child: Transform.rotate(
              angle: -0.18,
              child: const _LargeStoreLogo(store: StoreOption.aliexpress),
            ),
          ),
          Positioned(
            right: size * 0.12,
            top: size * 0.26,
            child: Transform.rotate(
              angle: 0.2,
              child: const _LargeStoreLogo(store: StoreOption.temu),
            ),
          ),
          Container(
            width: compact ? 46 : 58,
            height: compact ? 46 : 58,
            decoration: BoxDecoration(
              color: _isNeoSkin ? Colors.white : _CyberColors.bgDark,
              shape: BoxShape.circle,
              border: Border.all(
                color: _isNeoSkin
                    ? _NeoColors.primary.withValues(alpha: 0.22)
                    : _CyberColors.primary.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (_isNeoSkin ? _NeoColors.primary : _CyberColors.primary)
                          .withValues(alpha: 0.18),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Center(
              child: Text(
                'VS',
                style: TextStyle(
                  color: _isNeoSkin ? _NeoColors.primary : _CyberColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 16 : 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeStoreLogo extends StatelessWidget {
  const _LargeStoreLogo({required this.store});

  final StoreOption store;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: _storeLogoBackground(store),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _storeAccentColor(store).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _StoreLogoPainter(store: store, selected: true),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: size.width * (0.52 + i * 0.14),
          height: size.height * (0.44 + i * 0.12),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ComparatorBenefit extends StatelessWidget {
  const _ComparatorBenefit({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final accent = _isNeoSkin ? _NeoColors.primary : _CyberColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: _isNeoSkin ? 0.1 : 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.45)),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: _strongTextStyle()),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: _supportTextStyle(fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _CriteriaPanel extends StatelessWidget {
  const _CriteriaPanel({
    required this.ratingOptions,
    required this.salesOptions,
    required this.minRating,
    required this.minSales,
    required this.shippingFilter,
    required this.selectedStores,
    required this.onRatingChanged,
    required this.onSalesChanged,
    required this.onShippingFilterChanged,
    required this.onStoreToggled,
  });

  final List<double> ratingOptions;
  final List<int> salesOptions;
  final double minRating;
  final int minSales;
  final ShippingFilter shippingFilter;
  final Set<StoreOption> selectedStores;
  final ValueChanged<double?> onRatingChanged;
  final ValueChanged<int?> onSalesChanged;
  final ValueChanged<ShippingFilter?> onShippingFilterChanged;
  final ValueChanged<StoreOption> onStoreToggled;

  @override
  Widget build(BuildContext context) {
    final textPrimary = _isNeoSkin
        ? _NeoColors.textPrimary
        : _CyberColors.textPrimary;
    final textSecondary = _isNeoSkin
        ? _NeoColors.textSecondary
        : _CyberColors.textSecondary;
    final accent = _isNeoSkin ? _NeoColors.primary : _CyberColors.primary;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _isNeoSkin
          ? _applePanelDecoration()
          : _cyberPanelDecoration(radius: 12, glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(number: '01', title: 'Filtros de busqueda'),
          const SizedBox(height: 18),
          Text(
            'Tiendas a comparar',
            style: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Selecciona las plataformas que PriceSec debe abrir y comparar.',
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.65,
            children: [
              for (final store in StoreOption.values)
                _StoreChoiceChip(
                  store: store,
                  selected: selectedStores.contains(store),
                  onTap: () => onStoreToggled(store),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: accent.withValues(alpha: 0.24)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _LockedCriterion(
                icon: Icons.public,
                label: 'Pais',
                value: fixedMonitorConfig.country,
              ),
              _LockedCriterion(
                icon: Icons.payments,
                label: 'Moneda',
                value: fixedMonitorConfig.currency,
              ),
              _DropdownCriterion<double>(
                icon: Icons.star,
                label: 'Rating minimo',
                value: minRating,
                options: ratingOptions,
                onChanged: onRatingChanged,
                format: (value) => '${_formatRating(value)}+ estrellas',
              ),
              _DropdownCriterion<int>(
                icon: Icons.shopping_bag,
                label: 'Ventas minimas',
                value: minSales,
                options: salesOptions,
                onChanged: onSalesChanged,
                format: (value) => 'Mas de $value',
              ),
              _DropdownCriterion<ShippingFilter>(
                icon: Icons.local_shipping,
                label: 'Envio incluido',
                value: shippingFilter,
                options: ShippingFilter.values,
                onChanged: onShippingFilterChanged,
                format: (value) => value.label,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: _isNeoSkin ? 0.08 : 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Consejo', style: _strongTextStyle()),
                      const SizedBox(height: 4),
                      Text(
                        'Usa los filtros para obtener resultados mas precisos y comparar solo lo que realmente te importa.',
                        style: _supportTextStyle(height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsPanel extends StatelessWidget {
  const _ResultsPanel({
    required this.statusMessage,
    required this.bestResult,
    required this.results,
    required this.filters,
  });

  final String? statusMessage;
  final ProductResult? bestResult;
  final List<ProductResult> results;
  final SearchFilters filters;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cyberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(number: '02', title: 'Resultado'),
          const SizedBox(height: 16),
          if (statusMessage == null)
            const _EmptyState()
          else ...[
            Text(statusMessage!, style: _supportTextStyle()),
            if (bestResult != null) ...[
              const SizedBox(height: 16),
              _BestOptionCard(result: bestResult!, filters: filters),
            ],
            if (results.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...results.map(
                (result) => _ResultRow(result: result, filters: filters),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _StoreChoiceChip extends StatelessWidget {
  const _StoreChoiceChip({
    required this.store,
    required this.selected,
    required this.onTap,
  });

  final StoreOption store;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textPrimary = _isNeoSkin
        ? _NeoColors.textPrimary
        : _CyberColors.textPrimary;
    final textSecondary = _isNeoSkin
        ? _NeoColors.textSecondary
        : _CyberColors.textSecondary;
    final accent = _isNeoSkin ? _NeoColors.primary : _storeAccentColor(store);
    final bg = _isNeoSkin
        ? (selected ? Colors.white : const Color(0xffedf2f7))
        : (selected
              ? accent.withValues(
                  alpha: store == StoreOption.shein ? 0.1 : 0.16,
                )
              : _CyberColors.bgDarker.withValues(alpha: 0.76));
    final border = selected
        ? accent
        : (_isNeoSkin
              ? const Color(0xffcbd5e1)
              : _CyberColors.border.withValues(alpha: 0.95));
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(_isNeoSkin ? 18 : 10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_isNeoSkin ? 18 : 10),
            border: Border.all(color: border, width: selected ? 2 : 1.3),
            boxShadow: _isNeoSkin
                ? [
                    BoxShadow(
                      color: selected
                          ? accent.withValues(alpha: 0.18)
                          : _NeoColors.shadowDark.withValues(alpha: 0.65),
                      blurRadius: selected ? 18 : 10,
                      offset: const Offset(4, 4),
                    ),
                    const BoxShadow(
                      color: _NeoColors.shadowLight,
                      blurRadius: 10,
                      offset: Offset(-4, -4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              _StoreBrandIcon(store: store, selected: selected),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  store.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isNeoSkin
                        ? textPrimary
                        : (selected ? accent : textPrimary),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? accent : textSecondary,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreBrandIcon extends StatelessWidget {
  const _StoreBrandIcon({required this.store, required this.selected});

  final StoreOption store;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: _storeLogoBackground(store),
        borderRadius: BorderRadius.circular(
          store == StoreOption.amazon ? 8 : 12,
        ),
        border: Border.all(
          color: _isNeoSkin
              ? Colors.white.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: CustomPaint(
        painter: _StoreLogoPainter(store: store, selected: selected),
      ),
    );
  }
}

Color _storeAccentColor(StoreOption store) {
  if (!_isNeoSkin && store == StoreOption.shein) return const Color(0xfff8fafc);
  if (!_isNeoSkin && store == StoreOption.amazon) {
    return const Color(0xffffb454);
  }
  return store.brandColor;
}

Color _storeLogoBackground(StoreOption store) {
  return switch (store) {
    StoreOption.amazon => Colors.white,
    StoreOption.shein => Colors.black,
    StoreOption.temu => const Color(0xffff6a00),
    StoreOption.aliexpress => const Color(0xffef2b00),
  };
}

class _StoreLogoPainter extends CustomPainter {
  const _StoreLogoPainter({required this.store, required this.selected});

  final StoreOption store;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    switch (store) {
      case StoreOption.amazon:
        _paintAmazon(canvas, size);
      case StoreOption.shein:
        _paintShein(canvas, size);
      case StoreOption.temu:
        _paintTemu(canvas, size);
      case StoreOption.aliexpress:
        _paintAliExpress(canvas, size);
    }
  }

  void _paintAmazon(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: 'a',
        style: TextStyle(
          color: Colors.black,
          fontSize: size.height * 0.68,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(size.width * 0.33, size.height * 0.02));
    final smile = Paint()
      ..color = const Color(0xffff9900)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromLTWH(
      size.width * 0.18,
      size.height * 0.52,
      size.width * 0.62,
      size.height * 0.28,
    );
    canvas.drawArc(rect, 0.18, 2.35, false, smile);
    final arrow = Path()
      ..moveTo(size.width * 0.79, size.height * 0.64)
      ..lineTo(size.width * 0.86, size.height * 0.62)
      ..lineTo(size.width * 0.83, size.height * 0.72);
    canvas.drawPath(
      arrow,
      Paint()
        ..color = const Color(0xffff9900)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintShein(Canvas canvas, Size size) {
    final text = TextPainter(
      text: TextSpan(
        text: 'S',
        style: TextStyle(
          color: Colors.white,
          fontSize: size.height * 0.72,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset((size.width - text.width) / 2, (size.height - text.height) / 2),
    );
  }

  void _paintTemu(Canvas canvas, Size size) {
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * .16,
        size.height * .13,
        size.width * .68,
        size.height * .64,
      ),
      Radius.circular(size.width * .16),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white,
    );
    final text = TextPainter(
      text: TextSpan(
        text: 'TEMU',
        style: TextStyle(
          color: Colors.white,
          fontSize: size.height * 0.21,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
          height: 1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    text.paint(
      canvas,
      Offset((size.width - text.width) / 2, size.height * .49),
    );
    final icons = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * .34, size.height * .34), 2.4, icons);
    canvas.drawCircle(Offset(size.width * .50, size.height * .31), 2.2, icons);
    canvas.drawCircle(Offset(size.width * .66, size.height * .34), 2.4, icons);
  }

  void _paintAliExpress(Canvas canvas, Size size) {
    final top = Paint()..color = const Color(0xffffa000);
    final bag = Paint()..color = const Color(0xffef2b00);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(size.width * .23),
      ),
      top,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.height * .13, size.width, size.height * .87),
        Radius.circular(size.width * .21),
      ),
      bag,
    );
    final handle = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromLTWH(
      size.width * .26,
      size.height * .20,
      size.width * .48,
      size.height * .34,
    );
    canvas.drawArc(rect, 0.05, math.pi - .1, false, handle);
    final text = TextPainter(
      text: TextSpan(
        text: 'Ali',
        style: TextStyle(
          color: Colors.white,
          fontSize: size.height * 0.23,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(size.width * .24, size.height * .63));
  }

  @override
  bool shouldRepaint(covariant _StoreLogoPainter oldDelegate) {
    return oldDelegate.store != store || oldDelegate.selected != selected;
  }
}

class _CyberBadge extends StatelessWidget {
  const _CyberBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _isNeoSkin
            ? _NeoColors.bg
            : _CyberColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _isNeoSkin ? Colors.transparent : _CyberColors.primary,
        ),
        boxShadow: _isNeoSkin
            ? const [
                BoxShadow(
                  color: _NeoColors.shadowDark,
                  blurRadius: 8,
                  offset: Offset(4, 4),
                ),
                BoxShadow(
                  color: _NeoColors.shadowLight,
                  blurRadius: 8,
                  offset: Offset(-4, -4),
                ),
              ]
            : [
                BoxShadow(
                  color: _CyberColors.primary.withValues(alpha: 0.22),
                  blurRadius: 20,
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isNeoSkin ? _NeoColors.success : _CyberColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: _isNeoSkin ? _NeoColors.primary : _CyberColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    final titleColor = _isNeoSkin
        ? const Color(0xff0f172a)
        : _CyberColors.textPrimary;
    final accent = _isNeoSkin ? _NeoColors.primary : _CyberColors.primary;
    final secondary = _isNeoSkin ? _NeoColors.success : _CyberColors.secondary;
    return Row(
      children: [
        Text(
          number,
          style: TextStyle(color: accent, fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            shadows: _isNeoSkin
                ? null
                : [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accent, secondary]),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final accent = _isNeoSkin ? _NeoColors.primary : _CyberColors.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: _isNeoSkin ? 0.06 : 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Text(
        'Escribe un producto y presiona Comparar para iniciar la automatizacion.',
        style: _supportTextStyle(),
      ),
    );
  }
}

class _BestOptionCard extends StatelessWidget {
  const _BestOptionCard({required this.result, required this.filters});

  final ProductResult result;
  final SearchFilters filters;

  @override
  Widget build(BuildContext context) {
    final accent = _isNeoSkin ? _NeoColors.primary : _CyberColors.primary;
    final secondary = _isNeoSkin ? _NeoColors.success : _CyberColors.secondary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: _isNeoSkin ? 0.1 : 0.16),
            secondary.withValues(alpha: _isNeoSkin ? 0.07 : 0.09),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 24),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.verified, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mejor opcion: ${result.store.label} por ${result.priceLabel}',
              style: _strongTextStyle(),
            ),
          ),
          const SizedBox(width: 12),
          Text('Score ${result.score(filters).toStringAsFixed(1)}'),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => openExternalUrl(result.listingUrl),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Abrir'),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result, required this.filters});

  final ProductResult result;
  final SearchFilters filters;

  @override
  Widget build(BuildContext context) {
    final valid = result.isValid(filters);
    final color = valid
        ? (_isNeoSkin ? _NeoColors.primary : _CyberColors.primary)
        : _CyberColors.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => openExternalUrl(result.listingUrl),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isNeoSkin
                  ? const Color(0xfff8fafc)
                  : _CyberColors.card.withValues(alpha: 0.76),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: color.withValues(alpha: valid ? 0.28 : 0.45),
              ),
            ),
            child: Row(
              children: [
                Icon(valid ? Icons.check_circle : Icons.info, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              result.title,
                              style: _strongTextStyle(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.open_in_new, size: 15, color: color),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${result.store.label} - ${result.ratingLabel} - ${result.salesLabel} - ${result.shippingIncluded ? 'envio incluido' : 'envio no incluido'} - ${result.deliveryLabel}',
                        style: _supportTextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      result.priceLabel,
                      style: _strongTextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _CyberColors.primary,
                        side: BorderSide(
                          color: _CyberColors.primary.withValues(alpha: 0.75),
                        ),
                        minimumSize: const Size(92, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => openExternalUrl(result.listingUrl),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Abrir'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseSection extends StatefulWidget {
  const _PurchaseSection({
    required this.purchases,
    required this.message,
    required this.editingId,
    required this.initialTrm,
    required this.trmRevision,
    required this.onSave,
    required this.onCancelEdit,
  });

  final List<PurchaseRecord> purchases;
  final String? message;
  final int? editingId;
  final double? initialTrm;
  final int trmRevision;
  final Future<bool> Function(PurchaseDraft draft) onSave;
  final VoidCallback onCancelEdit;

  @override
  State<_PurchaseSection> createState() => _PurchaseSectionState();
}

class _PurchaseSectionState extends State<_PurchaseSection> {
  final _controllers = <String, TextEditingController>{};
  final _errors = <String, String>{};
  bool _isSaving = false;
  bool _isLoadingTrm = false;
  String? _trmStatus;

  PurchaseRecord? get _editingRecord {
    final id = widget.editingId;
    if (id == null) return null;
    for (final purchase in widget.purchases) {
      if (purchase.id == id) return purchase;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    for (final key in PurchaseDraft.fieldKeys) {
      _controllers[key] = TextEditingController();
      _controllers[key]!.addListener(() => setState(() {}));
    }
    _applyDefaults();
    _applyInitialTrm();
    if (widget.initialTrm == null) _loadCurrentTrm();
  }

  @override
  void didUpdateWidget(covariant _PurchaseSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingId != widget.editingId) {
      final record = _editingRecord;
      if (record == null) {
        _applyDefaults();
        _applyInitialTrm();
      } else {
        _applyDraft(record.toDraft());
      }
    }
    if (oldWidget.trmRevision != widget.trmRevision) {
      _applyInitialTrm();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draftFromControllers();
    final calculations = PurchaseCalculations.fromDraft(draft);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cyberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(number: '03', title: 'Registrar compra'),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 3 : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 5.4 : 3.4,
                children: [
                  _purchaseField('productName', 'Nombre producto'),
                  _purchaseField('priceUsd', 'Precio USD'),
                  _purchaseField('trm', 'TRM actual', isTrm: true),
                  _purchaseField('quantity', 'Cantidad und'),
                  _purchaseField('originShippingUsd', 'Envio origen USD'),
                  _purchaseField('cardCommissionRate', 'Comision T.C %'),
                  _purchaseField('heightCm', 'Alto cm'),
                  _purchaseField('widthCm', 'Ancho cm'),
                  _purchaseField('lengthCm', 'Largo cm'),
                  _purchaseField('boxCount', 'Cantidad cajas'),
                  _purchaseField('cbmRate', 'CBM agente carga'),
                  _purchaseField('nationalFreight', 'Flete nacional'),
                  _purchaseField('mercadoLibrePrice', 'Precio ML'),
                  _purchaseField('mercadoLibreCommissionRate', 'Comision ML %'),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          if (_trmStatus != null) ...[
            Text(
              _trmStatus!,
              style: const TextStyle(color: _CyberColors.textSecondary),
            ),
            const SizedBox(height: 12),
          ],
          _CalculationGrid(calculations: calculations),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _CyberColors.primary,
                  foregroundColor: _CyberColors.bgDarker,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isSaving ? null : () => _submit(draft),
                icon: Icon(_isSaving ? Icons.sync : Icons.save),
                label: Text(
                  widget.editingId == null ? 'Guardar' : 'Actualizar',
                ),
              ),
              if (widget.editingId != null) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    widget.onCancelEdit();
                    _applyDefaults();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Cancelar'),
                ),
              ],
            ],
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 12),
            _PurchaseMessage(message: widget.message!),
          ],
        ],
      ),
    );
  }

  Widget _purchaseField(String key, String label, {bool isTrm = false}) {
    final isText = key == 'productName';
    return TextField(
      controller: _controllers[key],
      keyboardType: isText
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      style: _inputTextStyle(),
      decoration: _inputDecoration(
        label: label,
        hint: '',
        icon: Icons.edit,
        errorText: _errors[key],
        suffixIcon: isTrm
            ? IconButton(
                tooltip: 'Actualizar TRM',
                onPressed: _isLoadingTrm ? null : _loadCurrentTrm,
                icon: Icon(
                  _isLoadingTrm ? Icons.sync : Icons.currency_exchange,
                  color: _CyberColors.primary,
                ),
              )
            : null,
      ),
    );
  }

  Future<void> _submit(PurchaseDraft draft) async {
    final errors = _validatePurchase();
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }

    setState(() {
      _errors.clear();
      _isSaving = true;
    });
    var saved = false;
    try {
      saved = await widget.onSave(draft);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (saved && mounted) _applyDefaults();
  }

  Map<String, String> _validatePurchase() {
    final errors = <String, String>{};
    for (final key in PurchaseDraft.fieldKeys) {
      final raw = _controllers[key]?.text.trim() ?? '';
      if (raw.isEmpty) {
        errors[key] = 'Debes ingresar este dato.';
        continue;
      }
      if (key == 'productName') continue;
      final value = parseLocalizedNumber(raw);
      final allowsZero =
          key == 'originShippingUsd' || key == 'cardCommissionRate';
      if (!allowsZero && value <= 0) {
        errors[key] = 'Debe ser mayor que 0.';
      } else if (allowsZero && value < 0) {
        errors[key] = 'No puede ser negativo.';
      }
    }
    return errors;
  }

  PurchaseDraft _draftFromControllers() {
    String text(String key) => _controllers[key]?.text.trim() ?? '';
    double number(String key) => parseLocalizedNumber(text(key));

    double rate(String key) {
      final value = number(key);
      return value > 1 ? value / 100 : value;
    }

    return PurchaseDraft(
      productName: text('productName'),
      priceUsd: number('priceUsd'),
      trm: number('trm'),
      quantity: number('quantity'),
      originShippingUsd: number('originShippingUsd'),
      cardCommissionRate: rate('cardCommissionRate'),
      heightCm: number('heightCm'),
      widthCm: number('widthCm'),
      lengthCm: number('lengthCm'),
      boxCount: number('boxCount'),
      cbmRate: number('cbmRate'),
      nationalFreight: number('nationalFreight'),
      mercadoLibrePrice: number('mercadoLibrePrice'),
      mercadoLibreCommissionRate: rate('mercadoLibreCommissionRate'),
    );
  }

  void _applyDefaults() {
    final currentTrm = parseLocalizedNumber(_controllers['trm']?.text ?? '');
    _applyDraft(
      PurchaseDraft(
        productName: '',
        priceUsd: 0,
        trm: currentTrm > 0 ? currentTrm : 0,
        quantity: 0,
        originShippingUsd: 0,
        cardCommissionRate: 0,
        heightCm: 0,
        widthCm: 0,
        lengthCm: 0,
        boxCount: 0,
        cbmRate: 0,
        nationalFreight: 100000,
        mercadoLibrePrice: 0,
        mercadoLibreCommissionRate: 0.24,
      ),
    );
  }

  Future<void> _loadCurrentTrm() async {
    setState(() {
      _isLoadingTrm = true;
      _trmStatus = 'Consultando TRM actual...';
    });
    try {
      final trm = await fetchCurrentTrm();
      if (!mounted) return;
      if (trm == null || trm <= 0) {
        setState(() {
          _trmStatus =
              'No pude autocompletar la TRM. Puedes escribirla manualmente.';
        });
        return;
      }
      final current = parseLocalizedNumber(_controllers['trm']?.text ?? '');
      final trmText = _formatTrmInput(trm);
      if (current == 0) {
        _controllers['trm']?.text = trmText;
      }
      setState(() {
        _trmStatus = 'TRM sugerida: $trmText COP por USD.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _trmStatus =
            'No pude autocompletar la TRM. Puedes escribirla manualmente.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingTrm = false);
      }
    }
  }

  void _applyInitialTrm() {
    final trm = widget.initialTrm;
    if (trm == null || trm <= 0) return;
    final current = parseLocalizedNumber(_controllers['trm']?.text ?? '');
    final trmText = _formatTrmInput(trm);
    if (current == 0) {
      _controllers['trm']?.text = trmText;
    }
    _trmStatus = 'TRM automatica: $trmText COP por USD.';
  }

  void _applyDraft(PurchaseDraft draft) {
    _errors.clear();
    void setText(String key, Object value) {
      _controllers[key]?.text = value is double
          ? _formatInputNumber(value)
          : value.toString();
    }

    setText('productName', draft.productName);
    setText('priceUsd', draft.priceUsd);
    setText('trm', draft.trm);
    setText('quantity', draft.quantity);
    setText('originShippingUsd', draft.originShippingUsd);
    setText('cardCommissionRate', draft.cardCommissionRate);
    setText('heightCm', draft.heightCm);
    setText('widthCm', draft.widthCm);
    setText('lengthCm', draft.lengthCm);
    setText('boxCount', draft.boxCount);
    setText('cbmRate', draft.cbmRate);
    setText('nationalFreight', draft.nationalFreight);
    setText('mercadoLibrePrice', draft.mercadoLibrePrice);
    setText('mercadoLibreCommissionRate', draft.mercadoLibreCommissionRate);
  }
}

class _CalculationGrid extends StatelessWidget {
  const _CalculationGrid({required this.calculations});

  final PurchaseCalculations calculations;

  @override
  Widget build(BuildContext context) {
    final items = {
      'Precio COP': calculations.priceCop,
      'Total mercancia China': calculations.totalMerchandiseCopChina,
      'Envio origen COP': calculations.originShippingCop,
      'Total COP China': calculations.totalCopChina,
      'Valor comision T.C': calculations.cardCommissionCop,
      'Cubicaje m3': calculations.cubicMeters,
      'Flete + nacionalizacion': calculations.freightAndNationalization,
      'Costo importado Bogota': calculations.importedProductCostBogota,
      'Costo pedido domicilio': calculations.orderHomeCost,
      'Costo unidad domicilio': calculations.unitHomeCost,
      'Precio ML - comision': calculations.mlNetPrice,
      'Comparacion': calculations.comparison,
    };
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.entries
          .map(
            (entry) => _MetricChip(
              label: entry.key,
              value: entry.key == 'Cubicaje m3' || entry.key == 'Comparacion'
                  ? entry.value.toStringAsFixed(2)
                  : formatCop(entry.value.round()),
            ),
          )
          .toList(),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _fieldDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: _supportTextStyle()),
          const SizedBox(height: 4),
          Text(value, style: _strongTextStyle()),
        ],
      ),
    );
  }
}

class _SavedPurchasesSection extends StatelessWidget {
  const _SavedPurchasesSection({
    required this.purchases,
    required this.message,
    required this.onEdit,
    required this.onDelete,
  });

  final List<PurchaseRecord> purchases;
  final String? message;
  final ValueChanged<PurchaseRecord> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cyberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(number: '04', title: 'Compras guardadas'),
          if (message != null) ...[
            const SizedBox(height: 12),
            _PurchaseMessage(message: message!),
          ],
          const SizedBox(height: 18),
          _PurchasesList(
            purchases: purchases,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AliExpressViabilitySection extends StatefulWidget {
  const _AliExpressViabilitySection({
    required this.records,
    required this.message,
    required this.editingId,
    required this.onSave,
    required this.onCancelEdit,
  });

  final List<AliExpressViabilityRecord> records;
  final String? message;
  final int? editingId;
  final Future<bool> Function(AliExpressViabilityDraft draft) onSave;
  final VoidCallback onCancelEdit;

  @override
  State<_AliExpressViabilitySection> createState() =>
      _AliExpressViabilitySectionState();
}

class _AliExpressViabilitySectionState
    extends State<_AliExpressViabilitySection> {
  final _controllers = <String, TextEditingController>{};
  final _errors = <String, String>{};
  bool _isSaving = false;

  AliExpressViabilityRecord? get _editingRecord {
    final id = widget.editingId;
    if (id == null) return null;
    for (final record in widget.records) {
      if (record.id == id) return record;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    for (final key in AliExpressViabilityDraft.fieldKeys) {
      _controllers[key] = TextEditingController();
      _controllers[key]!.addListener(() => setState(() {}));
    }
    _applyDefaults();
  }

  @override
  void didUpdateWidget(covariant _AliExpressViabilitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingId != widget.editingId) {
      final record = _editingRecord;
      if (record == null) {
        _applyDefaults();
      } else {
        _applyDraft(record.toDraft());
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draftFromControllers();
    final calculations = AliExpressViabilityCalculations.fromDraft(draft);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cyberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(number: '05', title: 'Viabilidad AliExpress'),
          const SizedBox(height: 8),
          const Text(
            'Formulario independiente basado en los encabezados y formulas del Excel, sin cargar sus filas de ejemplo.',
            style: TextStyle(color: _CyberColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 3 : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 5.4 : 3.2,
                children: [
                  _viabilityField('number', 'Numero'),
                  _viabilityField('productName', 'Nombre Producto'),
                  _viabilityField('productLink', 'Link del producto'),
                  _viabilityField('orderHomeCost', 'Costo pedido domicilio'),
                  _viabilityField('quantity', 'Cantidad (Und)'),
                  _viabilityField(
                    'mercadoLibreTotalPrice',
                    'Precio Total Producto en Mercadolibre',
                  ),
                  _viabilityField('meliCommissionRate', 'Comision Meli (%)'),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _AliExpressViabilityGrid(calculations: calculations),
          if (calculations.viability < 2) ...[
            const SizedBox(height: 10),
            const _PurchaseMessage(
              message:
                  'No se permite guardar: el puntaje es menor a 2 y no es viable para compra.',
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _CyberColors.primary,
                  foregroundColor: _CyberColors.bgDarker,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isSaving ? null : () => _submit(draft),
                icon: Icon(_isSaving ? Icons.sync : Icons.save),
                label: Text(
                  widget.editingId == null ? 'Guardar' : 'Actualizar',
                ),
              ),
              if (widget.editingId != null) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    widget.onCancelEdit();
                    _applyDefaults();
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Cancelar'),
                ),
              ],
            ],
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 12),
            _PurchaseMessage(message: widget.message!),
          ],
        ],
      ),
    );
  }

  Widget _viabilityField(String key, String label) {
    final isText = key == 'productName' || key == 'productLink';
    return TextField(
      controller: _controllers[key],
      keyboardType: isText
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      style: _inputTextStyle(),
      decoration: _inputDecoration(
        label: label,
        hint: '',
        icon: isText ? Icons.notes : Icons.calculate,
        errorText: _errors[key],
      ),
    );
  }

  Future<void> _submit(AliExpressViabilityDraft draft) async {
    final errors = _validateViability();
    final calculations = AliExpressViabilityCalculations.fromDraft(draft);
    if (calculations.viability < 2) {
      errors['mercadoLibreTotalPrice'] =
          'Viabilidad menor a 2. No se puede guardar.';
    }
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }

    setState(() {
      _errors.clear();
      _isSaving = true;
    });
    var saved = false;
    try {
      saved = await widget.onSave(draft);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    if (saved && mounted) _applyDefaults();
  }

  Map<String, String> _validateViability() {
    final errors = <String, String>{};
    for (final key in AliExpressViabilityDraft.fieldKeys) {
      final raw = _controllers[key]?.text.trim() ?? '';
      if (raw.isEmpty && key != 'productLink') {
        errors[key] = 'Debes ingresar este dato.';
        continue;
      }
      if (key == 'productName' || key == 'productLink') continue;
      final value = parseLocalizedNumber(raw);
      if (value <= 0) {
        errors[key] = 'Debe ser mayor que 0.';
      }
    }
    return errors;
  }

  AliExpressViabilityDraft _draftFromControllers() {
    String text(String key) => _controllers[key]?.text.trim() ?? '';
    double number(String key) => parseLocalizedNumber(text(key));

    double rate(String key) {
      final value = number(key);
      return value > 1 ? value / 100 : value;
    }

    return AliExpressViabilityDraft(
      number: number('number'),
      productName: text('productName'),
      productLink: text('productLink'),
      orderHomeCost: number('orderHomeCost'),
      quantity: number('quantity'),
      mercadoLibreTotalPrice: number('mercadoLibreTotalPrice'),
      meliCommissionRate: rate('meliCommissionRate'),
    );
  }

  void _applyDefaults() {
    _applyDraft(
      const AliExpressViabilityDraft(
        number: 1,
        productName: '',
        productLink: '',
        orderHomeCost: 0,
        quantity: 1,
        mercadoLibreTotalPrice: 0,
        meliCommissionRate: 0.24,
      ),
    );
  }

  void _applyDraft(AliExpressViabilityDraft draft) {
    _errors.clear();
    void setText(String key, Object value) {
      _controllers[key]?.text = value is double
          ? _formatInputNumber(value)
          : value.toString();
    }

    setText('number', draft.number);
    setText('productName', draft.productName);
    setText('productLink', draft.productLink);
    setText('orderHomeCost', draft.orderHomeCost);
    setText('quantity', draft.quantity);
    setText('mercadoLibreTotalPrice', draft.mercadoLibreTotalPrice);
    setText('meliCommissionRate', draft.meliCommissionRate);
  }
}

class _AliExpressViabilityGrid extends StatelessWidget {
  const _AliExpressViabilityGrid({required this.calculations});

  final AliExpressViabilityCalculations calculations;

  @override
  Widget build(BuildContext context) {
    final items = {
      'Costo unidad domicilio': calculations.unitHomeCost,
      'Libre de comision': calculations.commissionFreePrice,
      'Viabilidad': calculations.viability,
    };
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.entries
          .map(
            (entry) => _MetricChip(
              label: entry.key,
              value: entry.key == 'Viabilidad'
                  ? entry.value.toStringAsFixed(2)
                  : formatCop(entry.value.round()),
            ),
          )
          .toList(),
    );
  }
}

class _SavedViabilitiesSection extends StatelessWidget {
  const _SavedViabilitiesSection({
    required this.records,
    required this.message,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkPurchased,
  });

  final List<AliExpressViabilityRecord> records;
  final String? message;
  final ValueChanged<AliExpressViabilityRecord> onEdit;
  final ValueChanged<int> onDelete;
  final ValueChanged<AliExpressViabilityRecord> onMarkPurchased;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cyberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(number: '06', title: 'Viabilidades guardadas'),
          if (message != null) ...[
            const SizedBox(height: 12),
            _PurchaseMessage(message: message!),
          ],
          const SizedBox(height: 18),
          _ViabilitiesList(
            records: records,
            onEdit: onEdit,
            onDelete: onDelete,
            onMarkPurchased: onMarkPurchased,
          ),
        ],
      ),
    );
  }
}

class _InventorySection extends StatefulWidget {
  const _InventorySection({
    required this.items,
    required this.warehouses,
    required this.message,
    required this.onSave,
    required this.onDelete,
    required this.onReceive,
  });

  final List<InventoryItemRecord> items;
  final List<String> warehouses;
  final String? message;
  final Future<bool> Function(InventoryItemDraft draft) onSave;
  final ValueChanged<int> onDelete;
  final void Function(InventoryItemRecord item, String warehouse) onReceive;

  @override
  State<_InventorySection> createState() => _InventorySectionState();
}

class _InventorySectionState extends State<_InventorySection> {
  final _controllers = {
    'productName': TextEditingController(),
    'unitPurchaseValue': TextEditingController(),
    'quantity': TextEditingController(),
    'publicSaleValue': TextEditingController(),
    'loadedAt': TextEditingController(),
    'warehouse': TextEditingController(),
  };
  final _searchController = TextEditingController();
  final _errors = <String, String>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controllers['loadedAt']!.text = DateTime.now()
        .toIso8601String()
        .split('T')
        .first;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lowStock = widget.items.where((item) => item.quantity < 3).toList();
    final productNames = _uniqueInventoryValues(
      widget.items.map((item) => item.productName),
    );
    final warehouses = _uniqueInventoryValues([
      ...widget.warehouses,
      ...widget.items.map((item) => item.warehouse),
    ]);
    final filtered = widget.items.where((item) {
      return _smartMatches(_searchController.text, [
        item.productName,
        item.warehouse,
        item.createdByUsername,
      ]);
    }).toList();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cyberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(number: '07', title: 'Sistema de Gestion'),
          const SizedBox(height: 18),
          if (lowStock.isNotEmpty) ...[
            _StockAlert(items: lowStock),
            const SizedBox(height: 14),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 3 : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 5.4 : 3.2,
                children: [
                  _suggestedInventoryField(
                    'productName',
                    'Nombre del producto',
                    productNames,
                    Icons.inventory_2,
                  ),
                  _inventoryField('unitPurchaseValue', 'Costo unitario compra'),
                  _inventoryField('quantity', 'Cantidad ingresada'),
                  _inventoryField('publicSaleValue', 'Precio venta publico'),
                  _inventoryField('loadedAt', 'Fecha de carga'),
                  _suggestedInventoryField(
                    'warehouse',
                    'Bodega',
                    warehouses,
                    Icons.warehouse,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: Icon(_saving ? Icons.sync : Icons.save),
            label: const Text('Guardar inventario'),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 12),
            _PurchaseMessage(message: widget.message!),
          ],
          const SizedBox(height: 22),
          _ListSearchBox(
            controller: _searchController,
            label: 'Buscar movimientos de inventario',
            total: widget.items.length,
            filtered: filtered.length,
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Text(
              'Aun no hay inventario registrado.',
              style: TextStyle(color: _CyberColors.textSecondary),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Historial de movimientos',
                style: TextStyle(
                  color: _isNeoSkin
                      ? _NeoColors.textPrimary
                      : _CyberColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
          ...filtered.map(
            (item) => _InventoryRow(
              item: item,
              warehouses: warehouses,
              onDelete: widget.onDelete,
              onReceive: widget.onReceive,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _uniqueInventoryValues(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      final key = _normalizeSearchText(value);
      if (seen.add(key)) result.add(value);
    }
    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  Widget _inventoryField(String key, String label) {
    final isText =
        key == 'productName' || key == 'loadedAt' || key == 'warehouse';
    return TextField(
      controller: _controllers[key],
      keyboardType: isText
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      style: _inputTextStyle(),
      decoration: _inputDecoration(
        label: label,
        hint: key == 'loadedAt' ? 'YYYY-MM-DD' : '',
        icon: isText ? Icons.notes : Icons.calculate,
        errorText: _errors[key],
      ),
    );
  }

  Widget _suggestedInventoryField(
    String key,
    String label,
    List<String> options,
    IconData icon,
  ) {
    if (key == 'warehouse') {
      return _WarehouseAutocompleteField(
        controller: _controllers[key]!,
        label: label,
        options: options,
        errorText: _errors[key],
      );
    }
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _controllers[key]!.text),
      optionsBuilder: (value) {
        final query = value.text.trim();
        if (query.isEmpty) return options.take(8);
        return options
            .where((option) => _smartMatches(query, [option]))
            .take(8);
      },
      onSelected: (value) => _controllers[key]!.text = value,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            if (textEditingController.text != _controllers[key]!.text) {
              textEditingController.text = _controllers[key]!.text;
            }
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              onChanged: (value) => _controllers[key]!.text = value,
              style: _inputTextStyle(),
              decoration: _inputDecoration(
                label: label,
                hint: options.isEmpty
                    ? 'Escribe uno nuevo'
                    : 'Busca o escribe uno nuevo',
                icon: icon,
                errorText: _errors[key],
              ),
            );
          },
      optionsViewBuilder: (context, onSelected, visibleOptions) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxWidth: 360, maxHeight: 240),
              decoration: _cyberPanelDecoration(radius: 10),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: visibleOptions.length,
                itemBuilder: (context, index) {
                  final option = visibleOptions.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option, style: _inputTextStyle()),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final errors = <String, String>{};
    for (final entry in _controllers.entries) {
      if (entry.value.text.trim().isEmpty) {
        errors[entry.key] = 'Debes ingresar este dato.';
      }
    }
    for (final key in ['unitPurchaseValue', 'quantity', 'publicSaleValue']) {
      if (parseLocalizedNumber(_controllers[key]!.text) <= 0) {
        errors[key] = 'Debe ser mayor que 0.';
      }
    }
    if (errors.isNotEmpty) {
      setState(
        () => _errors
          ..clear()
          ..addAll(errors),
      );
      return;
    }
    setState(() {
      _errors.clear();
      _saving = true;
    });
    final saved = await widget.onSave(
      InventoryItemDraft(
        productName: _controllers['productName']!.text.trim(),
        unitPurchaseValue: parseLocalizedNumber(
          _controllers['unitPurchaseValue']!.text,
        ),
        quantity: parseLocalizedNumber(_controllers['quantity']!.text),
        publicSaleValue: parseLocalizedNumber(
          _controllers['publicSaleValue']!.text,
        ),
        loadedAt: _controllers['loadedAt']!.text.trim(),
        warehouse: _controllers['warehouse']!.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      _controllers['productName']!.clear();
      _controllers['unitPurchaseValue']!.clear();
      _controllers['quantity']!.clear();
      _controllers['publicSaleValue']!.clear();
      _controllers['warehouse']!.clear();
    }
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({
    required this.item,
    required this.warehouses,
    required this.onDelete,
    required this.onReceive,
  });

  final InventoryItemRecord item;
  final List<String> warehouses;
  final ValueChanged<int> onDelete;
  final void Function(InventoryItemRecord item, String warehouse) onReceive;

  @override
  Widget build(BuildContext context) {
    final addedBy = item.createdByUsername.trim().isEmpty
        ? 'Usuario no registrado'
        : item.createdByUsername.trim();
    final textPrimary = _isNeoSkin
        ? _NeoColors.textPrimary
        : _CyberColors.textPrimary;
    final textSecondary = _isNeoSkin
        ? _NeoColors.textSecondary
        : _CyberColors.textSecondary;
    final accent = _isNeoSkin ? _NeoColors.primary : _CyberColors.primary;
    final danger = _isNeoSkin ? const Color(0xffff5a5f) : _CyberColors.accent;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _fieldDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: TextStyle(
                    color: item.quantity < 3 ? danger : textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Estado: ${item.statusLabel} | Bodega: ${item.warehouse} | Cantidad: ${_formatInputNumber(item.quantity)} | Compra: ${formatCop(item.unitPurchaseValue.round())} | Venta: ${formatCop(item.publicSaleValue.round())}',
                  style: TextStyle(
                    color: textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                    children: [
                      TextSpan(
                        text:
                            'Movimiento: ${_formatDateTimeLabel(item.createdAt)} | Agregado por: ',
                      ),
                      TextSpan(
                        text: addedBy,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(text: ' | Fecha carga: ${item.loadedAt}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (item.status == 'in_transit')
            IconButton(
              tooltip: 'Marcar recibido',
              onPressed: () => _showReceiveDialog(context),
              icon: Icon(Icons.move_to_inbox, color: accent),
            ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: () => onDelete(item.id),
            icon: Icon(Icons.delete, color: danger),
          ),
        ],
      ),
    );
  }

  void _showReceiveDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recibir producto'),
        content: Autocomplete<String>(
          optionsBuilder: (value) {
            final query = value.text.trim();
            if (query.isEmpty) return warehouses.take(10);
            return warehouses
                .where((item) => _smartMatches(query, [item]))
                .take(10);
          },
          onSelected: (value) => controller.text = value,
          fieldViewBuilder: (context, textController, focusNode, onSubmit) {
            return TextField(
              controller: textController,
              focusNode: focusNode,
              onChanged: (value) => controller.text = value,
              decoration: const InputDecoration(labelText: 'Bodega de destino'),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final warehouse = controller.text.trim();
              if (warehouse.isEmpty) return;
              Navigator.pop(context);
              onReceive(item, warehouse);
            },
            child: const Text('Recibir'),
          ),
        ],
      ),
    );
  }
}

class _WarehouseAutocompleteField extends StatelessWidget {
  const _WarehouseAutocompleteField({
    required this.controller,
    required this.label,
    required this.options,
    required this.errorText,
  });

  final TextEditingController controller;
  final String label;
  final List<String> options;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final accent = _isNeoSkin ? _NeoColors.primary : _CyberColors.secondary;
    final textPrimary = _isNeoSkin
        ? _NeoColors.textPrimary
        : _CyberColors.textPrimary;
    final textSecondary = _isNeoSkin
        ? _NeoColors.textSecondary
        : _CyberColors.textSecondary;
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (value) {
        final query = value.text.trim();
        final matches = query.isEmpty
            ? options.take(12)
            : options
                  .where((option) => _smartMatches(query, [option]))
                  .take(18);
        return matches;
      },
      onSelected: (value) => controller.text = value,
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            if (textEditingController.text != controller.text) {
              textEditingController.text = controller.text;
            }
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              onChanged: (value) => controller.text = value,
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
              decoration: _inputDecoration(
                label: label,
                hint: 'Ciudad o bodega, ej: Florencia',
                icon: Icons.location_on,
                errorText: errorText,
                suffixIcon: controller.text.isEmpty
                    ? Icon(Icons.keyboard_arrow_down, color: textSecondary)
                    : IconButton(
                        tooltip: 'Limpiar bodega',
                        onPressed: () {
                          controller.clear();
                          textEditingController.clear();
                        },
                        icon: Icon(Icons.close, color: textSecondary),
                      ),
              ),
            );
          },
      optionsViewBuilder: (context, onSelected, visibleOptions) {
        final list = visibleOptions.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 0,
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 330),
              decoration: _appleFloatingDecoration(),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  indent: 54,
                  color: textSecondary.withValues(alpha: 0.16),
                ),
                itemBuilder: (context, index) {
                  final option = list[index];
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.place, size: 18, color: accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Colombia',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.north_west,
                            size: 16,
                            color: textSecondary,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _InventorySummarySection extends StatefulWidget {
  const _InventorySummarySection({required this.items});

  final List<InventoryItemRecord> items;

  @override
  State<_InventorySummarySection> createState() =>
      _InventorySummarySectionState();
}

class _InventorySummarySectionState extends State<_InventorySummarySection> {
  final _searchController = TextEditingController();
  static const _pageSize = 25;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _page = 0));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupInventory(widget.items);
    final filtered = grouped.where((item) {
      return _smartMatches(_searchController.text, [
        item.productName,
        item.warehousesLabel,
      ]);
    }).toList()..sort((a, b) => a.productName.compareTo(b.productName));
    final pageCount = math.max(1, (filtered.length / _pageSize).ceil());
    if (_page >= pageCount) _page = pageCount - 1;
    final start = _page * _pageSize;
    final visible = filtered.skip(start).take(_pageSize).toList();
    final totalUnits = grouped.fold<double>(
      0,
      (sum, item) => sum + item.totalQuantity,
    );

    final textSecondary = _isNeoSkin
        ? _NeoColors.textSecondary
        : _CyberColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _applePanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(number: '09', title: 'Inventario general'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricPill(
                icon: Icons.inventory_2,
                label: 'Productos agrupados',
                value: grouped.length.toString(),
              ),
              _MetricPill(
                icon: Icons.warehouse,
                label: 'Unidades totales',
                value: _formatInputNumber(totalUnits),
              ),
              _MetricPill(
                icon: Icons.warning_amber,
                label: 'Agotandose',
                value: grouped
                    .where((item) => item.totalQuantity < 3)
                    .length
                    .toString(),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _ListSearchBox(
            controller: _searchController,
            label: 'Buscar inventario general',
            total: grouped.length,
            filtered: filtered.length,
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            Text(
              'No hay inventario para mostrar.',
              style: TextStyle(color: textSecondary),
            )
          else
            ...visible.map((item) => _InventorySummaryRow(item: item)),
          if (filtered.length > _pageSize)
            _PaginationControls(
              page: _page,
              pageCount: pageCount,
              totalItems: filtered.length,
              pageSize: _pageSize,
              onPrevious: _page == 0 ? null : () => setState(() => _page--),
              onNext: _page >= pageCount - 1
                  ? null
                  : () => setState(() => _page++),
            ),
        ],
      ),
    );
  }

  List<_InventoryAggregate> _groupInventory(List<InventoryItemRecord> items) {
    final map = <String, _InventoryAggregate>{};
    for (final item in items) {
      final key = _normalizeSearchText(item.productName);
      final current = map[key];
      if (current == null) {
        map[key] = _InventoryAggregate.fromItem(item);
      } else {
        current.add(item);
      }
    }
    return map.values.toList();
  }
}

class _InventorySummaryRow extends StatelessWidget {
  const _InventorySummaryRow({required this.item});

  final _InventoryAggregate item;

  @override
  Widget build(BuildContext context) {
    final lowStock = item.totalQuantity < 3;
    final accent = lowStock
        ? (_isNeoSkin ? const Color(0xffff5a5f) : _CyberColors.accent)
        : (_isNeoSkin ? _NeoColors.primary : _CyberColors.primary);
    final textPrimary = _isNeoSkin
        ? _NeoColors.textPrimary
        : _CyberColors.textPrimary;
    final textSecondary = _isNeoSkin
        ? _NeoColors.textSecondary
        : _CyberColors.textSecondary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: _appleCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: _isNeoSkin ? 0.12 : 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_formatInputNumber(item.totalQuantity)} und',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InventoryMetaLine(
            icon: Icons.warehouse,
            text: 'Bodegas: ${item.warehousesLabel}',
            color: textSecondary,
          ),
          const SizedBox(height: 6),
          _InventoryMetaLine(
            icon: Icons.payments,
            text:
                'Compra promedio: ${formatCop(item.averagePurchaseValue.round())} | Venta actual: ${formatCop(item.lastSaleValue.round())} | Movimientos: ${item.movements}',
            color: textSecondary,
          ),
          const SizedBox(height: 6),
          _InventoryUserMetaLine(
            icon: Icons.history,
            prefix:
                'Ultimo movimiento: ${_formatDateTimeLabel(item.lastMovementAt)} por ',
            username: item.lastCreatedBy,
            color: textSecondary,
            accent: accent,
          ),
        ],
      ),
    );
  }
}

class _InventoryUserMetaLine extends StatelessWidget {
  const _InventoryUserMetaLine({
    required this.icon,
    required this.prefix,
    required this.username,
    required this.color,
    required this.accent,
  });

  final IconData icon;
  final String prefix;
  final String username;
  final Color color;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.9)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: color,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
              children: [
                TextSpan(text: prefix),
                TextSpan(
                  text: username.trim().isEmpty ? 'Usuario' : username,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InventoryMetaLine extends StatelessWidget {
  const _InventoryMetaLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _InventoryAggregate {
  _InventoryAggregate({
    required this.productName,
    required this.totalQuantity,
    required this.totalPurchaseValue,
    required this.lastSaleValue,
    required this.movements,
    required this.lastMovementAt,
    required this.lastCreatedBy,
    required Map<String, double> warehouses,
  }) : warehouses = Map<String, double>.from(warehouses);

  final String productName;
  double totalQuantity;
  double totalPurchaseValue;
  double lastSaleValue;
  int movements;
  String lastMovementAt;
  String lastCreatedBy;
  final Map<String, double> warehouses;

  factory _InventoryAggregate.fromItem(InventoryItemRecord item) {
    return _InventoryAggregate(
      productName: item.productName,
      totalQuantity: item.quantity,
      totalPurchaseValue: item.unitPurchaseValue * item.quantity,
      lastSaleValue: item.publicSaleValue,
      movements: 1,
      lastMovementAt: item.createdAt,
      lastCreatedBy: item.createdByUsername.trim().isEmpty
          ? 'Usuario no registrado'
          : item.createdByUsername.trim(),
      warehouses: {item.warehouse: item.quantity},
    );
  }

  void add(InventoryItemRecord item) {
    totalQuantity += item.quantity;
    totalPurchaseValue += item.unitPurchaseValue * item.quantity;
    lastSaleValue = item.publicSaleValue;
    movements++;
    warehouses[item.warehouse] =
        (warehouses[item.warehouse] ?? 0) + item.quantity;
    if (item.createdAt.compareTo(lastMovementAt) >= 0) {
      lastMovementAt = item.createdAt;
      lastCreatedBy = item.createdByUsername.trim().isEmpty
          ? 'Usuario no registrado'
          : item.createdByUsername.trim();
    }
  }

  double get averagePurchaseValue {
    if (totalQuantity <= 0) return 0;
    return totalPurchaseValue / totalQuantity;
  }

  String get warehousesLabel {
    final entries = warehouses.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((entry) => '${entry.key} (${_formatInputNumber(entry.value)})')
        .join(', ');
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final accent = _isNeoSkin ? _NeoColors.primary : _CyberColors.primary;
    final textPrimary = _isNeoSkin
        ? _NeoColors.textPrimary
        : _CyberColors.textPrimary;
    final textSecondary = _isNeoSkin
        ? _NeoColors.textSecondary
        : _CyberColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _appleCardDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(label, style: TextStyle(color: textSecondary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SalesSection extends StatefulWidget {
  const _SalesSection({
    required this.inventoryItems,
    required this.sales,
    required this.message,
    required this.onSave,
  });

  final List<InventoryItemRecord> inventoryItems;
  final List<SaleRecord> sales;
  final String? message;
  final Future<bool> Function(SaleDraft draft) onSave;

  @override
  State<_SalesSection> createState() => _SalesSectionState();
}

class _SalesSectionState extends State<_SalesSection> {
  final _searchController = TextEditingController();
  final _dateController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _priceController = TextEditingController();
  InventoryItemRecord? _selectedItem;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toIso8601String().split('T').first;
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dateController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.inventoryItems
        .where((item) => item.quantity > 0)
        .toList();
    final filteredItems = available
        .where(
          (item) => _smartMatches(_searchController.text, [
            item.productName,
            item.warehouse,
          ]),
        )
        .toList();
    final filteredSales = widget.sales
        .where(
          (sale) => _smartMatches(_searchController.text, [
            sale.productName,
            sale.warehouse,
          ]),
        )
        .toList();
    final lowStock = widget.inventoryItems
        .where((item) => item.quantity < 3)
        .toList();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cyberPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(number: '08', title: 'Registrar ventas'),
          const SizedBox(height: 18),
          if (lowStock.isNotEmpty) ...[
            _StockAlert(items: lowStock),
            const SizedBox(height: 14),
          ],
          _ListSearchBox(
            controller: _searchController,
            label: 'Buscar producto o venta',
            total: available.length,
            filtered: filteredItems.length,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<InventoryItemRecord>(
            initialValue: _selectedItem,
            dropdownColor: _CyberColors.card,
            decoration: _inputDecoration(
              label: 'Producto y bodega',
              hint: '',
              icon: Icons.inventory,
            ),
            items: filteredItems
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      '${item.productName} | ${item.warehouse} | ${_formatInputNumber(item.quantity)} und',
                    ),
                  ),
                )
                .toList(),
            onChanged: (item) {
              setState(() {
                _selectedItem = item;
                if (item != null) {
                  _priceController.text = _formatInputNumber(
                    item.publicSaleValue,
                  );
                }
              });
            },
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 3 : 1;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: columns == 1 ? 5.4 : 3.2,
                children: [
                  _saleField(
                    _dateController,
                    'Fecha de venta',
                    Icons.event,
                    true,
                  ),
                  _saleField(
                    _quantityController,
                    'Cantidad vendida',
                    Icons.numbers,
                    false,
                  ),
                  _saleField(
                    _priceController,
                    'Precio unitario venta',
                    Icons.payments,
                    false,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: Icon(_saving ? Icons.sync : Icons.point_of_sale),
            label: const Text('Registrar venta'),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 12),
            _PurchaseMessage(message: widget.message!),
          ],
          const SizedBox(height: 22),
          if (filteredSales.isEmpty)
            const Text(
              'Aun no hay ventas registradas.',
              style: TextStyle(color: _CyberColors.textSecondary),
            )
          else
            ...filteredSales.map(
              (sale) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: _fieldDecoration(),
                child: Text(
                  '${sale.soldAt} | ${sale.productName} | ${sale.warehouse} | ${_formatInputNumber(sale.quantity)} und | Total ${formatCop(sale.totalSaleValue.round())}',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _saleField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool text,
  ) {
    return TextField(
      controller: controller,
      keyboardType: text
          ? TextInputType.text
          : const TextInputType.numberWithOptions(decimal: true),
      style: _inputTextStyle(),
      decoration: _inputDecoration(
        label: label,
        hint: text ? 'YYYY-MM-DD' : '',
        icon: icon,
      ),
    );
  }

  Future<void> _submit() async {
    final item = _selectedItem;
    if (item == null) return;
    setState(() => _saving = true);
    final saved = await widget.onSave(
      SaleDraft(
        inventoryItemId: item.id,
        soldAt: _dateController.text.trim(),
        quantity: parseLocalizedNumber(_quantityController.text),
        unitSaleValue: parseLocalizedNumber(_priceController.text),
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) _selectedItem = null;
    });
  }
}

class _StockAlert extends StatelessWidget {
  const _StockAlert({required this.items});

  final List<InventoryItemRecord> items;

  @override
  Widget build(BuildContext context) {
    final names = items
        .take(4)
        .map(
          (item) =>
              '${item.productName} (${_formatInputNumber(item.quantity)})',
        )
        .join(', ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CyberColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _CyberColors.accent),
      ),
      child: Text(
        'Alerta de inventario bajo: $names',
        style: const TextStyle(
          color: _CyberColors.accent,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ViabilitiesList extends StatefulWidget {
  const _ViabilitiesList({
    required this.records,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkPurchased,
  });

  final List<AliExpressViabilityRecord> records;
  final ValueChanged<AliExpressViabilityRecord> onEdit;
  final ValueChanged<int> onDelete;
  final ValueChanged<AliExpressViabilityRecord> onMarkPurchased;

  @override
  State<_ViabilitiesList> createState() => _ViabilitiesListState();
}

class _ViabilitiesListState extends State<_ViabilitiesList> {
  static const _pageSize = 20;

  final _searchController = TextEditingController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _page = 0));
  }

  @override
  void didUpdateWidget(covariant _ViabilitiesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.records.length != widget.records.length) _page = 0;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) {
      return const Text(
        'Aun no hay viabilidades registradas.',
        style: TextStyle(color: _CyberColors.textSecondary),
      );
    }

    final query = _searchController.text;
    final filtered = widget.records.where((record) {
      return _smartMatches(query, [
        record.productName,
        record.draft.productLink,
        _formatInputNumber(record.draft.number),
      ]);
    }).toList();
    final pageCount = _pageCount(filtered.length, _pageSize);
    if (_page >= pageCount) _page = math.max(0, pageCount - 1);
    final visible = filtered.skip(_page * _pageSize).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ListSearchBox(
          controller: _searchController,
          label: 'Buscar viabilidad',
          total: widget.records.length,
          filtered: filtered.length,
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          const Text(
            'No encontre viabilidades con esa busqueda.',
            style: TextStyle(color: _CyberColors.textSecondary),
          )
        else ...[
          ...visible.map((record) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: _fieldDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${_formatInputNumber(record.draft.number)} ${record.productName}',
                          style: _strongTextStyle(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Unidad: ${formatCop(record.calculations.unitHomeCost.round())} | Libre comision: ${formatCop(record.calculations.commissionFreePrice.round())} | Viabilidad: ${record.calculations.viability.toStringAsFixed(2)}',
                          style: _supportTextStyle(),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Abrir producto',
                    onPressed: record.draft.productLink.trim().isEmpty
                        ? null
                        : () => openExternalUrl(record.draft.productLink),
                    icon: const Icon(
                      Icons.open_in_new,
                      color: _CyberColors.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: record.purchaseStatus == 'purchased'
                        ? 'Ya comprado'
                        : 'Marcar comprado',
                    onPressed: record.purchaseStatus == 'purchased'
                        ? null
                        : () => widget.onMarkPurchased(record),
                    icon: Icon(
                      record.purchaseStatus == 'purchased'
                          ? Icons.check_circle
                          : Icons.shopping_cart_checkout,
                      color: _CyberColors.primary,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: () => widget.onEdit(record),
                    icon: const Icon(Icons.edit, color: _CyberColors.secondary),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: () => widget.onDelete(record.id),
                    icon: const Icon(Icons.delete, color: _CyberColors.accent),
                  ),
                ],
              ),
            );
          }),
          _PaginationControls(
            page: _page,
            pageCount: pageCount,
            totalItems: filtered.length,
            pageSize: _pageSize,
            onPrevious: _page == 0 ? null : () => setState(() => _page--),
            onNext: _page >= pageCount - 1
                ? null
                : () => setState(() => _page++),
          ),
        ],
      ],
    );
  }
}

class _PurchaseMessage extends StatelessWidget {
  const _PurchaseMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final lower = message.toLowerCase();
    final success =
        lower.contains('correctamente') ||
        lower.contains('eliminad') ||
        lower.contains('recibido') ||
        lower.contains('comprado');
    final warning =
        lower.contains('alerta') ||
        lower.contains('viabilidad') ||
        lower.contains('menor') ||
        lower.contains('agot');
    final tone = success
        ? _AlertTone.success
        : warning
        ? _AlertTone.warning
        : _AlertTone.error;
    final color = switch (tone) {
      _AlertTone.success =>
        _isNeoSkin ? _NeoColors.success : _CyberColors.primary,
      _AlertTone.warning => const Color(0xfff8bb86),
      _AlertTone.error =>
        _isNeoSkin ? const Color(0xffef4444) : _CyberColors.accent,
    };
    final textColor = _isNeoSkin
        ? _NeoColors.textPrimary
        : _CyberColors.textPrimary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _isNeoSkin
            ? Colors.white.withValues(alpha: 0.45)
            : _CyberColors.card,
        borderRadius: BorderRadius.circular(_isNeoSkin ? 18 : 12),
        border: Border.all(color: color.withValues(alpha: 0.38)),
        boxShadow: _isNeoSkin
            ? const [
                BoxShadow(
                  color: _NeoColors.shadowDark,
                  blurRadius: 12,
                  offset: Offset(5, 5),
                ),
                BoxShadow(
                  color: _NeoColors.shadowLight,
                  blurRadius: 12,
                  offset: Offset(-5, -5),
                ),
              ]
            : [BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 18)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModalAlertIcon(tone: tone, color: color),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchasesList extends StatefulWidget {
  const _PurchasesList({
    required this.purchases,
    required this.onEdit,
    required this.onDelete,
  });

  final List<PurchaseRecord> purchases;
  final ValueChanged<PurchaseRecord> onEdit;
  final ValueChanged<int> onDelete;

  @override
  State<_PurchasesList> createState() => _PurchasesListState();
}

class _PurchasesListState extends State<_PurchasesList> {
  static const _pageSize = 20;

  final _searchController = TextEditingController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _page = 0));
  }

  @override
  void didUpdateWidget(covariant _PurchasesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.purchases.length != widget.purchases.length) _page = 0;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.purchases.isEmpty) {
      return const Text(
        'Aun no hay compras registradas.',
        style: TextStyle(color: _CyberColors.textSecondary),
      );
    }

    final query = _searchController.text;
    final filtered = widget.purchases.where((purchase) {
      return _smartMatches(query, [purchase.productName]);
    }).toList();
    final pageCount = _pageCount(filtered.length, _pageSize);
    if (_page >= pageCount) _page = math.max(0, pageCount - 1);
    final visible = filtered.skip(_page * _pageSize).take(_pageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ListSearchBox(
          controller: _searchController,
          label: 'Buscar compra',
          total: widget.purchases.length,
          filtered: filtered.length,
        ),
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          const Text(
            'No encontre compras con esa busqueda.',
            style: TextStyle(color: _CyberColors.textSecondary),
          )
        else ...[
          ...visible.map((purchase) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: _fieldDecoration(),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(purchase.productName, style: _strongTextStyle()),
                        const SizedBox(height: 4),
                        Text(
                          'Unidad: ${formatCop(purchase.calculations.unitHomeCost.round())} | Comparacion: ${purchase.calculations.comparison.toStringAsFixed(2)}',
                          style: _supportTextStyle(),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: () => widget.onEdit(purchase),
                    icon: const Icon(Icons.edit, color: _CyberColors.secondary),
                  ),
                  IconButton(
                    tooltip: 'Eliminar',
                    onPressed: () => widget.onDelete(purchase.id),
                    icon: const Icon(Icons.delete, color: _CyberColors.accent),
                  ),
                ],
              ),
            );
          }),
          _PaginationControls(
            page: _page,
            pageCount: pageCount,
            totalItems: filtered.length,
            pageSize: _pageSize,
            onPrevious: _page == 0 ? null : () => setState(() => _page--),
            onNext: _page >= pageCount - 1
                ? null
                : () => setState(() => _page++),
          ),
        ],
      ],
    );
  }
}

class _ListSearchBox extends StatelessWidget {
  const _ListSearchBox({
    required this.controller,
    required this.label,
    required this.total,
    required this.filtered,
  });

  final TextEditingController controller;
  final String label;
  final int total;
  final int filtered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          style: _inputTextStyle(),
          decoration: _inputDecoration(
            label: label,
            hint: 'Ej: Zapato, perros, audifonos...',
            icon: Icons.search,
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar busqueda',
                    onPressed: controller.clear,
                    icon: const Icon(
                      Icons.close,
                      color: _CyberColors.textSecondary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          filtered == total
              ? '$total registros'
              : '$filtered de $total registros',
          style: const TextStyle(color: _CyberColors.textSecondary),
        ),
      ],
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.page,
    required this.pageCount,
    required this.totalItems,
    required this.pageSize,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int pageCount;
  final int totalItems;
  final int pageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : (page * pageSize) + 1;
    final end = math.min(totalItems, (page + 1) * pageSize);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Mostrando $start-$end de $totalItems | Pagina ${page + 1} de $pageCount',
            style: const TextStyle(color: _CyberColors.textSecondary),
          ),
          OutlinedButton.icon(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Anterior'),
          ),
          OutlinedButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Siguiente'),
          ),
        ],
      ),
    );
  }
}

class _LockedCriterion extends StatelessWidget {
  const _LockedCriterion({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final accent = _isNeoSkin ? _NeoColors.primary : _CyberColors.secondary;
    final textSecondary = _isNeoSkin
        ? _NeoColors.textSecondary
        : _CyberColors.textSecondary;
    return Container(
      constraints: const BoxConstraints(minWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: _fieldDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 9),
          Text(
            '$label: ',
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.w700),
          ),
          Text(value, style: _strongTextStyle()),
          const SizedBox(width: 8),
          Icon(Icons.lock, size: 15, color: textSecondary),
        ],
      ),
    );
  }
}

class _DropdownCriterion<T> extends StatelessWidget {
  const _DropdownCriterion({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.format,
  });

  final IconData icon;
  final String label;
  final T value;
  final List<T> options;
  final ValueChanged<T?> onChanged;
  final String Function(T value) format;

  @override
  Widget build(BuildContext context) {
    final accent = _isNeoSkin ? _NeoColors.primary : _CyberColors.secondary;
    final textPrimary = _isNeoSkin
        ? _NeoColors.textPrimary
        : _CyberColors.textPrimary;
    final textSecondary = _isNeoSkin
        ? _NeoColors.textSecondary
        : _CyberColors.textSecondary;
    return Container(
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 310),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _fieldDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '$label: ',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: _isNeoSkin
                  ? const Color(0xfff8fafc)
                  : _CyberColors.card,
              iconEnabledColor: _isNeoSkin
                  ? _NeoColors.primary
                  : _CyberColors.primary,
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.w900),
              items: options
                  .map(
                    (option) => DropdownMenuItem<T>(
                      value: option,
                      child: Text(
                        format(option),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _CyberBackground extends StatefulWidget {
  const _CyberBackground();

  @override
  State<_CyberBackground> createState() => _CyberBackgroundState();
}

class _CyberBackgroundState extends State<_CyberBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) =>
          CustomPaint(painter: _CyberBackgroundPainter(_controller.value)),
    );
  }
}

class _NeumorphicBackground extends StatelessWidget {
  const _NeumorphicBackground();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: _NeoColors.bg);
  }
}

class _CyberBackgroundPainter extends CustomPainter {
  const _CyberBackgroundPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _CyberColors.bgDark);

    final gridPaint = Paint()
      ..color = _CyberColors.primary.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    const gap = 42.0;
    final offset = (t * gap) % gap;
    for (double x = -gap + offset; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = -gap + offset; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final rainPaint = TextPainter(textDirection: TextDirection.ltr);
    const chars = ['0', '1', '{', '}', '/', '<', '>', '¥'];
    for (var i = 0; i < 80; i++) {
      final x = (i * 97) % math.max(size.width, 1);
      final y =
          ((i * 41) + t * size.height * (0.5 + (i % 5) * 0.08)) %
          math.max(size.height, 1);
      rainPaint.text = TextSpan(
        text: chars[i % chars.length],
        style: TextStyle(
          color: _CyberColors.primary.withValues(alpha: 0.08 + (i % 4) * 0.03),
          fontSize: 12 + (i % 3) * 2,
          fontWeight: FontWeight.w700,
        ),
      );
      rainPaint.layout();
      rainPaint.paint(canvas, Offset(x.toDouble(), y));
    }

    final scanPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.transparent, _CyberColors.primary, Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2))
      ..strokeWidth = 2;
    final scanY = (size.height * t * 1.3) % math.max(size.height, 1);
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), scanPaint);
  }

  @override
  bool shouldRepaint(covariant _CyberBackgroundPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

class PurchaseDraft {
  const PurchaseDraft({
    required this.productName,
    required this.priceUsd,
    required this.trm,
    required this.quantity,
    required this.originShippingUsd,
    required this.cardCommissionRate,
    required this.heightCm,
    required this.widthCm,
    required this.lengthCm,
    required this.boxCount,
    required this.cbmRate,
    required this.nationalFreight,
    required this.mercadoLibrePrice,
    required this.mercadoLibreCommissionRate,
  });

  static const fieldKeys = [
    'productName',
    'priceUsd',
    'trm',
    'quantity',
    'originShippingUsd',
    'cardCommissionRate',
    'heightCm',
    'widthCm',
    'lengthCm',
    'boxCount',
    'cbmRate',
    'nationalFreight',
    'mercadoLibrePrice',
    'mercadoLibreCommissionRate',
  ];

  final String productName;
  final double priceUsd;
  final double trm;
  final double quantity;
  final double originShippingUsd;
  final double cardCommissionRate;
  final double heightCm;
  final double widthCm;
  final double lengthCm;
  final double boxCount;
  final double cbmRate;
  final double nationalFreight;
  final double mercadoLibrePrice;
  final double mercadoLibreCommissionRate;

  Map<String, dynamic> toJson() {
    return {
      'productName': productName,
      'priceUsd': priceUsd,
      'trm': trm,
      'quantity': quantity,
      'originShippingUsd': originShippingUsd,
      'cardCommissionRate': cardCommissionRate,
      'heightCm': heightCm,
      'widthCm': widthCm,
      'lengthCm': lengthCm,
      'boxCount': boxCount,
      'cbmRate': cbmRate,
      'nationalFreight': nationalFreight,
      'mercadoLibrePrice': mercadoLibrePrice,
      'mercadoLibreCommissionRate': mercadoLibreCommissionRate,
    };
  }

  factory PurchaseDraft.fromJson(Map<String, dynamic> json) {
    double number(String key) => (json[key] as num? ?? 0).toDouble();
    return PurchaseDraft(
      productName: json['productName'] as String? ?? '',
      priceUsd: number('priceUsd'),
      trm: number('trm'),
      quantity: number('quantity'),
      originShippingUsd: number('originShippingUsd'),
      cardCommissionRate: number('cardCommissionRate'),
      heightCm: number('heightCm'),
      widthCm: number('widthCm'),
      lengthCm: number('lengthCm'),
      boxCount: number('boxCount'),
      cbmRate: number('cbmRate'),
      nationalFreight: number('nationalFreight'),
      mercadoLibrePrice: number('mercadoLibrePrice'),
      mercadoLibreCommissionRate: number('mercadoLibreCommissionRate'),
    );
  }
}

class PurchaseCalculations {
  const PurchaseCalculations({
    required this.priceCop,
    required this.totalMerchandiseCopChina,
    required this.originShippingCop,
    required this.totalCopChina,
    required this.cardCommissionCop,
    required this.cubicMeters,
    required this.freightAndNationalization,
    required this.importedProductCostBogota,
    required this.orderHomeCost,
    required this.unitHomeCost,
    required this.mlNetPrice,
    required this.comparison,
  });

  final double priceCop;
  final double totalMerchandiseCopChina;
  final double originShippingCop;
  final double totalCopChina;
  final double cardCommissionCop;
  final double cubicMeters;
  final double freightAndNationalization;
  final double importedProductCostBogota;
  final double orderHomeCost;
  final double unitHomeCost;
  final double mlNetPrice;
  final double comparison;

  factory PurchaseCalculations.fromDraft(PurchaseDraft draft) {
    final priceCop = draft.priceUsd * draft.trm;
    final totalMerchandiseCopChina = priceCop * draft.quantity;
    final originShippingCop = draft.originShippingUsd * draft.trm;
    final totalCopChina = originShippingCop + totalMerchandiseCopChina;
    final cardCommissionCop = totalCopChina * draft.cardCommissionRate;
    final cubicMeters =
        (draft.heightCm / 100) *
        (draft.widthCm / 100) *
        (draft.lengthCm / 100) *
        draft.boxCount;
    final freightAndNationalization = cubicMeters * draft.cbmRate;
    final importedProductCostBogota =
        totalCopChina + cardCommissionCop + freightAndNationalization;
    final orderHomeCost = importedProductCostBogota + draft.nationalFreight;
    final unitHomeCost = draft.quantity == 0
        ? 0.0
        : orderHomeCost / draft.quantity;
    final mlNetPrice =
        draft.mercadoLibrePrice -
        (draft.mercadoLibrePrice * draft.mercadoLibreCommissionRate);
    final comparison = unitHomeCost == 0 ? 0.0 : mlNetPrice / unitHomeCost;
    return PurchaseCalculations(
      priceCop: priceCop,
      totalMerchandiseCopChina: totalMerchandiseCopChina,
      originShippingCop: originShippingCop,
      totalCopChina: totalCopChina,
      cardCommissionCop: cardCommissionCop,
      cubicMeters: cubicMeters,
      freightAndNationalization: freightAndNationalization,
      importedProductCostBogota: importedProductCostBogota,
      orderHomeCost: orderHomeCost,
      unitHomeCost: unitHomeCost,
      mlNetPrice: mlNetPrice,
      comparison: comparison,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'priceCop': priceCop,
      'totalMerchandiseCopChina': totalMerchandiseCopChina,
      'originShippingCop': originShippingCop,
      'totalCopChina': totalCopChina,
      'cardCommissionCop': cardCommissionCop,
      'cubicMeters': cubicMeters,
      'freightAndNationalization': freightAndNationalization,
      'importedProductCostBogota': importedProductCostBogota,
      'orderHomeCost': orderHomeCost,
      'unitHomeCost': unitHomeCost,
      'mlNetPrice': mlNetPrice,
      'comparison': comparison,
    };
  }
}

class PurchaseRecord {
  const PurchaseRecord({
    required this.id,
    required this.productName,
    required this.draft,
    required this.calculations,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String productName;
  final PurchaseDraft draft;
  final PurchaseCalculations calculations;
  final String createdAt;
  final String updatedAt;

  PurchaseDraft toDraft() => draft;

  factory PurchaseRecord.fromDraft(int id, PurchaseDraft draft) {
    final now = DateTime.now().toIso8601String();
    return PurchaseRecord(
      id: id,
      productName: draft.productName,
      draft: draft,
      calculations: PurchaseCalculations.fromDraft(draft),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) {
    final draft = PurchaseDraft.fromJson(json);
    return PurchaseRecord(
      id: (json['id'] as num? ?? 0).round(),
      productName: json['productName'] as String? ?? '',
      draft: draft,
      calculations: PurchaseCalculations.fromDraft(draft),
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

class AliExpressViabilityDraft {
  const AliExpressViabilityDraft({
    required this.number,
    required this.productName,
    required this.productLink,
    required this.orderHomeCost,
    required this.quantity,
    required this.mercadoLibreTotalPrice,
    required this.meliCommissionRate,
  });

  static const fieldKeys = [
    'number',
    'productName',
    'productLink',
    'orderHomeCost',
    'quantity',
    'mercadoLibreTotalPrice',
    'meliCommissionRate',
  ];

  final double number;
  final String productName;
  final String productLink;
  final double orderHomeCost;
  final double quantity;
  final double mercadoLibreTotalPrice;
  final double meliCommissionRate;

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'productName': productName,
      'productLink': productLink,
      'orderHomeCost': orderHomeCost,
      'quantity': quantity,
      'mercadoLibreTotalPrice': mercadoLibreTotalPrice,
      'meliCommissionRate': meliCommissionRate,
    };
  }

  factory AliExpressViabilityDraft.fromJson(Map<String, dynamic> json) {
    double number(String key) => (json[key] as num? ?? 0).toDouble();
    return AliExpressViabilityDraft(
      number: number('number'),
      productName: json['productName'] as String? ?? '',
      productLink: json['productLink'] as String? ?? '',
      orderHomeCost: number('orderHomeCost'),
      quantity: number('quantity'),
      mercadoLibreTotalPrice: number('mercadoLibreTotalPrice'),
      meliCommissionRate: number('meliCommissionRate'),
    );
  }
}

class AliExpressViabilityCalculations {
  const AliExpressViabilityCalculations({
    required this.unitHomeCost,
    required this.commissionFreePrice,
    required this.viability,
  });

  final double unitHomeCost;
  final double commissionFreePrice;
  final double viability;

  factory AliExpressViabilityCalculations.fromDraft(
    AliExpressViabilityDraft draft,
  ) {
    final unitHomeCost = draft.quantity == 0
        ? 0.0
        : draft.orderHomeCost / draft.quantity;
    final commissionFreePrice =
        draft.mercadoLibreTotalPrice -
        (draft.mercadoLibreTotalPrice * draft.meliCommissionRate);
    final viability = unitHomeCost == 0
        ? 0.0
        : commissionFreePrice / unitHomeCost;
    return AliExpressViabilityCalculations(
      unitHomeCost: unitHomeCost,
      commissionFreePrice: commissionFreePrice,
      viability: viability,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'unitHomeCost': unitHomeCost,
      'commissionFreePrice': commissionFreePrice,
      'viability': viability,
    };
  }
}

class AliExpressViabilityRecord {
  const AliExpressViabilityRecord({
    required this.id,
    required this.productName,
    required this.draft,
    required this.calculations,
    required this.createdAt,
    required this.updatedAt,
    this.purchaseStatus = 'pending',
  });

  final int id;
  final String productName;
  final AliExpressViabilityDraft draft;
  final AliExpressViabilityCalculations calculations;
  final String createdAt;
  final String updatedAt;
  final String purchaseStatus;

  AliExpressViabilityDraft toDraft() => draft;

  factory AliExpressViabilityRecord.fromDraft(
    int id,
    AliExpressViabilityDraft draft,
  ) {
    final now = DateTime.now().toIso8601String();
    return AliExpressViabilityRecord(
      id: id,
      productName: draft.productName,
      draft: draft,
      calculations: AliExpressViabilityCalculations.fromDraft(draft),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory AliExpressViabilityRecord.fromJson(Map<String, dynamic> json) {
    final draft = AliExpressViabilityDraft.fromJson(json);
    return AliExpressViabilityRecord(
      id: (json['id'] as num? ?? 0).round(),
      productName: json['productName'] as String? ?? '',
      draft: draft,
      calculations: AliExpressViabilityCalculations.fromDraft(draft),
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      purchaseStatus: json['purchaseStatus'] as String? ?? 'pending',
    );
  }
}

enum _AlertTone { success, warning, error }

class _ModalAlertIcon extends StatefulWidget {
  const _ModalAlertIcon({required this.tone, required this.color});

  final _AlertTone tone;
  final Color color;

  @override
  State<_ModalAlertIcon> createState() => _ModalAlertIconState();
}

class _ModalAlertIconState extends State<_ModalAlertIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutBack.transform(_controller.value);
          return CustomPaint(
            painter: _ModalAlertPainter(
              tone: widget.tone,
              color: widget.color,
              progress: t,
              pulse: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _ModalAlertPainter extends CustomPainter {
  const _ModalAlertPainter({
    required this.tone,
    required this.color,
    required this.progress,
    required this.pulse,
  });

  final _AlertTone tone;
  final Color color;
  final double progress;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = color;
    if (tone == _AlertTone.warning) {
      canvas.drawCircle(
        center,
        radius + (pulse * 4),
        Paint()..color = color.withValues(alpha: 0.12 * (1 - pulse)),
      );
    }
    canvas.drawCircle(center, radius, ring);
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (tone == _AlertTone.success) {
      final p1 = Offset(size.width * .28, size.height * .53);
      final p2 = Offset(size.width * .43, size.height * .68);
      final p3 = Offset(size.width * .74, size.height * .35);
      final path = Path()..moveTo(p1.dx, p1.dy);
      if (progress < .55) {
        final local = progress / .55;
        path.lineTo(
          lerpDouble(p1.dx, p2.dx, local)!,
          lerpDouble(p1.dy, p2.dy, local)!,
        );
      } else {
        path.lineTo(p2.dx, p2.dy);
        final local = (progress - .55) / .45;
        path.lineTo(
          lerpDouble(p2.dx, p3.dx, local)!,
          lerpDouble(p2.dy, p3.dy, local)!,
        );
      }
      canvas.drawPath(path, mark);
    } else if (tone == _AlertTone.error) {
      final leftA = Offset(size.width * .34, size.height * .34);
      final leftB = Offset(size.width * .66, size.height * .66);
      final rightA = Offset(size.width * .66, size.height * .34);
      final rightB = Offset(size.width * .34, size.height * .66);
      canvas.drawLine(leftA, Offset.lerp(leftA, leftB, progress)!, mark);
      canvas.drawLine(rightA, Offset.lerp(rightA, rightB, progress)!, mark);
    } else {
      canvas.drawLine(
        Offset(size.width * .5, size.height * .25),
        Offset(size.width * .5, size.height * (.25 + .35 * progress)),
        mark,
      );
      canvas.drawCircle(
        Offset(size.width * .5, size.height * .73),
        2.8 + (1 - progress) * 2,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ModalAlertPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.pulse != pulse ||
        oldDelegate.color != color ||
        oldDelegate.tone != tone;
  }
}

class InventoryItemDraft {
  const InventoryItemDraft({
    required this.productName,
    required this.unitPurchaseValue,
    required this.quantity,
    required this.publicSaleValue,
    required this.loadedAt,
    required this.warehouse,
    this.status = 'available',
    this.sourceViabilityId,
  });

  final String productName;
  final double unitPurchaseValue;
  final double quantity;
  final double publicSaleValue;
  final String loadedAt;
  final String warehouse;
  final String status;
  final int? sourceViabilityId;

  Map<String, dynamic> toJson() {
    return {
      'productName': productName,
      'unitPurchaseValue': unitPurchaseValue,
      'quantity': quantity,
      'publicSaleValue': publicSaleValue,
      'loadedAt': loadedAt,
      'warehouse': warehouse,
      'status': status,
      'sourceViabilityId': sourceViabilityId,
    };
  }

  factory InventoryItemDraft.fromJson(Map<String, dynamic> json) {
    double number(String key) => (json[key] as num? ?? 0).toDouble();
    return InventoryItemDraft(
      productName: json['productName'] as String? ?? '',
      unitPurchaseValue: number('unitPurchaseValue'),
      quantity: number('quantity'),
      publicSaleValue: number('publicSaleValue'),
      loadedAt: json['loadedAt'] as String? ?? '',
      warehouse: json['warehouse'] as String? ?? '',
      status: json['status'] as String? ?? 'available',
      sourceViabilityId: (json['sourceViabilityId'] as num?)?.round(),
    );
  }
}

class InventoryItemRecord {
  const InventoryItemRecord({
    required this.id,
    required this.draft,
    required this.createdAt,
    required this.updatedAt,
    this.createdByUserId,
    this.createdByUsername = '',
  });

  final int id;
  final InventoryItemDraft draft;
  final String createdAt;
  final String updatedAt;
  final int? createdByUserId;
  final String createdByUsername;

  String get productName => draft.productName;
  double get unitPurchaseValue => draft.unitPurchaseValue;
  double get quantity => draft.quantity;
  double get publicSaleValue => draft.publicSaleValue;
  String get loadedAt => draft.loadedAt;
  String get warehouse => draft.warehouse;
  String get status => draft.status;
  int? get sourceViabilityId => draft.sourceViabilityId;
  String get statusLabel =>
      status == 'in_transit' ? 'En transito' : 'Disponible';

  factory InventoryItemRecord.fromDraft(int id, InventoryItemDraft draft) {
    final now = DateTime.now().toIso8601String();
    return InventoryItemRecord(
      id: id,
      draft: draft,
      createdAt: now,
      updatedAt: now,
      createdByUsername: '',
    );
  }

  factory InventoryItemRecord.fromJson(Map<String, dynamic> json) {
    return InventoryItemRecord(
      id: (json['id'] as num? ?? 0).round(),
      draft: InventoryItemDraft.fromJson(json),
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      createdByUserId: (json['createdByUserId'] as num?)?.round(),
      createdByUsername: json['createdByUsername'] as String? ?? '',
    );
  }
}

class SaleDraft {
  const SaleDraft({
    required this.inventoryItemId,
    required this.soldAt,
    required this.quantity,
    required this.unitSaleValue,
  });

  final int inventoryItemId;
  final String soldAt;
  final double quantity;
  final double unitSaleValue;

  Map<String, dynamic> toJson() {
    return {
      'inventoryItemId': inventoryItemId,
      'soldAt': soldAt,
      'quantity': quantity,
      'unitSaleValue': unitSaleValue,
    };
  }
}

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.inventoryItemId,
    required this.productName,
    required this.warehouse,
    required this.soldAt,
    required this.quantity,
    required this.unitSaleValue,
    required this.totalSaleValue,
    required this.remainingQuantity,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int inventoryItemId;
  final String productName;
  final String warehouse;
  final String soldAt;
  final double quantity;
  final double unitSaleValue;
  final double totalSaleValue;
  final double remainingQuantity;
  final String createdAt;
  final String updatedAt;

  factory SaleRecord.fromDraft(int id, SaleDraft draft) {
    final now = DateTime.now().toIso8601String();
    return SaleRecord(
      id: id,
      inventoryItemId: draft.inventoryItemId,
      productName: '',
      warehouse: '',
      soldAt: draft.soldAt,
      quantity: draft.quantity,
      unitSaleValue: draft.unitSaleValue,
      totalSaleValue: draft.quantity * draft.unitSaleValue,
      remainingQuantity: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    double number(String key) => (json[key] as num? ?? 0).toDouble();
    return SaleRecord(
      id: (json['id'] as num? ?? 0).round(),
      inventoryItemId: (json['inventoryItemId'] as num? ?? 0).round(),
      productName: json['productName'] as String? ?? '',
      warehouse: json['warehouse'] as String? ?? '',
      soldAt: json['soldAt'] as String? ?? '',
      quantity: number('quantity'),
      unitSaleValue: number('unitSaleValue'),
      totalSaleValue: number('totalSaleValue'),
      remainingQuantity: number('remainingQuantity'),
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

class SaleSaveResult {
  const SaleSaveResult({required this.sale, required this.lowStock});

  final SaleRecord sale;
  final bool lowStock;
}

class ProductResult {
  const ProductResult({
    required this.store,
    required this.title,
    required this.totalPrice,
    required this.rating,
    required this.sales,
    required this.shippingIncluded,
    required this.deliveryDays,
    required this.listingUrl,
    this.shippingKnown = true,
  });

  final StoreOption store;
  final String title;
  final int totalPrice;
  final double rating;
  final int sales;
  final bool shippingIncluded;
  final bool shippingKnown;
  final int deliveryDays;
  final String listingUrl;

  factory ProductResult.fromJson(Map<String, dynamic> json) {
    final storeName = (json['store'] as String? ?? '').toLowerCase();
    final store = StoreOption.values.firstWhere(
      (option) =>
          option.name == storeName || option.label.toLowerCase() == storeName,
      orElse: () => StoreOption.aliexpress,
    );
    return ProductResult(
      store: store,
      title: json['title'] as String? ?? '${store.label} resultado',
      totalPrice: (json['totalPrice'] as num? ?? 0).round(),
      rating: (json['rating'] as num? ?? 0).toDouble(),
      sales: (json['sales'] as num? ?? 0).round(),
      shippingIncluded: json['shippingIncluded'] == true,
      shippingKnown: json['shippingKnown'] == true,
      deliveryDays: (json['deliveryDays'] as num? ?? 0).round(),
      listingUrl: json['listingUrl'] as String? ?? '',
    );
  }

  bool isValid(SearchFilters filters) {
    final shippingOk =
        !shippingKnown || filters.shippingFilter.accepts(shippingIncluded);
    return listingUrl.isNotEmpty &&
        (rating == 0 || rating >= filters.minRating) &&
        (sales == 0 || sales >= filters.minSales) &&
        filters.stores.contains(store) &&
        shippingOk;
  }

  double score(SearchFilters filters) {
    final priceScore = totalPrice <= 0 ? 1 : 1000000 / totalPrice;
    final ratingScore = rating == 0 ? 20 : rating * 12;
    final salesScore = sales == 0 ? 8.0 : sales.clamp(0, 2000).toDouble() / 80;
    final shippingScore = shippingKnown
        ? filters.shippingFilter.score(shippingIncluded)
        : 4;
    return priceScore + ratingScore + salesScore + shippingScore;
  }

  String get ratingLabel {
    if (rating == 0) return 'calificacion no visible';
    return '$rating estrellas';
  }

  String get salesLabel {
    if (sales == 0) return 'ventas no visibles';
    return '$sales ventas';
  }

  String get deliveryLabel {
    if (deliveryDays == 0) return 'entrega no visible';
    return '$deliveryDays dias';
  }

  String get priceLabel {
    if (totalPrice <= 0) return 'precio no visible';
    return formatCop(totalPrice);
  }
}

extension ShippingFilterRules on ShippingFilter {
  bool accepts(bool shippingIncluded) {
    return switch (this) {
      ShippingFilter.included => shippingIncluded,
      ShippingFilter.notIncluded => !shippingIncluded,
      ShippingFilter.any => true,
    };
  }

  double score(bool shippingIncluded) {
    return switch (this) {
      ShippingFilter.included => shippingIncluded ? 10 : -20,
      ShippingFilter.notIncluded => shippingIncluded ? 0 : 6,
      ShippingFilter.any => shippingIncluded ? 8 : 2,
    };
  }

  String get statusLabel {
    return switch (this) {
      ShippingFilter.included => 'INCLUDED',
      ShippingFilter.notIncluded => 'NOT INCLUDED',
      ShippingFilter.any => 'BOTH OPTIONS',
    };
  }

  double get progressValue {
    return switch (this) {
      ShippingFilter.included => 1,
      ShippingFilter.notIncluded => 0.45,
      ShippingFilter.any => 0.72,
    };
  }
}

BoxDecoration _cyberPanelDecoration({double radius = 12, bool glow = false}) {
  if (_isNeoSkin) {
    return BoxDecoration(
      color: _NeoColors.surface,
      borderRadius: BorderRadius.circular(math.max(radius, 20)),
      boxShadow: [
        const BoxShadow(
          color: _NeoColors.shadowDark,
          blurRadius: 12,
          offset: Offset(6, 6),
        ),
        const BoxShadow(
          color: _NeoColors.shadowLight,
          blurRadius: 12,
          offset: Offset(-6, -6),
        ),
      ],
    );
  }
  return BoxDecoration(
    color: _CyberColors.card.withValues(alpha: 0.9),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _CyberColors.primary.withValues(alpha: 0.28)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.35),
        blurRadius: 30,
        offset: const Offset(0, 18),
      ),
      if (glow)
        BoxShadow(
          color: _CyberColors.primary.withValues(alpha: 0.18),
          blurRadius: 34,
        ),
    ],
  );
}

BoxDecoration _fieldDecoration() {
  if (_isNeoSkin) {
    return BoxDecoration(
      color: const Color(0xfff8fafc),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xffcbd5e1), width: 1.1),
      boxShadow: const [
        BoxShadow(
          color: _NeoColors.shadowDark,
          blurRadius: 10,
          offset: Offset(3, 3),
        ),
        BoxShadow(
          color: _NeoColors.shadowLight,
          blurRadius: 10,
          offset: Offset(-3, -3),
        ),
      ],
    );
  }
  return BoxDecoration(
    color: _CyberColors.bgDarker.withValues(alpha: 0.5),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: _CyberColors.border),
  );
}

BoxDecoration _applePanelDecoration() {
  if (_isNeoSkin) {
    return BoxDecoration(
      color: const Color(0xffeef2f7),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 28,
          offset: Offset(0, 18),
        ),
        BoxShadow(color: Colors.white, blurRadius: 16, offset: Offset(-8, -8)),
      ],
    );
  }
  return BoxDecoration(
    color: _CyberColors.card.withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: _CyberColors.primary.withValues(alpha: 0.24)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.35),
        blurRadius: 30,
        offset: const Offset(0, 18),
      ),
    ],
  );
}

BoxDecoration _appleCardDecoration() {
  if (_isNeoSkin) {
    return BoxDecoration(
      color: const Color(0xfff7f9fc),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
        BoxShadow(color: Colors.white, blurRadius: 10, offset: Offset(-5, -5)),
      ],
    );
  }
  return BoxDecoration(
    color: _CyberColors.bgDarker.withValues(alpha: 0.72),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _CyberColors.border.withValues(alpha: 0.8)),
  );
}

BoxDecoration _appleFloatingDecoration() {
  if (_isNeoSkin) {
    return BoxDecoration(
      color: const Color(0xfff8fafc),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 24,
          offset: Offset(0, 14),
        ),
      ],
    );
  }
  return BoxDecoration(
    color: const Color(0xff111827),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _CyberColors.secondary.withValues(alpha: 0.28)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.45),
        blurRadius: 26,
        offset: const Offset(0, 14),
      ),
    ],
  );
}

int _pageCount(int totalItems, int pageSize) {
  if (totalItems <= 0) return 1;
  return (totalItems / pageSize).ceil();
}

// Normaliza texto para que la busqueda sea util aunque el usuario escriba
// fragmentos, plurales simples, mayusculas o palabras con/sin tildes.
bool _smartMatches(String query, Iterable<String> values) {
  final normalizedQuery = _normalizeSearchText(query);
  if (normalizedQuery.isEmpty) return true;
  final haystack = values.map(_normalizeSearchText).join(' ');
  return normalizedQuery
      .split(' ')
      .where((token) => token.isNotEmpty)
      .every(haystack.contains);
}

String _normalizeSearchText(String value) {
  return value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

Uint8List? _avatarBytes(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  try {
    final payload = raw.contains(',') ? raw.split(',').last : raw;
    return base64Decode(payload);
  } catch (_) {
    return null;
  }
}

String? _passwordValidationError(String password, {bool allowEmpty = false}) {
  if (allowEmpty && password.isEmpty) return null;
  if (password.length < 8) {
    return 'La contrasena debe tener minimo 8 caracteres.';
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
      !RegExp(r'\d').hasMatch(password) ||
      !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
    return 'La contrasena debe incluir letras, numeros y un caracter especial.';
  }
  return null;
}

TextStyle _inputTextStyle() {
  return TextStyle(
    color: _isNeoSkin ? _NeoColors.textPrimary : _CyberColors.textPrimary,
    fontWeight: _isNeoSkin ? FontWeight.w800 : FontWeight.w500,
  );
}

TextStyle _strongTextStyle({double? fontSize}) {
  return TextStyle(
    color: _isNeoSkin ? _NeoColors.textPrimary : _CyberColors.textPrimary,
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
  );
}

TextStyle _supportTextStyle({double? fontSize, double? height}) {
  return TextStyle(
    color: _isNeoSkin ? _NeoColors.textSecondary : _CyberColors.textSecondary,
    fontSize: fontSize,
    height: height,
    fontWeight: _isNeoSkin ? FontWeight.w700 : FontWeight.w500,
  );
}

InputDecoration _inputDecoration({
  required String label,
  required String hint,
  required IconData icon,
  String? errorText,
  Widget? suffixIcon,
}) {
  if (_isNeoSkin) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffcbd5e1), width: 1.2),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _NeoColors.primary),
      suffixIcon: suffixIcon,
      errorText: errorText,
      errorStyle: const TextStyle(color: _CyberColors.accent),
      labelStyle: const TextStyle(
        color: _NeoColors.textSecondary,
        fontWeight: FontWeight.w800,
      ),
      floatingLabelStyle: const TextStyle(
        color: _NeoColors.primary,
        fontWeight: FontWeight.w900,
      ),
      hintStyle: const TextStyle(
        color: Color(0xff94a3b8),
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: const Color(0xfff8fafc),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _NeoColors.primary, width: 2),
      ),
      disabledBorder: border,
    );
  }
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon, color: _CyberColors.secondary),
    suffixIcon: suffixIcon,
    errorText: errorText,
    errorStyle: const TextStyle(color: _CyberColors.accent),
    labelStyle: const TextStyle(color: _CyberColors.textSecondary),
    hintStyle: const TextStyle(color: Color(0xff64748b)),
    filled: true,
    fillColor: _CyberColors.bgDarker.withValues(alpha: 0.65),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _CyberColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _CyberColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _CyberColors.primary, width: 2),
    ),
  );
}

double parseLocalizedNumber(String input) {
  var value = input
      .replaceAll('%', '')
      .replaceAll(r'$', '')
      .replaceAll('COP', '')
      .replaceAll('USD', '')
      .replaceAll(RegExp(r'\s'), '');
  if (value.isEmpty) return 0;

  final hasDot = value.contains('.');
  final hasComma = value.contains(',');
  if (hasDot && hasComma) {
    final decimalSeparator = value.lastIndexOf(',') > value.lastIndexOf('.')
        ? ','
        : '.';
    final groupSeparator = decimalSeparator == ',' ? '.' : ',';
    value = value
        .replaceAll(groupSeparator, '')
        .replaceAll(decimalSeparator, '.');
  } else if (hasDot || hasComma) {
    final separator = hasDot ? '.' : ',';
    final parts = value.split(separator);
    if (parts.length > 2) {
      value = parts.join();
    } else {
      final left = parts.first;
      final right = parts.length > 1 ? parts.last : '';
      final looksLikeThousands =
          right.length == 3 && left.isNotEmpty && left.length <= 3;
      value = looksLikeThousands ? '$left$right' : '$left.$right';
    }
  }

  return double.tryParse(value) ?? 0;
}

String _formatInputNumber(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value
      .toStringAsFixed(4)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _formatDateTimeLabel(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.isEmpty ? 'Sin fecha' : value;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} ${two(parsed.hour)}:${two(parsed.minute)}';
}

String _formatTrmInput(double value) {
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _formatRating(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String formatCop(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index++) {
    final fromRight = raw.length - index;
    buffer.write(raw[index]);
    if (fromRight > 1 && fromRight % 3 == 1) buffer.write('.');
  }
  return '\$${buffer.toString()} COP';
}
