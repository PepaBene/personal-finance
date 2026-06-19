import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../core/preferences/preferences_controller.dart';

/// Pure idle-lock policy (FR-SEC-05), separated from the widget so it can be
/// unit-tested. [minutes] of 0 disables auto-lock.
class IdleLockPolicy {
  const IdleLockPolicy(this.minutes);
  final int minutes;

  bool get enabled => minutes > 0;
  Duration? get timeout => enabled ? Duration(minutes: minutes) : null;

  /// Whether an idle span (e.g. time spent backgrounded) should trigger a lock.
  bool exceeded(Duration idle) => enabled && idle >= timeout!;
}

/// Wraps the in-app shell and locks the app after a configurable idle timeout or
/// when it returns from the background having idled past the timeout (FR-SEC-05).
/// Locking drops the in-memory DB key, which the router guard turns into a
/// redirect to the lock screen.
class AutoLockScope extends ConsumerStatefulWidget {
  const AutoLockScope({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<AutoLockScope> createState() => _AutoLockScopeState();
}

class _AutoLockScopeState extends ConsumerState<AutoLockScope>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _backgroundedAt;

  IdleLockPolicy get _policy =>
      IdleLockPolicy(ref.read(preferencesProvider).autoLockMinutes);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reschedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _reschedule() {
    _timer?.cancel();
    final timeout = _policy.timeout;
    if (timeout != null) _timer = Timer(timeout, _lock);
  }

  void _onActivity() {
    if (_policy.enabled) _reschedule();
  }

  void _lock() {
    _timer?.cancel();
    if (ref.read(databaseKeyProvider) == null) return; // already locked
    ref.read(appLockServiceProvider).lock();
    ref.read(databaseKeyProvider.notifier).state = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _timer?.cancel();
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null && _policy.exceeded(DateTime.now().difference(since))) {
          _lock();
        } else {
          _reschedule();
        }
      case AppLifecycleState.detached:
        _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reschedule whenever the timeout preference changes.
    ref.listen(
      preferencesProvider.select((p) => p.autoLockMinutes),
      (_, __) => _reschedule(),
    );
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _onActivity(),
      child: widget.child,
    );
  }
}
