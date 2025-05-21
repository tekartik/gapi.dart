import 'package:googleapis/drive/v3.dart' as gd;
import 'package:http/http.dart';
import 'package:tekartik_io_auth_utils/io_auth_utils.dart';

/// Initialize GDrive auth client
Future<Client> initGDriveAuthClient() async {
  return await initAuthClient(
    scopes: [
      gd.DriveApi.driveFileScope,
      gd.DriveApi.driveAppdataScope,
      gd.DriveApi.driveScope,
    ],
  );
}
