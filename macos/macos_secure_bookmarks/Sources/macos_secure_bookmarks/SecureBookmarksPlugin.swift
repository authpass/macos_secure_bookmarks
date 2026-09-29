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
  private var resolvedUrls: [String: URL] = [:]

  /// URLs with an entered security scope, keyed by caller id. Each entry
  /// holds one outstanding `startAccessingSecurityScopedResource` call,
  /// balanced when the caller releases the id.
  private var scopedUrls: [String: URL] = [:]

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
        let url = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &isStale)
        if (url.isFileURL) {
          resolvedUrls[url.path] = url
          result(url.path)
        } else {
          result(FlutterError(code: "InvalidBookmark", message: "Bookmark is no file url. \(url)", details: nil))
          return
        }
      } catch {
        result(FlutterError(code: "UnexpectedError", message: "Error while resolving bookmark \(error)", details: nil))
      }
    case "startAccessingSecurityScopedResource":
      guard let file = args["file"] as? String else {
        result(FlutterError(code: "InvalidArguments", message: "expected file argument to be string.", details: nil))
        return
      }
      guard let url = resolvedUrls[file] else {
        result(FlutterError(code: "NoSuchBookmark", message: "No resolved bookmark for \(file). Call resolveBookmark first.", details: nil))
        return
      }
      result(url.startAccessingSecurityScopedResource())
    case "stopAccessingSecurityScopedResource":
      guard let file = args["file"] as? String else {
        result(FlutterError(code: "InvalidArguments", message: "expected file argument to be string.", details: nil))
        return
      }
      guard let url = resolvedUrls[file] else {
        result(FlutterError(code: "NoSuchBookmark", message: "No resolved bookmark for \(file). Call resolveBookmark first.", details: nil))
        return
      }
      url.stopAccessingSecurityScopedResource()
      result(true)
    case "resolve":
      resolveBookmark(args, result: result)
    case "release":
      releaseBookmark(args, result: result)
    case "mint":
      mintBookmark(args, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func resolveBookmark(_ args: Dictionary<String, Any>, result: @escaping FlutterResult) {
    guard let id = args["id"] as? String,
      let typedData = args["bookmark"] as? FlutterStandardTypedData else {
      result(FlutterError(code: "InvalidArguments", message: "Expected id and bookmark arguments.", details: nil))
      return
    }
    do {
      var isStale: Bool = false
      // withoutUI + withoutMounting keep this on the fast path: a detached
      // volume fails here in milliseconds instead of triggering mounts or dialogs.
      let url = try URL(
        resolvingBookmarkData: typedData.data,
        options: [.withSecurityScope, .withoutUI, .withoutMounting],
        bookmarkDataIsStale: &isStale)
      guard url.isFileURL else {
        // Resolved, but to something without a file path: report it through
        // the same typed error as every other unresolvable cause.
        unresolvable(
          NSError(
            domain: NSCocoaErrorDomain,
            code: CocoaError.fileReadUnknown.rawValue,
            userInfo: nil),
          result: result)
        return
      }
      // Renaming the target yields stale=true; only the rewritten bytes keep
      // working, so the caller must persist them in place of the old bytes.
      var refreshedBookmark: Data?
      if isStale {
        do {
          refreshedBookmark = try url.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
          unresolvable(error, result: result)
          return
        }
      }
      // Measured: entering the scope reports true even for a URL inside the container.
      let startedAccess = url.startAccessingSecurityScopedResource()
      // A deleted target still resolves to a URL, so confirm it stats
      // reachable before replacing the previous scope. Detached volumes
      // already failed at resolve, so this only sees present ones.
      do {
        guard try url.checkResourceIsReachable() else {
          throw NSError(
            domain: NSCocoaErrorDomain,
            code: CocoaError.fileNoSuchFile.rawValue,
            userInfo: nil)
        }
      } catch {
        url.stopAccessingSecurityScopedResource()
        unresolvable(error, result: result)
        return
      }
      // Only now that the new scope is verified, balance a previous resolve
      // under the same id: every failure above leaves the old scope intact.
      if let previous = scopedUrls[id] {
        previous.stopAccessingSecurityScopedResource()
      }
      scopedUrls[id] = url
      // Display data, never identity: best effort, never fails the resolve.
      let volumeName = try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName
      var reply: [String: Any] = [
        "path": url.path,
        "stale": isStale,
        "startedAccess": startedAccess,
      ]
      if let refreshedBookmark = refreshedBookmark {
        reply["refreshedBookmark"] = FlutterStandardTypedData(bytes: refreshedBookmark)
      }
      if let volumeName = volumeName {
        reply["volumeName"] = volumeName
      }
      result(reply)
    } catch {
      unresolvable(error, result: result)
    }
  }

  private func releaseBookmark(_ args: Dictionary<String, Any>, result: @escaping FlutterResult) {
    guard let id = args["id"] as? String else {
      result(FlutterError(code: "InvalidArguments", message: "Expected id argument to be string.", details: nil))
      return
    }
    // Releasing an unheld id is a no-op.
    if let url = scopedUrls.removeValue(forKey: id) {
      url.stopAccessingSecurityScopedResource()
    }
    result(nil)
  }

  private func mintBookmark(_ args: Dictionary<String, Any>, result: @escaping FlutterResult) {
    guard let filePath = args["file"] as? String else {
      result(FlutterError(code: "InvalidArguments", message: "expected file argument to be string.", details: nil))
      return
    }
    let url = URL(fileURLWithPath: filePath)
    do {
      let data = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
      var reply: [String: Any] = ["bookmark": FlutterStandardTypedData(bytes: data)]
      if let volumeName = try? url.resourceValues(forKeys: [.volumeNameKey]).volumeName {
        reply["volumeName"] = volumeName
      }
      result(reply)
    } catch {
      result(FlutterError(code: "UnexpectedError", message: "Error while creating bookmark \(error) for \(url)", details: nil))
    }
  }

  /// Detached volume, deleted or non-file target, and corrupt bytes all arrive
  /// here as one typed error carrying the native domain and code.
  private func unresolvable(_ error: Error, result: @escaping FlutterResult) {
    let nsError = error as NSError
    result(FlutterError(
      code: "Unresolvable",
      message: "Bookmark cannot be resolved: \(nsError.localizedDescription)",
      details: ["domain": nsError.domain, "code": nsError.code]))
  }
}
