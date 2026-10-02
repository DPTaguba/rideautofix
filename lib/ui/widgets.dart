import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ride_repository.dart' show friendlyError;
import 'format.dart';
import 'theme.dart';

typedef QStream = Stream<QuerySnapshot<Map<String, dynamic>>>;
typedef Docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>;

Future<T?> openPage<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.danger : null,
      ),
    );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(88, 44),
            backgroundColor: destructive ? AppColors.danger : null,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

// ---- layout ---------------------------------------------------------------

/// Centers content and caps its width so pages look good on phones, tablets
/// and desktop/web windows alike.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 1000});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: w < 600 ? 16 : 24),
          child: child,
        ),
      ),
    );
  }
}

/// Lays children out in as many equal columns as fit (1 on phones, more on
/// wider screens). Items size to their own content height.
class AdaptiveWrap extends StatelessWidget {
  const AdaptiveWrap({
    super.key,
    required this.children,
    this.minItemWidth = 280,
    this.spacing = 12,
  });
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = ((c.maxWidth + spacing) / (minItemWidth + spacing))
            .floor()
            .clamp(1, 6);
        final itemW = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final w in children) SizedBox(width: itemW, child: w)],
        );
      },
    );
  }
}

class NavItem {
  const NavItem(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Bottom navigation on phones, side rail on tablets / desktop / web.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.title,
    required this.items,
    required this.index,
    required this.onSelect,
    required this.body,
    this.actions = const [],
    this.fab,
  });
  final String title;
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  final Widget body;
  final List<Widget> actions;
  final Widget? fab;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 800;
        final appBar = AppBar(title: Text(title), actions: actions);
        if (!wide) {
          return Scaffold(
            appBar: appBar,
            body: body,
            floatingActionButton: fab,
            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: onSelect,
              destinations: [
                for (final i in items)
                  NavigationDestination(
                    icon: Icon(i.icon),
                    selectedIcon: Icon(i.selectedIcon),
                    label: i.label,
                  ),
              ],
            ),
          );
        }
        final extended = c.maxWidth >= 1100;
        return Scaffold(
          appBar: appBar,
          floatingActionButton: fab,
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: onSelect,
                extended: extended,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                destinations: [
                  for (final i in items)
                    NavigationRailDestination(
                      icon: Icon(i.icon),
                      selectedIcon: Icon(i.selectedIcon),
                      label: Text(i.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

// ---- small building blocks ------------------------------------------------

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.cloud_off_outlined,
    title: 'Something went wrong',
    message: message,
    action: onRetry == null
        ? null
        : OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
  );
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Text(label);
    final handler = busy ? null : onPressed;
    if (icon != null && !busy) {
      return FilledButton.icon(
        onPressed: handler,
        icon: Icon(icon),
        label: child,
      );
    }
    return FilledButton(onPressed: handler, child: child);
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    onChanged: onChanged,
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: const Icon(Icons.search),
    ),
  );
}

class QueryView extends StatelessWidget {
  const QueryView({super.key, required this.stream, required this.builder});
  final QStream stream;
  final Widget Function(BuildContext context, Docs docs) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return ErrorState(message: friendlyError(snap.error!));
        }
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return builder(context, snap.data!.docs);
      },
    );
  }
}

// ---- images ---------------------------------------------------------------

/// App logo. The file lives in assets/logo.jpeg (declared in pubspec.yaml).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 80});
  final double size;

  static const asset = 'assets/logo.jpeg';

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.22),
      border: Border.all(color: AppColors.outline),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.25),
          blurRadius: size * 0.3,
          spreadRadius: 1,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(
          color: AppColors.primary,
          child: Icon(Icons.build_circle, size: size * 0.6, color: Colors.white),
        ),
      ),
    ),
  );
}

/// Network image (Cloudinary-optimised) with a tidy placeholder.
class NetImage extends StatelessWidget {
  const NetImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.icon = Icons.directions_car_filled_outlined,
    this.radius = 12,
    this.circle = false,
  });
  final String? url;
  final double? width;
  final double? height;
  final IconData icon;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: width,
      height: height,
      color: AppColors.surfaceHigh,
      child: Icon(icon, color: AppColors.muted),
    );
    Widget child = placeholder;
    if (url != null && url!.isNotEmpty) {
      final px = (width != null && width!.isFinite ? width! * 2 : 900).round();
      child = Image.network(
        cldUrl(url!, w: px),
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (c, w, p) => p == null ? w : placeholder,
        errorBuilder: (c, e, s) => placeholder,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(circle ? 999 : radius),
      child: child,
    );
  }
}

Future<XFile?> pickPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          if (!kIsWeb)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
        ],
      ),
    ),
  );
  if (source == null) return null;
  try {
    return await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 82,
    );
  } catch (_) {
    if (context.mounted) {
      showSnack(context, 'Could not open the photo picker.', error: true);
    }
    return null;
  }
}

class PhotoField extends StatelessWidget {
  const PhotoField({
    super.key,
    required this.onTap,
    this.bytes,
    this.url,
    this.height = 170,
    this.label = 'Add photo',
    this.icon = Icons.add_a_photo_outlined,
    this.onRemove,
  });
  final VoidCallback onTap;
  final Uint8List? bytes;
  final String? url;
  final double height;
  final String label;
  final IconData icon;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    final hasImage = bytes != null || hasUrl;
    final placeholder = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: AppColors.muted),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (bytes != null)
                Image.memory(bytes!, fit: BoxFit.cover)
              else if (hasUrl)
                Image.network(
                  cldUrl(url!, w: 900),
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => placeholder,
                )
              else
                placeholder,
              Positioned(
                right: 10,
                bottom: 10,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.black54,
                  child: const Icon(Icons.edit, size: 18, color: Colors.white),
                ),
              ),
              if (hasImage && onRemove != null)
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Remove',
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- select fields --------------------------------------------------------

class Option<T> {
  const Option(this.value, this.label, {this.subtitle, this.leading});
  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
}

Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<Option<T>> options,
  T? selected,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    ListTile(
                      leading: o.leading,
                      title: Text(o.label),
                      subtitle: o.subtitle == null ? null : Text(o.subtitle!),
                      trailing: o.value == selected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(ctx, o.value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.errorText,
    this.icon,
  });
  final String label;
  final String? value;
  final String? errorText;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: InputDecorator(
      isEmpty: value == null,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        prefixIcon: icon == null ? null : Icon(icon),
        suffixIcon: const Icon(Icons.expand_more),
      ),
      child: Text(value ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}