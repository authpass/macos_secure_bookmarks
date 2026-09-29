import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Secure Bookmarks Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const BookmarkDemoPage(title: 'Secure Bookmarks Demo'),
    );
  }
}

class BookmarkDemoPage extends StatefulWidget {
  const BookmarkDemoPage({super.key, required this.title});

  final String title;

  @override
  State<BookmarkDemoPage> createState() => _BookmarkDemoPageState();
}

class _BookmarkDemoPageState extends State<BookmarkDemoPage> {
  static final SecureBookmarks _secureBookmarks = SecureBookmarks();
  static const String _resolveId = 'demo-pick';

  final ValueNotifier<String> _log = ValueNotifier<String>('');
  Uint8List? _bookmark;

  @override
  void dispose() {
    _log.dispose();
    super.dispose();
  }

  void _addLog(String line) {
    _log.value = '${_log.value}$line\n';
  }

  Future<void> _pickAndMint() async {
    _addLog('Opening file picker…');
    final XFile? picked = await openFile();
    if (picked == null || picked.path.isEmpty) {
      _addLog('No file selected.');
      return;
    }
    _addLog('Selected: ${picked.path}');
    // Mint while holding the panel grant, then persist the bytes.
    final SecureBookmarkMint mint = await _secureBookmarks.mint(
      File(picked.path),
    );
    setState(() {
      _bookmark = mint.bookmark;
    });
    final String? volumeName = mint.volumeName;
    if (volumeName != null) {
      _addLog('Minted ${mint.bookmark.length} bytes (on $volumeName).');
    } else {
      _addLog('Minted ${mint.bookmark.length} bytes.');
    }
  }

  Future<void> _resolve() async {
    final Uint8List? bookmark = _bookmark;
    if (bookmark == null) {
      _addLog('Mint a bookmark first.');
      return;
    }
    try {
      final SecureBookmarkResolution resolution = await _secureBookmarks
          .resolve(id: _resolveId, bookmarkBytes: bookmark);
      // Resolve-and-rewrite: a renamed target reports stale=true, and only
      // the rewritten bytes keep working, so persist them in place.
      if (resolution.stale) {
        setState(() {
          _bookmark = resolution.refreshedBookmark;
        });
        _addLog('Stale bookmark, persisted refreshed bytes.');
      }
      final String onVolume =
          resolution.volumeName != null ? ' (on ${resolution.volumeName})' : '';
      _addLog(
        'Resolved to ${resolution.path}$onVolume '
        '[stale=${resolution.stale}, '
        'startedAccess=${resolution.startedAccess}].',
      );
    } on UnresolvableBookmark catch (e) {
      _addLog('Cannot resolve: $e');
    }
  }

  Future<void> _release() async {
    await _secureBookmarks.release(_resolveId);
    _addLog('Released $_resolveId.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Wrap(
              spacing: 8,
              children: <Widget>[
                ElevatedButton(
                  onPressed: _pickAndMint,
                  child: const Text('Pick & Mint'),
                ),
                ElevatedButton(
                  onPressed: _resolve,
                  child: const Text('Resolve'),
                ),
                ElevatedButton(
                  onPressed: _release,
                  child: const Text('Release'),
                ),
              ],
            ),
            Expanded(
              child: Container(
                constraints: const BoxConstraints.expand(),
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: ValueListenableBuilder<String>(
                    valueListenable: _log,
                    builder: (BuildContext context, String log, _) {
                      return Text(log);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
