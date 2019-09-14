import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class SecureBookmarks {
  static const MethodChannel _channel = const MethodChannel('codeux.design/macos_secure_bookmarks');
  factory SecureBookmarks() => _instance;
  SecureBookmarks._();
  static final _instance = SecureBookmarks._();

  Future<String> bookmark(File file) async {
    return await _channel.invokeMethod('bookmarkData', {'file': file.absolute.path});
  }

  Future<File> resolveBookmark(String bookmark) async {
    final filePath = await _channel.invokeMethod('URLByResolvingBookmarkData', {'bookmark': bookmark});
    return File(filePath);
  }

  Future<String> startAccessingSecurityScopedResource(File file) async {
    return await _channel.invokeMethod('startAccessingSecurityScopedResource', {'file': file.absolute.path});
  }

  Future<String> stopAccessingSecurityScopedResource(File file) async {
    return await _channel.invokeMethod('stopAccessingSecurityScopedResource', {'file': file.absolute.path});
  }
}
