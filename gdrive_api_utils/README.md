# tekartik_gdrive_api_utils

Google Drive from a Dart VM program (a tool, a server): authentication helpers
and a `GDrive` object for the common file operations (list a folder, find,
upload or replace, delete), on top of `package:googleapis` Drive v3. The full
`DriveApi` stays available for the rest.

## Getting started

Git package, not on pub.dev:

```yaml
dependencies:
  tekartik_gdrive_api_utils:
    git:
      url: https://github.com/tekartik/gapi.dart
      path: gdrive_api_utils
```

List a folder with a service account
([example/main.dart](example/main.dart)):

```dart
import 'dart:convert';
import 'dart:io';

import 'package:tekartik_gdrive_api_utils/gdrive_io.dart';

/// `dart run example/main.dart <service_account.json> <folder id>`
///
/// The folder must be shared with the client_email of the service account.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('usage: main.dart <service_account.json> <folder id>');
    exitCode = 64;
    return;
  }
  var serviceAccount = jsonDecode(await File(args[0]).readAsString()) as Map;
  var client = await initGDriveAuthClientViaServiceAccount(serviceAccount);
  try {
    var drive = GDrive(client: client);
    var fileList = await drive.getFiles(folderId: args[1]);
    for (var file in [...?fileList.files]) {
      print('${file.name} ${file.mimeType} ${file.id}');
    }
  } finally {
    client.close();
  }
}
```

Interactive (desktop OAuth) instead: `await initGDriveAuthClient()`, which
reads `.local/client_id.yaml` (an OAuth desktop client id and secret), asks
for consent once and caches the token in `.local/access_credentials.yaml`
(see `tekartik_io_auth_utils`).

## Platforms

Dart VM and Flutter native (it uses `dart:io`), not the web.

## What to use

| You want | Use |
|---|---|
| A client, unattended | `initGDriveAuthClientViaServiceAccount(map)` |
| A client, a user's Drive | `initGDriveAuthClient()` |
| One page of a folder | `getFiles(folderId:, pageToken:, pageSize:)` (loop on `nextPageToken`) |
| A file id by name | `findFileInDrive(folderId:, filename:)`, `findFilesInDrive` |
| Upload, or replace the file with the same name | `copyFileToDrive(folderId:, filePath:, mimeType:)` |
| Delete | `deleteFile(id)`, `deleteFilesByName(folderId:, filename:)` |
| Anything else | `drive.driveApi` (`package:googleapis/drive/v3.dart`) |
| Google Docs | `GDocsClient(client:).docsApi` (`gdocs.dart`) |

## Common pitfalls

* Never commit a service account key or the `.local/` files; read the key
  from a file or a secret store.
* A service account sees its own Drive only: share the folder with its
  `client_email`.
* Shared drives are not handled by the `GDrive` helpers (no
  `supportsAllDrives`): use `driveApi` with `supportsAllDrives: true`.
* `findFilesInDrive` returns at most 10 ids, `deleteFilesByName` deletes at
  most 100 files per call.
* `GDrive.future(client: future)`: when the future fails, `ready` and every
  call fail with its error.
* `listFiles` and `copyFileToDrive` print to stdout.
* Close the client when done.
