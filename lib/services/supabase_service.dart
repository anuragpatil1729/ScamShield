import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SupabaseService strictly handles User Authentication (Sign Up, Sign In, Sign Out, Session).
/// Messages are NOT stored or synced through Supabase, as the classification and chat model
/// will be integrated locally in the app.
class SupabaseService {
  static const String supabaseUrl = 'https://pbmufkyjuopnfmhqbbbx.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_DtrE8rs-iBMOUBzwjzlv9g_ibo43x-E';

  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase with the provided publishable key
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Supabase initialization status: $e');
      _isInitialized = true;
    }
  }

  /// Current authenticated user (if any)
  User? get currentUser => isInitialized ? client.auth.currentUser : null;

  /// Current auth session
  Session? get currentSession => isInitialized ? client.auth.currentSession : null;

  /// Whether a user is currently signed in
  bool get isAuthenticated => currentUser != null;

  /// Stream of authentication state changes
  Stream<AuthState>? get authStateChanges =>
      isInitialized ? client.auth.onAuthStateChange : null;

  /// Sign Up a new user with email & password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await initialize();
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: displayName != null && displayName.isNotEmpty
          ? {'display_name': displayName.trim()}
          : null,
    );
    return response;
  }

  /// Sign In an existing user with email & password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    await initialize();
    final response = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    return response;
  }

  /// Sign Out the current user
  Future<void> signOut() async {
    if (!isInitialized) return;
    await client.auth.signOut();
  }

  /// Send a message to the Supabase messages table for cross-device sync
  Future<Map<String, dynamic>?> sendChatMessage({
    required String body,
    String? recipient,
    String? category,
    int? riskPercentage,
  }) async {
    if (!isInitialized) return null;
    final senderEmail = currentUser?.email ?? 'Unknown User';
    try {
      final response = await client.from('messages').insert({
        'sender': senderEmail,
        'subject': recipient ?? '',
        'body': body,
        'category': category ?? 'not_spam',
        'risk_percentage': riskPercentage ?? 0,
      }).select().single();
      return response;
    } catch (e) {
      debugPrint('Supabase sendChatMessage error: $e');
      return null;
    }
  }

  /// Fetch initial messages from remote table
  Future<List<Map<String, dynamic>>> fetchRemoteMessages({int limit = 50}) async {
    if (!isInitialized) return [];
    try {
      final response = await client
          .from('messages')
          .select()
          .order('created_at', ascending: true)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Supabase fetchRemoteMessages error: $e');
      return [];
    }
  }

  /// Subscribe to Realtime inserts on the public.messages table
  RealtimeChannel? subscribeToMessages(void Function(Map<String, dynamic> record) onNewMessage) {
    if (!isInitialized) return null;
    try {
      return client
          .channel('public:messages')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              onNewMessage(payload.newRecord);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Supabase subscribe error: $e');
      return null;
    }
  }
}
