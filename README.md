# macos_secure_bookmarks

[![Pub](https://img.shields.io/pub/v/macos_secure_bookmarks?color=green)](https://pub.dev/packages/macos_secure_bookmarks)

Flutter plugin to create security-scoped bookmarks and keep access to files
in sandboxed macOS apps.

## Setup

* Read the [documentation on security-scoped
  bookmarks](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/AppSandboxInDepth/AppSandboxInDepth.html#//apple_ref/doc/uid/TP40011183-CH3-SW16).
* Enable the app-sandbox entitlement and the required bookmark entitlement in
  both `DebugProfile.entitlements` and `Release.entitlements`:
  * `com.apple.security.app-sandbox`
  * `com.apple.security.files.user-selected.read-write` (for the open panel)
  * `com.apple.security.files.bookmarks.app-scope` (required — without it,
    resolving a bookmark fails)

## Usage

### Minting bookmarks

Let the user pick a file (picking stays consumer-side, e.g. with
[file_selector](https://pub.dev/packages/file_selector)), then mint a
bookmark while holding the panel grant and persist the bytes:

```dart
final XFile? picked = await openFile();
if (picked == null) {
  return;
}

final SecureBookmarks secureBookmarks = SecureBookmarks();
final SecureBookmarkMint mint = await secureBookmarks.mint(File(picked.path));
// Persist mint.bookmark, and show mint.volumeName ("on Red") in the UI.
// The volume name is display data, never identity.
```

### Resolving, accessing, releasing

Resolve the persisted bytes under a caller id. Resolving enters the security
scope; releasing the id leaves it. Releasing an unheld id is a no-op.

```dart
try {
  final SecureBookmarkResolution resolution = await secureBookmarks.resolve(
    id: 'my-document',
    bookmarkBytes: storedBytes,
  );
  // Read/write the file at resolution.path, then:
  await secureBookmarks.release('my-document');
} on UnresolvableBookmark catch (e) {
  // Detached volume, deleted target, or corrupt bytes.
  // e.domain and e.code carry the native NSError domain and code.
}
```

### Resolve-and-rewrite

Renaming the target yields `stale: true` plus rewritten bytes. Persist the
refresh in place of the old bytes — without the rewrite a renamed target
stays stale forever:

```dart
final SecureBookmarkResolution resolution = await secureBookmarks.resolve(
  id: 'my-document',
  bookmarkBytes: storedBytes,
);
if (resolution.stale) {
  storedBytes = resolution.refreshedBookmark!;
  await persist(storedBytes);
}
```

`refreshedBookmark` is present exactly when `stale` is true.

### A note on reachability

Reachability is resolve-plus-a-real-read. Under the sandbox, existence checks
answer true for files without a grant, then `open(2)` fails — a path alone
proves nothing until the file is actually opened. Do not treat "resolves to a
path" as "readable"; attempt the read and handle the failure.

### Legacy API

The original methods still work unchanged: `bookmark` mints a base64 string,
`resolveBookmark` maps it back to a `File` or `Directory`, and
`startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource`
bracket access. New code should prefer `mint` / `resolve` / `release`, which
add stale reporting, per-id scope lifetime, volume names, and typed errors.

## Manual sandbox verification

The headless test suite mocks the method channel, so it cannot cover the
kernel's half. Before release, verify against a real sandboxed build:

1. Build and run the example on macOS:
   `flutter run -d macos` from `example/`.
2. Plug in an external volume. Pick a file on it (Pick & Mint), then quit
   the app and relaunch it: Resolve must return the file with
   `startedAccess: true`, proving the bookmark survived the relaunch.
3. Rename-while-away: quit the app, rename the picked file's parent folder
   on the volume, relaunch, and Resolve. Expect `stale: true` plus refreshed
   bytes; Resolve again with the persisted refresh and expect `stale: false`.
4. Detach the volume and Resolve: expect an `UnresolvableBookmark` within
   milliseconds, with no hang.
5. Open the volume name in the UI and confirm it shows the Finder display
   name of the external volume (e.g. "on Red").
