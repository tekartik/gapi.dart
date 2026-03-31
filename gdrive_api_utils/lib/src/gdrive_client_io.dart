import 'package:googleapis/drive/v3.dart' as gd;
import 'package:googleapis_auth/auth_io.dart';
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

/// Initialize
Future<Client> initGDriveAuthClientViaServiceAccount(
  Map serviceAccount, {
  Client? baseClient,
}) {
  return clientViaServiceAccount(
    ServiceAccountCredentials.fromJson(serviceAccount),
    [
      gd.DriveApi.driveFileScope,
      gd.DriveApi.driveAppdataScope,
      gd.DriveApi.driveScope,
    ],
    baseClient: baseClient,
  );
}
