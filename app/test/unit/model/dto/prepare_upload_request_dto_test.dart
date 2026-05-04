import 'dart:convert';
import 'dart:io';

import 'package:common/model/device.dart';
import 'package:common/model/dto/file_dto.dart';
import 'package:common/model/dto/info_register_dto.dart';
import 'package:common/model/dto/multicast_dto.dart';
import 'package:common/model/dto/prepare_upload_request_dto.dart';
import 'package:common/model/dto/prepare_upload_response_dto.dart';
import 'package:common/model/file_type.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MapperContainer.globals.use(const FileDtoMapper());

  group('parse PrepareUploadRequestDto', () {
    test('should parse valid enums', () {
      final dto = {
        'info': {
          'alias': 'Nice Banana',
          'deviceModel': 'Samsung',
          'deviceType': 'mobile',
        },
        'files': {
          'some id': {
            'id': 'some id',
            'fileName': 'another image.jpg',
            'size': 1234,
            'fileType': 'image',
            'preview': '*preview data*',
          },
        },
      };
      final parsed = PrepareUploadRequestDto.fromJson(dto);
      expect(parsed.info.deviceType, DeviceType.mobile);
      expect(parsed.files.length, 1);
      expect(parsed.files.values.first.fileType, FileType.image);
    });

    test('Should fallback deviceType (simple)', () {
      final dto = {
        'alias': 'Nice Banana',
        'deviceModel': 'Samsung',
        'deviceType': 'invalidType',
      };

      final parsed = InfoRegisterDto.fromJson(dto);
      expect(parsed.deviceType, DeviceType.desktop);
    });

    test('should fallback deviceType', () {
      final dto = {
        'info': {
          'alias': 'Nice Banana',
          'deviceModel': 'Samsung',
          'deviceType': 'invalidType',
        },
        'files': {
          'some id': {
            'id': 'some id',
            'fileName': 'another image.jpg',
            'size': 1234,
            'fileType': 'image',
            'preview': '*preview data*',
          },
        },
      };
      final parsed = PrepareUploadRequestDto.fromJson(dto);
      expect(parsed.info.deviceType, DeviceType.desktop);
      expect(parsed.files.length, 1);
      expect(parsed.files.values.first.fileType, FileType.image);
    });

    test('should fallback fileType', () {
      final dto = {
        'info': {
          'alias': 'Nice Banana',
          'deviceModel': 'Samsung',
          'deviceType': 'mobile',
        },
        'files': {
          'some id': {
            'id': 'some id',
            'fileName': 'another image.jpg',
            'size': 1234,
            'fileType': 'superBigImage',
            'preview': '*preview data*',
          },
        },
      };
      final parsed = PrepareUploadRequestDto.fromJson(dto);
      expect(parsed.info.deviceType, DeviceType.mobile);
      expect(parsed.files.length, 1);
      expect(parsed.files.values.first.fileType, FileType.other);
    });

    test('should parse mime type', () {
      final dto = {
        'info': {
          'alias': 'Nice Banana',
          'deviceModel': 'Samsung',
          'deviceType': 'mobile',
        },
        'files': {
          'some id': {
            'id': 'some id',
            'fileName': 'another image.jpg',
            'size': 1234,
            'fileType': 'image/jpeg',
            'preview': '*preview data*',
          },
        },
      };
      final parsed = PrepareUploadRequestDto.fromJson(dto);
      expect(parsed.info.deviceType, DeviceType.mobile);
      expect(parsed.files.length, 1);
      expect(parsed.files.values.first.fileType, FileType.image);
    });

    test('should parse apk mime type', () {
      final dto = {
        'info': {
          'alias': 'Nice Banana',
          'deviceModel': 'Samsung',
          'deviceType': 'mobile',
        },
        'files': {
          'some id': {
            'id': 'some id',
            'fileName': 'myApk.apk',
            'size': 1234,
            'fileType': 'application/vnd.android.package-archive',
          },
        },
      };
      final parsed = PrepareUploadRequestDto.fromJson(dto);
      expect(parsed.info.deviceType, DeviceType.mobile);
      expect(parsed.files.length, 1);
      expect(parsed.files.values.first.fileType, FileType.apk);
    });

    test('should parse wakeSessionId when present', () {
      final dto = {
        'info': {
          'alias': 'Nice Banana',
          'deviceModel': 'Samsung',
          'deviceType': 'mobile',
        },
        'files': {
          'some id': {
            'id': 'some id',
            'fileName': 'photo.jpg',
            'size': 1234,
            'fileType': 'image',
          },
        },
        'wakeSessionId': 'nonce-abc',
      };
      final parsed = PrepareUploadRequestDto.fromJson(dto);
      expect(parsed.wakeSessionId, 'nonce-abc');
    });

    test('should default wakeSessionId to null when missing', () {
      final dto = {
        'info': {
          'alias': 'Nice Banana',
          'deviceModel': 'Samsung',
          'deviceType': 'mobile',
        },
        'files': {
          'some id': {
            'id': 'some id',
            'fileName': 'photo.jpg',
            'size': 1234,
            'fileType': 'image',
          },
        },
      };
      final parsed = PrepareUploadRequestDto.fromJson(dto);
      expect(parsed.wakeSessionId, isNull);
    });

    test('should parse stock LocalSend fixture', () {
      final fixture = File('test/fixtures/prepare_upload_request_stock_localsend.json').readAsStringSync();
      final parsed = PrepareUploadRequestDto.fromJson(jsonDecode(fixture));
      expect(parsed.wakeSessionId, isNull);
      expect(parsed.info.alias, 'Stock LocalSend');
      expect(parsed.files.length, 1);
      expect(parsed.files.values.first.fileType, FileType.image);
    });
  });

  group('serialize PrepareUploadRequestDto', () {
    const info = InfoRegisterDto(
      alias: 'Nice Banana',
      version: '2.0',
      deviceModel: 'Samsung',
      deviceType: DeviceType.mobile,
      fingerprint: '123',
      port: 123,
      protocol: ProtocolType.http,
      download: false,
    );

    test('should serialize in mime mode', () {
      final dto = PrepareUploadRequestDto(
        info: info,
        files: {
          'some id': const FileDto(
            id: 'some id',
            fileName: 'another image.jpg',
            size: 1234,
            fileType: FileType.image,
            hash: '*hash*',
            preview: '*preview data*',
            metadata: null,
          ),
          'some id 2': FileDto(
            id: 'some id 2',
            fileName: 'my apk.apk',
            size: 1234,
            fileType: FileType.apk,
            hash: '*hash*',
            preview: '*preview data*',
            metadata: FileMetadata(
              lastModified: DateTime.utc(2020),
              lastAccessed: DateTime.utc(2021),
            ),
          ),
        },
      );
      final serialized = dto.toJson();

      expect(serialized['info']['deviceType'], 'mobile');
      expect(serialized['files'].length, 2);
      expect(serialized['files']['some id']['fileType'], 'image/jpeg');
      expect(serialized['files']['some id 2']['fileType'], 'application/vnd.android.package-archive');
      expect(serialized['files']['some id 2']['metadata'], {
        'modified': '2020-01-01T00:00:00.000Z',
        'accessed': '2021-01-01T00:00:00.000Z',
      });
    });

    test('should serialize wakeSessionId as null when not set', () {
      // dart_mappable emits nullable fields as null rather than omitting them.
      // The Rust side accepts both null and missing-key for Option<String>,
      // so this asymmetry with the Rust serializer (which skips) is harmless.
      final dto = PrepareUploadRequestDto(
        info: info,
        files: const {},
      );
      final serialized = dto.toJson();
      expect(serialized['wakeSessionId'], isNull);
    });

    test('should include wakeSessionId when set', () {
      final dto = PrepareUploadRequestDto(
        info: info,
        files: const {},
        wakeSessionId: 'nonce-abc',
      );
      final serialized = dto.toJson();
      expect(serialized['wakeSessionId'], 'nonce-abc');
    });
  });

  test('PrepareUploadResponseDto', () {
    final parsed = PrepareUploadResponseDto.fromJson({
      'sessionId': 'some session id',
      'files': {
        'some id': 'some url',
        'some id 2': 'some url 2',
      },
    });

    expect(parsed.sessionId, 'some session id');
    expect(parsed.files.length, 2);
    expect(parsed.files['some id'], 'some url');
    expect(parsed.files['some id 2'], 'some url 2');
  });
}
