import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart' as fst;
import '../../core/errors/failures.dart';

abstract class StorageService {
  Future<String> uploadFile(String path, File file);
  Future<void> deleteFile(String url);
}

class FirebaseStorageService implements StorageService {
  final fst.FirebaseStorage _storage = fst.FirebaseStorage.instance;

  @override
  Future<String> uploadFile(String path, File file) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}

class MockStorageService implements StorageService {
  @override
  Future<String> uploadFile(String path, File file) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80';
  }

  @override
  Future<void> deleteFile(String url) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
