import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// PageView container for [StatefulShellRoute] branch navigators.
class TabSwipeShell extends StatefulWidget {
  const TabSwipeShell({
    super.key,
    required this.navigationShell,
    required this.children,
    required this.visibleBranchIndices,
    required this.branchNavigatorKeys,
    this.authGatedVisibleIndices = const {},
    this.isAuthenticated = true,
    this.onAuthRequired,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;
  final List<int> visibleBranchIndices;
  final List<GlobalKey<NavigatorState>> branchNavigatorKeys;
  final Set<int> authGatedVisibleIndices;
  final bool isAuthenticated;
  final VoidCallback? onAuthRequired;

  @override
  State<TabSwipeShell> createState() => _TabSwipeShellState();
}

class _TabSwipeShellState extends State<TabSwipeShell> {
  late final PageController _pageController;
  bool _pageAnimating = false;
  int? _lastLightHapticPage;

  int get _visibleIndex {
    final i = widget.visibleBranchIndices.indexOf(
      widget.navigationShell.currentIndex,
    );
    return i < 0 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _visibleIndex);
  }

  @override
  void didUpdateWidget(covariant TabSwipeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = _visibleIndex;
    if (!_pageAnimating &&
        _pageController.hasClients &&
        (_pageController.page?.round() ?? _pageController.initialPage) !=
            target) {
      _animateTo(target);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _animateTo(int page, {int ms = 280}) async {
    if (!_pageController.hasClients) return;
    _pageAnimating = true;
    try {
      await _pageController.animateToPage(
        page,
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _pageAnimating = false;
    }
  }

  bool _activeBranchCanPop() {
    final branch = widget.navigationShell.currentIndex;
    if (branch < 0 || branch >= widget.branchNavigatorKeys.length) {
      return false;
    }
    final nav = widget.branchNavigatorKeys[branch].currentState;
    return nav?.canPop() ?? false;
  }

  void _onPageChanged(int visibleIndex) {
    if (_pageAnimating) return;

    if (!widget.isAuthenticated &&
        widget.authGatedVisibleIndices.contains(visibleIndex)) {
      widget.onAuthRequired?.call();
      _animateTo(_visibleIndex, ms: 220);
      return;
    }

    if (_lastLightHapticPage != visibleIndex) {
      _lastLightHapticPage = visibleIndex;
      HapticFeedback.lightImpact();
    }

    final branch = widget.visibleBranchIndices[visibleIndex];
    if (branch != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(branch, initialLocation: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[];
    for (final branchIndex in widget.visibleBranchIndices) {
      if (branchIndex >= 0 && branchIndex < widget.children.length) {
        pages.add(widget.children[branchIndex]);
      }
    }

    final hidden = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      if (!widget.visibleBranchIndices.contains(i)) {
        hidden.add(Offstage(offstage: true, child: widget.children[i]));
      }
    }

    final canPop = _activeBranchCanPop();

    return Stack(
      fit: StackFit.expand,
      children: [
        ...hidden,
        PageView(
          controller: _pageController,
          physics: canPop
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(parent: PageScrollPhysics()),
          onPageChanged: _onPageChanged,
          children: pages,
        ),
      ],
    );
  }
}
