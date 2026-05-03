import { logger } from 'firebase-functions';
import { type CallableRequest, HttpsError } from 'firebase-functions/v2/https';

/**
 * Wrap an `onCall` handler with structured logging. Every invocation
 * emits exactly one log line on completion containing:
 *
 *   - op         the callable's name (passed in by the caller)
 *   - callerUid  request.auth?.uid, or 'anonymous' when unset
 *   - status     'ok' | 'error'
 *   - latencyMs  wall-clock duration of the handler
 *   - errorCode  HttpsError code on failure (omitted on success)
 *
 * No PII flows through the logger: display names, FCM tokens, payload
 * contents, link URLs, and join-token IDs are all kept out. Spec §5.4
 * and Epic 6 require this exact shape — "caller UID, op, success/error,
 * latency. No PII." Cloud-side observability dashboards (Epic 14)
 * consume the structured fields directly.
 *
 * Errors propagate to the caller untouched; logging is fire-and-forget.
 */
export function instrument<T, R>(
  op: string,
  handler: (request: CallableRequest<T>) => Promise<R>,
): (request: CallableRequest<T>) => Promise<R> {
  return async (request) => {
    const start = Date.now();
    const callerUid = request.auth?.uid ?? 'anonymous';
    try {
      const result = await handler(request);
      logger.info('cloud-fn:ok', {
        op,
        callerUid,
        status: 'ok',
        latencyMs: Date.now() - start,
      });
      return result;
    } catch (error) {
      const errorCode = error instanceof HttpsError ? error.code : 'internal';
      logger.warn('cloud-fn:error', {
        op,
        callerUid,
        status: 'error',
        latencyMs: Date.now() - start,
        errorCode,
      });
      throw error;
    }
  };
}
