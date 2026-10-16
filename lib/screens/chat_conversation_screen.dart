import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/message_repository.dart';
import '../theme/app_colors.dart';
import 'message_detail_screen.dart';

class ChatConversationScreen extends StatefulWidget {
  final String chatId;
  final MessageRepository repository;

  const ChatConversationScreen({
    super.key,
    required this.chatId,
    required this.repository,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.repository.markChatAsRead(widget.chatId);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendOutgoing() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _textController.clear();

    await widget.repository.sendOutgoingMessage(
      chatId: widget.chatId,
      text: text,
    );

    setState(() => _isSending = false);
    _scrollToBottom();
  }



  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final conversation = widget.repository.getConversation(widget.chatId);
        if (conversation == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Chat')),
            body: const Center(child: Text('Conversation not found')),
          );
        }

        final messages = conversation.messages;
        final isSpamChat = conversation.overallCategory == MessageCategory.spam;
        final isSusChat = conversation.overallCategory == MessageCategory.sus;

        return Scaffold(
          backgroundColor: const Color(0xFFECE5DD), // WhatsApp chat background wallpaper tint
          appBar: _buildWhatsAppAppBar(conversation),
          body: Column(
            children: [
              // Security Warning Banner if Spam or Sus
              if (isSpamChat)
                _buildSecurityBanner(
                  icon: Icons.dangerous_rounded,
                  color: const Color(0xFFFFEEEE),
                  borderColor: AppColors.accentRed,
                  textColor: const Color(0xFFC62828),
                  title: 'ScamShield High Risk Warning',
                  subtitle:
                      'This conversation contains messages classified as SPAM. Do not share OTPs, click links, or transfer money.',
                  actionLabel: 'Block Contact',
                  onAction: () => widget.repository.blockContact(conversation.id),
                )
              else if (isSusChat)
                _buildSecurityBanner(
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFFFFBEA),
                  borderColor: const Color(0xFFFFB300),
                  textColor: const Color(0xFFF57F17),
                  title: 'Caution: Suspicious Signals Detected',
                  subtitle:
                      'Contains unverified links or urgency flags. Proceed carefully.',
                  actionLabel: 'Mark Safe',
                  onAction: () => widget.repository.markChatAsSafe(conversation.id),
                ),

              // Chat Messages Thread
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'No messages yet. Send a message or simulate incoming!',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        itemCount: messages.length,
                        itemBuilder: (ctx, index) {
                          final msg = messages[index];
                          return _buildMessageBubble(msg, conversation);
                        },
                      ),
              ),

              // Bottom Input Bar
              _buildBottomInputBar(conversation),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildWhatsAppAppBar(ChatConversation conversation) {
    Color statusColor;
    String statusText;
    if (conversation.overallCategory == MessageCategory.spam) {
      statusColor = AppColors.accentRed;
      statusText = 'Spam Quarantine';
    } else if (conversation.overallCategory == MessageCategory.sus) {
      statusColor = const Color(0xFFF57F17);
      statusText = 'Suspicious Contact';
    } else {
      statusColor = const Color(0xFF2E7D32);
      statusText = 'Safe • ScamShield Protected';
    }

    return AppBar(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      elevation: 1,
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              conversation.avatarChar,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Call',
          icon: const Icon(Icons.call_outlined, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          tooltip: 'More options',
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildSecurityBanner({
    required IconData icon,
    required Color color,
    required Color borderColor,
    required Color textColor,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              backgroundColor: textColor.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              actionLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageItem msg, ChatConversation conversation) {
    final isOutgoing = msg.isOutgoing;

    // Outgoing WhatsApp bubble: Soft light green/slate
    if (isOutgoing) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFDCF8C6), // Classic WhatsApp outgoing bubble
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                msg.fullMessage,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(msg.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_all_rounded,
                    size: 14,
                    color: Color(0xFF34B7F1), // WhatsApp blue double tick
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Incoming bubble:
    // Color requirements:
    // Red if spam: #FFFFEEEE
    // Yellow if sus: #FFFBEA
    // White if not spam: #FFFFFF
    Color bubbleColor;
    Color badgeColor;
    Color badgeTextColor;
    String badgeText;

    switch (msg.category) {
      case MessageCategory.spam:
        bubbleColor = const Color(0xFFFFEEEE); // RED
        badgeColor = const Color(0xFFFFCDD2);
        badgeTextColor = const Color(0xFFC62828);
        badgeText = 'SPAM • ${msg.riskPercentage}% RISK';
        break;
      case MessageCategory.sus:
        bubbleColor = const Color(0xFFFFFBEA); // YELLOW
        badgeColor = const Color(0xFFFFE082);
        badgeTextColor = const Color(0xFFF57F17);
        badgeText = 'SUS • ${msg.riskPercentage}% RISK';
        break;
      case MessageCategory.notSpam:
        bubbleColor = const Color(0xFFFFFFFF); // WHITE
        badgeColor = const Color(0xFFE8F5E9);
        badgeTextColor = const Color(0xFF2E7D32);
        badgeText = 'SAFE • NOT SPAM';
        break;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          // Open detail screen for reasons / masked links
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => MessageDetailScreen(
                message: msg,
                repository: widget.repository,
              ),
            ),
          );
        },
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82,
          ),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            border: Border.all(
              color: msg.category == MessageCategory.spam
                  ? AppColors.accentRed.withValues(alpha: 0.5)
                  : (msg.category == MessageCategory.sus
                      ? const Color(0xFFFFB300).withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.08)),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Safety Tag Badge
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: badgeTextColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Message Body
              Text(
                msg.fullMessage,
                style: const TextStyle(
                  fontSize: 14.5,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),

              // Timestamp & Info
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _formatTime(msg.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInputBar(ChatConversation conversation) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.textSecondary),
              tooltip: 'Attach',
              onPressed: () {},
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  onSubmitted: (_) => _sendOutgoing(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.primaryDark,
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: _isSending ? null : _sendOutgoing,
                icon: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
