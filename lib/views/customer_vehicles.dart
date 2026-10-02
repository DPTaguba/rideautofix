import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ride_repository.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ride_app.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  late final QStream _stream = () {
    final s = AppScope.read(context);
    return s.vm.vehiclesFor(s.uid);
  }();

  Future<void> _open({QueryDocumentSnapshot<Map<String, dynamic>>? doc}) async {
    final saved = await openPage<bool>(
      context,
      VehicleFormPage(id: doc?.id, data: doc?.data()),
    );
    if (saved == true && mounted) showSnack(context, 'Vehicle saved.');
  }

  Future<void> _delete(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final vm = AppScope.read(context).vm;
    final ok = await confirmDialog(
      context,
      title: 'Delete vehicle?',
      message: '${vehicleTitle(doc.data())} will be removed from your account.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await vm.deleteVehicle(doc.id);
      if (mounted) showSnack(context, 'Vehicle deleted.');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Vehicles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Add vehicle'),
      ),
      body: QueryView(
        stream: _stream,
        builder: (context, docs) {
          if (docs.isEmpty) {
            return EmptyState(
              icon: Icons.directions_car_outlined,
              title: 'No vehicles yet',
              message: 'Add your vehicle so the mechanic knows what to bring.',
              action: FilledButton.icon(
                onPressed: () => _open(),
                icon: const Icon(Icons.add),
                label: const Text('Add vehicle'),
              ),
            );
          }
          final sorted = [...docs]
            ..sort((a, b) => vehicleTitle(a.data()).compareTo(vehicleTitle(b.data())));
          return ResponsiveBody(
            child: ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 100),
              children: [
                AdaptiveWrap(
                  minItemWidth: 340,
                  children: [
                    for (final d in sorted)
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _open(doc: d),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                NetImage(
                                  txt(d.data(), 'photoUrl'),
                                  width: 76,
                                  height: 76,
                                ),
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
                                      const SizedBox(height: 2),
                                      Text(
                                        '${txt(d.data(), 'plate')} · ${txt(d.data(), 'type')}',
                                        style: const TextStyle(color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (v) =>
                                      v == 'edit' ? _open(doc: d) : _delete(d),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ],
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

class VehicleFormPage extends StatefulWidget {
  const VehicleFormPage({super.key, this.id, this.data});
  final String? id;
  final Map<String, dynamic>? data;

  @override
  State<VehicleFormPage> createState() => _VehicleFormPageState();
}

class _VehicleFormPageState extends State<VehicleFormPage> {
  final _form = GlobalKey<FormState>();
  late final _brand = TextEditingController(text: txt(widget.data ?? {}, 'brand'));
  late final _model = TextEditingController(text: txt(widget.data ?? {}, 'model'));
  late final _year = TextEditingController(text: txt(widget.data ?? {}, 'year'));
  late final _plate = TextEditingController(text: txt(widget.data ?? {}, 'plate'));
  late String? _type = widget.data == null ? null : txt(widget.data!, 'type');
  late String? _photoUrl = widget.data == null ? null : txt(widget.data!, 'photoUrl');
  XFile? _photo;
  Uint8List? _photoBytes;
  String? _typeError;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_brand, _model, _year, _plate]) {
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
    final valid = _form.currentState!.validate();
    if (_type == null || _type!.isEmpty) {
      setState(() => _typeError = 'Select a vehicle type');
      return;
    }
    if (!valid) return;
    final scope = AppScope.read(context);
    setState(() => _busy = true);
    try {
      var url = _photoUrl ?? '';
      if (_photo != null) url = await scope.vm.uploadVehiclePhoto(_photo!);
      await scope.vm.saveVehicle(scope.uid, {
        'type': _type,
        'brand': _brand.text.trim(),
        'model': _model.text.trim(),
        'year': int.parse(_year.text.trim()),
        'plate': _plate.text.trim().toUpperCase(),
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
      appBar: AppBar(title: Text(editing ? 'Edit vehicle' : 'Add vehicle')),
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
                label: 'Add a photo of your vehicle',
                icon: Icons.directions_car_outlined,
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
              const Text('Vehicle type', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in kVehicleTypes)
                    ChoiceChip(
                      label: Text(t),
                      selected: _type == t,
                      onSelected: (_) => setState(() {
                        _type = t;
                        _typeError = null;
                      }),
                    ),
                ],
              ),
              if (_typeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _typeError!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _brand,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Brand', hintText: 'Toyota'),
                validator: (v) => requiredText(v, 'the brand'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _model,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Model', hintText: 'Vios'),
                validator: (v) => requiredText(v, 'the model'),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(labelText: 'Year', hintText: '2020'),
                      validator: (v) {
                        final y = int.tryParse((v ?? '').trim());
                        final max = DateTime.now().year + 1;
                        if (y == null) return 'Enter the year';
                        if (y < 1950 || y > max) return '1950–$max';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _plate,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Plate number',
                        hintText: 'ABC 1234',
                      ),
                      validator: (v) => requiredText(v, 'the plate number'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              BusyButton(
                label: editing ? 'Save changes' : 'Save vehicle',
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