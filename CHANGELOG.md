# 0.3.0

* Add stale-aware `resolve` with per-id security scope lifetime, returning the
  path, stale flag, rewritten bookmark bytes, and volume display name.
* Add `release` to leave a resolve scope (releasing an unheld id is a no-op).
* Add `mint`, returning bookmark bytes plus the volume display name.
* Report detached volumes, deleted targets, and corrupt bytes as one typed
  `UnresolvableBookmark` error carrying the native domain and code.
* Modernize: Dart 3, current Flutter stable, Swift Package Manager support
  alongside CocoaPods, lint-clean, refreshed example app.
* Existing API unchanged and backward compatible.

# 0.2.1

* change method signature without breaking the API.

# 0.2.0

* null safety migration

# 0.1.2+1

* Upgrade dependencies.

# 0.1.2

* Remove android/ plugin folder. This is no longer required since flutter 1.16.3

# 0.1.1

* Fix compile errors for Swift 5.1, thanks @copypasteearth #1

# 0.1.0+2

* Improved error handling: Don't try to pass exception back to dart.
  (resulted in crashes)

# 0.1.0+1

* Added noop modules for ios/android so the builds run.

# 0.1.0 - 2019-09-14

* Improved readme, documentation.
* Fixed a couple of bugs, actually using it now in
  [AuthPass Password Manager for MacOS](https://authpass.app/)

# 0.0.1

* Initial release 🎉️
