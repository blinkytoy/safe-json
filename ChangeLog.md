# Changelog for safe-json

## 1.0.0

* Removed `FromJSON`/`ToJSON` dependecy on `SafeJSON`
    * Default implementation of `safeFrom` and `safeTo` unchanged, still require `FromJSON` and `ToJSON`
* Added unsafe `setVersion` and `removeVersion` functions.
* Integrated `Data.SafeJSON.Instances` into `Data.SafeJSON.Internal`
* Some documentation cleanup/fixes
* Added convenience functions for defining `safeFrom` and `safeTo`
    * e.g. `containWithObject`, `(.:$)`, `(.=$)`, etc.

## 0.1.0

* First release. Includes:
    * `Data.Aeson.Safe`
    * `Data.SafeJSON`
    * `Data.SafeJSON.Instances`
    * `Data.SafeJSON.Internal`
    * `Data.SafeJSON.Test`
