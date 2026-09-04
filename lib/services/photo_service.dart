import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PhotoService {
  PhotoService._();

  static final instance = PhotoService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  final ImagePicker _picker = ImagePicker();

  Future<File?> pickCamera() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (file == null) return null;

    return File(file.path);
  }

  Future<File?> pickGallery() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (file == null) return null;

    return File(file.path);
  }

  Future<String> uploadRoomPhoto(int roomId, File file) async {
    final name = "${DateTime.now().millisecondsSinceEpoch}.jpg";

    final ref = _storage
        .ref()
        .child("rooms")
        .child(roomId.toString())
        .child(name);

    await ref.putFile(file);

    return await ref.getDownloadURL();
  }

  Future<void> deletePhoto(String url) async {
    await _storage.refFromURL(url).delete();
  }
}
