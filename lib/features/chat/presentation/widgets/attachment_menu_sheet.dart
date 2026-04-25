import 'package:flutter/material.dart';

class AttachmentMenuChoice {
  const AttachmentMenuChoice._(this.id);
  final String id;

  static const AttachmentMenuChoice camera =
      AttachmentMenuChoice._('camera');
  static const AttachmentMenuChoice gallery =
      AttachmentMenuChoice._('gallery');
  static const AttachmentMenuChoice video =
      AttachmentMenuChoice._('video');
  static const AttachmentMenuChoice file =
      AttachmentMenuChoice._('file');
}

class AttachmentMenuSheet extends StatelessWidget {
  const AttachmentMenuSheet({super.key});

  static Future<AttachmentMenuChoice?> show(BuildContext context) {
    return showModalBottomSheet<AttachmentMenuChoice>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext c) => const AttachmentMenuSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Сделать фото'),
              onTap: () =>
                  Navigator.of(context).pop(AttachmentMenuChoice.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Фото из галереи'),
              onTap: () =>
                  Navigator.of(context).pop(AttachmentMenuChoice.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('Видео'),
              onTap: () =>
                  Navigator.of(context).pop(AttachmentMenuChoice.video),
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_outlined),
              title: const Text('Файл'),
              onTap: () =>
                  Navigator.of(context).pop(AttachmentMenuChoice.file),
            ),
          ],
        ),
      ),
    );
  }
}
