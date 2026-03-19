import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../services/persistence_service.dart';
import '../core/utils/extensions.dart';

// ─────────────────────────────────────────────
// State
// ─────────────────────────────────────────────
class StoreState {
  final List<Store> stores;
  final List<Employee> employees;
  final String? activeStoreId;
  final Store? selectedStore;

  // Form fields
  final String newStoreName;
  final String newStoreAddress;
  final String newStorePhone;
  final String newStoreEmail;
  final String newStoreManager;

  const StoreState({
    this.stores = const [],
    this.employees = const [],
    this.activeStoreId,
    this.selectedStore,
    this.newStoreName = '',
    this.newStoreAddress = '',
    this.newStorePhone = '',
    this.newStoreEmail = '',
    this.newStoreManager = '',
  });

  // ── Computed ──────────────────────────────

  Store? get activeStore =>
      stores.where((s) => s.id == activeStoreId).firstOrNull;

  List<Employee> employeesForStore(String storeId) =>
      employees.where((e) => e.storeId == storeId).toList();

  bool get isAddStoreValid =>
      newStoreName.isNotEmpty &&
      newStoreAddress.isNotEmpty &&
      newStorePhone.isNotEmpty;

  StoreState copyWith({
    List<Store>? stores,
    List<Employee>? employees,
    String? activeStoreId,
    Store? selectedStore,
    bool clearSelectedStore = false,
    String? newStoreName,
    String? newStoreAddress,
    String? newStorePhone,
    String? newStoreEmail,
    String? newStoreManager,
  }) {
    return StoreState(
      stores: stores ?? this.stores,
      employees: employees ?? this.employees,
      activeStoreId: activeStoreId ?? this.activeStoreId,
      selectedStore: clearSelectedStore
          ? null
          : (selectedStore ?? this.selectedStore),
      newStoreName: newStoreName ?? this.newStoreName,
      newStoreAddress: newStoreAddress ?? this.newStoreAddress,
      newStorePhone: newStorePhone ?? this.newStorePhone,
      newStoreEmail: newStoreEmail ?? this.newStoreEmail,
      newStoreManager: newStoreManager ?? this.newStoreManager,
    );
  }
}

// ─────────────────────────────────────────────
// Notifier  (mirrors StoreViewModel)
// ─────────────────────────────────────────────
class StoreNotifier extends AsyncNotifier<StoreState> {
  final _persistence = PersistenceService.shared;

  @override
  Future<StoreState> build() async {
    await _persistence.seedInitialDataIfNeeded();
    final stores = await _persistence.loadStores();
    final employees = await _persistence.loadEmployees();
    return StoreState(
      stores: stores,
      employees: employees,
      activeStoreId: stores.isNotEmpty ? stores.first.id : null,
    );
  }

  // ── Form field setters ────────────────────

  void setNewStoreName(String v) =>
      _update((s) => s.copyWith(newStoreName: v));
  void setNewStoreAddress(String v) =>
      _update((s) => s.copyWith(newStoreAddress: v));
  void setNewStorePhone(String v) =>
      _update((s) => s.copyWith(newStorePhone: v));
  void setNewStoreEmail(String v) =>
      _update((s) => s.copyWith(newStoreEmail: v));
  void setNewStoreManager(String v) =>
      _update((s) => s.copyWith(newStoreManager: v));

  // ── Actions ───────────────────────────────

  Future<void> addStore() async {
    final s = state.value;
    if (s == null || !s.isAddStoreValid) return;

    final store = Store(
      id: const Uuid().v4(),
      name: s.newStoreName,
      address: s.newStoreAddress,
      phone: s.newStorePhone,
      email: s.newStoreEmail,
      manager: s.newStoreManager,
      employeeCount: 0,
      productCount: 0,
      monthlySales: 0,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final updated = [...s.stores, store];
    await _persistence.saveStores(updated);
    await HapticManager.success();
    _update((_) => s.copyWith(stores: updated).copyWith(
          newStoreName: '',
          newStoreAddress: '',
          newStorePhone: '',
          newStoreEmail: '',
          newStoreManager: '',
        ));
  }

  Future<void> deleteStore(Store store) async {
    final s = state.value;
    if (s == null) return;
    final updatedStores = s.stores.where((st) => st.id != store.id).toList();
    final updatedEmployees =
        s.employees.where((e) => e.storeId != store.id).toList();
    await _persistence.saveStores(updatedStores);
    await _persistence.saveEmployees(updatedEmployees);
    _update((_) =>
        s.copyWith(stores: updatedStores, employees: updatedEmployees));
  }

  void setActiveStore(Store store) =>
      _update((s) => s.copyWith(activeStoreId: store.id));

  void selectStore(Store? store) => _update((s) =>
      store == null ? s.copyWith(clearSelectedStore: true) : s.copyWith(selectedStore: store));

  void clearForm() => _update((s) => s.copyWith(
        newStoreName: '',
        newStoreAddress: '',
        newStorePhone: '',
        newStoreEmail: '',
        newStoreManager: '',
      ));

  // ── Private ───────────────────────────────

  void _update(StoreState Function(StoreState) fn) {
    final current = state.value;
    if (current != null) state = AsyncData(fn(current));
  }
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────
final storeProvider =
    AsyncNotifierProvider<StoreNotifier, StoreState>(StoreNotifier.new);
