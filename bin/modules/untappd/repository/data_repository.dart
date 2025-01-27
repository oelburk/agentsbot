abstract class DataRepository {
  Future<void> init(); // For optional Hive init
  Future<Map<String, int>> getUserList();
  Future<void> setUserList(Map<String, int> users);

  Future<Map<String, String>> getLatestCheckins();
  Future<void> setLatestCheckins(Map<String, String> latestCheckins);

  Future<int?> getUpdateChannelId();
  Future<void> setUpdateChannelId(int channelId);
}
