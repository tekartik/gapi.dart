// ignore_for_file: avoid_print

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
