import 'package:flutter/material.dart';

import '../ui/format.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'booking_flow.dart';

class ServicesPage extends StatefulWidget {
  const ServicesPage({super.key, required this.services, required this.onBooked});
  final QStream services;
  final VoidCallback onBooked;

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  String _query = '';
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    return QueryView(
      stream: widget.services,
      builder: (context, docs) {
        final categories = <String>{
          for (final d in docs)
            if (txt(d.data(), 'category').isNotEmpty) txt(d.data(), 'category'),
        }.toList()..sort();
        final q = _query.trim().toLowerCase();
        final shown = docs.where((d) {
          final m = d.data();
          final matchesCat = _category == 'All' || txt(m, 'category') == _category;
          final matchesQ =
              q.isEmpty ||
              txt(m, 'name').toLowerCase().contains(q) ||
              txt(m, 'description').toLowerCase().contains(q);
          return matchesCat && matchesQ;
        }).toList()..sort((a, b) => txt(a.data(), 'name').compareTo(txt(b.data(), 'name')));

        return ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 100),
            children: [
              SearchField(
                hint: 'Search services',
                onChanged: (v) => setState(() => _query = v),
              ),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final c in ['All', ...categories])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.build_outlined,
                    title: 'No services available yet',
                    message: 'Please check back soon.',
                  ),
                )
              else if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.search_off,
                    title: 'No matching services',
                    message: 'Try a different search or category.',
                  ),
                )
              else
                AdaptiveWrap(
                  minItemWidth: 280,
                  children: [
                    for (final d in shown)
                      _ServiceCard(
                        data: d.data(),
                        onTap: () async {
                          final booked = await openPage<bool>(
                            context,
                            ServiceDetailPage(id: d.id, data: d.data()),
                          );
                          if (booked == true) widget.onBooked();
                        },
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

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.data, required this.onTap});
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: NetImage(
                txt(data, 'photoUrl'),
                width: double.infinity,
                radius: 0,
                icon: Icons.build_circle_outlined,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (txt(data, 'category').isNotEmpty)
                    Text(
                      txt(data, 'category').toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    txt(data, 'name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    txt(data, 'description'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        money(numOf(data['price'])),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Spacer(),
                      if (txt(data, 'estimatedTime').isNotEmpty) ...[
                        const Icon(Icons.schedule, size: 15, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text(
                          txt(data, 'estimatedTime'),
                          style: const TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceDetailPage extends StatelessWidget {
  const ServiceDetailPage({super.key, required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service details')),
      body: ResponsiveBody(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: NetImage(
                txt(data, 'photoUrl'),
                width: double.infinity,
                radius: 18,
                icon: Icons.build_circle_outlined,
              ),
            ),
            const SizedBox(height: 18),
            if (txt(data, 'category').isNotEmpty)
              Text(
                txt(data, 'category').toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              txt(data, 'name'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    InfoRow('Service fee', money(numOf(data['price']))),
                    InfoRow('Home service fee', money(kHomeServiceFee)),
                    if (txt(data, 'estimatedTime').isNotEmpty)
                      InfoRow('Estimated time', txt(data, 'estimatedTime')),
                  ],
                ),
              ),
            ),
            const SectionTitle('About this service'),
            Text(
              txt(data, 'description', 'No description provided.'),
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Book this service'),
                  onPressed: () async {
                    final ok = await openPage<bool>(
                      context,
                      BookingPage(serviceId: id, service: data),
                    );
                    if (ok == true && context.mounted) Navigator.pop(context, true);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}