import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ride_repository.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'customer_vehicles.dart';
import 'ride_app.dart';

/// Book a home service in three steps: Details -> Payment -> Review.
/// Pops with `true` once the request has been submitted.
class BookingPage extends StatefulWidget {
  const BookingPage({super.key, this.serviceId, this.service});
  final String? serviceId;
  final Map<String, dynamic>? service;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _detailsForm = GlobalKey<FormState>();
  final _payForm = GlobalKey<FormState>();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  final _gcash = TextEditingController();
  final _cardNo = TextEditingController();
  final _cardName = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _vSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sSub;
  Docs _vehicleDocs = [];
  Docs _serviceDocs = [];

  int _step = 0;
  bool _busy = false;

  String? _vehicleId;
  Map<String, dynamic>? _vehicle;
  String? _serviceId;
  Map<String, dynamic>? _service;
  DateTime? _date;
  String? _time;
  String? _method;

  String? _vehicleError;
  String? _serviceError;
  String? _dateError;
  String? _timeError;
  String? _methodError;

  @override
  void initState() {
    super.initState();
    final scope = AppScope.read(context);
    _serviceId = widget.serviceId;
    _service = widget.service;
    final profileAddress = txt(scope.profile, 'address');
    if (profileAddress.isNotEmpty) _location.text = profileAddress;

    _vSub = scope.vm.vehiclesFor(scope.uid).listen((snap) {
      if (!mounted) return;
      setState(() {
        _vehicleDocs = snap.docs;
        // Auto-pick when the customer only has one vehicle.
        if (_vehicle == null && snap.docs.length == 1) {
          _vehicleId = snap.docs.first.id;
          _vehicle = snap.docs.first.data();
        }
      });
    });
    _sSub = scope.vm.services().listen((snap) {
      if (!mounted) return;
      setState(() => _serviceDocs = snap.docs);
    });
  }

  @override
  void dispose() {
    _vSub?.cancel();
    _sSub?.cancel();
    for (final c in [_location, _notes, _gcash, _cardNo, _cardName, _expiry, _cvv]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- derived values -----------------------------------------------------

  double get _serviceFee => numOf(_service?['price']).toDouble();
  double get _total => _serviceFee + kHomeServiceFee;
  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  bool _slotDisabled(String slot) {
    if (_date == null || _date != _today) return false;
    return slotHour(slot) <= DateTime.now().hour;
  }

  String get _last4 {
    final digits = _cardNo.text.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
  }

  String get _vehicleLabel {
    final v = _vehicle;
    if (v == null) return '—';
    return '${vehicleTitle(v)} · ${txt(v, 'plate')}';
  }

  // ---- pickers ------------------------------------------------------------

  Future<void> _pickVehicle() async {
    if (_vehicleDocs.isEmpty) {
      final add = await confirmDialog(
        context,
        title: 'Add a vehicle first',
        message: 'Register your vehicle so the mechanic knows what to bring.',
        confirmLabel: 'Add vehicle',
      );
      if (add && mounted) await openPage(context, const VehicleFormPage());
      return;
    }
    final id = await showOptionSheet<String>(
      context,
      title: 'Choose your vehicle',
      selected: _vehicleId,
      options: [
        for (final d in _vehicleDocs)
          Option(
            d.id,
            vehicleTitle(d.data()),
            subtitle: txt(d.data(), 'plate'),
            leading: NetImage(txt(d.data(), 'photoUrl'), width: 44, height: 44),
          ),
      ],
    );
    if (id == null) return;
    final doc = _vehicleDocs.firstWhere((d) => d.id == id);
    setState(() {
      _vehicleId = id;
      _vehicle = doc.data();
      _vehicleError = null;
    });
  }

  Future<void> _pickService() async {
    if (_serviceDocs.isEmpty) {
      showSnack(context, 'No services are available right now.', error: true);
      return;
    }
    final id = await showOptionSheet<String>(
      context,
      title: 'Choose a service',
      selected: _serviceId,
      options: [
        for (final d in _serviceDocs)
          Option(
            d.id,
            txt(d.data(), 'name'),
            subtitle:
                '${money(numOf(d.data()['price']))}${txt(d.data(), 'estimatedTime').isEmpty ? '' : ' · ${txt(d.data(), 'estimatedTime')}'}',
            leading: NetImage(
              txt(d.data(), 'photoUrl'),
              width: 44,
              height: 44,
              icon: Icons.build_circle_outlined,
            ),
          ),
      ],
    );
    if (id == null) return;
    final doc = _serviceDocs.firstWhere((d) => d.id == id);
    setState(() {
      _serviceId = id;
      _service = doc.data();
      _serviceError = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? _today,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() {
      _date = DateUtils.dateOnly(picked);
      _dateError = null;
      if (_time != null && _slotDisabled(_time!)) _time = null;
    });
  }

  // ---- step handling ------------------------------------------------------

  bool _validateDetails() {
    final formOk = _detailsForm.currentState!.validate();
    setState(() {
      _vehicleError = _vehicle == null ? 'Select your vehicle' : null;
      _serviceError = _service == null ? 'Select a service' : null;
      _dateError = _date == null
          ? 'Pick a date'
          : (_date!.isBefore(_today) ? 'Past dates are not allowed' : null);
      _timeError = _time == null ? 'Pick a time' : null;
    });
    return formOk &&
        _vehicleError == null &&
        _serviceError == null &&
        _dateError == null &&
        _timeError == null;
  }

  bool _validatePayment() {
    if (_method == null) {
      setState(() => _methodError = 'Choose a payment method');
      return false;
    }
    setState(() => _methodError = null);
    if (_method == 'Cash') return true;
    return _payForm.currentState!.validate();
  }

  void _next() {
    if (_step == 0) {
      if (_validateDetails()) setState(() => _step = 1);
    } else if (_step == 1) {
      if (_validatePayment()) setState(() => _step = 2);
    }
  }

  void _back() => setState(() => _step -= 1);

  Future<void> _submit() async {
    final scope = AppScope.read(context);
    setState(() => _busy = true);
    try {
      final d = _date!;
      final scheduled = DateTime(d.year, d.month, d.day, slotHour(_time!));
      final paidOnline = _method != 'Cash';
      await scope.vm.book({
        'customerId': scope.uid,
        'customerName': txt(scope.profile, 'name'),
        'customerPhone': txt(scope.profile, 'phone'),
        'vehicleId': _vehicleId,
        'vehicleLabel': _vehicleLabel,
        'serviceId': _serviceId,
        'serviceName': txt(_service!, 'name'),
        'serviceCategory': txt(_service!, 'category'),
        'serviceFee': _serviceFee,
        'homeServiceFee': kHomeServiceFee,
        'totalAmount': _total,
        'date': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        'time': _time,
        'scheduledAt': Timestamp.fromDate(scheduled),
        'location': _location.text.trim(),
        'notes': _notes.text.trim(),
        'paymentMethod': _method,
        'paymentStatus': paidOnline ? 'Paid' : 'Unpaid',
        // Only non-sensitive references are stored. Never save the full card
        // number or CVV in Firestore.
        if (_method == 'GCash') 'gcashNumber': _gcash.text.trim(),
        if (_method == 'Card') 'cardLast4': _last4,
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.success, size: 52),
          title: const Text('Request sent!'),
          content: const Text(
            'Your home-service request is Pending. We will confirm it shortly — you can track it under Bookings.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('View my bookings'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final titles = ['Book a service', 'Payment', 'Review & confirm'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_step])),
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final main = switch (_step) {
            0 => _detailsStep(),
            1 => _paymentStep(),
            _ => _reviewStep(),
          };
          return ResponsiveBody(
            maxWidth: 1000,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _StepHeader(step: _step),
                const SizedBox(height: 20),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: main),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: _summaryCard()),
                    ],
                  )
                else ...[
                  main,
                  const SizedBox(height: 20),
                  _summaryCard(),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _back,
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: BusyButton(
                      label: _step == 2 ? 'Confirm request' : 'Continue',
                      busy: _busy,
                      onPressed: _step == 2 ? _submit : _next,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailsStep() {
    return Form(
      key: _detailsForm,
      child: Column(
        children: [
          SelectField(
            label: 'Vehicle',
            icon: Icons.directions_car_outlined,
            value: _vehicle == null ? null : _vehicleLabel,
            errorText: _vehicleError,
            onTap: _pickVehicle,
          ),
          const SizedBox(height: 14),
          SelectField(
            label: 'Repair service',
            icon: Icons.build_outlined,
            value: _service == null ? null : txt(_service!, 'name'),
            errorText: _serviceError,
            onTap: _pickService,
          ),
          const SizedBox(height: 14),
          SelectField(
            label: 'Preferred date',
            icon: Icons.calendar_today_outlined,
            value: _date == null ? null : fmtDate(_date!),
            errorText: _dateError,
            onTap: _pickDate,
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Preferred time',
              style: TextStyle(
                color: _timeError == null ? AppColors.muted : AppColors.danger,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in kTimeSlots)
                  ChoiceChip(
                    label: Text(t),
                    selected: _time == t,
                    onSelected: _slotDisabled(t)
                        ? null
                        : (_) => setState(() {
                            _time = t;
                            _timeError = null;
                          }),
                  ),
              ],
            ),
          ),
          if (_timeError != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _timeError!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
            ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _location,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Service location',
              hintText: 'House no., street, barangay, city',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Enter where the mechanic should go';
              }
              if (v.trim().length < 8) return 'Please enter a more complete address';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _notes,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes for the mechanic (optional)',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentStep() {
    const methods = {
      'Cash': (Icons.payments_outlined, 'Pay the mechanic after the service'),
      'GCash': (Icons.phone_android, 'Pay now with your GCash number'),
      'Card': (Icons.credit_card, 'Pay now with a credit/debit card'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in kPaymentMethods) ...[
          _MethodTile(
            icon: methods[m]!.$1,
            title: m,
            subtitle: methods[m]!.$2,
            selected: _method == m,
            onTap: () => setState(() {
              _method = m;
              _methodError = null;
            }),
          ),
          const SizedBox(height: 10),
        ],
        if (_methodError != null)
          Text(
            _methodError!,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        if (_method == 'GCash' || _method == 'Card') ...[
          const SizedBox(height: 10),
          Form(
            key: _payForm,
            child: _method == 'GCash'
                ? TextFormField(
                    controller: _gcash,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'GCash mobile number',
                      hintText: '09171234567',
                      prefixIcon: Icon(Icons.phone_android),
                    ),
                    validator: phoneValidator,
                  )
                : Column(
                    children: [
                      TextFormField(
                        controller: _cardNo,
                        keyboardType: TextInputType.number,
                        inputFormatters: [_CardNumberFormatter()],
                        decoration: const InputDecoration(
                          labelText: 'Card number',
                          prefixIcon: Icon(Icons.credit_card),
                        ),
                        validator: (v) =>
                            (v ?? '').replaceAll(RegExp(r'\D'), '').length == 16
                            ? null
                            : 'Enter the 16-digit card number',
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _cardName,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Name on card',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => requiredText(v, 'the name on the card'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _expiry,
                              keyboardType: TextInputType.number,
                              inputFormatters: [_ExpiryFormatter()],
                              decoration: const InputDecoration(
                                labelText: 'Expiry (MM/YY)',
                              ),
                              validator: _validateExpiry,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cvv,
                              obscureText: true,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: const InputDecoration(labelText: 'CVV'),
                              validator: (v) =>
                                  RegExp(r'^\d{3,4}$').hasMatch(v ?? '')
                                  ? null
                                  : '3–4 digits',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  String? _validateExpiry(String? v) {
    final m = RegExp(r'^(0[1-9]|1[0-2])/(\d{2})$').firstMatch(v ?? '');
    if (m == null) return 'Use MM/YY';
    final month = int.parse(m.group(1)!);
    final year = 2000 + int.parse(m.group(2)!);
    final now = DateTime.now();
    if (year < now.year || (year == now.year && month < now.month)) {
      return 'Card has expired';
    }
    return null;
  }

  Widget _reviewStep() {
    final method = _method ?? '—';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InfoRow('Vehicle', _vehicleLabel),
            InfoRow('Service', txt(_service ?? {}, 'name', '—')),
            InfoRow('Date', _date == null ? '—' : fmtDate(_date!)),
            InfoRow('Time', _time ?? '—'),
            InfoRow('Location', _location.text.trim()),
            if (_notes.text.trim().isNotEmpty) InfoRow('Notes', _notes.text.trim()),
            const Divider(height: 24),
            InfoRow('Payment', method),
            if (_method == 'GCash') InfoRow('GCash', _gcash.text.trim()),
            if (_method == 'Card') InfoRow('Card', '•••• $_last4'),
            InfoRow(
              'Status',
              _method == 'Cash' ? 'Unpaid — pay the mechanic' : 'Paid',
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _line('Service', _service == null ? '—' : txt(_service!, 'name')),
            _line('Service fee', _service == null ? '—' : money(_serviceFee)),
            _line('Home service fee', money(kHomeServiceFee)),
            const Divider(height: 24),
            Row(
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  _service == null ? '—' : money(_total),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(a, style: const TextStyle(color: AppColors.muted))),
        const SizedBox(width: 12),
        Flexible(child: Text(b, textAlign: TextAlign.right)),
      ],
    ),
  );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Details', 'Payment', 'Review'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: i <= step ? 1 : 0,
                    minHeight: 5,
                    backgroundColor: AppColors.outline,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${i + 1}. ${labels[i]}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: i == step ? FontWeight.w700 : FontWeight.w400,
                    color: i <= step ? null : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          if (i < labels.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.outline,
        width: selected ? 1.6 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.muted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColors.primary : AppColors.outline,
            ),
          ],
        ),
      ),
    ),
  );
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    var d = next.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 4) d = d.substring(0, 4);
    final t = d.length > 2 ? '${d.substring(0, 2)}/${d.substring(2)}' : d;
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    var d = next.text.replaceAll(RegExp(r'\D'), '');
    if (d.length > 16) d = d.substring(0, 16);
    final t = [
      for (var i = 0; i < d.length; i += 4) d.substring(i, i + 4 > d.length ? d.length : i + 4),
    ].join(' ');
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }
}