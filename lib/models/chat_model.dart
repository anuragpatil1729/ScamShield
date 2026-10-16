import 'message_model.dart';

class ChatConversation {
  final String id;
  final String name;
  final String phoneOrHandle;
  final String avatarChar;
  final bool isVerified;
  final bool isOnline;
  final List<MessageItem> messages;

  const ChatConversation({
    required this.id,
    required this.name,
    required this.phoneOrHandle,
    required this.avatarChar,
    this.isVerified = false,
    this.isOnline = false,
    this.messages = const [],
  });

  MessageItem? get latestMessage =>
      messages.isNotEmpty ? messages.last : null;

  int get unreadCount =>
      messages.where((m) => !m.isOutgoing && !m.isRead).length;

  MessageCategory get overallCategory {
    if (messages.any((m) => m.category == MessageCategory.spam)) {
      return MessageCategory.spam;
    }
    if (messages.any((m) => m.category == MessageCategory.sus)) {
      return MessageCategory.sus;
    }
    return MessageCategory.notSpam;
  }

  ChatConversation copyWith({
    String? id,
    String? name,
    String? phoneOrHandle,
    String? avatarChar,
    bool? isVerified,
    bool? isOnline,
    List<MessageItem>? messages,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneOrHandle: phoneOrHandle ?? this.phoneOrHandle,
      avatarChar: avatarChar ?? this.avatarChar,
      isVerified: isVerified ?? this.isVerified,
      isOnline: isOnline ?? this.isOnline,
      messages: messages ?? this.messages,
    );
  }
}
