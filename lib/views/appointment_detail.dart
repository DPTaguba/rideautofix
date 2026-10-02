import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/ride_repository.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ride_app.dart';

String scheduleText(Map<String, dynamic> m) {
  final at = tsToDate(m['scheduledAt']);
  final date = at != null ? fmtDate(at) : txt(m, 'date', '—');
  return '$date · ${txt(m, 'time', '—')}';
}

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({
    super.key,
    required this.id,
    required this.data,
    required this.onTap,
    this.showCustomer = false,
  });
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final status = txt(data, 'status', 'Pending');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      txt(data, 'serviceName', 'Service'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status),
                ],
              ),
              if (showCustomer) ...[
                const SizedBox(height: 4),
                Text(
                  '${shortId(id)} · ${txt(data, 'customerName', 'Customer')}',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 10),
              _line(Icons.event_outlined, scheduleText(data)),
              const SizedBox(height: 4),
              _line(Icons.directions_car_outlined, txt(data, 'vehicleLabel', '—')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    money(numOf(data['totalAmount'])),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '${txt(data, 'paymentMethod', '—')} · ${txt(data, 'paymentStatus', 'Unpaid')}',
                    style: TextStyle(
                      color: txt(data, 'paymentStatus') == 'Paid'
                          ? AppColors.success
                          : AppColors.muted,
                      fontSize: 13,
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

  Widget _line(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 16, color: AppColors.muted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}

class AppointmentDetailPage extends StatefulWidget {
  const AppointmentDetailPage({super.key, required this.id, this.admin = false});
  final String id;
  final bool admin;

  @override
  State<AppointmentDetailPage> createState() => _AppointmentDetailPageState();
}

class _AppointmentDetailPageState extends State<AppointmentDetailPage> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _stream =
      AppScope.read(context).vm.appointment(widget.id);
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showSnack(context, done);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = AppScope.read(context).vm;
    return Scaffold(
      appBar: AppBar(title: Text('Appointment ${shortId(widget.id)}')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorState(message: friendlyError(snap.error!));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final doc = snap.data!;
          if (!doc.exists) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Appointment not found',
            );
          }
          final d = doc.data()!;
          final status = txt(d, 'status', 'Pending');
          final method = txt(d, 'paymentMethod', '—');
          final payStatus = txt(d, 'paymentStatus', 'Unpaid');

          return ResponsiveBody(
            maxWidth: 760,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        txt(d, 'serviceName', 'Service'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    StatusChip(status),
                  ],
                ),
                const SizedBox(height: 16),
                if (status == 'Cancelled')
                  const _Banner(
                    icon: Icons.cancel_outlined,
                    color: AppColors.danger,
                    text: 'This appointment was cancelled.',
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _Timeline(status: status),
                    ),
                  ),
                const SectionTitle('Service details'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (widget.admin)
                          InfoRow('Customer', txt(d, 'customerName', '—')),
                        if (widget.admin)
                          InfoRow('Phone', txt(d, 'customerPhone', '—')),
                        InfoRow('Vehicle', txt(d, 'vehicleLabel', '—')),
                        InfoRow('Schedule', scheduleText(d)),
                        InfoRow('Location', txt(d, 'location', '—')),
                        if (txt(d, 'notes').isNotEmpty)
                          InfoRow('Notes', txt(d, 'notes')),
                      ],
                    ),
                  ),
                ),
                const SectionTitle('Payment'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        InfoRow('Method', method),
                        InfoRow('Status', payStatus),
                        InfoRow('Service fee', money(numOf(d['serviceFee']))),
                        InfoRow(
                          'Home service fee',
                          money(numOf(d['homeServiceFee'])),
                        ),
                        const Divider(height: 20),
                        InfoRow('Total', money(numOf(d['totalAmount']))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (!widget.admin && status == 'Pending')
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel appointment'),
                    onPressed: _busy
                        ? null
                        : () async {
                            final ok = await confirmDialog(
                              context,
                              title: 'Cancel appointment?',
                              message:
                                  'This request will be cancelled and cannot be resumed.',
                              confirmLabel: 'Yes, cancel',
                              cancelLabel: 'Keep it',
                              destructive: true,
                            );
                            if (ok) {
                              await _run(
                                () => vm.cancelAppointment(widget.id),
                                'Appointment cancelled.',
                              );
                            }
                          },
                ),
                if (widget.admin) ...[
                  const SectionTitle('Update progress'),
                  _AdminPanel(
                    key: ValueKey(status),
                    status: status,
                    busy: _busy,
                    onSave: (s) => _run(
                      () => vm.setAppointmentStatus(widget.id, s),
                      'Status updated to $s.',
                    ),
                  ),
                  if (payStatus != 'Paid') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Mark as paid'),
                      onPressed: _busy
                          ? null
                          : () async {
                              final ok = await confirmDialog(
                                context,
                                title: 'Mark as paid?',
                                message:
                                    'Confirm that ${money(numOf(d['totalAmount']))} was received.',
                                confirmLabel: 'Mark paid',
                              );
                              if (ok) {
                                await _run(
                                  () => vm.recordPayment(widget.id),
                                  'Payment recorded.',
                                );
                              }
                            },
                    ),
                  ],
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final current = kProgressSteps.indexOf(status);
    return Column(
      children: [
        for (var i = 0; i < kProgressSteps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  i < current
                      ? Icons.check_circle
                      : i == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: i <= current ? AppColors.primary : AppColors.outline,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  kProgressSteps[i],
                  style: TextStyle(
                    fontWeight: i == current ? FontWeight.w700 : FontWeight.w400,
                    color: i <= current ? null : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AdminPanel extends StatefulWidget {
  const _AdminPanel({
    super.key,
    required this.status,
    required this.busy,
    required this.onSave,
  });
  final String status;
  final bool busy;
  final ValueChanged<String> onSave;

  @override
  State<_AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<_AdminPanel> {
  late String _selected = widget.status;

  @override
  Widget build(BuildContext context) {
    final locked = widget.status == 'Cancelled';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (locked)
              const Text(
                'Cancelled appointments cannot move to another status.',
                style: TextStyle(color: AppColors.muted),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in kStatuses)
                    ChoiceChip(
                      label: Text(s),
                      selected: _selected == s,
                      onSelected: (_) => setState(() => _selected = s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              BusyButton(
                label: 'Update status',
                busy: widget.busy,
                onPressed: _selected == widget.status
                    ? null
                    : () => widget.onSave(_selected),
              ),
            ],
          ],
        ),
      ),
    );
  }
}