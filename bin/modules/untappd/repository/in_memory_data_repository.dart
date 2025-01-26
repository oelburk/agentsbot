import 'data_repository.dart';

class InMemoryDataRepository implements DataRepository {
  Map<int, String> _userList = {};
  Map<String, String> _latestCheckins = {};
  int? _updateChannelId;

  @override
  Future<void> init() async {
    // No-op. Nothing to init for an in-memory store.
  }

  @override
  Future<Map<int, String>> getUserList() async {
    return _userList;
  }

  @override
  Future<void> setUserList(Map<int, String> users) async {
    _userList = users;
  }

  @override
  Future<Map<String, String>> getLatestCheckins() async {
    return _latestCheckins;
  }

  @override
  Future<void> setLatestCheckins(Map<String, String> latestCheckins) async {
    _latestCheckins = latestCheckins;
  }

  @override
  Future<int?> getUpdateChannelId() async {
    return _updateChannelId;
  }

  @override
  Future<void> setUpdateChannelId(int channelId) async {
    _updateChannelId = channelId;
  }
}
