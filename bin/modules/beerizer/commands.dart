part of 'beerizer_module.dart';

ChatCommand _buildCommand(
    String name, String description, void Function(ChatContext) callback) {
  return ChatCommand(
    name,
    description,
    callback,
    options: CommandOptions(
      type: CommandType.slashOnly,
    ),
  );
}
