// Copyright 2019 Google LLC
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

import Cocoa
import Foundation
import FlutterMacOS

public class SecureBookmarksPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "codeux.design/macos_secure_bookmarks", binaryMessenger: registrar.messenger)
    let instance = SecureBookmarksPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  
  /// We store all resolved Urls by their absolute path,
  /// because `startAccessingSecurityScopedResource` requires
  /// the same URL instance, not just an arbitrary file URL.
  private var resolvedUrls: [String: URL] = [:];

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? Dictionary<String, Any> else {
      result(FlutterError(code: "InvalidArguments", message: "Invalid arguments, expected dictionary.", details: nil))
      return
    }

    switch call.method {
    case "bookmarkData":
      guard let filePath = args["file"] as? String else {
        result(FlutterError(code: "InvalidArguments", message: "expected file argument to be string.", details: nil))
        return
      }
      let url = URL(fileURLWithPath: filePath)
      print("need bookmark for \(url)")
      // create app scope security bookmark.
      do {
        let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        result(data.base64EncodedString())
      } catch {
        result(FlutterError(code: "UnexpectedError", message: "Error while creating bookmark \(error) for \(url)", details: nil))
      }
    case "URLByResolvingBookmarkData":
      guard let bookmark64 = args["bookmark"] as? String,
        let bookmark = Data.init(base64Encoded: bookmark64) else {
        result(FlutterError(code: "InvalidArguments", message: "expected bookmark argument to be string.", details: nil))
        return
      }
      do {
        var isStale: Bool = false
        guard let url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &isStale) else {
          result(FlutterError(code: "UnexpectedError", message: "Error while resolving bookmark", details: nil))
          return
        }
        print("resolved bookmark to: \(url) (\(isStale))")
        if (url.isFileURL) {
          resolvedUrls[url.path] = url
          result(url.path)
        } else {
          result(FlutterError(code: "InvalidBookmark", message: "Bookmark is no file url. \(url)", details: nil))
          return
        }
      } catch {
        result(FlutterError(code: "UnexpectedError", message: "Error while resolving bookmark", details: nil))
      }
    case "startAccessingSecurityScopedResource":
      guard let file = args["file"] as? String,
        let url = resolvedUrls[file] else {
          result(FlutterError(code: "InvalidArguments", message: "expected file argument to be string.", details: nil))
          return
      }
//      let url = URL(fileURLWithPath: file)
      result(url.startAccessingSecurityScopedResource())
    case "stopAccessingSecurityScopedResource":
      guard let file = args["file"] as? String,
        let url = resolvedUrls[file] else {
          result(FlutterError(code: "InvalidArguments", message: "expected file argument to be string.", details: nil))
          return
      }
//      let url = URL(fileURLWithPath: file)
      url.stopAccessingSecurityScopedResource()
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
