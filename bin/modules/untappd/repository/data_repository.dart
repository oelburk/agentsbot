abstract class DataRepository {
  Future<void> init(); // For optional Hive init
  Future<Map<int, String>> getUserList();
  Future<void> setUserList(Map<int, String> users);

  Future<Map<String, String>> getLatestCheckins();
  Future<void> setLatestCheckins(Map<String, String> latestCheckins);

  Future<int?> getUpdateChannelId();
  Future<void> setUpdateChannelId(int channelId);
}
