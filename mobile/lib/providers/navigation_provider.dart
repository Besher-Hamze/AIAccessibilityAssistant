import 'package:flutter/material.dart';

/// App-wide navigation that both touch UI and the voice assistant drive.
class NavigationProvider extends ChangeNotifier {
  static const tabCount = 5;
  static const settingsTab = 4;

  final navigatorKey = GlobalKey<NavigatorState>();
  final List<ScrollController> _tabScroll =
      List.generate(tabCount, (_) => ScrollController());
  final List<ScrollController> _routeScroll = [];

  int _tab = 0;

  int get tab => _tab;
  bool get hasPushedRoute => _routeScroll.isNotEmpty;
  BuildContext? get context => navigatorKey.currentContext;

  ScrollController scrollFor(int tab) => _tabScroll[tab];

  void goTab(int index) {
    popToRoot();
    if (_tab == index) return;
    _tab = index;
    notifyListeners();
  }

  /// Pushes [page] with its own scroll controller so voice scrolling works on it.
  Future<T?> push<T>(Widget page) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return null;
    final controller = ScrollController();
    _routeScroll.add(controller);
    notifyListeners();
    final result = await nav.push<T>(
      MaterialPageRoute(
        builder: (_) => PrimaryScrollController(
          controller: controller,
          automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
          child: page,
        ),
      ),
    );
    _routeScroll.remove(controller);
    controller.dispose();
    notifyListeners();
    return result;
  }

  void popToRoot() {
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
  }

  /// Returns false when there is nothing to go back to.
  Future<bool> back() async {
    final nav = navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return true;
    }
    if (_tab != 0) {
      goTab(0);
      return true;
    }
    return false;
  }

  /// direction: 1 = down, -1 = up, 0 = top, 2 = bottom.
  /// Returns false if nothing scrolled.
  Future<bool> scroll(int direction) async {
    final controller =
        _routeScroll.isNotEmpty ? _routeScroll.last : _tabScroll[_tab];
    if (!controller.hasClients) return false;
    final pos = controller.positions.last;
    final double target = switch (direction) {
      0 => pos.minScrollExtent,
      2 => pos.maxScrollExtent,
      _ => (pos.pixels + direction * pos.viewportDimension * 0.75)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent),
    };
    if ((target - pos.pixels).abs() < 1) return false;
    await pos.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
    return true;
  }

  void reset() {
    popToRoot();
    _tab = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final c in _tabScroll) {
      c.dispose();
    }
    super.dispose();
  }
}
