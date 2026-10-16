import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/shield_stats_model.dart';
import 'classifier_service.dart';

class MessageRepository extends ChangeNotifier {
  SpamClassifierService _classifierService;

  MessageRepository({SpamClassifierService? classifierService})
      : _classifierService = classifierService ?? HeuristicMockClassifierService() {
    _loadInitialDataset();
  }

  void updateClassifierService(SpamClassifierService service) {
    _classifierService = service;
    notifyListeners();
  }

  SpamClassifierService get classifierService => _classifierService;

  List<MessageItem> _messages = [];
  String _searchQuery = '';
  MessageCategory? _selectedFilter; // null means 'All'

  List<MessageItem> get allMessages => List.unmodifiable(_messages);
  String get searchQuery => _searchQuery;
  MessageCategory? get selectedFilter => _selectedFilter;

  // Dynamic counts
  int get totalCount => _messages.length;
  int get spamCount => _messages.where((m) => m.category == MessageCategory.spam).length;
  int get notSpamCount => _messages.where((m) => m.category == MessageCategory.notSpam).length;
  int get susCount => _messages.where((m) => m.category == MessageCategory.sus).length;

  List<MessageItem> get filteredMessages {
    return _messages.where((msg) {
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

  void setFilter(MessageCategory? category) {
    _selectedFilter = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void deleteSpamMessages() {
    _messages.removeWhere((m) => m.category == MessageCategory.spam);
    notifyListeners();
  }

  void blockAndReport(String id) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(isBlocked: true);
      notifyListeners();
    }
  }

  void markAsNotSpam(String id) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index != -1) {
      final old = _messages[index];
      _messages[index] = old.copyWith(
        category: MessageCategory.notSpam,
        riskPercentage: 4,
        statusDescription: 'Marked safe by user. Normal message.',
        reasons: ['User approved sender', 'Manual safety override'],
      );
      notifyListeners();
    }
  }

  void reportAsSpam(String id) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index != -1) {
      final old = _messages[index];
      _messages[index] = old.copyWith(
        category: MessageCategory.spam,
        riskPercentage: 92,
        statusDescription: 'Reported as spam by user.',
        reasons: ['User flagged as unwanted message', 'Reported to community filter'],
      );
      notifyListeners();
    }
  }

  Future<MessageItem> processAndAddMessage({
    required String sender,
    required String messageText,
  }) async {
    final classification = await _classifierService.classify(
      messageText,
      sender: sender,
    );

    final avatarChar = sender.isNotEmpty
        ? (classification.category == MessageCategory.spam
            ? '!'
            : (classification.category == MessageCategory.sus ? '?' : sender.trim()[0].toUpperCase()))
        : '?';

    final newItem = MessageItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: sender,
      senderAvatarChar: avatarChar,
      snippet: messageText.length > 55 ? '${messageText.substring(0, 52)}...' : messageText,
      fullMessage: messageText,
      category: classification.category,
      riskPercentage: classification.riskPercentage,
      statusDescription: classification.statusDescription,
      reasons: classification.reasons,
      maskedLinks: classification.maskedLinks,
      timestamp: DateTime.now(),
      isSavedContact: classification.category == MessageCategory.notSpam,
      isVerifiedSender: classification.category == MessageCategory.notSpam,
    );

    _messages.insert(0, newItem);
    notifyListeners();
    return newItem;
  }

  // Dynamic Shield Statistics
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

  void _loadInitialDataset() {
    _messages = [
      MessageItem(
        id: 'msg-1',
        sender: 'VK-KYCTEAM',
        senderAvatarChar: '!',
        snippet: 'Your KYC expires today. Update now to avoid block',
        fullMessage:
            'Your KYC expires today. Update now to avoid account block: https://kyc-update-portal-auth.com/verify?id=98124',
        category: MessageCategory.spam,
        riskPercentage: 96,
        statusDescription: 'Blocked before opening. Do not tap links or share OTPs.',
        reasons: const [
          'Urgent deadline pressure',
          'Shortened link hides real address',
          'Sender ID not verified',
        ],
        maskedLinks: const ['https://kyc-update-portal-auth.com/verify?id=98124'],
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      MessageItem(
        id: 'msg-2',
        sender: '+91 98xxx 41207',
        senderAvatarChar: '!',
        snippet: 'You won a prize! Claim your reward within 1 hour',
        fullMessage:
            'Congratulations! You won a cash prize of ₹25,000 in Mega Lucky Draw! Claim your reward within 1 hour: http://claim-prize-now.biz/25k',
        category: MessageCategory.spam,
        riskPercentage: 88,
        statusDescription: 'Blocked before opening. Do not tap links or share OTPs.',
        reasons: const [
          'Unsolicited prize and lottery lure',
          'Artificial 1-hour urgency trigger',
          'Unregistered private mobile number',
        ],
        maskedLinks: const ['http://claim-prize-now.biz/25k'],
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      MessageItem(
        id: 'msg-3',
        sender: 'Parcel-Update',
        senderAvatarChar: '!',
        snippet: 'Delivery on hold, pay a small fee to release it',
        fullMessage:
            'Delivery on hold! Package #IN94821 requires ₹48 custom clearance fee to release it today. Pay now at: https://parcel-dispatch-fee.online',
        category: MessageCategory.spam,
        riskPercentage: 84,
        statusDescription: 'Blocked before opening. Do not tap links or share OTPs.',
        reasons: const [
          'Postal delivery fee extortion pattern',
          'Disguised payment gateway domain',
          'Untracked courier identifier',
        ],
        maskedLinks: const ['https://parcel-dispatch-fee.online'],
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      MessageItem(
        id: 'msg-4',
        sender: 'FastCrypto Telegram',
        senderAvatarChar: '?',
        snippet: 'Unusual link pattern · Verify sender identity',
        fullMessage:
            'Exclusive invite: Get 200% returns in 24 hours with AI Crypto signals. Join telegram t.me/fastcrypto_vip',
        category: MessageCategory.sus,
        riskPercentage: 62,
        statusDescription: 'Potential threat detected. Proceed with caution.',
        reasons: const [
          'High risk financial return guarantee',
          'Redirects to unmoderated third party chat',
          'Unrecognized international sender handle',
        ],
        maskedLinks: const ['t.me/fastcrypto_vip'],
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      MessageItem(
        id: 'msg-5',
        sender: 'Rohan',
        senderAvatarChar: 'R',
        snippet: 'Are we still on for dinner tonight?',
        fullMessage: 'Are we still on for dinner tonight?',
        category: MessageCategory.notSpam,
        riskPercentage: 4,
        statusDescription: 'Looks like a normal message. Safe to open.',
        reasons: const [
          'Saved contact',
          'No links or payment requests',
          'Normal conversation history',
        ],
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        isSavedContact: true,
      ),
      MessageItem(
        id: 'msg-6',
        sender: 'Mom',
        senderAvatarChar: 'M',
        snippet: 'Call me when you reach home',
        fullMessage: 'Call me when you reach home',
        category: MessageCategory.notSpam,
        riskPercentage: 2,
        statusDescription: 'Looks like a normal message. Safe to open.',
        reasons: const [
          'Saved contact (Family)',
          'High frequency conversation pattern',
          'No suspicious keywords or requests',
        ],
        timestamp: DateTime.now().subtract(const Duration(hours: 6)),
        isSavedContact: true,
      ),
      MessageItem(
        id: 'msg-7',
        sender: 'Bank alerts',
        senderAvatarChar: 'B',
        snippet: 'Verified sender · Salary credited',
        fullMessage:
            'Your account ending in XX8102 has been credited with ₹85,000 on 16-OCT-2026. Avail Bal: ₹1,42,390. - HDFC Bank',
        category: MessageCategory.notSpam,
        riskPercentage: 5,
        statusDescription: 'Looks like a normal message. Safe to open.',
        reasons: const [
          'Verified sender in authorized bank registry',
          'Standard transaction notification template',
          'No external links or urgent OTP demands',
        ],
        timestamp: DateTime.now().subtract(const Duration(hours: 8)),
        isVerifiedSender: true,
      ),
    ];
  }
}
