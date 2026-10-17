import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/device_message_service.dart';
import '../services/message_repository.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../widgets/filter_chip_bar.dart';
import 'auth_screen.dart';
import 'chat_conversation_screen.dart';
import 'compose_message_sheet.dart';
import 'message_detail_screen.dart';

class InboxScreen extends StatefulWidget {
  final MessageRepository repository;

  const InboxScreen({
    super.key,
    required this.repository,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  bool _hasNotifAccess = true;

  @override
  void initState() {
    super.initState();
    _checkNotificationAccess();
  }

  Future<void> _checkNotificationAccess() async {
    final access = await DeviceMessageService().hasNotificationAccess();
    if (mounted) {
      setState(() => _hasNotifAccess = access);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAuthScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AuthScreen(
          onAuthSuccess: () {
            setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final conversations = widget.repository.filteredConversations;
        final selectedFilter = widget.repository.selectedFilter;
        final isSpamFilterSelected = selectedFilter == MessageCategory.spam;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Top Header: ScamShield Chats + Search + Supabase Auth
                _buildHeader(context),

                // Phone Identity Bar
                _buildPhoneIdentityBar(),

                // Device SMS Sync & Protection Bar
                _buildDeviceProtectionBar(),

                // Notification Access prompt if not enabled
                if (!_hasNotifAccess) _buildNotificationAccessBanner(),

                // Search Bar (if opened)
                if (_isSearchOpen) _buildSearchBar(),

                // Status Banner (Spam Quarantined Alert or Shield Active)
                _buildStatusBanner(isSpamFilterSelected),

                const SizedBox(height: 12),

                // Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: FilterChipBar(
                    selectedCategory: selectedFilter,
                    totalCount: widget.repository.totalCount,
                    spamCount: widget.repository.spamCount,
                    susCount: widget.repository.susCount,
                    notSpamCount: widget.repository.notSpamCount,
                    onSelected: (cat) => widget.repository.setFilter(cat),
                  ),
                ),

                const SizedBox(height: 12),

                // WhatsApp-style Conversations List (Normal list items, no stretch effect)
                Expanded(
                  child: conversations.isEmpty
                      ? _buildEmptyState(selectedFilter)
                      : ListView.separated(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: conversations.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            thickness: 0.8,
                            color: AppColors.borderSubtle,
                          ),
                          itemBuilder: (context, index) {
                            final conv = conversations[index];
                            return _buildConversationTile(conv);
                          },
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => ComposeMessageSheet.show(context, widget.repository),
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            elevation: 3,
            tooltip: 'New Message',
            child: const Icon(Icons.edit_note_rounded, size: 26),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final supabaseUser = SupabaseService().currentUser;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'ScamShield',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'CHATS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Local AI Protection • Safe Notifications Only',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Search Toggle
          IconButton(
            icon: Icon(
              _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              setState(() {
                _isSearchOpen = !_isSearchOpen;
                if (!_isSearchOpen) {
                  _searchController.clear();
                  widget.repository.setSearchQuery('');
                }
              });
            },
          ),

          // Supabase Auth Profile Avatar / Login Button
          GestureDetector(
            onTap: _openAuthScreen,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: supabaseUser != null
                      ? const Color(0xFF2E7D32)
                      : AppColors.borderSubtle,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: supabaseUser != null
                    ? const Color(0xFFE8F5E9)
                    : AppColors.surface,
                child: Icon(
                  supabaseUser != null ? Icons.person_rounded : Icons.login_rounded,
                  size: 18,
                  color: supabaseUser != null
                      ? const Color(0xFF2E7D32)
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneIdentityBar() {
    final verifiedPhone = SupabaseService().verifiedPhone;
    final isVerified = verifiedPhone != null && verifiedPhone.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: InkWell(
        onTap: _openAuthScreen,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isVerified
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isVerified
                  ? const Color(0xFFA5D6A7)
                  : const Color(0xFFFFE082),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isVerified ? Icons.phone_android_rounded : Icons.phone_rounded,
                size: 16,
                color: isVerified ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isVerified
                      ? 'My Phone: $verifiedPhone'
                      : 'Tap to verify phone number & enable direct messaging',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isVerified
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFF57F17),
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 11,
                color: isVerified ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceProtectionBar() {
    final isSyncing = widget.repository.isSyncingDeviceSms;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.mark_chat_unread_rounded, size: 15, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Default Messages Protection',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Scanning SMS & silencing live spam notifications',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: isSyncing
                  ? null
                  : () async {
                      final count = await widget.repository.syncDeviceSms();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(count > 0
                                ? 'Protected & synced $count messages from default app'
                                : 'SMS inbox is already up to date'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSyncing)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    else
                      const Icon(Icons.sync_rounded, size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      isSyncing ? 'Syncing...' : 'Sync SMS',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationAccessBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      child: InkWell(
        onTap: () async {
          await DeviceMessageService().requestNotificationAccess();
          Future.delayed(const Duration(seconds: 2), _checkNotificationAccess);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFEDE7F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD1C4E9)),
          ),
          child: const Row(
            children: [
              Icon(Icons.notifications_active_rounded, size: 15, color: Color(0xFF5E35B1)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap to enable Notification Listener (Silences spam notifications in real-time)',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF5E35B1)),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Color(0xFF5E35B1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search chats, contacts, or message text...',
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    widget.repository.setSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderSubtle),
          ),
        ),
        onChanged: (val) => widget.repository.setSearchQuery(val),
      ),
    );
  }

  Widget _buildStatusBanner(bool isSpamFilterSelected) {
    final spamCount = widget.repository.spamCount;

    if (isSpamFilterSelected) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEEE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentRed.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.accentRed, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Quarantined Spam ($spamCount) • Notifications are strictly silenced',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentRed,
                ),
              ),
            ),
            TextButton(
              onPressed: () => widget.repository.deleteSpamMessages(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Clear All',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentRed,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Local AI Active: Only safe messages trigger phone notifications',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF15803D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(ChatConversation conv) {
    final latest = conv.latestMessage;
    final cat = conv.overallCategory;

    // Color requirements:
    // Red if spam: #FFFFEEEE
    // Yellow if sus: #FFFBEA
    // White if not spam: #FFFFFF
    Color cardBg;
    Color badgeBg;
    Color badgeTextColor;
    String badgeLabel;

    switch (cat) {
      case MessageCategory.spam:
        cardBg = const Color(0xFFFFEEEE); // RED
        badgeBg = const Color(0xFFFFCDD2);
        badgeTextColor = const Color(0xFFC62828);
        badgeLabel = 'SPAM';
        break;
      case MessageCategory.sus:
        cardBg = const Color(0xFFFFFBEA); // YELLOW
        badgeBg = const Color(0xFFFFE082);
        badgeTextColor = const Color(0xFFF57F17);
        badgeLabel = 'SUS';
        break;
      case MessageCategory.notSpam:
        cardBg = const Color(0xFFFFFFFF); // WHITE
        badgeBg = const Color(0xFFE8F5E9);
        badgeTextColor = const Color(0xFF2E7D32);
        badgeLabel = 'SAFE';
        break;
    }

    return InkWell(
      onTap: () {
        if (conv.overallCategory == MessageCategory.spam && latest != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => MessageDetailScreen(
                message: latest,
                repository: widget.repository,
              ),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ChatConversationScreen(
                chatId: conv.id,
                repository: widget.repository,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(
            left: BorderSide(
              color: cat == MessageCategory.spam
                  ? AppColors.spamBadgeText
                  : (cat == MessageCategory.sus
                      ? AppColors.susBadgeText
                      : Colors.transparent),
              width: cat != MessageCategory.notSpam ? 4 : 0,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Contact Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryDark.withValues(alpha: 0.1),
                  child: Text(
                    conv.avatarChar,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                if (conv.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF4CAF50),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Safety Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: badgeTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Time
                      if (latest != null)
                        Text(
                          _formatTime(latest.timestamp),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          latest != null ? latest.snippet : 'No messages',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: conv.unreadCount > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: conv.unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (conv.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF25D366), // WhatsApp green unread badge
                          ),
                          child: Text(
                            '${conv.unreadCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(MessageCategory? filter) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            filter == null
                ? 'No chats found'
                : 'No ${filter.filterLabel.toLowerCase()} chats',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Simulate an incoming message to test classification!',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inMinutes < 60) {
      return '${now.difference(dt).inMinutes}m ago';
    }
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
