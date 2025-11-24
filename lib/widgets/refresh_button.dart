import 'package:flutter/material.dart';

class RefreshButton extends StatelessWidget {
  const RefreshButton({
    super.key,
    required this.onRefresh,
    this.tooltip = 'Refresh',
  });

  final Future<void> Function() onRefresh;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.refresh),
      onPressed: () async {
        await onRefresh();
      },
      tooltip: tooltip,
    );
  }
}

