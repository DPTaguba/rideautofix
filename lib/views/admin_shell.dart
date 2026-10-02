import 'package:flutter/material.dart';

import '../data/ride_repository.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'admin_lists.dart';
import 'appointment_detail.dart';
import 'ride_app.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  late final QStream _customers;
  late final QStream _vehicles;
  late final QStream _services;
  late final QStream _appointments;

  static const _items = [
    NavItem('Dash', Icons.dashboard_outlined, Icons.dashboard),
    NavItem('Users', Icons.people_outline, Icons.people),
    NavItem('Cars', Icons.directions_car_outlined, Icons.directions_car),
    NavItem('Services', Icons.build_outlined, Icons.build),
    NavItem('Bookings', Icons.event_note_outlined, Icons.event_note),
  ];
  static const _titles = [
    'Admin Dashboard',
    'Customers',
    'Vehicles',
    'Services',
    'Appointments',
  ];

  @override
  void initState() {
    super.initState();
    final vm = AppScope.read(context).vm;
    _customers = vm.customers();
    _vehicles = vm.vehicles();
    _services = vm.allServices();
    _appointments = vm.appointments();
  }

  Future<void> _logout() async {
    final repo = AppScope.read(context).repository;
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again to manage bookings.',
      confirmLabel: 'Log out',
    );
    if (ok) await repo.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: _titles[_index],
      items: _items,
      index: _index,
      onSelect: (i) => setState(() => _index = i),
      actions: [
        IconButton(
          tooltip: 'Log out',
          icon: const Icon(Icons.logout),
          onPressed: _logout,
        ),
      ],
      body: IndexedStack(
        index: _index,
        children: [
          DashboardPage(
            appointments: _appointments,
            onSeeAll: () => setState(() => _index = 4),
          ),
          AdminCustomersPage(customers: _customers),
          AdminVehiclesPage(vehicles: _vehicles, customers: _customers),
          AdminServicesPage(services: _services),
          AdminAppointmentsPage(appointments: _appointments),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.appointments, required this.onSeeAll});
  final QStream appointments;
  final VoidCallback onSeeAll;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, int>> _counts = AppScope.read(context).vm.dashboardCounts();

  Future<void> _refresh() async {
    final f = AppScope.read(context).vm.dashboardCounts();
    setState(() => _counts = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ResponsiveBody(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          children: [
            FutureBuilder<Map<String, int>>(
              future: _counts,
              builder: (context, snap) {
                if (snap.hasError) {
                  return ErrorState(
                    message: friendlyError(snap.error!),
                    onRetry: _refresh,
                  );
                }
                final c = snap.data;
                String v(String k) => c == null ? '…' : '${c[k] ?? 0}';
                return AdaptiveWrap(
                  minItemWidth: 160,
                  children: [
                    _StatCard(Icons.people_outline, 'Customers', v('customers')),
                    _StatCard(Icons.directions_car_outlined, 'Vehicles', v('vehicles')),
                    _StatCard(Icons.build_outlined, 'Services', v('services')),
                    _StatCard(Icons.event_note_outlined, 'Appointments', v('appointments')),
                  ],
                );
              },
            ),
            SectionTitle(
              'Recent appointments',
              trailing: TextButton(
                onPressed: widget.onSeeAll,
                child: const Text('See all'),
              ),
            ),
            QueryView(
              stream: widget.appointments,
              builder: (context, docs) {
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: 'No appointments yet',
                      message: 'New booking requests will show up here.',
                    ),
                  );
                }
                return AdaptiveWrap(
                  minItemWidth: 400,
                  children: [
                    for (final d in docs.take(6))
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    ),
  );
}