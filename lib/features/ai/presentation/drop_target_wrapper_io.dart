import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
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
    return DropTarget(
      onDragDone: (details) async {
        final attachments = <Map<String, Object?>>[];
        for (final file in details.files) {
          final path = file.path;
          if (!File(path).existsSync()) {
            continue;
          }
          final bytes = await File(path).readAsBytes();
          final name = file.name.isNotEmpty ? file.name : path.split(Platform.pathSeparator).last;
          attachments.add({
            'name': name,
            'mimeType': _inferMimeType(name),
            'bytes': bytes,
          });
        }
        if (attachments.isNotEmpty) {
          await onFilesDropped(attachments);
        }
      },
      child: child,
    );
  }

  String _inferMimeType(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}
