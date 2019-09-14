# macos_secure_bookmarks

Flutter plugin to create secure bookmarks to keep access to files in sandboxed apps.


## Usage

* Check the [documentation on security-scoped bookmarks](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/AppSandboxInDepth/AppSandboxInDepth.html#//apple_ref/doc/uid/TP40011183-CH3-SW16)
* Make sure to [enable the necessary entitlements](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html#//apple_ref/doc/uid/TP40011195-CH4-SW18)
    * com.apple.security.files.bookmarks.app-scope

### Creating Security Scoped Bookmarks

```dart
// First let the user choose a file, e.g. using the file chooser plugin.

showOpenPanel((result, files) {
  if (result != FileChooserResult.ok || files.isEmpty) {
    return;
  }
  
  // Now create a security scoped bookmark
  final secureBookmarks = SecureBookmarks();
  final bookmark = await _secureBookmarks.bookmark(File(_file));
  
  // Now store the bookmark somewhere for later invocations
});
```

### Resolving and accessing bookmarks

```dart
// resolve bookmark from persistet 'bookmark' string from earlier
final resolvedFile = await _secureBookmarks.resolveBookmark(_bookmark);
// resolved is now a File object, but before accessing it, call:
await startAccessingSecurityScopedResource(resolvedFile);

// now read/write the file

// and later give up access.
await stopAccessingSecurityScopedResource(resolvedFile);

```

