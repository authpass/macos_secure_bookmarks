import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Create and resolve security aware bookmarks to access files
/// in sandboxed MacOS apps.
class SecureBookmarks {
  static const MethodChannel _channel =
      const MethodChannel('codeux.design/macos_secure_bookmarks');

  /// Right now always returns a global (stateless) singleton instance.
  factory SecureBookmarks() => _instance;

  SecureBookmarks._();

  static final _instance = SecureBookmarks._();

  /// Create a security aware bookmark for the given [file].
  Future<String> bookmark(File file) async {
    return await _channel
        .invokeMethod('bookmarkData', {'file': file.absolute.path});
  }

  /// Converts the given bookmark, created previously with [bookmark]
  /// back into a File.
  /// Before accessing it, it is still required to call
  /// [startAccessingSecurityScopedResource]
  Future<File> resolveBookmark(String bookmark) async {
    final filePath = await _channel
        .invokeMethod('URLByResolvingBookmarkData', {'bookmark': bookmark});
    return File(filePath);
  }

  /// Allows you to access the given file. (which was previously stored
  /// as security aware bookmark).
  /// You should call [stopAccessingSecurityScopedResource] afterwards.
  Future<bool> startAccessingSecurityScopedResource(File file) async {
    return await _channel.invokeMethod(
        'startAccessingSecurityScopedResource', {'file': file.absolute.path});
  }

  /// Frees resources associated with the security scoped resource.
  /// see [apple docs](https://developer.apple.com/documentation/foundation/nsurl/1413736-stopaccessingsecurityscopedresou?language=objc) for details.
  Future<bool> stopAccessingSecurityScopedResource(File file) async {
    return await _channel.invokeMethod(
        'stopAccessingSecurityScopedResource', {'file': file.absolute.path});
  }
}
