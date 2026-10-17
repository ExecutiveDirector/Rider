// lib/features/chat/order_chat_screen.dart
// In-app chat with the customer. Phone numbers stay private: the server hides
// any number typed into a message. Polls every 4s while open; a push wakes the app otherwise.
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';

class _Msg {
  final String id;
  final bool mine;
  final String body;
  final DateTime? at;
  _Msg(this.id, this.mine, this.body, this.at);
}

class OrderChatScreen extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  const OrderChatScreen(
      {super.key, required this.orderId, required this.orderNumber});

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final _api = ApiService.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  Timer? _timer;
  bool _canSend = true;
  String? _closedReason;
  bool _sending = false;
  bool _loadFailed = false;

  static const _quick = [
    "I'm on my way",
    "I've arrived",
    'Please come to the gate',
    "I can't find the address",
  ];

  String get _path => '${ApiConstants.ordersBase}/${widget.orderId}/messages';

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final after = _msgs.isEmpty ? 0 : int.tryParse(_msgs.last.id) ?? 0;
      final res = await _api.get(_path, params: {if (after > 0) 'after': after});
      final data = res.data is Map ? Map<String, dynamic>.from(res.data) : {};
      final fresh = ((data['messages'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((m) => _Msg(m['id'].toString(), m['mine'] == true,
              (m['body'] ?? '').toString(), DateTime.tryParse('${m['created_at']}')?.toLocal()))
          .where((m) => !_msgs.any((x) => x.id == m.id))
          .toList();
      if (!mounted) return;
      setState(() {
        _loadFailed = false;
        _canSend = data['can_send'] != false;
        _closedReason = data['closed_reason']?.toString();
        if (fresh.isNotEmpty) _msgs.addAll(fresh);
      });
      if (fresh.isNotEmpty) _toBottom();
    } catch (_) {
      if (mounted && _msgs.isEmpty) setState(() => _loadFailed = true);
    }
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });

  Future<void> _send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _api.post(_path, data: {'body': body});
      _input.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Couldn't send. Check your connection and try again."),
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _time(DateTime? t) => t == null
      ? ''
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Customer · #${widget.orderNumber}')),
      body: Column(
        children: [
          Expanded(
            child: _msgs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _loadFailed
                            ? "Couldn't load messages."
                            : 'No messages yet. Say hello, or use a quick reply below.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _msgs.length,
                    itemBuilder: (_, i) {
                      final m = _msgs[i];
                      return Align(
                        alignment:
                            m.mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: m.mine ? AppColors.primary : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(m.body,
                                  style: TextStyle(
                                      color: m.mine ? Colors.white : Colors.black87)),
                              const SizedBox(height: 2),
                              Text(_time(m.at),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: m.mine
                                          ? Colors.white70
                                          : Colors.black45)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (!_canSend)
            Container(
              width: double.infinity,
              color: Colors.amber.shade50,
              padding: const EdgeInsets.all(12),
              child: Text(_closedReason ?? 'Chat is closed for this order.'),
            )
          else ...[
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final q in _quick)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                          label: Text(q, style: const TextStyle(fontSize: 12)),
                          onPressed: _sending ? null : () => _send(q)),
                    ),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        maxLength: 500,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _send,
                        decoration: const InputDecoration(
                            hintText: 'Message the customer',
                            counterText: '',
                            border: OutlineInputBorder()),
                      ),
                    ),
                    IconButton(
                      onPressed: _sending ? null : () => _send(_input.text),
                      icon: const Icon(Icons.send, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
