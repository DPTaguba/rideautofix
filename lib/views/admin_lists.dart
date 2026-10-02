import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ride_repository.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'appointment_detail.dart';
import 'ride_app.dart';

// ---- Customers --------------------------------------------------------------

class AdminCustomersPage extends StatefulWidget {
  const AdminCustomersPage({super.key, required this.customers});
  final QStream customers;

  @override
  State<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends State<AdminCustomersPage> {
  String _query = '';

  void _details(Map<String, dynamic> m) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Avatar(m, radius: 36),
              const SizedBox(height: 12),
              Text(
                txt(m, 'name', 'Customer'),
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              InfoRow('Email', txt(m, 'email', '—')),
              InfoRow('Phone', txt(m, 'phone', '—')),
              InfoRow('Address', txt(m, 'address', '—')),
              InfoRow(
                'Joined',
                tsToDate(m['createdAt']) == null ? '—' : fmtDate(tsToDate(m['createdAt'])!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return QueryView(
      stream: widget.customers,
      builder: (context, docs) {
        final q = _query.trim().toLowerCase();
        final shown = docs.where((d) {
          final m = d.data();
          return q.isEmpty ||
              txt(m, 'name').toLowerCase().contains(q) ||
              txt(m, 'email').toLowerCase().contains(q) ||
              txt(m, 'phone').contains(q);
        }).toList()..sort((a, b) => txt(a.data(), 'name').compareTo(txt(b.data(), 'name')));

        return ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            children: [
              SearchField(
                hint: 'Search by name, email or phone',
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 16),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'No customers found',
                    message: 'Try a different search.',
                  ),
                )
              else
                AdaptiveWrap(
                  minItemWidth: 340,
                  children: [
                    for (final d in shown)
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: _Avatar(d.data()),
                          title: Text(
                            txt(d.data(), 'name', 'Customer'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${txt(d.data(), 'email')}\n${txt(d.data(), 'phone')}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          onTap: () => _details(d.data()),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.m, {this.radius = 24});
  final Map<String, dynamic> m;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = txt(m, 'photoUrl');
    if (url.isNotEmpty) {
      return NetImage(url, width: radius * 2, height: radius * 2, circle: true);
    }
    final name = txt(m, 'name', '?');
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceHigh,
      child: Text(
        name.characters.first.toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: radius * 0.8),
      ),
    );
  }
}

// ---- Vehicles ---------------------------------------------------------------

class AdminVehiclesPage extends StatefulWidget {
  const AdminVehiclesPage({super.key, required this.vehicles, required this.customers});
  final QStream vehicles;
  final QStream customers;

  @override
  State<AdminVehiclesPage> createState() => _AdminVehiclesPageState();
}

class _AdminVehiclesPageState extends State<AdminVehiclesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return QueryView(
      stream: widget.customers,
      builder: (context, owners) {
        final names = {for (final o in owners) o.id: txt(o.data(), 'name', 'Unknown')};
        return QueryView(
          stream: widget.vehicles,
          builder: (context, docs) {
            final q = _query.trim().toLowerCase();
            final shown = docs.where((d) {
              final m = d.data();
              final owner = (names[txt(m, 'ownerId')] ?? '').toLowerCase();
              return q.isEmpty ||
                  vehicleTitle(m).toLowerCase().contains(q) ||
                  txt(m, 'plate').toLowerCase().contains(q) ||
                  owner.contains(q);
            }).toList()..sort((a, b) => vehicleTitle(a.data()).compareTo(vehicleTitle(b.data())));

            return ResponsiveBody(
              child: ListView(
                padding: const EdgeInsets.only(top: 16, bottom: 32),
                children: [
                  SearchField(
                    hint: 'Search by plate, vehicle or owner',
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 16),
                  if (shown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.directions_car_outlined,
                        title: 'No vehicles found',
                        message: 'Registered customer vehicles appear here.',
                      ),
                    )
                  else
                    AdaptiveWrap(
                      minItemWidth: 340,
                      children: [
                        for (final d in shown)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  NetImage(txt(d.data(), 'photoUrl'), width: 72, height: 72),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          vehicleTitle(d.data()),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '${txt(d.data(), 'plate')} · ${txt(d.data(), 'type')}',
                                          style: const TextStyle(color: AppColors.muted),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Owner: ${names[txt(d.data(), 'ownerId')] ?? 'Unknown'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ---- Services ---------------------------------------------------------------

class AdminServicesPage extends StatelessWidget {
  const AdminServicesPage({super.key, required this.services});
  final QStream services;

  Future<void> _open(BuildContext context, {String? id, Map<String, dynamic>? data}) async {
    final saved = await openPage<bool>(context, ServiceFormPage(id: id, data: data));
    if (saved == true && context.mounted) showSnack(context, 'Service saved.');
  }

  @override
  Widget build(BuildContext context) {
    final vm = AppScope.read(context).vm;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context),
        icon: const Icon(Icons.add),
        label: const Text('Add service'),
      ),
      body: QueryView(
        stream: services,
        builder: (context, docs) {
          if (docs.isEmpty) {
            return EmptyState(
              icon: Icons.build_outlined,
              title: 'No services yet',
              message: 'Add the repair and maintenance services you offer.',
              action: FilledButton.icon(
                onPressed: () => _open(context),
                icon: const Icon(Icons.add),
                label: const Text('Add service'),
              ),
            );
          }
          final sorted = [...docs]
            ..sort((a, b) => txt(a.data(), 'name').compareTo(txt(b.data(), 'name')));
          return ResponsiveBody(
            child: ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 100),
              children: [
                AdaptiveWrap(
                  minItemWidth: 360,
                  children: [
                    for (final d in sorted)
                      Opacity(
                        opacity: d.data()['active'] == false ? 0.55 : 1,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _open(context, id: d.id, data: d.data()),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  NetImage(
                                    txt(d.data(), 'photoUrl'),
                                    width: 72,
                                    height: 72,
                                    icon: Icons.build_circle_outlined,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          txt(d.data(), 'name'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          '${txt(d.data(), 'category')} · ${money(numOf(d.data()['price']))}',
                                          style: const TextStyle(color: AppColors.muted),
                                        ),
                                        Text(
                                          d.data()['active'] == false ? 'Archived' : 'Visible to customers',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: d.data()['active'] == false
                                                ? AppColors.muted
                                                : AppColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: d.data()['active'] != false,
                                    onChanged: (v) async {
                                      try {
                                        await vm.setServiceActive(d.id, v);
                                      } catch (e) {
                                        if (context.mounted) {
                                          showSnack(context, friendlyError(e), error: true);
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ServiceFormPage extends StatefulWidget {
  const ServiceFormPage({super.key, this.id, this.data});
  final String? id;
  final Map<String, dynamic>? data;

  @override
  State<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends State<ServiceFormPage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: txt(widget.data ?? {}, 'name'));
  late final _category = TextEditingController(text: txt(widget.data ?? {}, 'category'));
  late final _description = TextEditingController(text: txt(widget.data ?? {}, 'description'));
  late final _time = TextEditingController(text: txt(widget.data ?? {}, 'estimatedTime'));
  late final _price = TextEditingController(
    text: widget.data == null ? '' : '${numOf(widget.data!['price'])}'.replaceAll(RegExp(r'\.0$'), ''),
  );
  late String? _photoUrl = widget.data == null ? null : txt(widget.data!, 'photoUrl');
  XFile? _photo;
  Uint8List? _photoBytes;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _category, _description, _time, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick() async {
    final photo = await pickPhoto(context);
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = photo;
      _photoBytes = bytes;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final vm = AppScope.read(context).vm;
    setState(() => _busy = true);
    try {
      var url = _photoUrl ?? '';
      if (_photo != null) {
        url = await vm.uploadPhoto(_photo!, folder: 'rideautofix/services');
      }
      await vm.saveService({
        'name': _name.text.trim(),
        'category': _category.text.trim(),
        'description': _description.text.trim(),
        'estimatedTime': _time.text.trim(),
        'price': double.parse(_price.text.trim()),
        'photoUrl': url,
      }, id: widget.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.id != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Edit service' : 'Add service')),
      body: ResponsiveBody(
        maxWidth: 640,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              PhotoField(
                bytes: _photoBytes,
                url: _photoUrl,
                height: 190,
                label: 'Add a service photo',
                icon: Icons.build_circle_outlined,
                onTap: _busy ? () {} : _pick,
                onRemove: _busy
                    ? null
                    : () => setState(() {
                        _photo = null;
                        _photoBytes = null;
                        _photoUrl = null;
                      }),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Service name', hintText: 'Oil change'),
                validator: (v) => requiredText(v, 'the service name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _category,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Category', hintText: 'Maintenance'),
                validator: (v) => requiredText(v, 'a category'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => requiredText(v, 'a description'),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _time,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Estimated time',
                        hintText: '1–2 hours',
                      ),
                      validator: (v) => requiredText(v, 'the estimated time'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(labelText: 'Price (₱)', hintText: '1500'),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').trim());
                        if (n == null) return 'Enter the price';
                        if (n <= 0) return 'Must be above 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              BusyButton(
                label: editing ? 'Save changes' : 'Add service',
                busy: _busy,
                onPressed: _save,
              ),
              if (_busy && _photo != null)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    'Uploading photo…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Appointments -----------------------------------------------------------

class AdminAppointmentsPage extends StatefulWidget {
  const AdminAppointmentsPage({super.key, required this.appointments});
  final QStream appointments;

  @override
  State<AdminAppointmentsPage> createState() => _AdminAppointmentsPageState();
}

class _AdminAppointmentsPageState extends State<AdminAppointmentsPage> {
  static const _filters = <String, Set<String>?>{
    'All': null,
    'Pending': {'Pending'},
    'Confirmed': {'Confirmed'},
    'In progress': {'On the Way', 'In Service'},
    'Done': {'Completed'},
    'Cancelled': {'Cancelled'},
  };
  String _filter = 'All';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return QueryView(
      stream: widget.appointments,
      builder: (context, docs) {
        final statuses = _filters[_filter];
        final q = _query.trim().toLowerCase();
        final shown = docs.where((d) {
          final m = d.data();
          final okStatus = statuses == null || statuses.contains(txt(m, 'status', 'Pending'));
          final okQuery =
              q.isEmpty ||
              txt(m, 'customerName').toLowerCase().contains(q) ||
              txt(m, 'serviceName').toLowerCase().contains(q) ||
              shortId(d.id).toLowerCase().contains(q);
          return okStatus && okQuery;
        }).toList();

        return ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 32),
            children: [
              SearchField(
                hint: 'Search customer, service or number',
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final f in _filters.keys)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'No appointments found',
                    message: 'Try another filter or search.',
                  ),
                )
              else
                AdaptiveWrap(
                  minItemWidth: 400,
                  children: [
                    for (final d in shown)
                      AppointmentCard(
                        id: d.id,
                        data: d.data(),
                        showCustomer: true,
                        onTap: () => openPage(
                          context,
                          AppointmentDetailPage(id: d.id, admin: true),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}