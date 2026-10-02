import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ride_repository.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'appointment_detail.dart';
import 'booking_flow.dart';
import 'customer_bookings.dart';
import 'customer_services.dart';
import 'customer_vehicles.dart';
import 'ride_app.dart';

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _index = 0;
  late final QStream _vehicles;
  late final QStream _appointments;
  late final QStream _services;

  static const _items = [
    NavItem('Home', Icons.home_outlined, Icons.home),
    NavItem('Services', Icons.build_outlined, Icons.build),
    NavItem('Bookings', Icons.event_note_outlined, Icons.event_note),
    NavItem('Profile', Icons.person_outline, Icons.person),
  ];

  @override
  void initState() {
    super.initState();
    final s = AppScope.read(context);
    _vehicles = s.vm.vehiclesFor(s.uid);
    _appointments = s.vm.appointmentsFor(s.uid);
    _services = s.vm.services();
  }

  void _go(int i) => setState(() => _index = i);

  Future<void> _book() async {
    final ok = await openPage<bool>(context, const BookingPage());
    if (ok == true && mounted) _go(2);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: _items[_index].label == 'Home' ? 'RideAutoFix' : _items[_index].label,
      items: _items,
      index: _index,
      onSelect: _go,
      fab: _index == 3
          ? null
          : FloatingActionButton.extended(
              onPressed: _book,
              icon: const Icon(Icons.add),
              label: const Text('Book service'),
            ),
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(
            vehicles: _vehicles,
            appointments: _appointments,
            onGo: _go,
            onBook: _book,
          ),
          ServicesPage(services: _services, onBooked: () => _go(2)),
          BookingsPage(appointments: _appointments),
          const ProfilePage(),
        ],
      ),
    );
  }
}

// ---- Home -----------------------------------------------------------------

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.vehicles,
    required this.appointments,
    required this.onGo,
    required this.onBook,
  });
  final QStream vehicles;
  final QStream appointments;
  final ValueChanged<int> onGo;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final name = txt(scope.profile, 'name', 'there').split(' ').first;

    return ResponsiveBody(
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 100),
        children: [
          Text(
            'Hi, $name 👋',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'What does your ride need today?',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          _VehicleSummary(stream: vehicles),
          const SizedBox(height: 16),
          AdaptiveWrap(
            minItemWidth: 150,
            children: [
              _ActionTile(
                icon: Icons.build_circle_outlined,
                label: 'Repair Services',
                onTap: () => onGo(1),
              ),
              _ActionTile(
                icon: Icons.event_available_outlined,
                label: 'Book Home Service',
                onTap: onBook,
              ),
              _ActionTile(
                icon: Icons.directions_car_outlined,
                label: 'My Vehicles',
                onTap: () => openPage(context, const VehiclesPage()),
              ),
              _ActionTile(
                icon: Icons.history,
                label: 'History',
                onTap: () => onGo(2),
              ),
            ],
          ),
          const SectionTitle('Upcoming appointment'),
          QueryView(
            stream: appointments,
            builder: (context, docs) {
              final active = docs.where((d) => isActiveStatus(txt(d.data(), 'status', 'Pending'))).toList()
                ..sort((a, b) => sortKey(a.data()).compareTo(sortKey(b.data())));
              if (active.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.event_busy_outlined, color: AppColors.muted),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'No upcoming appointments. Book a home service and a mechanic will come to you.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final first = active.first;
              return AppointmentCard(
                id: first.id,
                data: first.data(),
                onTap: () => openPage(context, AppointmentDetailPage(id: first.id)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VehicleSummary extends StatelessWidget {
  const _VehicleSummary({required this.stream});
  final QStream stream;

  @override
  Widget build(BuildContext context) {
    return QueryView(
      stream: stream,
      builder: (context, docs) {
        if (docs.isEmpty) {
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const NetImage(null, width: 56, height: 56),
              title: const Text('No vehicle yet'),
              subtitle: const Text('Add your vehicle to start booking'),
              trailing: const Icon(Icons.add_circle_outline),
              onTap: () => openPage(context, const VehicleFormPage()),
            ),
          );
        }
        final v = docs.first.data();
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: NetImage(
              txt(v, 'photoUrl'),
              width: 56,
              height: 56,
            ),
            title: Text(
              vehicleTitle(v),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${txt(v, 'plate')} · ${docs.length == 1 ? 'My vehicle' : '${docs.length} vehicles'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openPage(context, const VehiclesPage()),
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}

// ---- Profile --------------------------------------------------------------

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  bool _saving = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final p = AppScope.read(context).profile;
    _name = TextEditingController(text: txt(p, 'name'));
    _phone = TextEditingController(text: txt(p, 'phone'));
    _address = TextEditingController(text: txt(p, 'address'));
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final XFile? photo = await pickPhoto(context);
    if (photo == null || !mounted) return;
    final scope = AppScope.read(context);
    setState(() => _uploading = true);
    try {
      final url = await scope.vm.uploadPhoto(photo, folder: 'rideautofix/profiles');
      await scope.vm.updateProfile(scope.uid, photoUrl: url);
      if (mounted) showSnack(context, 'Profile photo updated.');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final scope = AppScope.read(context);
    setState(() => _saving = true);
    try {
      await scope.vm.updateProfile(
        scope.uid,
        name: _name.text,
        phone: _phone.text,
        address: _address.text,
      );
      if (mounted) showSnack(context, 'Changes saved.');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final repo = AppScope.read(context).repository;
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again to book services.',
      confirmLabel: 'Log out',
    );
    if (ok) await repo.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final p = scope.profile;
    final initial = txt(p, 'name', '?').characters.first.toUpperCase();

    return ResponsiveBody(
      maxWidth: 640,
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        children: [
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _uploading ? null : _changePhoto,
                  child: SizedBox(
                    width: 104,
                    height: 104,
                    child: txt(p, 'photoUrl').isEmpty
                        ? CircleAvatar(
                            backgroundColor: AppColors.surfaceHigh,
                            child: Text(
                              initial,
                              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700),
                            ),
                          )
                        : NetImage(txt(p, 'photoUrl'), width: 104, height: 104, circle: true),
                  ),
                ),
                if (_uploading)
                  const Positioned.fill(
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.primary,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 17,
                      color: Colors.white,
                      tooltip: 'Change photo',
                      icon: const Icon(Icons.photo_camera),
                      onPressed: _uploading ? null : _changePhoto,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => requiredText(v, 'your full name'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: txt(p, 'email'),
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: phoneValidator,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _address,
                  minLines: 2,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: BusyButton(
                    label: 'Save changes',
                    busy: _saving,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.directions_car_outlined),
              title: const Text('My vehicles'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openPage(context, const VehiclesPage()),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }
}