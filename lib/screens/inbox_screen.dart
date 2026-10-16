import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../services/message_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/filter_chip_bar.dart';
import '../widgets/message_tile.dart';
import 'classify_tester_sheet.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.repository,
      builder: (context, _) {
        final messages = widget.repository.filteredMessages;
        final selectedFilter = widget.repository.selectedFilter;
        final isSpamFilterSelected = selectedFilter == MessageCategory.spam;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Top Header: ScamShield + Search + Test Button
                _buildHeader(context),

                // Search Bar (if opened)
                if (_isSearchOpen) _buildSearchBar(),

                // Status Banner (Blue in All/Safe, Pink in Spam)
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

                // Message List
                Expanded(
                  child: messages.isEmpty
                      ? _buildEmptyState(selectedFilter)
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: messages.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.borderSubtle,
                          ),
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            return MessageTile(
                              message: msg,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => MessageDetailScreen(
                                      message: msg,
                                      repository: widget.repository,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),

                // "Delete all spam" Button (Screen 4)
                if (isSpamFilterSelected && widget.repository.spamCount > 0)
                  _buildDeleteAllSpamButton(context),
              ],
            ),
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'inbox_send_fab',
                onPressed: () => ComposeMessageSheet.show(context, widget.repository),
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text(
                  'Send via Supabase',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
              FloatingActionButton.small(
                heroTag: 'inbox_tester_fab',
                onPressed: () => ClassifyTesterSheet.show(context, widget.repository),
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textPrimary,
                tooltip: 'Test Classifier',
                child: const Icon(Icons.bolt_rounded, size: 20),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ScamShield',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              // Send Pill
              GestureDetector(
                onTap: () => ComposeMessageSheet.show(context, widget.repository),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.send_rounded, size: 14, color: AppColors.textPrimary),
                      SizedBox(width: 5),
                      Text(
                        'Send',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Search Pill
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isSearchOpen = !_isSearchOpen;
                    if (!_isSearchOpen) {
                      _searchController.clear();
                      widget.repository.setSearchQuery('');
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isSearchOpen ? AppColors.surfaceMuted : AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                        size: 16,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSearchOpen ? 'Close' : 'Search',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search sender, phone, or keyword...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
          onChanged: (q) => widget.repository.setSearchQuery(q),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(bool isSpamSelected) {
    final spamCount = widget.repository.spamCount;
    final bgColor = isSpamSelected ? AppColors.spamBannerBg : AppColors.bannerBlueBg;
    final textColor = isSpamSelected ? AppColors.spamBannerText : AppColors.bannerBlueText;

    final String text = isSpamSelected
        ? '$spamCount spam messages stopped before you opened them'
        : 'Protection on · $spamCount spam messages moved to Spam today';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 14,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildDeleteAllSpamButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete All Spam?'),
                content: const Text(
                  'Are you sure you want to permanently delete all messages marked as spam?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.spamActionPrimary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      widget.repository.deleteSpamMessages();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All spam messages deleted'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.spamActionPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Delete all spam',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(MessageCategory? selectedFilter) {
    final label = selectedFilter != null ? selectedFilter.filterLabel : 'messages';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 48,
            color: AppColors.textMuted.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No $label found',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your inbox is clean and protected.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
