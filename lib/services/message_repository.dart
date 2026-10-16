import 'package:flutter/foundation.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../models/shield_stats_model.dart';
import 'classifier_service.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

class MessageRepository extends ChangeNotifier {
  SpamClassifierService _classifierService;
  final SupabaseService _supabaseService = SupabaseService();
  final NotificationService _notificationService = NotificationService();

  final bool enableRemoteSync;

  MessageRepository({
    SpamClassifierService? classifierService,
    this.enableRemoteSync = true,
  }) : _classifierService = classifierService ?? HeuristicMockClassifierService() {
    _loadInitialDataset();
    if (enableRemoteSync) {
      _initServices();
    }
  }

  void updateClassifierService(SpamClassifierService service) {
    _classifierService = service;
    notifyListeners();
  }

  SpamClassifierService get classifierService => _classifierService;
  SupabaseService get supabaseService => _supabaseService;
  NotificationService get notificationService => _notificationService;

  List<ChatConversation> _conversations = [];
  String _searchQuery = '';
  MessageCategory? _selectedFilter; // null means 'All'

  List<ChatConversation> get conversations => List.unmodifiable(_conversations);
  String get searchQuery => _searchQuery;
  MessageCategory? get selectedFilter => _selectedFilter;

  /// Flat list of all messages across all conversations (sorted newest first)
  List<MessageItem> get allMessages {
    final List<MessageItem> all = [];
    for (final c in _conversations) {
      all.addAll(c.messages);
    }
    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return List.unmodifiable(all);
  }

  // Dynamic counts
  int get totalCount => allMessages.length;
  int get spamCount => allMessages.where((m) => m.category == MessageCategory.spam).length;
  int get notSpamCount => allMessages.where((m) => m.category == MessageCategory.notSpam).length;
  int get susCount => allMessages.where((m) => m.category == MessageCategory.sus).length;

  List<MessageItem> get filteredMessages {
    return allMessages.where((msg) {
      if (_selectedFilter != null && msg.category != _selectedFilter) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesSender = msg.sender.toLowerCase().contains(q);
        final matchesSnippet = msg.snippet.toLowerCase().contains(q);
        final matchesBody = msg.fullMessage.toLowerCase().contains(q);
        return matchesSender || matchesSnippet || matchesBody;
      }
      return true;
    }).toList();
  }

  List<ChatConversation> get filteredConversations {
    return _conversations.where((conv) {
      if (_selectedFilter != null && conv.overallCategory != _selectedFilter) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = conv.name.toLowerCase().contains(q);
        final matchesPhone = conv.phoneOrHandle.toLowerCase().contains(q);
        final matchesLastMsg =
            conv.latestMessage?.fullMessage.toLowerCase().contains(q) ?? false;
        return matchesName || matchesPhone || matchesLastMsg;
      }
      return true;
    }).toList();
  }

  void setFilter(MessageCategory? category) {
    _selectedFilter = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  ChatConversation? getConversation(String chatId) {
    try {
      return _conversations.firstWhere((c) => c.id == chatId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _initServices() async {
    try {
      await _supabaseService.initialize();
      await _notificationService.initialize();
      _setupSupabaseRealtime();
    } catch (e) {
      debugPrint('Initialization note: $e');
    }
  }

  void _setupSupabaseRealtime() {
    _supabaseService.subscribeToMessages((record) {
      final sender = record['sender'] as String? ?? '';
      final body = record['body'] as String? ?? '';
      final currentEmail = _supabaseService.currentUser?.email ?? '';

      // Skip messages sent from this exact account (already visible as outgoing)
      if (currentEmail.isNotEmpty && sender.toLowerCase() == currentEmail.toLowerCase()) {
        return;
      }

      if (body.isEmpty) return;

      // New message from another user/device:
      // Run ON-DEVICE Layer 1 rule scorer + pre-open notification gatekeeper!
      receiveIncomingMessage(
        chatId: sender,
        sender: sender,
        text: body,
      );
    });
  }

  /// Send an outgoing message in a WhatsApp chat conversation
  Future<MessageItem> sendOutgoingMessage({
    required String chatId,
    required String text,
    String? recipientName,
  }) async {
    final newItem = MessageItem(
      id: 'out_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'You',
      senderAvatarChar: 'Y',
      snippet: text.length > 55 ? '${text.substring(0, 52)}...' : text,
      fullMessage: text,
      category: MessageCategory.notSpam,
      riskPercentage: 0,
      statusDescription: 'Outgoing message sent by you.',
      reasons: const ['Outgoing user message'],
      timestamp: DateTime.now(),
      isOutgoing: true,
      chatId: chatId,
      isRead: true,
    );

    _appendMessageToChat(chatId, newItem, contactName: recipientName);
    notifyListeners();

    // Broadcast through Supabase messages table so the second device receives it in Realtime
    final conv = getConversation(chatId);
    final recipient = conv?.phoneOrHandle ?? chatId;
    _supabaseService.sendChatMessage(
      body: text,
      recipient: recipient,
    );

    return newItem;
  }

  /// Receive an incoming message locally in a chat conversation
  /// Classifies the message and enforces PRE-OPEN NOTIFICATION RULE:
  /// Only NOT SPAM messages trigger device notifications!
  Future<MessageItem> receiveIncomingMessage({
    required String chatId,
    required String sender,
    required String text,
    MessageCategory? overrideCategory,
  }) async {
    final knownContacts = _conversations.map((c) => c.name).toSet();
    final classification = await _classifierService.classify(
      text,
      sender: sender,
      metadata: {
        'known_contacts': knownContacts,
      },
    );

    final finalCategory = overrideCategory ?? classification.category;
    final risk = overrideCategory != null
        ? (overrideCategory == MessageCategory.spam
            ? 96
            : (overrideCategory == MessageCategory.sus ? 48 : 2))
        : classification.riskPercentage;

    final avatarChar = sender.isNotEmpty
        ? (finalCategory == MessageCategory.spam
            ? '!'
            : (finalCategory == MessageCategory.sus ? '?' : sender.trim()[0].toUpperCase()))
        : '?';

    final newItem = MessageItem(
      id: 'inc_${DateTime.now().millisecondsSinceEpoch}',
      sender: sender,
      senderAvatarChar: avatarChar,
      snippet: text.length > 55 ? '${text.substring(0, 52)}...' : text,
      fullMessage: text,
      category: finalCategory,
      riskPercentage: risk,
      statusDescription: classification.statusDescription,
      reasons: classification.reasons,
      maskedLinks: classification.maskedLinks,
      timestamp: DateTime.now(),
      isOutgoing: false,
      chatId: chatId,
      isRead: false,
      isVerifiedSender: finalCategory == MessageCategory.notSpam,
    );

    _appendMessageToChat(chatId, newItem);
    notifyListeners();

    // PRE-OPEN NOTIFICATION GATEKEEPER:
    // Only NOT SPAM messages trigger phone notifications!
    if (finalCategory == MessageCategory.notSpam) {
      await _notificationService.showSafeMessageNotification(newItem);
    } else {
      debugPrint('Notification suppressed: Message is ${finalCategory.name}. Quarantined silently.');
    }

    return newItem;
  }

  void _appendMessageToChat(String chatId, MessageItem message, {String? contactName}) {
    final index = _conversations.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      final conv = _conversations[index];
      final updatedMessages = List<MessageItem>.from(conv.messages)..add(message);
      _conversations[index] = conv.copyWith(messages: updatedMessages);
    } else {
      final name = contactName ?? (message.isOutgoing ? chatId : message.sender);
      final char = name.isNotEmpty ? name[0].toUpperCase() : '?';
      // Create new conversation
      final newConv = ChatConversation(
        id: chatId,
        name: name,
        phoneOrHandle: name,
        avatarChar: char,
        messages: [message],
      );
      _conversations.insert(0, newConv);
    }
  }

  void markChatAsRead(String chatId) {
    final index = _conversations.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      final conv = _conversations[index];
      final updated = conv.messages.map((m) => m.copyWith(isRead: true)).toList();
      _conversations[index] = conv.copyWith(messages: updated);
      notifyListeners();
    }
  }

  void blockContact(String chatId) {
    final index = _conversations.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      final conv = _conversations[index];
      final updated = conv.messages.map((m) => m.copyWith(isBlocked: true)).toList();
      _conversations[index] = conv.copyWith(messages: updated);
      notifyListeners();
    }
  }

  void markChatAsSafe(String chatId) {
    final index = _conversations.indexWhere((c) => c.id == chatId);
    if (index != -1) {
      final conv = _conversations[index];
      final updated = conv.messages.map((m) {
        if (m.category != MessageCategory.notSpam) {
          return m.copyWith(
            category: MessageCategory.notSpam,
            riskPercentage: 4,
            statusDescription: 'Marked safe by user. Normal message.',
          );
        }
        return m;
      }).toList();
      _conversations[index] = conv.copyWith(messages: updated);
      notifyListeners();
    }
  }

  void deleteSpamMessages() {
    for (int i = 0; i < _conversations.length; i++) {
      final conv = _conversations[i];
      final cleaned = conv.messages.where((m) => m.category != MessageCategory.spam).toList();
      _conversations[i] = conv.copyWith(messages: cleaned);
    }
    // Remove conversations that had only spam and now have 0 messages
    _conversations.removeWhere((c) => c.messages.isEmpty);
    notifyListeners();
  }

  void blockAndReport(String id) {
    _updateMessage(id, (old) => old.copyWith(isBlocked: true, category: MessageCategory.spam, riskPercentage: 96));
  }

  void markAsNotSpam(String id) {
    _updateMessage(id, (old) => old.copyWith(
      category: MessageCategory.notSpam,
      riskPercentage: 4,
      statusDescription: 'Marked safe by user. Normal message.',
      reasons: ['User approved sender', 'Manual safety override'],
    ));
  }

  void reportAsSpam(String id) {
    _updateMessage(id, (old) => old.copyWith(
      category: MessageCategory.spam,
      riskPercentage: 92,
      statusDescription: 'Reported as spam by user.',
      reasons: ['User flagged as unwanted message', 'Reported to community filter'],
    ));
  }

  void _updateMessage(String id, MessageItem Function(MessageItem old) transform) {
    for (int i = 0; i < _conversations.length; i++) {
      final conv = _conversations[i];
      final msgIdx = conv.messages.indexWhere((m) => m.id == id);
      if (msgIdx != -1) {
        final updatedMsgs = List<MessageItem>.from(conv.messages);
        updatedMsgs[msgIdx] = transform(updatedMsgs[msgIdx]);
        _conversations[i] = conv.copyWith(messages: updatedMsgs);
        notifyListeners();
        return;
      }
    }
  }

  /// Process message directly and add to repository
  Future<MessageItem> processAndAddMessage({
    required String sender,
    required String messageText,
  }) async {
    return receiveIncomingMessage(
      chatId: sender.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
      sender: sender,
      text: messageText,
    );
  }

  /// Initial dataset organized as WhatsApp-style chat conversations
  void _loadInitialDataset() {
    _conversations = [
      ChatConversation(
        id: 'vk_kyc',
        name: 'VK-KYCTEAM',
        phoneOrHandle: 'VK-KYCTEAM',
        avatarChar: '!',
        messages: [
          MessageItem(
            id: 'm_kyc_1',
            sender: 'VK-KYCTEAM',
            senderAvatarChar: '!',
            snippet: 'URGENT: Your Bank account will be suspended in 24 hours. Update KYC immediately.',
            fullMessage: 'URGENT: Your Bank account will be suspended in 24 hours. Update KYC immediately. Tap http://bit.ly/bank-kyc to verify your identity now.',
            category: MessageCategory.spam,
            riskPercentage: 96,
            statusDescription: 'Blocked before opening. Do not tap links or share OTPs.',
            reasons: const ['Urgent deadline pressure', 'Suspicious verification link'],
            maskedLinks: const ['http://bit.ly/bank-kyc'],
            timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
            chatId: 'vk_kyc',
            isRead: false,
          ),
        ],
      ),
      ChatConversation(
        id: 'parcel_scam',
        name: 'FastTrack Courier',
        phoneOrHandle: '+1 800 555-0199',
        avatarChar: '!',
        messages: [
          MessageItem(
            id: 'm_parcel_1',
            sender: 'FastTrack Courier',
            senderAvatarChar: '!',
            snippet: 'Your package is on hold due to missing address fee of \$2.40.',
            fullMessage: 'Your package is on hold due to missing address fee of \$2.40. Tap link to pay and reschedule delivery.',
            category: MessageCategory.spam,
            riskPercentage: 94,
            statusDescription: 'Blocked before opening. Do not tap links or share OTPs.',
            reasons: const ['Unsolicited fee request', 'Delivery scam pattern'],
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
            chatId: 'parcel_scam',
            isRead: false,
          ),
        ],
      ),
      ChatConversation(
        id: 'lottery_scam',
        name: 'MegaPrize Global',
        phoneOrHandle: 'winner@lottery-claim.org',
        avatarChar: '!',
        messages: [
          MessageItem(
            id: 'm_lottery_1',
            sender: 'MegaPrize Global',
            senderAvatarChar: '!',
            snippet: 'You won \$50,000 lottery! Call back now to claim.',
            fullMessage: 'You won \$50,000 lottery! Call back now to claim your prize before deadline.',
            category: MessageCategory.spam,
            riskPercentage: 98,
            statusDescription: 'Blocked before opening. Do not tap links or share OTPs.',
            reasons: const ['Advance fee fraud', 'Unrealistic prize promise'],
            timestamp: DateTime.now().subtract(const Duration(hours: 4)),
            chatId: 'lottery_scam',
            isRead: false,
          ),
        ],
      ),
      ChatConversation(
        id: 'unknown_crypto',
        name: 'Unknown (+1 555-0192)',
        phoneOrHandle: '+1 (555) 019-2849',
        avatarChar: '?',
        messages: [
          MessageItem(
            id: 'm_crypto_1',
            sender: 'Unknown (+1 555-0192)',
            senderAvatarChar: '?',
            snippet: '🎉 Congratulations! You have been selected for 0.5 BTC air-drop!',
            fullMessage: '🎉 Congratulations! You have been selected for 0.5 BTC air-drop! Join telegram t.me/free_crypto_claim immediately to verify wallet keys before slot closes.',
            category: MessageCategory.sus,
            riskPercentage: 48,
            statusDescription: 'High risk promotional scheme detected. External Telegram redirect link.',
            reasons: const [
              'Contains cryptocurrency reward lure',
              'External channel redirect: t.me link',
              'Artificial time urgency'
            ],
            maskedLinks: const ['t.me/free_crypto_claim'],
            timestamp: DateTime.now().subtract(const Duration(hours: 6)),
            chatId: 'unknown_crypto',
            isRead: false,
          ),
        ],
      ),
      ChatConversation(
        id: 'rohan_sharma',
        name: 'Rohan Sharma',
        phoneOrHandle: '+91 98200 45678',
        avatarChar: 'R',
        isVerified: true,
        isOnline: true,
        messages: [
          MessageItem(
            id: 'm_rohan_1',
            sender: 'Rohan Sharma',
            senderAvatarChar: 'R',
            snippet: 'Hey! Are we still syncing up for the review at 4 PM?',
            fullMessage: 'Hey! Are we still syncing up for the review at 4 PM? Let me know if you need the agenda document.',
            category: MessageCategory.notSpam,
            riskPercentage: 3,
            statusDescription: 'Direct contact with clean communication history.',
            reasons: const ['Known contact', 'Normal conversational language'],
            timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
            isVerifiedSender: true,
            isSavedContact: true,
            chatId: 'rohan_sharma',
            isRead: true,
          ),
        ],
      ),
      ChatConversation(
        id: 'mom',
        name: 'Mom',
        phoneOrHandle: '+91 94400 11223',
        avatarChar: 'M',
        isVerified: true,
        isOnline: true,
        messages: [
          MessageItem(
            id: 'm_mom_1',
            sender: 'Mom',
            senderAvatarChar: 'M',
            snippet: 'Dinner will be ready by 8. Remember groceries.',
            fullMessage: 'Dinner will be ready by 8. Remember to pick up groceries on your way back home.',
            category: MessageCategory.notSpam,
            riskPercentage: 2,
            statusDescription: 'Verified family contact.',
            reasons: const ['Saved contact', 'Everyday personal conversation'],
            timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
            isVerifiedSender: true,
            isSavedContact: true,
            chatId: 'mom',
            isRead: true,
          ),
        ],
      ),
      ChatConversation(
        id: 'hdfc_alert',
        name: 'HDFC Bank Alerts',
        phoneOrHandle: 'alerts@hdfcbank.com',
        avatarChar: 'H',
        isVerified: true,
        messages: [
          MessageItem(
            id: 'm_hdfc_1',
            sender: 'HDFC Bank Alerts',
            senderAvatarChar: 'H',
            snippet: 'Your HDFC account XXX4092 was debited for INR 1,250.00 at Swiggy.',
            fullMessage: 'Your HDFC account XXX4092 was debited for INR 1,250.00 at Swiggy on 16-Oct. Info: Not you? Call 1800-258-3838.',
            category: MessageCategory.notSpam,
            riskPercentage: 8,
            statusDescription: 'Legitimate transaction alert from official bank channel.',
            reasons: const ['Registered financial institution', 'No deceptive redirect URLs detected'],
            timestamp: DateTime.now().subtract(const Duration(hours: 3)),
            isVerifiedSender: true,
            chatId: 'hdfc_alert',
            isRead: true,
          ),
        ],
      ),
    ];
  }

  ShieldStats get shieldStats {
    return const ShieldStats(
      totalSpamStopped: 128,
      timeRange: 'This week',
      dailyStats: [
        DailySpamStat(dayName: 'Mon', count: 14),
        DailySpamStat(dayName: 'Tue', count: 22),
        DailySpamStat(dayName: 'Wed', count: 12),
        DailySpamStat(dayName: 'Thu', count: 28),
        DailySpamStat(dayName: 'Fri', count: 24),
        DailySpamStat(dayName: 'Sat', count: 16),
        DailySpamStat(dayName: 'Sun', count: 38, isCurrentDay: true),
      ],
      topSpamTypes: [
        SpamTypeStat(typeName: 'Fake KYC and bank', count: 46),
        SpamTypeStat(typeName: 'Parcel and delivery', count: 31),
        SpamTypeStat(typeName: 'Prize and lottery', count: 22),
        SpamTypeStat(typeName: 'Crypto & Job schemes', count: 18),
        SpamTypeStat(typeName: 'Phishing OTP request', count: 11),
      ],
      protectionBannerCount: 3,
    );
  }
}
