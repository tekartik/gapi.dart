// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:io';
import 'package:cv/cv_json.dart';
import 'package:googleapis/drive/v3.dart' as gd;
import 'package:http/http.dart';
import 'package:path/path.dart';

/// Google Drive helper on an authenticated client: [GDrive.new], or
/// [GDrive.future] while the client is created.
class GDrive {
  /// Google doc mime type
  static const documentMimeType = 'application/vnd.google-apps.document';

  /// Google drive folder mime type
  static const folderMimeType = 'application/vnd.google-apps.folder';

  /// Auth client
  late final Client client;

  final _readyCompleter = Completer<bool>();

  /// True when ready
  Future<bool> get ready => _readyCompleter.future;

  /// Constructor
  GDrive({required this.client}) {
    _readyCompleter.complete(true);
  }

  /// ready must be called first, it fails with the error of [client].
  GDrive.future({required Future<Client> client}) {
    // Not an uncaught error when nobody awaits ready, later awaits still fail.
    ready.ignore();
    client.then(
      (value) {
        this.client = value;
        _readyCompleter.complete(true);
      },
      onError: (Object error, StackTrace stackTrace) {
        _readyCompleter.completeError(error, stackTrace);
      },
    );
  }

  /// Drive api
  late final driveApi = gd.DriveApi(client);

  /// List files - compat
  Future<void> listFiles({required String folderId}) async {
    await ready;
    var files = await driveApi.files.list(
      pageSize: 100,
      q: '${_queryString(folderId)} in parents and trashed = false',
    );
    for (var file in files.files!) {
      // ignore: avoid_print
      print('${file.name} ${file.mimeType} ${file.id}');
    }
  }

  /// Get a single file
  Future<Object> getFile(String fileId) async {
    await ready;
    return await driveApi.files.get(fileId);
  }

  /// Get files
  Future<gd.FileList> getFiles({
    required String folderId,
    String? pageToken,

    /// default to 100
    int? pageSize,
  }) async {
    await ready;
    pageSize ??= 100;
    var files = await driveApi.files.list(
      pageSize: pageSize,
      q: '${_queryString(folderId)} in parents and trashed = false',
      pageToken: pageToken,
    );
    return files;
  }

  /// Delete a single file
  Future<void> deleteFile(String fileId) async {
    await ready;
    await driveApi.files.delete(fileId);
  }

  /// Drive query string literal: `\` and `'` are escaped.
  String _queryString(String value) =>
      "'${value.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

  String _queryByParentAndName(String folderId, String filename) {
    return '${_queryString(folderId)} in parents and name=${_queryString(filename)} and trashed = false';
  }

  /// Find a file by name in a folder (not trashed), its id or null.
  Future<String?> findFileInDrive({
    required String folderId,
    required String filename,
  }) async {
    await ready;
    var files = await driveApi.files.list(
      pageSize: 10,
      q: _queryByParentAndName(folderId, filename),
    );
    if (files.files!.isEmpty) {
      return null;
    }
    return files.files!.first.id;
  }

  /// Delete the files named [filename] in a folder (100 at most), returns
  /// the number deleted.
  Future<int> deleteFilesByName({
    required String folderId,
    required String filename,
  }) async {
    await ready;
    var files = await driveApi.files.list(
      pageSize: 100,
      q: _queryByParentAndName(folderId, filename),
    );
    for (var file in files.files!) {
      await driveApi.files.delete(file.id!);
    }
    return files.files!.length;
  }

  /// Ids of the files named [filename] in a folder (10 at most).
  Future<List<String>> findFilesInDrive({
    required String folderId,
    required String filename,
  }) async {
    await ready;
    var files = await driveApi.files.list(
      pageSize: 10,
      q: _queryByParentAndName(folderId, filename),
    );
    if (files.files!.isEmpty) {
      return <String>[];
    }
    return files.files!.map((file) => file.id).nonNulls.toList();
  }

  /// Upload [filePath] to a folder, replacing the file with the same name.
  Future<void> copyFileToDrive({
    required String folderId,
    required String filePath,
    required String mimeType,
  }) async {
    await ready;
    var existingId = await findFileInDrive(
      folderId: folderId,
      filename: basename(filePath),
    );

    var ioFile = File(filePath);
    gd.File? result;
    if (existingId != null) {
      var file = gd.File()
        ..name = basename(filePath)
        ..mimeType = mimeType;
      result = await driveApi.files.update(
        file,
        existingId,
        uploadMedia: gd.Media(ioFile.openRead(), ioFile.statSync().size),
      );
    } else {
      var file = gd.File()
        ..name = basename(filePath)
        ..parents = [folderId]
        ..mimeType = mimeType;
      result = await driveApi.files.create(
        file,
        enforceSingleParent: true,
        uploadMedia: gd.Media(ioFile.openRead(), ioFile.statSync().size),
      );
    }

    // ignore: avoid_print
    print(jsonPrettyEncode(result.toJson()));
  }
}
