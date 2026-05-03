package com.magicshare.app

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Stub Android FCM service. Decryption + dispatch of wake / link payloads
 * is the responsibility of Epic 13 (Notification reception). For Epic 7 we
 * just claim the binding and forward the token-refresh callback so the
 * Dart-side FcmService can react.
 */
class MagicShareFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        // Real handling lands in Epic 13. Until then the message is logged
        // implicitly by the SDK and ignored on the Dart side.
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // FirebaseMessaging.onTokenRefresh on the Dart side fires from the
        // SDK plugin; no manual bridging is needed here.
    }
}
