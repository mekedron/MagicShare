use crate::http::dto_v2::{
    PrepareUploadRequestDtoV2, PrepareUploadResponseDtoV2, ProtocolTypeV2, RegisterDtoV2,
    RegisterResponseDtoV2,
};
use crate::model::discovery::DeviceType;
use crate::model::transfer::FileDto;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Clone, Debug, PartialEq, Eq, Deserialize, Serialize)]
pub struct NonceRequest {
    /// The nonce string.
    pub nonce: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize, Serialize)]
pub struct NonceResponse {
    /// The nonce string.
    pub nonce: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize, Serialize)]
pub struct ErrorResponse {
    /// The error message.
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RegisterDto {
    pub alias: String,

    pub version: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub device_model: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub device_type: Option<DeviceType>,

    pub token: String,

    pub port: u16,

    pub protocol: ProtocolType,

    #[serde(default, skip_serializing_if = "is_default")]
    pub has_web_interface: bool,
}

#[derive(Clone, Debug, Deserialize, Eq, Serialize, PartialEq)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ProtocolType {
    Http,
    Https,
}

impl ProtocolType {
    pub fn as_str(&self) -> &'static str {
        match self {
            ProtocolType::Http => "http",
            ProtocolType::Https => "https",
        }
    }
}

impl From<ProtocolType> for ProtocolTypeV2 {
    fn from(p: ProtocolType) -> Self {
        match p {
            ProtocolType::Http => ProtocolTypeV2::Http,
            ProtocolType::Https => ProtocolTypeV2::Https,
        }
    }
}

impl From<RegisterDto> for RegisterDtoV2 {
    fn from(v3: RegisterDto) -> Self {
        RegisterDtoV2 {
            alias: v3.alias,
            version: v3.version,
            device_model: v3.device_model,
            device_type: v3.device_type,
            fingerprint: v3.token,
            port: v3.port,
            protocol: v3.protocol.into(),
            download: v3.has_web_interface,
        }
    }
}

/// Similar to `RegisterDto`, but without `port` and `protocol` (those are already known).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RegisterResponseDto {
    pub alias: String,

    pub version: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub device_model: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub device_type: Option<DeviceType>,

    pub token: String,

    #[serde(default, skip_serializing_if = "is_default")]
    pub has_web_interface: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrepareUploadRequestDto {
    pub info: RegisterDto,
    pub files: HashMap<String, FileDto>,

    /// MagicShare extension: nonce that lets the receiver auto-accept a
    /// transfer triggered by a wake notification. Absent on stock LocalSend.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub wake_session_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PrepareUploadResponseDto {
    pub session_id: String,
    pub files: HashMap<String, String>,
}

impl From<PrepareUploadRequestDto> for PrepareUploadRequestDtoV2 {
    fn from(v3: PrepareUploadRequestDto) -> Self {
        PrepareUploadRequestDtoV2 {
            info: v3.info.into(),
            files: v3.files,
        }
    }
}

pub struct PrepareUploadResult {
    pub status_code: u16,
    pub response: Option<PrepareUploadResponseDto>,
}

impl From<PrepareUploadResponseDtoV2> for PrepareUploadResponseDto {
    fn from(v2: PrepareUploadResponseDtoV2) -> Self {
        PrepareUploadResponseDto {
            session_id: v2.session_id,
            files: v2.files,
        }
    }
}

impl From<crate::http::dto_v2::PrepareUploadResultV2> for PrepareUploadResult {
    fn from(v2: crate::http::dto_v2::PrepareUploadResultV2) -> Self {
        PrepareUploadResult {
            status_code: v2.status_code,
            response: v2.response.map(|r| r.into()),
        }
    }
}

impl From<RegisterResponseDtoV2> for RegisterResponseDto {
    fn from(v2: RegisterResponseDtoV2) -> Self {
        RegisterResponseDto {
            alias: v2.alias,
            version: v2.version,
            device_model: v2.device_model,
            device_type: v2.device_type,
            token: v2.fingerprint,
            has_web_interface: v2.download,
        }
    }
}

fn is_default<T: Default + PartialEq>(t: &T) -> bool {
    t == &T::default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::transfer::FileDto;

    fn sample_register_dto() -> RegisterDto {
        RegisterDto {
            alias: "Sender".to_string(),
            version: "2.1".to_string(),
            device_model: None,
            device_type: None,
            token: "sender-token".to_string(),
            port: 53317,
            protocol: ProtocolType::Https,
            has_web_interface: false,
        }
    }

    fn sample_files() -> HashMap<String, FileDto> {
        let mut files = HashMap::new();
        files.insert(
            "file-1".to_string(),
            FileDto {
                id: "file-1".to_string(),
                file_name: "photo.jpg".to_string(),
                size: 1234,
                file_type: "image/jpeg".to_string(),
                sha256: None,
                preview: None,
                metadata: None,
            },
        );
        files
    }

    #[test]
    fn prepare_upload_request_round_trips_with_wake_session_id() {
        let dto = PrepareUploadRequestDto {
            info: sample_register_dto(),
            files: sample_files(),
            wake_session_id: Some("nonce-abc".to_string()),
        };

        let json = serde_json::to_string(&dto).unwrap();
        assert!(
            json.contains("\"wakeSessionId\":\"nonce-abc\""),
            "expected camelCase key in {json}",
        );

        let parsed: PrepareUploadRequestDto = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.wake_session_id, Some("nonce-abc".to_string()));
        assert_eq!(parsed.files.len(), 1);
        assert_eq!(parsed.info.alias, "Sender");
    }

    #[test]
    fn prepare_upload_request_omits_wake_session_id_when_none() {
        let dto = PrepareUploadRequestDto {
            info: sample_register_dto(),
            files: sample_files(),
            wake_session_id: None,
        };

        let json = serde_json::to_string(&dto).unwrap();
        assert!(
            !json.contains("wakeSessionId"),
            "wakeSessionId should be skipped when None, got {json}",
        );
    }

    #[test]
    fn prepare_upload_request_parses_legacy_payload() {
        // Stock LocalSend v2.1 client body: no wakeSessionId field.
        let json = r#"{
            "info": {
                "alias": "Stock LocalSend",
                "version": "2.1",
                "token": "stock-token",
                "port": 53317,
                "protocol": "HTTPS"
            },
            "files": {
                "file-1": {
                    "id": "file-1",
                    "fileName": "photo.jpg",
                    "size": 1234,
                    "fileType": "image/jpeg"
                }
            }
        }"#;

        let parsed: PrepareUploadRequestDto = serde_json::from_str(json).unwrap();
        assert!(parsed.wake_session_id.is_none());
        assert_eq!(parsed.info.alias, "Stock LocalSend");
        assert_eq!(parsed.files.len(), 1);
    }

    #[test]
    fn v3_to_v2_conversion_drops_wake_session_id() {
        let dto = PrepareUploadRequestDto {
            info: sample_register_dto(),
            files: sample_files(),
            wake_session_id: Some("nonce-abc".to_string()),
        };

        let v2: PrepareUploadRequestDtoV2 = dto.into();
        let json = serde_json::to_string(&v2).unwrap();
        assert!(
            !json.contains("wakeSessionId"),
            "v2 wire shape must not carry wakeSessionId, got {json}",
        );
        assert_eq!(v2.files.len(), 1);
    }
}
