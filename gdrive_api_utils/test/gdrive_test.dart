import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tekartik_gdrive_api_utils/gdrive.dart';
import 'package:test/test.dart';

/// A Drive api answering an empty file list, recording the `q` queries.
GDrive _emptyListDrive(List<String> queries) {
  var client = MockClient((request) async {
    queries.add(request.url.queryParameters['q']!);
    return http.Response(
      jsonEncode({'files': <Object?>[]}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return GDrive(client: client);
}

void main() {
  group('gdrive', () {
    test('file name quotes are escaped in queries', () async {
      var queries = <String>[];
      var drive = _emptyListDrive(queries);
      expect(
        await drive.findFileInDrive(folderId: 'f1', filename: "l'été.txt"),
        isNull,
      );
      expect(
        await drive.findFilesInDrive(folderId: 'f1', filename: r'a\b'),
        isEmpty,
      );
      // An injection attempt stays a name
      expect(
        await drive.deleteFilesByName(
          folderId: 'f1',
          filename: "x' or name contains '",
        ),
        0,
      );
      expect(queries, [
        r"'f1' in parents and name='l\'été.txt' and trashed = false",
        r"'f1' in parents and name='a\\b' and trashed = false",
        r"'f1' in parents and name='x\' or name contains \'' and trashed = false",
      ]);
    });

    test('future client failure fails ready', () async {
      var drive = GDrive.future(
        client: Future<http.Client>.error(StateError('no client')),
      );
      await expectLater(
        drive.ready.timeout(const Duration(seconds: 5)),
        throwsA(isA<StateError>()),
      );
      // Every call fails the same way
      await expectLater(
        drive.getFiles(folderId: 'f1').timeout(const Duration(seconds: 5)),
        throwsA(isA<StateError>()),
      );
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('future client', () async {
      var queries = <String>[];
      var client = _emptyListDrive(queries).client;
      var drive = GDrive.future(client: Future.value(client));
      expect(await drive.ready, isTrue);
      expect(await drive.getFiles(folderId: 'f1'), isA<Object>());
      expect(queries, ["'f1' in parents and trashed = false"]);
    });
  });
}
