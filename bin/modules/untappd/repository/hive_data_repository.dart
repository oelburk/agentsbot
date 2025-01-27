import 'package:hive/hive.dart';

import '../hive_constants.dart';
import 'data_repository.dart';

class HiveDataRepository implements DataRepository {
  late Box _box;

  @override
  Future<void> init() async {
    Hive.init('/data');
    _box = await Hive.openBox(HiveConstants.untappdBox);
  }

  @override
  Future<Map<String, int>> getUserList() async {
    return Map<String, int>.from(
      _box.get(HiveConstants.untappdUserList, defaultValue: {}) as Map,
    );
  }

  @override
  Future<void> setUserList(Map<String, int> users) async {
    await _box.put(HiveConstants.untappdUserList, users);
  }

  @override
  Future<Map<String, String>> getLatestCheckins() async {
    return Map<String, String>.from(
      _box.get(HiveConstants.untappdLatestUserCheckins, defaultValue: {})
          as Map,
    );
  }

  @override
  Future<void> setLatestCheckins(Map<String, String> latestCheckins) async {
    await _box.put(HiveConstants.untappdLatestUserCheckins, latestCheckins);
  }

  @override
  Future<int?> getUpdateChannelId() async {
    return _box.get(HiveConstants.untappdUpdateChannelId) as int?;
  }

  @override
  Future<void> setUpdateChannelId(int channelId) async {
    await _box.put(HiveConstants.untappdUpdateChannelId, channelId);
  }
}
