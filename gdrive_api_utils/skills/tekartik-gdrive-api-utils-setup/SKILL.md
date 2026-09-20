---
name: tekartik-gdrive-api-utils-setup
description: >-
  Use when a Dart VM tool or server talks to Google Drive (or Google Docs) with
  tekartik_gdrive_api_utils: the GDrive helper (GDrive.future, ready, driveApi,
  listFiles, getFiles, getFile, findFileInDrive, findFilesInDrive,
  deleteFile, deleteFilesByName, copyFileToDrive, folderMimeType,
  documentMimeType), the io auth helpers initGDriveAuthClient and
  initGDriveAuthClientViaServiceAccount from
  package:tekartik_gdrive_api_utils/gdrive_io.dart, GDocsClient from gdocs.dart,
  the .local/client_id.yaml OAuth setup and the git dependency block.
---

# tekartik_gdrive_api_utils: Google Drive from the Dart VM (tekartik_gdrive_api_utils)

`tekartik_gdrive_api_utils` is a thin, `dart:io` only layer over
`package:googleapis` Drive v3: an authenticated `GDrive` object with the few
operations a build or sync script needs (list, find, delete, upload), plus two
helpers that build the `http.Client`. The full `DriveApi` stays reachable for
everything else.

## Guidelines

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    tekartik_gdrive_api_utils:
      git:
        url: https://github.com/tekartik/gapi.dart
        path: gdrive_api_utils
      version: '>=0.1.0'
  ```
* Import `package:tekartik_gdrive_api_utils/gdrive_io.dart`: it re-exports
  `gdrive.dart` (the `GDrive` class) and adds `initGDriveAuthClient` and
  `initGDriveAuthClientViaServiceAccount`. `package:tekartik_gdrive_api_utils/gdocs.dart`
  adds `GDocsClient`. The whole package uses `dart:io` (file upload), so it is
  VM/Flutter-native only, never web.
* Interactive (desktop OAuth) auth: `await initGDriveAuthClient()` returns an
  authenticated `http.Client` for the scopes `DriveApi.driveFileScope`,
  `driveAppdataScope` and `driveScope`. It reads
  `.local/client_id.yaml` (`client_id:` / `client_secret:` of an *OAuth 2.0
  desktop client* created in the Google Cloud console), prints a consent URL on
  stdout and caches the token in `.local/access_credentials.yaml`. Keep
  `.local/` out of git; delete the cached credentials file to force a new
  consent. Under the hood this is `initAuthClient` from
  `tekartik_io_auth_utils`, which takes `clientIdPath`, `clientIdMap` and
  `credentialsPath` when the defaults do not fit.
* Unattended auth: `initGDriveAuthClientViaServiceAccount(serviceAccountMap,
  {baseClient})` takes the *parsed* service account JSON (a `Map`, read it from
  a file or an environment variable — never inline a key in source) and returns
  a client for the same scopes. A service account has its own Drive: share the
  target folder with its `client_email` first.
* Build the helper with `GDrive(client: client)`, or `GDrive.future(client:
  futureClient)` when the client is still being created; in that case await
  `drive.ready` (every method already awaits it internally). Close the
  underlying client when the program is done.
* Folder ids: `'root'` is the user's My Drive root; otherwise take the id from
  the Drive url (`https://drive.google.com/drive/folders/<folderId>`). Queries
  in this package are always `'<folderId>' in parents and trashed = false`, so
  they list one level, not a whole tree.
* API surface of `GDrive`:
  * `getFiles({required folderId, pageToken, pageSize})` → `gd.FileList`; loop
    on `fileList.nextPageToken` for more than `pageSize` (default 100) entries.
  * `listFiles({required folderId})` *prints* name/mimeType/id and returns
    nothing — a debug helper, use `getFiles` in code.
  * `getFile(fileId)` returns `Future<Object>`; cast it to `gd.File`.
  * `findFileInDrive({folderId, filename})` → the first matching id or `null`;
    `findFilesInDrive(...)` → every matching id (Drive allows duplicate names).
  * `deleteFile(fileId)`, `deleteFilesByName({folderId, filename})` (returns
    how many were deleted).
  * `copyFileToDrive({folderId, filePath, mimeType})` uploads a local file
    under its basename; if a file with that name already exists in the folder
    it is *updated* instead of duplicated. It prints the resulting metadata.
  * `GDrive.folderMimeType` (`application/vnd.google-apps.folder`) and
    `GDrive.documentMimeType` (`application/vnd.google-apps.document`).
* Anything else (create a folder, download media, export a Google doc, shared
  drives, permissions) goes through `drive.driveApi`, the plain
  `package:googleapis` `DriveApi`; add `googleapis` to your own dependencies
  when you name its types (`import 'package:googleapis/drive/v3.dart' as gd;`).
* Google Docs: `GDocsClient(client: client).docsApi` is the `DocsApi`. The
  Drive helper does not request the Docs scope, so build the client with
  `initAuthClient(scopes: [...docs scopes])` from
  `package:tekartik_io_auth_utils/io_auth_utils.dart` when you need it (declare
  `tekartik_io_auth_utils`, `git: url: https://github.com/tekartik/io_auth_utils.dart`,
  in your own pubspec to import it directly).
* Failures surface as `gd.DetailedApiRequestError` (status 403/404...); catch
  it around calls that may hit quota or permission errors.

## Examples

### Interactive OAuth and a first listing

```dart
import 'package:tekartik_gdrive_api_utils/gdrive_io.dart';

Future<void> main(List<String> args) async {
  // Needs .local/client_id.yaml, prompts for consent the first time.
  var client = await initGDriveAuthClient();
  try {
    var drive = GDrive(client: client);
    await drive.listFiles(folderId: args.isNotEmpty ? args.first : 'root');
  } finally {
    client.close();
  }
}
```

### Service account credentials read from a file

```dart
import 'dart:convert';
import 'dart:io';

import 'package:tekartik_gdrive_api_utils/gdrive_io.dart';

/// [path] points to the service account json key (never commit it).
/// The target folder must be shared with the service account client_email.
Future<GDrive> openDrive(String path) async {
  var serviceAccount = jsonDecode(await File(path).readAsString()) as Map;
  var client = await initGDriveAuthClientViaServiceAccount(serviceAccount);
  return GDrive(client: client);
}
```

### List a whole folder, page by page

```dart
import 'package:googleapis/drive/v3.dart' as gd;
import 'package:tekartik_gdrive_api_utils/gdrive_io.dart';

Future<List<gd.File>> listFolder(GDrive drive, String folderId) async {
  var result = <gd.File>[];
  String? pageToken;
  do {
    var fileList = await drive.getFiles(
      folderId: folderId,
      pageSize: 100,
      pageToken: pageToken,
    );
    result.addAll(fileList.files ?? <gd.File>[]);
    pageToken = fileList.nextPageToken;
  } while (pageToken != null);
  return result;
}
```

### Upload (or replace) a build artifact, then clean up old ones

```dart
import 'package:tekartik_gdrive_api_utils/gdrive_io.dart';

Future<void> publish(GDrive drive, String folderId, String filePath) async {
  // Replaces the file with the same basename if it already exists there.
  await drive.copyFileToDrive(
    folderId: folderId,
    filePath: filePath,
    mimeType: 'application/zip',
  );
  var id = await drive.findFileInDrive(
    folderId: folderId,
    filename: 'previous.zip',
  );
  if (id != null) {
    await drive.deleteFile(id);
  }
  var count = await drive.deleteFilesByName(
    folderId: folderId,
    filename: 'obsolete.zip',
  );
  print('deleted $count obsolete file(s)');
}
```

### Drop down to driveApi: create a folder, download a file

```dart
import 'dart:io';

import 'package:googleapis/drive/v3.dart' as gd;
import 'package:tekartik_gdrive_api_utils/gdrive_io.dart';

Future<String> createFolder(GDrive drive, String parentId, String name) async {
  await drive.ready;
  var folder = await drive.driveApi.files.create(
    gd.File()
      ..name = name
      ..mimeType = GDrive.folderMimeType
      ..parents = [parentId],
  );
  return folder.id!;
}

Future<void> download(GDrive drive, String fileId, String localPath) async {
  await drive.ready;
  var media =
      await drive.driveApi.files.get(
            fileId,
            downloadOptions: gd.DownloadOptions.fullMedia,
          )
          as gd.Media;
  var sink = File(localPath).openWrite();
  await media.stream.pipe(sink);
}
```

### Google Docs with the right scopes

```dart
import 'package:googleapis/docs/v1.dart' as docs;
import 'package:tekartik_gdrive_api_utils/gdocs.dart';
import 'package:tekartik_io_auth_utils/io_auth_utils.dart';

Future<String?> documentTitle(String documentId) async {
  var client = await initAuthClient(
    scopes: [docs.DocsApi.documentsReadonlyScope],
  );
  try {
    var gdocs = GDocsClient(client: client);
    var document = await gdocs.docsApi.documents.get(documentId);
    return document.title;
  } finally {
    client.close();
  }
}
```

## Common mistakes

* Importing the package in web or Flutter web code: it uses `dart:io`.
* Expecting `listFiles` to return the files; it prints them.
* Assuming `getFile` is typed: it returns `Object`, cast to `gd.File`.
* Reading only the first page of `getFiles` and missing `nextPageToken`.
* Uploading with `copyFileToDrive` and expecting a second copy: a same-named
  file in the folder is updated in place.
* Using a service account client and wondering where the files are: they land
  in the service account's own Drive unless a shared folder id is used.
* Committing `.local/client_id.yaml`, `.local/access_credentials.yaml` or a
  service account key.
