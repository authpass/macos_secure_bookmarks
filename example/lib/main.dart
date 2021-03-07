// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';

final MemoryAppender logMessages = MemoryAppender();
final _logger = Logger('main');

void main() {
  Logger.root.level = Level.ALL;
  PrintAppender().attachToLogger(Logger.root);
  logMessages.attachToLogger(Logger.root);
  _logger.fine('Application launched.');

  // See https://github.com/flutter/flutter/wiki/Desktop-shells#target-platform-override
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

  FlutterError.onError = (errorDetails) {
    _logger.shout(
        'Unhandled Flutter framework (${errorDetails.library}) error.',
        errorDetails.exception,
        errorDetails.stack);
    _logger.fine(errorDetails.summary.toString());
  };

  runApp(ExampleApp());
}

class ExampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // See https://github.com/flutter/flutter/wiki/Desktop-shells#fonts
        fontFamily: 'Roboto',
      ),
      home: MyHomePage(title: 'Flutter Demo Home Pageasdf'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static final SecureBookmarks _secureBookmarks = SecureBookmarks();
  String _file;

  String _bookmark;

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
            Row(
              children: <Widget>[
                ElevatedButton(
                  child: Text('Select File'),
                  onPressed: () async {
                    _logger.fine('showOpenPanel..');
                    final result = await openFile();
                    _logger.fine('got result: $result');
                    if (result == null || result.path.isEmpty) {
                      return;
                    }
                    setState(() {
                      _file = result.path;
                    });
                    _logger.info('Selected file: $_file');
                  },
                ),
                ElevatedButton(
                  child: Text('Bookmark'),
                  onPressed: () async {
                    final bookmark =
                        await _secureBookmarks.bookmark(File(_file));
                    setState(() {
                      _bookmark = bookmark;
                    });
                    _logger.info('Got bookmark: $bookmark');
                  },
                ),
                ElevatedButton(
                  child: Text('Resolve Bookmark'),
                  onPressed: () async {
                    final resolved =
                        await _secureBookmarks.resolveBookmark(_bookmark);
                    _logger.info('Resolved to $resolved');
                  },
                ),
              ],
            ),
            Expanded(
              child: Container(
                color: Colors.white,
                constraints: BoxConstraints.expand(),
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: AnimatedBuilder(
                      animation: logMessages.log,
                      builder: (context, _) => Text(
                        logMessages.log.toString(),
                      ),
                    ),
                  ),
                  reverse: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShortFormatter extends LogRecordFormatter {
  @override
  StringBuffer formatToStringBuffer(LogRecord rec, StringBuffer sb) {
    sb.write(
        '${rec.time.hour}:${rec.time.minute}:${rec.time.second} ${rec.level.name} '
        '${rec.message}');

    if (rec.error != null) {
      sb.write(rec.error);
    }
    // ignore: avoid_as
    final stackTrace = rec.stackTrace ??
        (rec.error is Error ? (rec.error as Error).stackTrace : null);
    if (stackTrace != null) {
      sb.write(stackTrace);
    }
    return sb;
  }
}

class StringBufferWrapper with ChangeNotifier implements ValueNotifier<String> {
  final StringBuffer _buffer = StringBuffer();

  void writeln(String line) {
    _buffer.writeln(line);
    notifyListeners();
  }

  @override
  String toString() => _buffer.toString();

  @override
  String get value => _buffer.toString();

  @override
  set value(String newValue) => _buffer
    ..clear()
    ..write(newValue);
}

class MemoryAppender extends BaseLogAppender {
  MemoryAppender() : super(ShortFormatter());

  final StringBufferWrapper log = StringBufferWrapper();

  @override
  void handle(LogRecord record) {
    log.writeln(formatter.format(record));
  }
}
