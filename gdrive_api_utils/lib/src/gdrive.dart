// ignore_for_file: depend_on_referenced_packages

import 'dart:io';
import 'package:cv/cv_json.dart';
import 'package:googleapis/drive/v3.dart' as gd;
import 'package:http/http.dart';
import 'package:path/path.dart';

/// GDrive helper
class GDrive {
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
      print('${file.name} ${file.mimeType}');
    }
  }

  /// Find file in drive
  Future<String?> findFileInDrive(
      {required String folderId, required String filename}) async {
    var files = await driveApi.files.list(
        pageSize: 10,
        q: "'$folderId' in parents and name='$filename' and trashed = false");
    if (files.files!.isEmpty) {
      return null;
    }
    return files.files!.first.id;
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
