# Notice

This repository contains a community-maintained patch for WeFlow 5.0.0.

- Upstream project: https://github.com/hicccc77/WeFlow
- Patch source baseline: `e5b7067aa0554151d2762c6f889dd47bc1bf2f46`
- Upstream author metadata: cc / hicccc77
- Patch maintainer repository: https://github.com/AnonymousUser443/WeFlow-Community-Patch
- License: CC BY-NC-SA 4.0

The patch is distributed for non-commercial troubleshooting and interoperability. It is not affiliated with or endorsed by WeChat or Tencent.

No user chat data, account identifiers, decryption keys, local configuration, backup executables, or debugging logs are included.

The only binary in this repository is `binaries/wcdb_api.dll`, a 6-byte-patched build of the prebuilt upstream `wcdb_api.dll` (its hard-coded build-expiry gates are disabled). It is provided so existing installations can be repaired without a rebuild, and it is not an upstream artefact.
