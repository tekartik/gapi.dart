// ignore_for_file: depend_on_referenced_packages

import 'dart:io';
import 'package:cv/cv_json.dart';
import 'package:googleapis/drive/v3.dart' as gd;
import 'package:http/http.dart';
import 'package:path/path.dart';

/// GDrive helper
class GDrive {
  /// Google doc mime type
  static const documentMimeType = 'application/vnd.google-apps.document';

  /// Google drive folder mime type
  static const folderMimeType = 'application/vnd.google-apps.folder';

  /// Auth client
  final Client client;

  /// Constructor
  GDrive({required this.client});

  /// Drive api
  late final driveApi = gd.DriveApi(client);

  /// List files
  Future<void> listFiles({required String folderId}) async {
    var files = await driveApi.files
        .list(pageSize: 100, q: "'$folderId' in parents and trashed = false");
    for (var file in files.files!) {
      // ignore: avoid_print
      print('${file.name} ${file.mimeType} ${file.id}');
    }
  }

  /// Delete a single file
  Future<void> deleteFile(String fileId) async {
    await driveApi.files.delete(fileId);
  }

  String _queryByParentAndName(String folderId, String filename) {
    return "'$folderId' in parents and name='$filename' and trashed = false";
  }

  /// Find file in drive
  Future<String?> findFileInDrive(
      {required String folderId, required String filename}) async {
    var files = await driveApi.files
        .list(pageSize: 10, q: _queryByParentAndName(folderId, filename));
    if (files.files!.isEmpty) {
      return null;
    }
    return files.files!.first.id;
  }

  /// Delete files by name
  Future<int> deleteFilesByName(
      {required String folderId, required String filename}) async {
    var files = await driveApi.files
        .list(pageSize: 100, q: _queryByParentAndName(folderId, filename));
    for (var file in files.files!) {
      await driveApi.files.delete(file.id!);
    }
    return files.files!.length;
  }

  /// Find file in drive
  Future<List<String>> findFilesInDrive(
      {required String folderId, required String filename}) async {
    var files = await driveApi.files
        .list(pageSize: 10, q: _queryByParentAndName(folderId, filename));
    if (files.files!.isEmpty) {
      return <String>[];
    }
    return files.files!.map((file) => file.id).nonNulls.toList();
  }

  /// Copy file to drive
  Future<void> copyFileToDrive(
      {required String folderId,
      required String filePath,
      required String mimeType}) async {
    var existingId =
        await findFileInDrive(folderId: folderId, filename: basename(filePath));

    var ioFile = File(filePath);
    gd.File? result;
    if (existingId != null) {
      var file = gd.File()
        ..name = basename(filePath)
        ..mimeType = mimeType;
      result = await driveApi.files.update(file, existingId,
          uploadMedia: gd.Media(ioFile.openRead(), ioFile.statSync().size));
    } else {
      var file = gd.File()
        ..name = basename(filePath)
        ..parents = [folderId]
        ..mimeType = mimeType;
      result = await driveApi.files.create(file,
          enforceSingleParent: true,
          uploadMedia: gd.Media(ioFile.openRead(), ioFile.statSync().size));
    }

    // ignore: avoid_print
    print(jsonPrettyEncode(result.toJson()));
  }
}
