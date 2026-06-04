import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';

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
  static const AttachmentMenuChoice gif =
      AttachmentMenuChoice._('gif');
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildTile(
              context,
              theme: theme,
              scheme: scheme,
              icon: Icons.photo_camera_outlined,
              label: 'Сделать фото',
              choice: AttachmentMenuChoice.camera,
            ),
            _buildTile(
              context,
              theme: theme,
              scheme: scheme,
              icon: Icons.photo_library_outlined,
              label: 'Фото из галереи',
              choice: AttachmentMenuChoice.gallery,
            ),
            _buildTile(
              context,
              theme: theme,
              scheme: scheme,
              icon: Icons.video_library_outlined,
              label: 'Видео',
              choice: AttachmentMenuChoice.video,
            ),
            _buildTile(
              context,
              theme: theme,
              scheme: scheme,
              icon: Icons.gif_box_outlined,
              label: 'GIF',
              choice: AttachmentMenuChoice.gif,
            ),
            _buildTile(
              context,
              theme: theme,
              scheme: scheme,
              icon: Icons.attach_file_outlined,
              label: 'Файл',
              choice: AttachmentMenuChoice.file,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required ThemeData theme,
    required ColorScheme scheme,
    required IconData icon,
    required String label,
    required AttachmentMenuChoice choice,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: AppRadius.smAll,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () => Navigator.of(context).pop(choice),
    );
  }
}
