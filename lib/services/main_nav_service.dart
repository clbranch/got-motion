/// Lets celebration flows jump to a main-nav tab (e.g. Profile).
class MainNavService {
  MainNavService._();
  static final MainNavService instance = MainNavService._();

  void Function(int tabIndex)? selectTab;

  void goToProfile() => selectTab?.call(2);
}

final mainNavService = MainNavService.instance;
