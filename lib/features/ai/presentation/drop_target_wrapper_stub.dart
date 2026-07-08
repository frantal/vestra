import 'package:flutter/widgets.dart';

class DropTargetWrapper extends StatelessWidget {
  const DropTargetWrapper({
    super.key,
    required this.child,
    required this.onFilesDropped,
  });

  final Widget child;
  final Future<void> Function(List<Map<String, Object?>> attachments) onFilesDropped;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
