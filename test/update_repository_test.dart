import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dilse/data/datasources/remote/github_update_datasource.dart';
import 'package:dilse/data/models/app_update_info.dart';
import 'package:dilse/data/repositories/update_repository.dart';
import 'package:dilse/data/repositories/update_repository_impl.dart';
import 'package:dilse/features/app_update/viewmodels/update_viewmodel.dart';

class _FakeUpdateRepository extends UpdateRepositoryImpl {
  _FakeUpdateRepository({required super.remoteDatasource});

  @override
  Future<({String version, String buildNumber})> getInstalledPackageInfo() async {
    return (version: '1.0.0', buildNumber: '1');
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UpdateRepositoryImpl version comparison', () {
    late UpdateRepository repo;

    setUp(() {
      repo = UpdateRepositoryImpl(
        remoteDatasource: GithubUpdateDatasourceImpl(
          client: MockClient((_) async => http.Response('{}', 404)),
        ),
      );
    });

    test('detects newer semver tags accurately', () {
      expect(repo.compareVersion('v1.0.1', '1.0.0', '1'), equals(1));
      expect(repo.compareVersion('1.1.0', '1.0.9', '5'), equals(1));
      expect(repo.compareVersion('v2.0.0', '1.9.9', '99'), equals(1));
      expect(repo.compareVersion('v1.0.1-beta', '1.0.0', '1'), equals(1));
    });

    test('detects newer build number on matching semver', () {
      expect(repo.compareVersion('v1.0.0+2', '1.0.0', '1'), equals(1));
      expect(repo.compareVersion('1.0.0+5', '1.0.0+2'), equals(1));
    });

    test('detects equal and older versions accurately', () {
      expect(repo.compareVersion('v1.0.0', '1.0.0', '1'), equals(0));
      expect(repo.compareVersion('v1.0.0+1', '1.0.0', '1'), equals(0));
      expect(repo.compareVersion('v0.9.5', '1.0.0', '1'), equals(-1));
      expect(repo.compareVersion('v1.0.0+1', '1.0.0', '2'), equals(-1));
    });
  });

  group('GithubUpdateDatasourceImpl & UpdateViewModel', () {
    test('prefers APK asset and falls back to /releases when /latest returns 404 for pre-release', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/releases/latest')) {
          return http.Response('{"message":"Not Found"}', 404);
        }
        if (request.url.path.endsWith('/releases')) {
          return http.Response(
            json.encode([
              {
                'tag_name': 'v1.0.2-beta',
                'name': 'Beta Test Build',
                'body': 'Added GitHub OTA updater',
                'prerelease': true,
                'draft': false,
                'html_url': 'https://github.com/charanteja-k/dilse-releases/releases/tag/v1.0.2-beta',
                'published_at': '2026-11-10T10:00:00Z',
                'assets': [
                  {
                    'name': 'app-arm64-v8a-release.apk',
                    'size': 25165824,
                    'browser_download_url':
                        'https://github.com/charanteja-k/dilse-releases/releases/download/v1.0.2-beta/app-arm64-v8a-release.apk',
                  },
                ],
              },
            ]),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final repo = _FakeUpdateRepository(
        remoteDatasource: GithubUpdateDatasourceImpl(client: client),
      );
      final vm = UpdateViewModel(updateRepository: repo);

      await vm.initialize();

      expect(vm.hasAvailableUpdate, isTrue);
      expect(vm.latestUpdate?.tagName, equals('v1.0.2-beta'));
      expect(vm.latestUpdate?.hasApk, isTrue);
      expect(vm.latestUpdate?.formattedSize, equals('24.0 MB'));
      expect(vm.downloadState.phase, equals(OtaDownloadPhase.idle));
    });

    test('parses custom GitHub repo URL and slug inputs cleanly', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/releases')) {
          return http.Response('[]', 200);
        }
        return http.Response('{"message":"Not Found"}', 404);
      });

      final repo = _FakeUpdateRepository(
        remoteDatasource: GithubUpdateDatasourceImpl(client: client),
      );
      final vm = UpdateViewModel(updateRepository: repo);

      expect(await vm.updateTargetRepo('invalid-slug'), isFalse);
      expect(vm.errorMessage, isNotNull);

      final updated = await vm.updateTargetRepo(
        'https://github.com/charanteja-k/temp-dilse-test.git',
      );
      expect(updated, isTrue);
      expect(vm.repoOwner, equals('charanteja-k'));
      expect(vm.repoName, equals('temp-dilse-test'));
      expect(vm.repoSlug, equals('charanteja-k/temp-dilse-test'));
    });
  });
}

