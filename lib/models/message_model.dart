enum MessageCategory {
  spam,
  notSpam,
  sus;

  String get displayName {
    switch (this) {
      case MessageCategory.spam:
        return 'SPAM';
      case MessageCategory.notSpam:
        return 'NOT SPAM';
      case MessageCategory.sus:
        return 'SUS';
    }
  }

  String get filterLabel {
    switch (this) {
      case MessageCategory.spam:
        return 'Spam';
      case MessageCategory.notSpam:
        return 'Not spam';
      case MessageCategory.sus:
        return 'Sus';
    }
  }
}

class MessageItem {
  final String id;
  final String sender;
  final String senderAvatarChar;
  final String snippet;
  final String fullMessage;
  final MessageCategory category;
  final int riskPercentage;
  final String statusDescription;
  final List<String> reasons;
  final List<String> maskedLinks;
  final DateTime timestamp;
  final bool isVerifiedSender;
  final bool isSavedContact;
  final bool isBlocked;

  const MessageItem({
    required this.id,
    required this.sender,
    required this.senderAvatarChar,
    required this.snippet,
    required this.fullMessage,
    required this.category,
    required this.riskPercentage,
    required this.statusDescription,
    required this.reasons,
    this.maskedLinks = const [],
    required this.timestamp,
    this.isVerifiedSender = false,
    this.isSavedContact = false,
    this.isBlocked = false,
  });

  MessageItem copyWith({
    String? id,
    String? sender,
    String? senderAvatarChar,
    String? snippet,
    String? fullMessage,
    MessageCategory? category,
    int? riskPercentage,
    String? statusDescription,
    List<String>? reasons,
    List<String>? maskedLinks,
    DateTime? timestamp,
    bool? isVerifiedSender,
    bool? isSavedContact,
    bool? isBlocked,
  }) {
    return MessageItem(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      senderAvatarChar: senderAvatarChar ?? this.senderAvatarChar,
      snippet: snippet ?? this.snippet,
      fullMessage: fullMessage ?? this.fullMessage,
      category: category ?? this.category,
      riskPercentage: riskPercentage ?? this.riskPercentage,
      statusDescription: statusDescription ?? this.statusDescription,
      reasons: reasons ?? this.reasons,
      maskedLinks: maskedLinks ?? this.maskedLinks,
      timestamp: timestamp ?? this.timestamp,
      isVerifiedSender: isVerifiedSender ?? this.isVerifiedSender,
      isSavedContact: isSavedContact ?? this.isSavedContact,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }
}
