import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../theme.dart';

class AppState extends ChangeNotifier {
  // ================================================================
  // AUTH / APP STATE
  // ================================================================

  bool isLoggedIn = false;
  bool isDarkMode = false;

  static const String _loggedInKey = 'karigarkart_logged_in';

  /// Restores the local login session before the application starts.
  ///
  /// The current KarigarKart authentication flow is local-only, so a
  /// persisted boolean is sufficient. No Firebase dependency is required.
  Future<void> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();

    isLoggedIn = preferences.getBool(_loggedInKey) ?? false;
  }

  void toggleDarkMode() {
    isDarkMode = !isDarkMode;
    notifyListeners();
  }

  String language = 'English';
  bool isChangingLanguage = false;
  String? draftImagePath;

  String profileName = 'Anshika Thakur';
  String businessName = 'Anshi Handicrafts';
  String contactInfo = '+91 9000000000';

  Product draft = Product(
    id: 'draft',
    title: '',
    description: '',
    price: 1499,
    category: 'Textiles',
    color: AppColors.clay,
    published: false,
  );

  final List<Product> products = [
    Product(
      id: '1',
      title: 'Indigo Block Print Stole',
      description:
      'Hand block printed cotton stole made with natural indigo dyes.',
      price: 1299,
      category: 'Textiles',
      color: const Color(0xFF426B93),
      stock: 4,
    ),
    Product(
      id: '2',
      title: 'Terracotta Planter',
      description:
      'Earthy, hand-thrown planter with a warm matte finish.',
      price: 899,
      category: 'Pottery',
      color: const Color(0xFFC86B42),
      stock: 7,
    ),
    Product(
      id: '3',
      title: 'Cane Storage Basket',
      description:
      'Durable handwoven cane basket for everyday spaces.',
      price: 1599,
      category: 'Basketry',
      color: const Color(0xFFB78A4A),
      stock: 2,
    ),
  ];

  // ================================================================
  // AUTH
  // ================================================================

  void login() {
    isLoggedIn = true;
    notifyListeners();

    // Persist the session without blocking the existing login animation.
    _saveLoginState(true);
  }

  void logout() {
    isLoggedIn = false;
    notifyListeners();

    // Remove the persisted session.
    _saveLoginState(false);
  }

  Future<void> _saveLoginState(bool value) async {
    try {
      final preferences = await SharedPreferences.getInstance();

      await preferences.setBool(
        _loggedInKey,
        value,
      );
    } catch (e) {
      debugPrint(
        'KarigarKart session persistence error: $e',
      );
    }
  }

  // ================================================================
  // LANGUAGE
  // ================================================================

  Future<void> setLanguage(String value) async {
    if (value == language) return;

    isChangingLanguage = true;
    notifyListeners();

    await Future.delayed(
      const Duration(milliseconds: 450),
    );

    language = value;
    isChangingLanguage = false;
    notifyListeners();
  }

  // ================================================================
  // PRODUCT DRAFT
  // ================================================================

  void setDraftImage(String path) {
    draftImagePath = path;
    notifyListeners();
  }

  void updateDraft({
    String? title,
    String? description,
    int? price,
    String? category,
  }) {
    if (title != null) {
      draft.title = title;
    }

    if (description != null) {
      draft.description = description;
    }

    if (price != null) {
      draft.price = price;
    }

    if (category != null) {
      draft.category = category;
    }

    notifyListeners();
  }

  void publishDraft() {
    draft.published = true;
    draft.id = DateTime.now().millisecondsSinceEpoch.toString();

    products.insert(0, draft);

    draft = Product(
      id: 'draft',
      title: '',
      description: '',
      price: 1499,
      category: 'Textiles',
      color: AppColors.clay,
      published: false,
    );

    draftImagePath = null;

    notifyListeners();
  }

  void saveProduct(Product product) {
    notifyListeners();
  }

  // ================================================================
  // PROFILE
  // ================================================================

  void updateProfile({
    required String name,
    required String business,
    required String contact,
  }) {
    profileName = name.trim();
    businessName = business.trim();
    contactInfo = contact.trim();

    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppScope>()!
        .notifier!;
  }
}