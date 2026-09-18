import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class NetworkStatusOverlay extends StatefulWidget {
  const NetworkStatusOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<NetworkStatusOverlay> createState() => _NetworkStatusOverlayState();
}

class _NetworkStatusOverlayState extends State<NetworkStatusOverlay>
    with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _offline = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateStatus,
    );
  }

  Future<void> _checkConnectivity() async {
    try {
      _updateStatus(await _connectivity.checkConnectivity());
    } catch (_) {}
  }

  void _updateStatus(List<ConnectivityResult> result) {
    if (!mounted) return;

    setState(() {
      _offline = !result.any(
            (item) => item != ConnectivityResult.none,
      );
      _ready = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkConnectivity();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _ready && _offline;
    final colors = Theme.of(context).colorScheme;

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, -1.15),
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: colors.outline.withOpacity(.28),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withOpacity(.18),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.clay.withOpacity(.12),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.cloud_off_rounded,
                                color: AppColors.clay,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                'You are offline. Changes will stay on this device.',
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
