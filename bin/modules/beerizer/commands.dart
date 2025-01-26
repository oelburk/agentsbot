part of 'beerizer_module.dart';

ChatCommand _buildCommand(String name, String description,
    void Function(InteractionChatContext) callback) {
  return ChatCommand(
    name,
    description,
    callback,
    options: CommandOptions(
      type: CommandType.slashOnly,
      autoAcknowledgeDuration: Duration(seconds: 3),
    ),
  );
}
