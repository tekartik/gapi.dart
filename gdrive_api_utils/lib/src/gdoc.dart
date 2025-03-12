import 'package:googleapis/docs/v1.dart' as docs;
import 'package:http/http.dart';

/// GDocs client
class GDocsClient {
  /// Auth client
  final Client client;

  /// Constructor
  GDocsClient({required this.client});

  /// Drive api
  late final docsApi = docs.DocsApi(client);
}
