import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
        sizeBytes = null,
        permissionDenied = false,
        errorMessage = null;
  const AttachmentPickerResult.tooLarge(int size)
      : attachment = null,
        tooLarge = true,
        sizeBytes = size,
        permissionDenied = false,
        errorMessage = null;
  const AttachmentPickerResult.cancelled()
      : attachment = null,
        tooLarge = false,
        sizeBytes = null,
        permissionDenied = false,
        errorMessage = null;
  const AttachmentPickerResult.permissionDenied(String message)
      : attachment = null,
        tooLarge = false,
        sizeBytes = null,
        permissionDenied = true,
        errorMessage = message;
  const AttachmentPickerResult.error(String message)
      : attachment = null,
        tooLarge = false,
        sizeBytes = null,
        permissionDenied = false,
        errorMessage = message;

  final OutgoingAttachment? attachment;
  final bool tooLarge;
  final int? sizeBytes;
  final bool permissionDenied;
  final String? errorMessage;
}

class AttachmentPicker {
  AttachmentPicker._();

  static final ImagePicker _imagePicker = ImagePicker();

  /// Картинка из галереи или с камеры.
  static Future<AttachmentPickerResult> pickImage({
    bool fromCamera = false,
  }) async {
    try {
      final XFile? x = await _imagePicker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 4096,
        maxHeight: 4096,
        imageQuality: 88,
      );
      if (x == null) return const AttachmentPickerResult.cancelled();
      return _wrapXFile(x, AttachmentKind.image);
    } on PlatformException catch (e) {
      return _mapPickerPlatformException(
        e,
        fromCamera: fromCamera,
        forVideo: false,
      );
    } catch (e) {
      return AttachmentPickerResult.error('Не удалось выбрать фото: $e');
    }
  }

  /// Видео из галереи или с камеры.
  static Future<AttachmentPickerResult> pickVideo({
    bool fromCamera = false,
  }) async {
    try {
      final XFile? x = await _imagePicker.pickVideo(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (x == null) return const AttachmentPickerResult.cancelled();
      return _wrapXFile(x, AttachmentKind.video);
    } on PlatformException catch (e) {
      return _mapPickerPlatformException(
        e,
        fromCamera: fromCamera,
        forVideo: true,
      );
    } catch (e) {
      return AttachmentPickerResult.error('Не удалось выбрать видео: $e');
    }
  }

  /// Любой файл.
  static Future<AttachmentPickerResult> pickFile() async {
    try {
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
      final String ext =
          (pf.extension ?? p.extension(name).replaceFirst('.', ''))
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
    } on PlatformException catch (e) {
      // FilePicker на iOS / Android тоже умеет бросать permission ошибки.
      final String? code = e.code.isEmpty ? null : e.code;
      if (code != null &&
          (code.contains('denied') || code.contains('permission'))) {
        return const AttachmentPickerResult.permissionDenied(
          'Нет доступа к файлам — разрешите в настройках устройства.',
        );
      }
      return AttachmentPickerResult.error(
        'Не удалось открыть файл: ${e.message ?? e.code}',
      );
    } catch (e) {
      return AttachmentPickerResult.error('Не удалось открыть файл: $e');
    }
  }

  static AttachmentPickerResult _mapPickerPlatformException(
    PlatformException e, {
    required bool fromCamera,
    required bool forVideo,
  }) {
    final String code = e.code.toLowerCase();
    // image_picker_ios / image_picker_android типичные коды:
    //   `camera_access_denied`, `photo_access_denied`,
    //   `camera_access_restricted`, `photo_access_restricted`.
    if (code.contains('camera_access_denied')) {
      return const AttachmentPickerResult.permissionDenied(
        'Нет доступа к камере — разрешите в настройках устройства.',
      );
    }
    if (code.contains('photo_access_denied') ||
        code.contains('photo_access_restricted') ||
        code.contains('photo_library_unavailable')) {
      return const AttachmentPickerResult.permissionDenied(
        'Нет доступа к фото — разрешите в настройках устройства.',
      );
    }
    if (code.contains('camera_access_restricted')) {
      return const AttachmentPickerResult.permissionDenied(
        'Камера недоступна на этом устройстве.',
      );
    }
    if (code.contains('multiple_request')) {
      // Двойной вызов picker'а — это не ошибка пользователя.
      return const AttachmentPickerResult.cancelled();
    }
    final String what = forVideo ? 'видео' : (fromCamera ? 'фото' : 'фото');
    return AttachmentPickerResult.error(
      'Не удалось выбрать $what: ${e.message ?? e.code}',
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
