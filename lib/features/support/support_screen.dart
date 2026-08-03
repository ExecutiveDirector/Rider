// lib/features/support/support_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/providers/support_provider.dart';
import '../../data/models/support_ticket.dart';
import 'new_ticket_screen.dart';
import 'ticket_detail_screen.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supportProvider.notifier).load();
    });
  }

  Color _statusColor(SupportTicket t) {
    switch (t.status) {
      case 'open':
        return AppColors.warning;
      case 'in_progress':
        return AppColors.info;
      case 'waiting_customer':
        return AppColors.accepted;
      case 'resolved':
      case 'closed':
        return AppColors.success;
      default:
        return AppColors.textHint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Help & Support')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const NewTicketScreen()),
          );
          if (created == true) ref.read(supportProvider.notifier).load();
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Ticket'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(supportProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            // Quick contact fallback — kept alongside tickets, not instead
            // of them, in case someone just wants to email directly.
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Raise a ticket and our support team will get back '
                      'to you — track replies right here.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text('My Tickets',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            if (state.isLoading && state.tickets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.tickets.isEmpty)
              const AppEmptyState(
                icon: Icons.confirmation_number_outlined,
                title: 'No support tickets yet',
                message: 'Raise one if you run into an issue',
                compact: true,
              )
            else
              ...state.tickets.map((t) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TicketDetailScreen(ticketId: t.id),
                        ),
                      ),
                      title: Text(t.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '#${t.ticketNumber} · ${DateFormat('d MMM').format(t.createdAt)}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                      trailing: StatusPill(
                        label: t.statusLabel,
                        color: _statusColor(t),
                        dense: true,
                      ),
                    ),
                  )),

            const SizedBox(height: 28),
            const Text('Frequently Asked Questions',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            if (state.faqs.isEmpty && !state.isLoading)
              const Text('No FAQs available right now.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ...state.faqs.map((f) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: ExpansionTile(
                      shape: const RoundedRectangleBorder(
                          side: BorderSide(color: Colors.transparent)),
                      title: Text(f.question,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13.5)),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.answer,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4)),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
