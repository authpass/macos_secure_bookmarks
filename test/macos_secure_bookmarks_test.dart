import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel(
    'codeux.design/macos_secure_bookmarks',
  );
  final TestDefaultBinaryMessengerBinding binding =
      TestDefaultBinaryMessengerBinding.instance;

  final Uint8List bookmarkBytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
  final Uint8List refreshedBytes = Uint8List.fromList(<int>[5, 6, 7, 8]);

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  void mockReply(Future<Object?>? Function(MethodCall call) handler) {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, handler);
  }

  group('resolve', () {
    test('stale resolve returns refresh bytes plus volume name', () async {
      mockReply((MethodCall call) async {
        return <String, Object?>{
          'path': '/Volumes/Red/file.txt',
          'stale': true,
          'startedAccess': true,
          'refreshedBookmark': refreshedBytes,
          'volumeName': 'Red',
        };
      });

      final SecureBookmarkResolution resolution = await SecureBookmarks()
          .resolve(id: 'doc', bookmarkBytes: bookmarkBytes);

      expect(resolution.path, '/Volumes/Red/file.txt');
      expect(resolution.stale, isTrue);
      expect(resolution.startedAccess, isTrue);
      expect(resolution.refreshedBookmark, refreshedBytes);
      expect(resolution.volumeName, 'Red');
    });

    test('refresh bytes are absent exactly when fresh', () async {
      mockReply((MethodCall call) async {
        return <String, Object?>{
          'path': '/Volumes/Red/file.txt',
          'stale': false,
          'startedAccess': true,
          'volumeName': 'Red',
        };
      });

      final SecureBookmarkResolution resolution = await SecureBookmarks()
          .resolve(id: 'doc', bookmarkBytes: bookmarkBytes);

      expect(resolution.stale, isFalse);
      expect(resolution.refreshedBookmark, isNull);
    });

    test('forwards id and bookmark bytes to the native side', () async {
      MethodCall? seen;
      mockReply((MethodCall call) async {
        seen = call;
        return <String, Object?>{
          'path': '/file.txt',
          'stale': false,
          'startedAccess': false,
        };
      });

      await SecureBookmarks().resolve(id: 'doc', bookmarkBytes: bookmarkBytes);

      expect(seen!.method, 'resolve');
      expect(seen!.arguments['id'], 'doc');
      expect(seen!.arguments['bookmark'], bookmarkBytes);
    });

    test('volume name passes through, including absent', () async {
      final List<String?> seenNames = <String?>[];
      int calls = 0;
      mockReply((MethodCall call) async {
        calls++;
        if (calls == 1) {
          return <String, Object?>{
            'path': '/Volumes/Red/file.txt',
            'stale': false,
            'startedAccess': true,
            'volumeName': 'Red',
          };
        } else {
          return <String, Object?>{
            'path': '/file.txt',
            'stale': false,
            'startedAccess': true,
          };
        }
      });

      final SecureBookmarkResolution named = await SecureBookmarks().resolve(
        id: 'a',
        bookmarkBytes: bookmarkBytes,
      );
      seenNames.add(named.volumeName);
      final SecureBookmarkResolution unnamed = await SecureBookmarks().resolve(
        id: 'b',
        bookmarkBytes: bookmarkBytes,
      );
      seenNames.add(unnamed.volumeName);

      expect(seenNames, <String?>['Red', null]);
    });

    test('detached volume arrives as typed unresolvable', () async {
      mockReply((MethodCall call) async {
        throw PlatformException(
          code: 'Unresolvable',
          message: 'Bookmark cannot be resolved',
          details: <String, Object?>{
            'domain': 'NSCocoaErrorDomain',
            'code': 4,
          },
        );
      });

      try {
        await SecureBookmarks().resolve(
          id: 'doc',
          bookmarkBytes: bookmarkBytes,
        );
        fail('Expected UnresolvableBookmark.');
      } on UnresolvableBookmark catch (e) {
        expect(e.domain, 'NSCocoaErrorDomain');
        expect(e.code, 4);
      }
    });

    test('corrupt bytes arrive as the same typed error', () async {
      mockReply((MethodCall call) async {
        throw PlatformException(
          code: 'Unresolvable',
          message: 'Bookmark cannot be resolved',
          details: <String, Object?>{
            'domain': 'NSCocoaErrorDomain',
            'code': 259,
          },
        );
      });

      try {
        await SecureBookmarks().resolve(
          id: 'doc',
          bookmarkBytes: bookmarkBytes,
        );
        fail('Expected UnresolvableBookmark.');
      } on UnresolvableBookmark catch (e) {
        expect(e.domain, 'NSCocoaErrorDomain');
        expect(e.code, 259);
      }
    });

    test('null native answer stays loud, never maps onto detached', () async {
      mockReply((MethodCall call) async {
        return null;
      });

      await expectLater(
        SecureBookmarks().resolve(id: 'doc', bookmarkBytes: bookmarkBytes),
        throwsA(isA<StateError>()),
      );
      try {
        await SecureBookmarks().resolve(
          id: 'doc',
          bookmarkBytes: bookmarkBytes,
        );
        fail('Expected StateError.');
      } on UnresolvableBookmark catch (_) {
        fail('A null answer must never report as unresolvable.');
      } on StateError catch (_) {
        // Expected: broken native side stays loud.
      }
    });

    test('malformed unresolvable details stay loud', () async {
      mockReply((MethodCall call) async {
        throw PlatformException(
          code: 'Unresolvable',
          details: <String, Object?>{'unexpected': true},
        );
      });

      await expectLater(
        SecureBookmarks().resolve(id: 'doc', bookmarkBytes: bookmarkBytes),
        throwsA(isA<StateError>()),
      );
    });

    test('unexpected native errors propagate unwrapped', () async {
      mockReply((MethodCall call) async {
        throw PlatformException(code: 'InvalidBookmark');
      });

      await expectLater(
        SecureBookmarks().resolve(id: 'doc', bookmarkBytes: bookmarkBytes),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('release', () {
    test('forwards the id and tolerates the native no-op', () async {
      MethodCall? seen;
      mockReply((MethodCall call) async {
        seen = call;
        return null;
      });

      await SecureBookmarks().release('doc');

      expect(seen!.method, 'release');
      expect(seen!.arguments['id'], 'doc');
    });
  });

  group('mint', () {
    test('returns bytes plus volume name', () async {
      MethodCall? seen;
      mockReply((MethodCall call) async {
        seen = call;
        return <String, Object?>{
          'bookmark': bookmarkBytes,
          'volumeName': 'Red',
        };
      });

      final SecureBookmarkMint mint = await SecureBookmarks().mint(
        File('/Volumes/Red/file.txt'),
      );

      expect(seen!.method, 'mint');
      expect(
        seen!.arguments['file'],
        File('/Volumes/Red/file.txt').absolute.path,
      );
      expect(mint.bookmark, bookmarkBytes);
      expect(mint.volumeName, 'Red');
    });

    test('null native answer stays loud', () async {
      mockReply((MethodCall call) async {
        return null;
      });

      await expectLater(
        SecureBookmarks().mint(File('/file.txt')),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('existing API stays backward compatible', () {
    test('bookmark mints through the legacy verb', () async {
      MethodCall? seen;
      mockReply((MethodCall call) async {
        seen = call;
        return 'Ym9va21hcms=';
      });

      final String bookmark = await SecureBookmarks().bookmark(
        File('/file.txt'),
      );

      expect(seen!.method, 'bookmarkData');
      expect(
        seen!.arguments['file'],
        File('/file.txt').absolute.path,
      );
      expect(bookmark, 'Ym9va21hcms=');
    });

    test('resolveBookmark maps to File or Directory', () async {
      mockReply((MethodCall call) async {
        expect(call.method, 'URLByResolvingBookmarkData');
        expect(call.arguments['bookmark'], 'Ym9va21hcms=');
        return '/resolved/path';
      });

      final FileSystemEntity file = await SecureBookmarks().resolveBookmark(
        'Ym9va21hcms=',
      );
      final FileSystemEntity dir = await SecureBookmarks().resolveBookmark(
        'Ym9va21hcms=',
        isDirectory: true,
      );

      expect(file, isA<File>());
      expect(file.path, '/resolved/path');
      expect(dir, isA<Directory>());
      expect(dir.path, '/resolved/path');
    });

    test('start/stop access use the legacy verbs', () async {
      final List<String> seenMethods = <String>[];
      mockReply((MethodCall call) async {
        seenMethods.add(call.method);
        return true;
      });

      final FileSystemEntity entity = File('/file.txt');
      expect(
        await SecureBookmarks().startAccessingSecurityScopedResource(entity),
        isTrue,
      );
      expect(
        await SecureBookmarks().stopAccessingSecurityScopedResource(entity),
        isTrue,
      );
      expect(
        seenMethods,
        <String>[
          'startAccessingSecurityScopedResource',
          'stopAccessingSecurityScopedResource',
        ],
      );
    });
  });
}
