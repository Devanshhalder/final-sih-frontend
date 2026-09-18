import 'dart:ui';

import 'package:flutter/material.dart';

import 'services/app_state.dart';
import 'services/ai_background_service.dart';
import 'services/app_localization.dart';
import 'services/app_transitions.dart';
import 'services/session_service.dart';
import 'services/profile_storage.dart';
import 'services/offline_request_queue.dart';
import 'widgets/network_status_overlay.dart';
import 'theme.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/business_dashboard_screen.dart';
import 'screens/add_product_screen.dart';
import 'screens/ai_flow_screens.dart';
import 'screens/catalog_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/market_linkage_screen.dart';
import 'screens/pricing_assistant_screen.dart';

String _tr(BuildContext context, String key) {
  return AppLocalization.text(AppScope.of(context).language, key);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  final loggedIn = await SessionService.isLoggedIn();
  if (loggedIn) state.login();
  final profile = await ProfileStorage.load();
  state.updateProfile(
    name: profile['name'] ?? 'USER',
    business: profile['shop'] ?? 'User handicrafts',
    contact: profile['contact'] ?? state.contactInfo,
  );
  await OfflineRequestQueue.initialize();
  if (AiBackgroundService.isBackgroundSupported) {
    await AiBackgroundService.initialize();
  }
  runApp(KarigarKartApp(state: state));
}

class KarigarKartApp extends StatelessWidget {
  const KarigarKartApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => AppScope(
        state: state,
        child: MaterialApp(
          title: 'KarigarKart',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          darkTheme: buildTheme(darkMode: true),
          themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          themeAnimationDuration: const Duration(milliseconds: 250),
          builder: (context, child) => NetworkStatusOverlay(
            child: ScrollConfiguration(
              behavior: const _AppScrollBehavior(),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: const EntryGate(),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/home':
                return KarigarPageRoute(settings: settings, beginOffset: const Offset(0, .012), builder: (_) => const MainShell());
              case '/add':
                return KarigarPageRoute(settings: settings, builder: (_) => const AddProductScreen());
              case '/language':
                return KarigarPageRoute(settings: settings, builder: (_) => const LanguageScreen());
              case '/processing':
                return KarigarPageRoute(settings: settings, builder: (_) => const ProcessingScreen());
              case '/preview':
                return KarigarPageRoute(settings: settings, builder: (_) => const ImagePreviewScreen());
              case '/listing':
                return KarigarPageRoute(settings: settings, builder: (_) => const ListingScreen());
              case '/publish':
                return KarigarPageRoute(settings: settings, builder: (_) => const PublishScreen());
              case '/catalog':
                return KarigarPageRoute(settings: settings, builder: (_) => const CatalogScreen());
              case '/market-linkage':
                return KarigarPageRoute(settings: settings, builder: (_) => const MarketLinkageScreen());
              case '/pricing-assistant':
                return KarigarPageRoute(settings: settings, builder: (_) => const PricingAssistantScreen());
              case '/profile':
                return KarigarPageRoute(settings: settings, builder: (_) => const ProfileScreen());
            }
            return null;
          },
          onUnknownRoute: (settings) => KarigarPageRoute(settings: settings, builder: (_) => const EntryGate()),
        ),
      ),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad};
}

class EntryGate extends StatelessWidget {
  const EntryGate({super.key});
  @override
  Widget build(BuildContext context) {
    final loggedIn = AppScope.of(context).isLoggedIn;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, .018), end: Offset.zero).animate(curved),
            child: ScaleTransition(scale: Tween<double>(begin: .992, end: 1).animate(curved), child: child),
          ),
        );
      },
      child: loggedIn ? const MainShell(key: ValueKey('main-shell')) : const AuthScreen(key: ValueKey('auth-screen')),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  int _previousIndex = 0;

  void _openAddProduct() => Navigator.pushNamed(context, '/add');

  @override
  Widget build(BuildContext context) {
    final pages = [const DashboardScreen(), const BusinessDashboardScreen(), const CatalogScreen(embedded: true), const ProfileScreen(embedded: true)];
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        reverseDuration: const Duration(milliseconds: 240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
          final direction = index >= _previousIndex ? 1.0 : -1.0;
          return FadeTransition(opacity: curved, child: SlideTransition(position: Tween<Offset>(begin: Offset(.045 * direction, .012), end: Offset.zero).animate(curved), child: ScaleTransition(scale: Tween<double>(begin: .985, end: 1).animate(curved), child: child)));
        },
        child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: index == 0 ? _AnimatedFab(onTap: _openAddProduct, icon: Icons.add_a_photo_outlined, label: _tr(context, 'addProduct')) : null,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          height: 76,
          decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: colors.outline, width: .7), boxShadow: [BoxShadow(color: Colors.black.withOpacity(theme.brightness == Brightness.dark ? .25 : .08), blurRadius: 22, offset: const Offset(0, 8))]),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (value) {
              if (value == index) return;
              setState(() { _previousIndex = index; index = value; });
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 76,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: _tr(context, 'home')),
              NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: _tr(context, 'dashboard')),
              NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: _tr(context, 'catalog')),
              NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: _tr(context, 'profile')),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedFab extends StatefulWidget {
  const _AnimatedFab({required this.onTap, required this.icon, required this.label});
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  @override
  State<_AnimatedFab> createState() => _AnimatedFabState();
}

class _AnimatedFabState extends State<_AnimatedFab> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _pressed = true),
    onTapCancel: () => setState(() => _pressed = false),
    onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
    child: AnimatedScale(
      scale: _pressed ? .95 : 1,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: FloatingActionButton.extended(
        heroTag: 'main_add_product_fab',
        onPressed: widget.onTap,
        backgroundColor: AppColors.clay,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: Icon(widget.icon),
        label: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    ),
  );
}
