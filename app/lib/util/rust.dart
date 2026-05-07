import 'package:common/model/device.dart';
import 'package:common/model/dto/file_dto.dart';
import 'package:common/model/dto/multicast_dto.dart';
import 'package:magicshare_app/rust/api/model.dart' as rust_model;
import 'package:mime/mime.dart';

extension ProtocolTypeExt on ProtocolType {
  rust_model.ProtocolType toRust() {
    return switch (this) {
      ProtocolType.http => rust_model.ProtocolType.http,
      ProtocolType.https => rust_model.ProtocolType.https,
    };
  }
}

extension DeviceExt on Device {
  /// Reads the protocol from the first [HttpEndpoint]; defaults to
  /// HTTPS for devices with no HTTP endpoint (callers that hit this
  /// path are about to fail elsewhere).
  rust_model.ProtocolType getProtocolType() {
    final endpoint = firstHttpEndpoint;
    return switch (endpoint?.https ?? true) {
      false => rust_model.ProtocolType.http,
      true => rust_model.ProtocolType.https,
    };
  }

  /// Builds a [rust_model.RegisterDto] from this device's first
  /// [HttpEndpoint]. Throws if the device has no HTTP endpoint —
  /// the register handshake is HTTP-specific.
  rust_model.RegisterDto toRegisterDto() {
    final endpoint = firstHttpEndpoint;
    if (endpoint == null) {
      throw StateError('toRegisterDto requires an HttpEndpoint on $alias');
    }
    return rust_model.RegisterDto(
      alias: alias,
      version: version,
      deviceModel: deviceModel,
      deviceType: deviceType.toRust(),
      token: endpoint.certHash,
      port: endpoint.port,
      protocol: getProtocolType(),
      hasWebInterface: download,
    );
  }
}

extension DeviceTypeExt on DeviceType {
  rust_model.DeviceType toRust() {
    return switch (this) {
      DeviceType.mobile => rust_model.DeviceType.mobile,
      DeviceType.desktop => rust_model.DeviceType.desktop,
      DeviceType.web => rust_model.DeviceType.web,
      DeviceType.headless => rust_model.DeviceType.headless,
      DeviceType.server => rust_model.DeviceType.server,
    };
  }
}

extension FileDtoExt on FileDto {
  rust_model.FileDto toRust() {
    return rust_model.FileDto(
      id: id,
      fileName: fileName,
      size: BigInt.from(size),
      fileType: lookupMimeType(fileName) ?? 'application/octet-stream',
      sha256: hash,
      preview: preview,
      metadata: metadata != null
          ? rust_model.FileMetadata(
              modified: metadata!.lastModified?.toUtc().toIso8601String(),
              accessed: metadata!.lastAccessed?.toUtc().toIso8601String(),
            )
          : null,
    );
  }
}

extension RustDeviceTypeExt on rust_model.DeviceType {
  DeviceType toDart() {
    return switch (this) {
      rust_model.DeviceType.mobile => DeviceType.mobile,
      rust_model.DeviceType.desktop => DeviceType.desktop,
      rust_model.DeviceType.web => DeviceType.web,
      rust_model.DeviceType.headless => DeviceType.headless,
      rust_model.DeviceType.server => DeviceType.server,
    };
  }
}

extension RegisterResponseDtoExt on rust_model.RegisterResponseDto {
  Device toDevice(String ip, int port, bool https, DiscoveryMethod method) {
    return Device(
      version: version,
      alias: alias,
      deviceModel: deviceModel,
      deviceType: deviceType?.toDart() ?? DeviceType.desktop,
      download: hasWebInterface,
      endpoints: {
        HttpEndpoint(
          ip: ip,
          port: port,
          https: https,
          certHash: token,
        ),
      },
      discoveryMethods: {method},
    );
  }
}
