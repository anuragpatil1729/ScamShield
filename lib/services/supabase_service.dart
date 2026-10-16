import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://pbmufkyjuopnfmhqbbbx.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBibXVma3lqdW9wbmZtaHFiYmJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIxNjU4ODAsImV4cCI6MjEwNzc0MTg4MH0.jyYH0giRfXj34UAkD3TMPzjgmHOrGdDPI_YzxJxWB3c';

  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SupabaseClient get client => Supabase.instance.client;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      _isInitialized = true;
    } catch (e) {
      // In case already initialized
      _isInitialized = true;
    }
  }

  /// Send a message by inserting it into the Supabase database
  Future<Map<String, dynamic>> sendMessage({
    required String sender,
    required String body,
    String subject = '',
    String snippet = '',
    MessageCategory category = MessageCategory.notSpam,
    int riskPercentage = 0,
    String statusDescription = '',
    List<String> reasons = const [],
    List<String> maskedLinks = const [],
  }) async {
    final categoryString = _categoryToString(category);
    final autoSnippet = snippet.isNotEmpty
        ? snippet
        : (body.length > 55 ? '${body.substring(0, 52)}...' : body);

    final response = await client
        .from('messages')
        .insert({
          'sender': sender,
          'subject': subject,
          'body': body,
          'snippet': autoSnippet,
          'category': categoryString,
          'risk_percentage': riskPercentage,
          'status_description': statusDescription,
          'reasons': reasons,
          'masked_links': maskedLinks,
          'is_read': false,
          'is_blocked': false,
        })
        .select()
        .single();

    return response;
  }

  /// Fetch all messages ordered by creation time
  Future<List<Map<String, dynamic>>> fetchMessages() async {
    final response = await client
        .from('messages')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Subscribe to real-time incoming messages
  RealtimeChannel subscribeToIncomingMessages({
    required void Function(Map<String, dynamic> newRow) onInsert,
  }) {
    final channel = client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            onInsert(payload.newRecord);
          },
        )
        .subscribe();

    return channel;
  }

  /// Delete all messages flagged as spam from Supabase
  Future<void> deleteAllSpamMessages() async {
    await client.from('messages').delete().eq('category', 'spam');
  }

  /// Delete a single message by ID
  Future<void> deleteMessage(String id) async {
    await client.from('messages').delete().eq('id', id);
  }

  /// Update message category (e.g. mark safe or spam)
  Future<void> updateCategory(String id, MessageCategory category, int risk) async {
    await client.from('messages').update({
      'category': _categoryToString(category),
      'risk_percentage': risk,
    }).eq('id', id);
  }

  String _categoryToString(MessageCategory cat) {
    switch (cat) {
      case MessageCategory.spam:
        return 'spam';
      case MessageCategory.sus:
        return 'sus';
      case MessageCategory.notSpam:
        return 'not_spam';
    }
  }

  static MessageCategory stringToCategory(String str) {
    switch (str.toLowerCase()) {
      case 'spam':
        return MessageCategory.spam;
      case 'sus':
        return MessageCategory.sus;
      case 'not_spam':
      case 'notspam':
      case 'safe':
      default:
        return MessageCategory.notSpam;
    }
  }
}
