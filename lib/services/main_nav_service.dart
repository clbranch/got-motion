/// Lets celebration flows and notification taps jump to a main-nav tab.
class MainNavService {
  MainNavService._();
  static final MainNavService instance = MainNavService._();

  void Function(int tabIndex)? selectTab;
  int? _pendingTab;

  void goToProfile() => goToTab(2);
  void goToGroup() => goToTab(3);

  void goToTab(int tabIndex) {
    final select = selectTab;
    if (select != null) {
      select(tabIndex);
    } else {
      _pendingTab = tabIndex;
    }
  }

  void bind(void Function(int tabIndex) select) {
    selectTab = select;
    final pending = _pendingTab;
    if (pending != null) {
      _pendingTab = null;
      select(pending);
    }
  }

  void unbind(void Function(int tabIndex) select) {
    if (selectTab == select) selectTab = null;
  }
}

final mainNavService = MainNavService.instance;
