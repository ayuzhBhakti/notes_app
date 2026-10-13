import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/analytics.dart';

/// Reports a screen view once, when the screen is created.
///
/// For screens that are stateless: calling analytics from their `build` would
/// send the event again on every rebuild.
class TrackView extends ConsumerStatefulWidget {
  const TrackView({super.key, required this.onView, required this.child});

  final void Function(Analytics analytics) onView;
  final Widget child;

  @override
  ConsumerState<TrackView> createState() => _TrackViewState();
}

class _TrackViewState extends ConsumerState<TrackView> {
  @override
  void initState() {
    super.initState();
    widget.onView(ref.read(analyticsProvider));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
