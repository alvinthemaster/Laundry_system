import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_system/features/messaging/data/datasources/chat_data_source.dart';
import 'package:laundry_system/features/messaging/domain/entities/chat_message_entity.dart';
import 'package:laundry_system/features/messaging/domain/entities/chat_room_entity.dart';

// ── Singleton datasource ────────────────────────────────────────────────────

final chatDataSourceProvider = Provider<ChatDataSource>((ref) {
  return ChatDataSource();
});

// ── Stream providers ─────────────────────────────────────────────────────────

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessageEntity>, String>((ref, bookingId) {
  return ref.read(chatDataSourceProvider).watchMessages(bookingId);
});

final chatRoomProvider =
    StreamProvider.family<ChatRoomEntity?, String>((ref, bookingId) {
  return ref.read(chatDataSourceProvider).watchChatRoom(bookingId);
});

// ── Chat state ───────────────────────────────────────────────────────────────

class ChatState {
  final bool isSending;
  final String? error;

  const ChatState({this.isSending = false, this.error});

  ChatState copyWith({bool? isSending, String? error}) {
    return ChatState(
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

// ── Chat notifier ────────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatDataSource _dataSource;

  ChatNotifier(this._dataSource) : super(const ChatState());

  Future<void> ensureChatRoom({
    required String bookingId,
    required String customerId,
    required String driverId,
    required String customerName,
    required String driverName,
  }) async {
    try {
      await _dataSource.ensureChatRoom(
        bookingId: bookingId,
        customerId: customerId,
        driverId: driverId,
        customerName: customerName,
        driverName: driverName,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<bool> sendMessage({
    required String bookingId,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String text,
  }) async {
    if (text.trim().isEmpty) return false;
    state = state.copyWith(isSending: true, error: null);
    try {
      await _dataSource.sendMessage(
        bookingId: bookingId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        text: text.trim(),
      );
      state = state.copyWith(isSending: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
      return false;
    }
  }

  Future<void> markAsRead({
    required String bookingId,
    required String userRole,
  }) async {
    try {
      await _dataSource.markAsRead(bookingId: bookingId, userRole: userRole);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.read(chatDataSourceProvider));
});
