// lib/features/earnings/cash_payouts_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/json_utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/models/cash_models.dart';
import '../../data/providers/cash_provider.dart';
import '../../data/providers/earnings_provider.dart';

String _kes(double v) => 'KES ${NumberFormat('#,##0').format(v)}';

/// COD cash the rider is carrying, how to hand it in, and payouts of earned
/// money to M-Pesa.
class CashPayoutsScreen extends ConsumerStatefulWidget {
  const CashPayoutsScreen({super.key});

  @override
  ConsumerState<CashPayoutsScreen> createState() => _CashPayoutsScreenState();
}

class _CashPayoutsScreenState extends ConsumerState<CashPayoutsScreen>
    with SingleTickerProviderStateMixin {
  // Two tabs keep "my money" (earnings to withdraw) apart from "AquaGas's
  // money" (cash collected on delivery that must be handed in).
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future.wait([
      ref.read(cashProvider.notifier).load(),
      ref.read(earningsProvider.notifier).fetchSummary(),
    ]);
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _remit(CashSummary summary) async {
    final input = await showDialog<_RemitInput>(
      context: context,
      builder: (_) => _RemitDialog(summary: summary),
    );
    if (input == null || !mounted) return;

    final err = await ref
        .read(cashProvider.notifier)
        .remit(amount: input.amount, mpesaCode: input.code);
    err == null
        ? _toast('Sent for confirmation. Finance will match your M-Pesa code.')
        : _toast(err, error: true);
  }

  Future<void> _requestPayout(double available) async {
    final request = await showDialog<PayoutRequest>(
      context: context,
      builder: (_) => _PayoutDialog(available: available),
    );
    if (request == null || !mounted) return;

    final err = await ref.read(cashProvider.notifier).requestPayout(request);
    err == null
        ? _toast(request.bank
            ? 'Withdrawal requested. Once approved it is paid to your bank account.'
            : 'Withdrawal requested. Once approved it is sent to your M-Pesa.')
        : _toast(err, error: true);
  }

  Widget _scrollTab(List<Widget> children, {double top = 16}) =>
      RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, top, 20, 32),
          children: children,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cash = ref.watch(cashProvider);
    final available = ref.watch(earningsProvider).summary?.pendingPayout ?? 0;
    final summary = cash.summary;
    final toRemit = summary?.cashInHand ?? 0;
    final overLimit = summary?.overLimit ?? false;

    Widget body;
    if (cash.isLoading && summary == null && cash.payouts.isEmpty) {
      body = const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    } else if (cash.error != null && summary == null && cash.payouts.isEmpty) {
      body = _scrollTab([
        AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load',
          message: cash.error!,
          iconColor: AppColors.error,
          actionLabel: 'Retry',
          onAction: _refresh,
        ),
      ], top: 70);
    } else {
      body = TabBarView(
        controller: _tabs,
        children: [
          // ── My earnings: withdraw + history ───────────────────────────
          _scrollTab([
            _WithdrawHero(
              available: available,
              onWithdraw: available > 0 && !overLimit
                  ? () => _requestPayout(available)
                  : null,
            ),
            if (overLimit) ...[
              const SizedBox(height: 12),
              _Banner(
                icon: Icons.lock_outline_rounded,
                color: AppColors.warning,
                text:
                    'Withdrawals are paused until you hand in the cash you are carrying (you are over your limit).',
                actionLabel: 'Hand in cash',
                onAction: () => _tabs.animateTo(1),
              ),
            ],
            const SizedBox(height: 20),
            const _HowItWorks(),
            const SizedBox(height: 24),
            const _SectionTitle('Withdrawal history'),
            if (cash.payouts.isEmpty)
              const _EmptyHint(
                icon: Icons.receipt_long_outlined,
                text:
                    'No withdrawals yet. Your requests and their status will show here.',
              )
            else
              ...cash.payouts.map((p) => _PayoutTile(payout: p)),
          ]),

          // ── Cash to remit: COD cash that belongs to AquaGas ───────────
          _scrollTab([
            if (summary != null) ...[
              _CashCard(summary: summary, onRemit: () => _remit(summary)),
              const SizedBox(height: 12),
              const _Notice(
                icon: Icons.info_outline,
                text:
                    'Send the cash to AquaGas by M-Pesa, then enter the amount and the confirmation code. Finance confirms it once the code matches.',
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Cash collected'),
              if (summary.collections.isEmpty)
                const _EmptyHint(
                  icon: Icons.payments_outlined,
                  text:
                      'No cash collected yet. Cash-on-delivery payments you take will be listed here.',
                )
              else
                ...summary.collections.map((c) => _CollectionTile(item: c)),
            ] else
              const _Notice(
                icon: Icons.info_outline,
                text: 'Cash tracking is not available for your account yet.',
              ),
          ]),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cash & payouts'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: [
            const Tab(text: 'My earnings'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Cash to remit'),
                  if (toRemit > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: overLimit ? AppColors.error : AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: body,
    );
  }
}

// ─── Cash in hand ────────────────────────────────────────────────────────────

class _CashCard extends StatelessWidget {
  final CashSummary summary;
  final VoidCallback onRemit;
  const _CashCard({required this.summary, required this.onRemit});

  @override
  Widget build(BuildContext context) {
    final color = summary.overLimit
        ? AppColors.error
        : summary.nearLimit
            ? AppColors.warning
            : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: summary.nearLimit ? color : AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cash in hand',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            _kes(summary.cashInHand),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'This money belongs to AquaGas, not to you.',
            style: TextStyle(color: AppColors.textHint, fontSize: 12),
          ),
          if (summary.cashLimit > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: summary.usage,
                minHeight: 8,
                color: color,
                backgroundColor: AppColors.divider,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              summary.overLimit
                  ? 'Over your ${_kes(summary.cashLimit)} limit — remit before taking more cash jobs.'
                  : 'Limit ${_kes(summary.cashLimit)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: summary.nearLimit ? FontWeight.w700 : FontWeight.w500,
                color: summary.nearLimit ? color : AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Mini(
                    label: 'Collected today',
                    value: _kes(summary.collectedToday)),
              ),
              Expanded(
                child: _Mini(
                    label: 'Remitted today',
                    value: _kes(summary.remittedToday)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: summary.cashInHand > 0 ? onRemit : null,
              icon: const Icon(Icons.phone_android),
              label: const Text('Remit cash via M-Pesa'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  const _Mini({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary)),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      );
}

// ─── Payout ──────────────────────────────────────────────────────────────────

class _WithdrawHero extends StatelessWidget {
  final double available;
  final VoidCallback? onWithdraw;
  const _WithdrawHero({required this.available, required this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Available to withdraw',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _kes(available),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            available > 0
                ? 'Ready to send to your M-Pesa or bank.'
                : 'Earnings from delivered orders show up here.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onWithdraw,
              icon: const Icon(Icons.south_west_rounded, size: 20),
              label: const Text('Withdraw earnings'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                disabledBackgroundColor: Colors.white24,
                disabledForegroundColor: Colors.white70,
                minimumSize: const Size.fromHeight(52),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(icon: Icons.flag_outlined, text: 'Min. KES 100'),
              _HeroChip(icon: Icons.phone_android, text: 'M-Pesa or bank'),
              _HeroChip(icon: Icons.verified_outlined, text: 'Admin approves'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 11.5)),
          ],
        ),
      );
}

/// Three-step explainer so riders know what happens after tapping Withdraw.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    Widget step(IconData icon, String title, String body) => Expanded(
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 22),
              ),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11.5)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How withdrawing works',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              step(Icons.touch_app_outlined, '1. Request',
                  'Pick the amount and where to send it'),
              step(Icons.fact_check_outlined, '2. Approval',
                  'An admin reviews your request'),
              step(Icons.payments_outlined, '3. Paid',
                  'Money lands in your M-Pesa or bank'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;
  const _Banner({
    required this.icon,
    required this.color,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 13)),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(actionLabel,
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: AppColors.textHint),
            const SizedBox(height: 8),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
}

class _PayoutTile extends StatelessWidget {
  final PayoutModel payout;
  const _PayoutTile({required this.payout});

  @override
  Widget build(BuildContext context) {
    final color = payout.isPaid
        ? AppColors.success
        : payout.isFailed
            ? AppColors.error
            : AppColors.warning;
    final label = payout.isPaid
        ? 'Paid'
        : payout.isFailed
            ? 'Rejected'
            : payout.status == 'pending'
                ? 'Awaiting approval'
                : 'Processing';

    return _TileShell(
      leading: Icons.arrow_downward_rounded,
      leadingColor: color,
      title: _kes(payout.amount),
      subtitle: [
        DateFormat('MMM d, h:mm a').format(payout.createdAt.toLocal()),
        if (payout.reference != null && payout.reference!.isNotEmpty)
          payout.reference!,
      ].join(' · '),
      trailing: label,
      trailingColor: color,
    );
  }
}

class _CollectionTile extends StatelessWidget {
  final CashCollection item;
  const _CollectionTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      leading: Icons.payments_outlined,
      leadingColor: item.remitted ? AppColors.success : AppColors.warning,
      title: _kes(item.amount),
      subtitle:
          'Order #${shortId(item.orderNumber)} · ${DateFormat('MMM d, h:mm a').format(item.collectedAt.toLocal())}',
      trailing: item.remitted ? 'Remitted' : 'To remit',
      trailingColor: item.remitted ? AppColors.success : AppColors.warning,
    );
  }
}

class _TileShell extends StatelessWidget {
  final IconData leading;
  final Color leadingColor;
  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;
  const _TileShell({
    required this.leading,
    required this.leadingColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.trailingColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: leadingColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(leading, color: leadingColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.textPrimary)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: trailingColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(trailing,
                style: TextStyle(
                    color: trailingColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
      );
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Notice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textHint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
}

// ─── Dialogs ─────────────────────────────────────────────────────────────────

class _RemitInput {
  final double amount;
  final String code;
  const _RemitInput(this.amount, this.code);
}

class _RemitDialog extends StatefulWidget {
  final CashSummary summary;
  const _RemitDialog({required this.summary});

  @override
  State<_RemitDialog> createState() => _RemitDialogState();
}

class _RemitDialogState extends State<_RemitDialog> {
  late final TextEditingController _amountCtrl;
  final _codeCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.summary.cashInHand.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '').trim());
    final code = _codeCtrl.text.trim().toUpperCase();

    if (amount == null || amount <= 0) {
      return setState(() => _error = 'Enter the amount you sent.');
    }
    if (amount > widget.summary.cashInHand + 0.5) {
      return setState(() =>
          _error = 'That is more than the ${_kes(widget.summary.cashInHand)} you hold.');
    }
    if (!RegExp(r'^[A-Z0-9]{10}$').hasMatch(code)) {
      return setState(() =>
          _error = 'The M-Pesa code is 10 letters and numbers, e.g. SJK3L9XYZ1.');
    }
    Navigator.pop(context, _RemitInput(amount, code));
  }

  @override
  Widget build(BuildContext context) {
    final instructions = widget.summary.instructions;
    return AlertDialog(
      title: const Text('Remit cash'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              instructions != null && instructions.isNotEmpty
                  ? instructions
                  : 'Send the cash to AquaGas by M-Pesa first, then enter the '
                      'amount and the M-Pesa confirmation code here.',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount sent',
                prefixText: 'KES ',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
              decoration: const InputDecoration(
                labelText: 'M-Pesa confirmation code',
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Submit')),
      ],
    );
  }
}

class _PayoutDialog extends StatefulWidget {
  final double available;
  const _PayoutDialog({required this.available});

  @override
  State<_PayoutDialog> createState() => _PayoutDialogState();
}

class _PayoutDialogState extends State<_PayoutDialog> {
  late final TextEditingController _ctrl;
  final _phone = TextEditingController();
  final _bankName = TextEditingController();
  final _account = TextEditingController();
  final _holder = TextEditingController();
  bool _bank = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.available.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _phone.dispose();
    _bankName.dispose();
    _account.dispose();
    _holder.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_ctrl.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      return setState(() => _error = 'Enter an amount to withdraw.');
    }
    if (amount > widget.available + 0.5) {
      return setState(
          () => _error = 'You can withdraw up to ${_kes(widget.available)}.');
    }
    if (_bank &&
        (_bankName.text.trim().length < 2 ||
            _account.text.trim().length < 6 ||
            _holder.text.trim().length < 3)) {
      return setState(() => _error = 'Fill in the bank, account number and account name.');
    }
    Navigator.pop(
      context,
      PayoutRequest(
        amount: amount,
        bank: _bank,
        mpesaPhone: _phone.text.trim(),
        bankName: _bankName.text.trim(),
        bankAccountNumber: _account.text.trim(),
        bankAccountName: _holder.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Withdraw earnings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('An admin approves the request, then it is paid to the account you choose.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('M-Pesa'), icon: Icon(Icons.phone_android)),
                ButtonSegment(value: true, label: Text('Bank'), icon: Icon(Icons.account_balance)),
              ],
              selected: {_bank},
              onSelectionChanged: (s) => setState(() {
                _bank = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: 'KES ',
                helperText: 'Available ${_kes(widget.available)}',
              ),
            ),
            const SizedBox(height: 8),
            if (!_bank)
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'M-Pesa number (optional)',
                  helperText: 'Leave empty to use the number on your profile',
                ),
              )
            else ...[
              TextField(controller: _bankName, decoration: const InputDecoration(labelText: 'Bank name')),
              TextField(
                controller: _account,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Account number'),
              ),
              TextField(controller: _holder, decoration: const InputDecoration(labelText: 'Account name')),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Request')),
      ],
    );
  }
}
