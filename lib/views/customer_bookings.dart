import 'package:flutter/material.dart';

import '../ui/format.dart';
import '../ui/widgets.dart';
import 'appointment_detail.dart';

class BookingsPage extends StatelessWidget {
  const BookingsPage({super.key, required this.appointments});
  final QStream appointments;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const ResponsiveBody(
            maxWidth: 700,
            child: TabBar(
              tabs: [Tab(text: 'Active'), Tab(text: 'Previous')],
            ),
          ),
          Expanded(
            child: QueryView(
              stream: appointments,
              builder: (context, docs) {
                final active = docs
                    .where((d) => isActiveStatus(txt(d.data(), 'status', 'Pending')))
                    .toList()
                  ..sort((a, b) => sortKey(a.data()).compareTo(sortKey(b.data())));
                final previous = docs
                    .where((d) => !isActiveStatus(txt(d.data(), 'status', 'Pending')))
                    .toList()
                  ..sort((a, b) => sortKey(b.data()).compareTo(sortKey(a.data())));
                return TabBarView(
                  children: [
                    _List(
                      docs: active,
                      emptyTitle: 'No active appointments',
                      emptyMessage: 'Book a home service and track it here.',
                    ),
                    _List(
                      docs: previous,
                      emptyTitle: 'No previous appointments',
                      emptyMessage: 'Completed and cancelled bookings appear here.',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.docs,
    required this.emptyTitle,
    required this.emptyMessage,
  });
  final Docs docs;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) {
      return EmptyState(
        icon: Icons.event_note_outlined,
        title: emptyTitle,
        message: emptyMessage,
      );
    }
    return ResponsiveBody(
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 100),
        children: [
          AdaptiveWrap(
            minItemWidth: 400,
            children: [
              for (final d in docs)
                AppointmentCard(
                  id: d.id,
                  data: d.data(),
                  onTap: () =>
                      openPage(context, AppointmentDetailPage(id: d.id)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}