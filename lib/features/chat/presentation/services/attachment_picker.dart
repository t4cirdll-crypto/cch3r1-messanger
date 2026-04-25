import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';

/// Максимальный размер вложения (25 МБ).
const int kMaxAttachmentBytes = 25 * 1024 * 1024;

class AttachmentPickerResult {
  const AttachmentPickerResult.success(this.attachment)
      : tooLarge = false,
        sizeBytes = null;
  const AttachmentPickerResult.tooLarge(int size)
      : attachment = null,
        tooLarge = true,
        sizeBytes = size;
  const AttachmentPickerResult.cancelled()
      : attachment = null,
        tooLarge = false,
        sizeBytes = null;

  final OutgoingAttachment? attachment;
  final bool tooLarge;
  final int? sizeBytes;
}

class AttachmentPicker {
  AttachmentPicker._();

  static final ImagePicker _imagePicker = ImagePicker();

  /// Картинка из галереи или с камеры.
  static Future<AttachmentPickerResult> pickImage({
    bool fromCamera = false,
  }) async {
    final XFile? x = await _imagePicker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 4096,
      maxHeight: 4096,
      imageQuality: 88,
    );
    if (x == null) return const AttachmentPickerResult.cancelled();
    return _wrapXFile(x, AttachmentKind.image);
  }

  /// Видео из галереи или с камеры.
  static Future<AttachmentPickerResult> pickVideo({
    bool fromCamera = false,
  }) async {
    final XFile? x = await _imagePicker.pickVideo(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (x == null) return const AttachmentPickerResult.cancelled();
    return _wrapXFile(x, AttachmentKind.video);
  }

  /// Любой файл.
  static Future<AttachmentPickerResult> pickFile() async {
    final FilePickerResult? r = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
      withReadStream: false,
    );
    if (r == null || r.files.isEmpty) {
      return const AttachmentPickerResult.cancelled();
    }
    final PlatformFile pf = r.files.first;
    final String? path = pf.path;
    if (path == null) return const AttachmentPickerResult.cancelled();
    final File file = File(path);
    final int size = await file.length();
    if (size > kMaxAttachmentBytes) {
      return AttachmentPickerResult.tooLarge(size);
    }
    final String name = pf.name;
    final String ext = (pf.extension ?? p.extension(name).replaceFirst('.', ''))
        .toLowerCase();
    final String mime = lookupMimeType(name) ?? 'application/octet-stream';
    return AttachmentPickerResult.success(
      OutgoingAttachment(
        kind: AttachmentKind.file,
        mime: mime,
        extension: ext.isEmpty ? 'bin' : ext,
        file: file,
        name: name,
        size: size,
      ),
    );
  }

  static Future<AttachmentPickerResult> _wrapXFile(
    XFile x,
    AttachmentKind kind,
  ) async {
    final File file = File(x.path);
    final int size = await file.length();
    if (size > kMaxAttachmentBytes) {
      return AttachmentPickerResult.tooLarge(size);
    }
    final String name = p.basename(x.path);
    final String ext = p.extension(name).replaceFirst('.', '').toLowerCase();
    final String mime = x.mimeType ??
        lookupMimeType(name) ??
        (kind == AttachmentKind.image ? 'image/jpeg' : 'video/mp4');
    return AttachmentPickerResult.success(
      OutgoingAttachment(
        kind: kind,
        mime: mime,
        extension: ext.isEmpty
            ? (kind == AttachmentKind.image ? 'jpg' : 'mp4')
            : ext,
        file: file,
        name: name,
        size: size,
      ),
    );
  }

  /// Запрос микрофонного разрешения. Возвращает true, если предоставлено.
  static Future<bool> ensureMicPermission() async {
    if (kIsWeb) return true;
    final PermissionStatus status = await Permission.microphone.request();
    return status.isGranted;
  }
}
