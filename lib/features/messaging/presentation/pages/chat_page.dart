import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:laundry_system/core/utils/app_utils.dart';
import 'package:laundry_system/features/auth/presentation/providers/auth_provider.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';
import 'package:laundry_system/features/messaging/domain/entities/chat_message_entity.dart';
import 'package:laundry_system/features/messaging/presentation/providers/chat_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  final BookingEntity booking;
  /// The role of the user opening this chat: 'driver' or 'customer'
  final String currentUserRole;

  const ChatPage({
    super.key,
    required this.booking,
    required this.currentUserRole,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initChat());
  }

  Future<void> _initChat() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final b = widget.booking;
    await ref.read(chatProvider.notifier).ensureChatRoom(
          bookingId: b.bookingId,
          customerId: b.userId,
          driverId: b.driverId ?? user.uid,
          customerName: b.customerName ?? 'Customer',
          driverName: b.driverName ?? user.fullName,
        );

    await ref.read(chatProvider.notifier).markAsRead(
          bookingId: b.bookingId,
          userRole: widget.currentUserRole,
        );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(bool locked) async {
    if (locked) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    _controller.clear();

    final success = await ref.read(chatProvider.notifier).sendMessage(
          bookingId: widget.booking.bookingId,
          senderId: user.uid,
          senderName: user.fullName,
          senderRole: widget.currentUserRole,
          text: text,
        );

    if (!mounted) return;
    if (!success) {
      final error = ref.read(chatProvider).error;
      final isLocked = (error ?? '').contains('CHAT_LOCKED');
      AppUtils.showSnackBar(
        context,
        isLocked
            ? 'This chat is read-only because the booking is completed.'
            : (error ?? 'Failed to send message'),
        isError: true,
      );
    }

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final messagesAsync =
        ref.watch(chatMessagesProvider(widget.booking.bookingId));
    final roomAsync =
        ref.watch(chatRoomProvider(widget.booking.bookingId));

    final locked = roomAsync.whenOrNull(data: (r) => r?.locked) ?? false;

    // Auto-scroll when messages update
    messagesAsync.whenData((_) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom());

      // Keep unread badge accurate while this chat is visible.
      ref.read(chatProvider.notifier).markAsRead(
        bookingId: widget.booking.bookingId,
        userRole: widget.currentUserRole,
          );
    });

    final otherName = widget.currentUserRole == 'driver'
        ? (widget.booking.customerName ?? 'Customer')
        : (widget.booking.driverName ?? 'Driver');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(otherName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              'Booking #${widget.booking.bookingId.substring(0, 8)}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (locked)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Closed',
                  style: TextStyle(fontSize: 12, color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Message list ────────────────────────────────────────────────
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('No messages yet',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('Start the conversation!',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 13)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _MessageBubble(
                    message: messages[i],
                    isMe: messages[i].senderId == user?.uid,
                  ),
                );
              },
            ),
          ),

          // ── Locked banner ────────────────────────────────────────────────
          if (locked)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: Colors.grey.shade100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'This conversation has ended — booking completed',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),

          // ── Input field ──────────────────────────────────────────────────
          if (!locked)
            SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      top: BorderSide(color: Colors.grey.shade200)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, -2)),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Type a message…',
                          hintStyle:
                              TextStyle(color: Colors.grey.shade400),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(locked),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Consumer(builder: (context, ref, _) {
                      final sending =
                          ref.watch(chatProvider).isSending;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        child: Material(
                          color: Theme.of(context).colorScheme.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: sending
                                ? null
                                : () => _sendMessage(locked),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: sending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Icon(Icons.send,
                                      color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Message bubble widget ────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessageEntity message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade200;
    final textColor = isMe ? Colors.white : Colors.black87;
    final align =
        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final borderRadius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                message.senderName,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    message.senderName.isNotEmpty
                        ? message.senderName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: borderRadius,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 3,
                          offset: const Offset(0, 1)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(message.text,
                          style:
                              TextStyle(color: textColor, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('hh:mm a').format(message.sentAt),
                        style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white70
                                : Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
              if (isMe) const SizedBox(width: 4),
            ],
          ),
        ],
      ),
    );
  }
}
