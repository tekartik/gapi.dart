/// [GDrive] plus the io auth helpers [initGDriveAuthClient] (desktop OAuth)
/// and [initGDriveAuthClientViaServiceAccount].
library;

export 'gdrive.dart';
export 'src/gdrive_client_io.dart'
    show initGDriveAuthClient, initGDriveAuthClientViaServiceAccount;
