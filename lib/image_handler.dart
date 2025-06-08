// image_handler.dart

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageHandler {
  static Future<File?> pickImageFromCamera() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    return _cropImage(pickedFile);
  }

  static Future<File?> pickImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    return _cropImage(pickedFile);
  }

  static Future<File?> _cropImage(XFile? pickedFile) async {
    if (pickedFile == null) return null;
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      maxHeight: 1080,
      maxWidth: 1080,
    );
    return croppedFile != null ? File(croppedFile.path) : null;
  }
}
