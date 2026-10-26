import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/app/providers.dart';
import 'package:spendwise/presentation/screens/analytics/analytics_screen.dart';
import 'package:spendwise/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:spendwise/presentation/screens/transactions/transactions_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final engine = ref.read(syncEngineProvider);
      engine.startLiveMonitoring();
      engine.startGmailPolling();
      unawaited(engine.onAppResumed());
      unawaited(_resumeSmsBackfillIfGranted());
    });
  }

  /// Scans SMS history when permission was granted in an earlier session.
  ///
  /// The engine is idempotent: a completed or running backfill returns
  /// immediately, so this is cheap on every resume.
  Future<void> _resumeSmsBackfillIfGranted() async {
    final source = ref.read(deviceMessageSourceProvider);
    if (!source.isSupported) return;
    try {
      final status = await ref.read(permissionServiceProvider).smsStatus();
      if (!mounted || !status.isGranted) return;
      await ref.read(syncEngineProvider).startSmsBackfillInBackground();
    } catch (_) {
      // Failures are surfaced by the sync status card.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final engine = ref.read(syncEngineProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(engine.onAppResumed());
        ref.invalidate(notificationAccessProvider);
        ref.invalidate(smsPermissionProvider);
        unawaited(_resumeSmsBackfillIfGranted());
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        engine.onAppPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(homeTabProvider);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: const <Widget>[
          DashboardScreen(),
          TransactionsScreen(),
          AnalyticsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            ref.read(homeTabProvider.notifier).state = value,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}
