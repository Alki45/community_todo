import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/group_announcement.dart';

class StorageService {
  StorageService() : _storage = FirebaseStorage.instance;

  final FirebaseStorage _storage;
  final ImagePicker _imagePicker = ImagePicker();

  // Allowed file types
  static const List<String> allowedImageTypes = [
    'jpg', 'jpeg', 'png', 'gif', 'webp'
  ];
  static const List<String> allowedPdfTypes = ['pdf'];
  static const List<String> allowedWordTypes = ['doc', 'docx'];
  
  static const List<String> allowedExtensions = [
    ...allowedImageTypes,
    ...allowedPdfTypes,
    ...allowedWordTypes,
  ];

  /// Get file type from extension
  String _getFileType(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');
    if (allowedImageTypes.contains(ext)) {
      return 'image';
    } else if (allowedPdfTypes.contains(ext)) {
      return 'pdf';
    } else if (allowedWordTypes.contains(ext)) {
      return 'word';
    }
    return 'unknown';
  }

  /// Check if file type is allowed
  bool isFileTypeAllowed(String fileName) {
    final extension = path.extension(fileName).toLowerCase().replaceAll('.', '');
    return allowedExtensions.contains(extension);
  }

  /// Pick an image from gallery or camera
  Future<XFile?> pickImage({bool fromCamera = false}) async {
    try {
      final source = fromCamera ? ImageSource.camera : ImageSource.gallery;
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      return image;
    } catch (e) {
      return null;
    }
  }

  /// Pick a file (PDF, Word, etc.)
  Future<FilePickerResult?> pickFile({
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions ?? StorageService.allowedExtensions,
        withData: false,
      );
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Upload file to Firebase Storage
  Future<FileAttachment> uploadFile({
    required String filePath,
    required String fileName,
    required String groupId,
    required String userId,
    String? subfolder,
  }) async {
    try {
      // Validate file type
      if (!isFileTypeAllowed(fileName)) {
        throw StateError('File type not allowed. Only images, PDF, and Word documents are supported.');
      }

      // Get file
      int fileSize;
      if (kIsWeb) {
        // For web, we need to handle differently
        throw StateError('Web file upload not yet implemented');
      }
      final file = File(filePath);
      if (!await file.exists()) {
        throw StateError('File not found');
      }

      fileSize = await file.length();
      final maxSize = 10 * 1024 * 1024; // 10MB
      if (fileSize > maxSize) {
        throw StateError('File size exceeds 10MB limit');
      }

      // Generate unique file name
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(fileName);
      final uniqueFileName = '${timestamp}_${path.basenameWithoutExtension(fileName)}$extension';

      // Create storage path
      final folder = subfolder ?? 'announcements';
      final storagePath = 'groups/$groupId/$folder/$userId/$uniqueFileName';

      // Upload file
      final ref = _storage.ref(storagePath);
      if (kIsWeb) {
        throw StateError('Web file upload not yet implemented');
      }
      await ref.putFile(file);

      // Get download URL
      final url = await ref.getDownloadURL();

      // Get file type
      final fileType = _getFileType(extension);

      return FileAttachment(
        url: url,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
      );
    } catch (e) {
      throw StateError('Failed to upload file: $e');
    }
  }

  /// Upload file from XFile (for images)
  Future<FileAttachment> uploadImageFile({
    required XFile file,
    required String groupId,
    required String userId,
    String? subfolder,
  }) async {
    return uploadFile(
      filePath: file.path,
      fileName: path.basename(file.path),
      groupId: groupId,
      userId: userId,
      subfolder: subfolder ?? 'announcements',
    );
  }

  /// Upload file from PlatformFile (for file picker)
  Future<FileAttachment> uploadPlatformFile({
    required PlatformFile platformFile,
    required String groupId,
    required String userId,
    String? subfolder,
  }) async {
    if (platformFile.path == null) {
      throw StateError('File path is null');
    }
    return uploadFile(
      filePath: platformFile.path!,
      fileName: platformFile.name,
      groupId: groupId,
      userId: userId,
      subfolder: subfolder ?? 'announcements',
    );
  }

  /// Delete file from Firebase Storage
  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      // Ignore errors for file deletion
    }
  }

  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}

