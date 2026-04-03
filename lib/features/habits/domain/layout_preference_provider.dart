import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HomeLayout { cardList, iconGrid, rings }

class LayoutPreferenceNotifier extends AsyncNotifier<HomeLayout> {
  static const _key = 'home_layout';

  @override
  Future<HomeLayout> build() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_key);
    return HomeLayout.values.firstWhere(
      (e) => e.name == val,
      orElse: () => HomeLayout.cardList,
    );
  }

  Future<void> setLayout(HomeLayout layout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, layout.name);
    state = AsyncValue.data(layout);
  }
}

final layoutPreferenceProvider =
    AsyncNotifierProvider<LayoutPreferenceNotifier, HomeLayout>(
  LayoutPreferenceNotifier.new,
);
