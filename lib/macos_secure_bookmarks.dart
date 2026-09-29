import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Resolution of a security-scoped bookmark, see [SecureBookmarks.resolve].
///
/// [refreshedBookmark] is present exactly when [stale] is true: renaming the
/// target yields stale=true, and only the rewritten bytes keep working.
typedef SecureBookmarkResolution = ({
  /// Absolute file path the bookmark resolved to.
  String path,

  /// Whether the bookmark data was stale. Persist [refreshedBookmark]
  /// in place of the old bytes when this is true.
  bool stale,

  /// What `startAccessingSecurityScopedResource` reported while entering
  /// the security scope for the resolve id.
  bool startedAccess,

  /// Rewritten bookmark bytes, present exactly when [stale] is true.
  Uint8List? refreshedBookmark,

  /// Display name of the resolving volume (e.g. for "on Red" UI).
  /// Display data, never identity.
  String? volumeName,
});

/// Result of minting a security-scoped bookmark, see [SecureBookmarks.mint].
typedef SecureBookmarkMint = ({
  /// Bookmark bytes to persist and later pass to [SecureBookmarks.resolve].
  Uint8List bookmark,

  /// Display name of the volume holding the target. Display data,
  /// never identity.
  String? volumeName,
});

/// Failure domain for the bookmark lifecycle API.
///
/// Sealed so that adding an error case fails to compile at every consumer
/// decision site.
sealed class SecureBookmarkFailure implements Exception {
  const SecureBookmarkFailure({required this.message});

  final String message;

  @override
  String toString() {
    return '$runtimeType: $message';
  }
}

/// Detached volume, deleted or non-file target, or corrupt bytes.
///
/// All unresolvable causes arrive as this one type; [domain] and [code] carry
/// the native NSError domain and code for diagnosis.
final class UnresolvableBookmark extends SecureBookmarkFailure {
  const UnresolvableBookmark({
    required this.domain,
    required this.code,
    super.message = 'Bookmark cannot be resolved.',
  });

  /// Native NSError domain (e.g. `NSCocoaErrorDomain`).
  final String domain;

  /// Native NSError code.
  final int code;

  @override
  String toString() {
    return 'UnresolvableBookmark: $message ($domain $code)';
  }
}

/// Create and resolve security aware bookmarks to access files
/// in sandboxed macOS apps.
class SecureBookmarks {
  static const MethodChannel _channel = MethodChannel(
    'codeux.design/macos_secure_bookmarks',
  );

  /// Right now always returns a global (stateless) singleton instance.
  factory SecureBookmarks() => _instance;

  SecureBookmarks._();

  static final _instance = SecureBookmarks._();

  /// Create a security aware bookmark for the given [entity].
  Future<String> bookmark(FileSystemEntity entity) async {
    return await _channel.invokeMethod('bookmarkData', {
      'file': entity.absolute.path,
    });
  }

  /// Converts the given bookmark, created previously with [bookmark]
  /// back into either a File or a Directory depending on the optional value of [isDirectory], which defaults to false.
  /// Before accessing it, it is still required to call
  /// [startAccessingSecurityScopedResource]
  Future<FileSystemEntity> resolveBookmark(
    String bookmark, {
    bool isDirectory = false,
  }) async {
    final String filePath = await _channel.invokeMethod(
      'URLByResolvingBookmarkData',
      {'bookmark': bookmark},
    );
    if (isDirectory) {
      return Directory(filePath);
    } else {
      return File(filePath);
    }
  }

  /// Allows you to access the given FileSystemEntity. (which was previously stored
  /// as security aware bookmark).
  /// You should call [stopAccessingSecurityScopedResource] afterwards.
  Future<bool> startAccessingSecurityScopedResource(
    FileSystemEntity entity,
  ) async {
    return await _channel.invokeMethod('startAccessingSecurityScopedResource', {
      'file': entity.absolute.path,
    });
  }

  /// Frees resources associated with the security scoped resource.
  /// see [apple docs](https://developer.apple.com/documentation/foundation/nsurl/1413736-stopaccessingsecurityscopedresou?language=objc) for details.
  Future<bool> stopAccessingSecurityScopedResource(
    FileSystemEntity entity,
  ) async {
    return await _channel.invokeMethod('stopAccessingSecurityScopedResource', {
      'file': entity.absolute.path,
    });
  }

  /// Mint a security-scoped bookmark for [entity] while holding the panel
  /// grant, and report the volume's display name for UI.
  ///
  /// This is the lifecycle counterpart to [bookmark]: same mint-from-path
  /// semantics, but the bookmark comes back as bytes (persist them for
  /// [resolve]) alongside the display-only [SecureBookmarkMint.volumeName].
  Future<SecureBookmarkMint> mint(FileSystemEntity entity) async {
    final Map<dynamic, dynamic>? reply = await _channel.invokeMethod<Map>(
      'mint',
      {'file': entity.absolute.path},
    );
    if (reply == null) {
      throw StateError(
        'Native mint returned null for "${entity.absolute.path}".',
      );
    }
    return (
      bookmark: reply['bookmark']! as Uint8List,
      volumeName: reply['volumeName'] as String?,
    );
  }

  /// Resolve [bookmarkBytes] to a path and enter its security scope under [id].
  ///
  /// The scope stays entered until [release] is called with the same [id];
  /// resolving again under the same [id] replaces the previous scope.
  ///
  /// Resolve-and-rewrite: when the returned [SecureBookmarkResolution.stale]
  /// is true (e.g. the target was renamed), persist
  /// [SecureBookmarkResolution.refreshedBookmark] in place of the old bytes.
  /// Without the rewrite a renamed target stays stale forever.
  ///
  /// Throws [UnresolvableBookmark] for a detached volume, a deleted target,
  /// or corrupt bytes. Resolve confirms the target stats reachable with the
  /// scope held, but a path alone still proves nothing: attempt the actual
  /// read and handle its failure.
  Future<SecureBookmarkResolution> resolve({
    required String id,
    required Uint8List bookmarkBytes,
  }) async {
    try {
      final Map<dynamic, dynamic>? reply = await _channel.invokeMethod<Map>(
        'resolve',
        {'id': id, 'bookmark': bookmarkBytes},
      );
      if (reply == null) {
        // A broken native side must stay loud, never map onto "detached".
        throw StateError('Native resolve returned null for id "$id".');
      }
      final SecureBookmarkResolution resolution = (
        path: reply['path']! as String,
        stale: reply['stale']! as bool,
        startedAccess: reply['startedAccess']! as bool,
        refreshedBookmark: reply['refreshedBookmark'] as Uint8List?,
        volumeName: reply['volumeName'] as String?,
      );
      if (resolution.stale != (resolution.refreshedBookmark != null)) {
        throw StateError(
          'Native resolve broke the stale/refresh invariant for id "$id".',
        );
      }
      return resolution;
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'Unresolvable':
          throw _unresolvableFrom(e);
        default:
          rethrow;
      }
    }
  }

  /// Leave the security scope entered by [resolve] for [id].
  ///
  /// Releasing an unheld id is a no-op.
  Future<void> release(String id) async {
    await _channel.invokeMethod<void>('release', {'id': id});
  }
}

/// Map a native `Unresolvable` failure onto its typed error.
///
/// Anything misshaped stays loud: malformed details mean a broken native
/// side, which must never be reported as "detached".
UnresolvableBookmark _unresolvableFrom(PlatformException e) {
  return switch (e.details) {
    {'domain': final String domain, 'code': final int code} =>
      UnresolvableBookmark(domain: domain, code: code),
    _ => throw StateError(
        'Native resolve reported unresolvable with malformed details: '
        '${e.details}.',
      ),
  };
}
