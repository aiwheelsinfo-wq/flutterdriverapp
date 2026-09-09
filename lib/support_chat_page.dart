import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'api_config.dart';

class SupportChatPage extends StatefulWidget {
  final String phoneNumber;
  final String? vendorName;
  final String? blockReason;
  final bool isBlocked;

  const SupportChatPage({
    super.key,
    required this.phoneNumber,
    this.vendorName,
    this.blockReason,
    this.isBlocked = false,
  });

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _pollingTimer;

  final Color _primaryAmber = const Color(0xFFFFB300);
  final Color _darkCharcoal = const Color(0xFF212121);
  final Color _bgGrey = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _fetchMessages(initial: true);
    // Poll every 4 seconds for real-time replies
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchMessages());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({bool initial = false}) async {
    try {
      final url = Uri.parse("${ApiConfig.supportChat}?action=get_messages&vendor_phone=${widget.phoneNumber}&reader=vendor");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['messages'] != null) {
          final List<dynamic> newMsgs = data['messages'];
          if (mounted) {
            final bool countChanged = newMsgs.length != _messages.length;
            setState(() {
              _messages = newMsgs;
              _isLoading = false;
            });
            if (countChanged || initial) {
              _scrollToBottom();
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Support fetch error: $e");
      if (mounted && initial) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage({String? customText}) async {
    final text = customText ?? _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    if (customText == null) {
      _messageController.clear();
    }

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.supportChat}?action=send_message"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "vendor_phone": widget.phoneNumber,
          "sender_type": "vendor",
          "sender_name": widget.vendorName ?? "Partner",
          "message": text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          if (mounted) {
            setState(() {
              _messages.add(data['data']);
            });
            _scrollToBottom();
          }
        }
      }
    } catch (e) {
      debugPrint("Send message error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to send message. Please check internet connection.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGrey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1E293B), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _primaryAmber.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: _primaryAmber.withValues(alpha: 0.5), width: 1.5),
              ),
              child: const Icon(Icons.support_agent_rounded, color: Color(0xFFB45309), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Rentox Helpdesk",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        "Operations Team • Online",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
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
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
            onPressed: () => _fetchMessages(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Account Suspension Alert if blocked
            if (widget.isBlocked) _buildSuspensionNotice(),

            // Chat Messages List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: _primaryAmber))
                  : _messages.isEmpty
                      ? _buildEmptyChatState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final bool isMe = (msg['sender_type'] == 'vendor');
                            return _buildMessageBubble(msg, isMe);
                          },
                        ),
            ),

            // Quick suggestion chips
            if (_messages.length < 5) _buildQuickChips(),

            // Message Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuspensionNotice() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Account Suspended",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.blockReason != null && widget.blockReason!.isNotEmpty
                      ? "Reason: ${widget.blockReason}. Send payment details or dispute info below."
                      : "Send payment proof or dispute details below for immediate review.",
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB91C1C),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, color: _primaryAmber, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              "How can we assist you today?",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Our operations team is available to assist with settlements, commission queries, and account re-activation.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final String text = msg['message'] ?? '';
    final String? attachmentUrl = msg['attachment_url'];
    final String createdAt = msg['created_at'] ?? '';
    String timeStr = '';
    try {
      final dt = DateTime.parse(createdAt);
      timeStr = DateFormat('hh:mm a').format(dt);
    } catch (_) {
      timeStr = '';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: _primaryAmber.withValues(alpha: 0.2),
              child: const Icon(Icons.support_agent_rounded, size: 16, color: Color(0xFFB45309)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        "Rentox Support",
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),

                  // Attachment thumbnail if image
                  if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
                    GestureDetector(
                      onTap: () => _showAttachmentPreview(attachmentUrl),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: Image.network(
                            attachmentUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 120,
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Message Text
                  if (text.isNotEmpty)
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isMe ? Colors.white : const Color(0xFF1E293B),
                        height: 1.35,
                      ),
                    ),

                  const SizedBox(height: 4),

                  // Timestamp
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 9.5,
                          color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 13,
                          color: (msg['is_read'] == 1) ? const Color(0xFF38BDF8) : Colors.white60,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  void _showAttachmentPreview(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.black54,
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChips() {
    final List<String> suggestions = [
      "I have paid my pending commission",
      "Please re-activate my account",
      "Need settlement details",
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          return ActionChip(
            label: Text(
              suggestions[idx],
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            ),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () => _sendMessage(customText: suggestions[idx]),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: "Type message or dispute note...",
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : () => _sendMessage(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isSending ? Colors.grey[300] : _primaryAmber,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _primaryAmber.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isSending
                  ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
