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
  final bool isOutgoing;
  final String chatId;
  final bool isRead;

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
    this.isOutgoing = false,
    String? chatId,
    this.isRead = false,
  }) : chatId = chatId ?? sender;

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
    bool? isOutgoing,
    String? chatId,
    bool? isRead,
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
      isOutgoing: isOutgoing ?? this.isOutgoing,
      chatId: chatId ?? this.chatId,
      isRead: isRead ?? this.isRead,
    );
  }

  factory MessageItem.fromMap(Map<String, dynamic> map) {
    final catStr = (map['category'] as String?)?.toLowerCase() ?? 'not_spam';
    final MessageCategory cat;
    if (catStr == 'spam') {
      cat = MessageCategory.spam;
    } else if (catStr == 'sus') {
      cat = MessageCategory.sus;
    } else {
      cat = MessageCategory.notSpam;
    }

    final senderStr = (map['sender'] as String?) ?? 'Unknown';
    final avatarChar = cat == MessageCategory.spam
        ? '!'
        : (cat == MessageCategory.sus
            ? '?'
            : (senderStr.trim().isNotEmpty ? senderStr.trim()[0].toUpperCase() : '?'));

    List<String> parseList(dynamic val) {
      if (val is List) {
        return val.map((e) => e.toString()).toList();
      }
      return [];
    }

    DateTime parsedDate;
    if (map['created_at'] != null) {
      parsedDate = DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now();
    } else if (map['timestamp'] != null) {
      parsedDate = DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final bodyText = map['body']?.toString() ?? (map['fullMessage']?.toString() ?? '');
    final snippetText = map['snippet']?.toString() ??
        (bodyText.length > 55 ? '${bodyText.substring(0, 52)}...' : bodyText);

    return MessageItem(
      id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sender: senderStr,
      senderAvatarChar: avatarChar,
      snippet: snippetText,
      fullMessage: bodyText,
      category: cat,
      riskPercentage: (map['risk_percentage'] as num?)?.toInt() ?? 0,
      statusDescription: map['status_description']?.toString() ??
          (cat == MessageCategory.spam
              ? 'Blocked before opening. Do not tap links or share OTPs.'
              : (cat == MessageCategory.sus
                  ? 'Suspicious flags detected. Proceed with caution.'
                  : 'Looks like a normal message. Safe to open.')),
      reasons: parseList(map['reasons']),
      maskedLinks: parseList(map['masked_links']),
      timestamp: parsedDate,
      isVerifiedSender: cat == MessageCategory.notSpam,
      isSavedContact: cat == MessageCategory.notSpam,
      isBlocked: map['is_blocked'] as bool? ?? false,
      isOutgoing: map['is_outgoing'] as bool? ?? false,
      chatId: map['chat_id']?.toString() ?? senderStr,
      isRead: map['is_read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'snippet': snippet,
      'fullMessage': fullMessage,
      'category': category.name,
      'risk_percentage': riskPercentage,
      'status_description': statusDescription,
      'reasons': reasons,
      'masked_links': maskedLinks,
      'timestamp': timestamp.toIso8601String(),
      'is_verified': isVerifiedSender,
      'is_saved': isSavedContact,
      'is_blocked': isBlocked,
      'is_outgoing': isOutgoing,
      'chat_id': chatId,
      'is_read': isRead,
    };
  }
}
