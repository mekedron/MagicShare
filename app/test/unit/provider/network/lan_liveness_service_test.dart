import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/provider/network/lan_liveness_service.dart';

class _Counter {
  int announces = 0;
  int prunes = 0;
  int goodbyes = 0;
}

LanLivenessService _makeService(
  _Counter counter, {
  Duration? reannouncePeriod,
  Duration? prunePeriod,
}) {
  return LanLivenessService(
    deps: LanLivenessDeps(
      dispatchAnnounce: () => counter.announces++,
      dispatchPrune: () => counter.prunes++,
      dispatchGoodbye: () => counter.goodbyes++,
    ),
    reannouncePeriod: reannouncePeriod,
    prunePeriod: prunePeriod,
  );
}

void main() {
  group('LanLivenessService.markForeground', () {
    test('starts re-announce + prune timers', () {
      fakeAsync((async) {
        final c = _Counter();
        final svc = _makeService(c);
        svc.markForeground();

        async.elapse(const Duration(seconds: 25));

        expect(c.announces, greaterThanOrEqualTo(1));
        expect(c.prunes, greaterThanOrEqualTo(2));
        expect(c.goodbyes, 0);
      });
    });

    test('is idempotent — second call does not stack timers', () {
      fakeAsync((async) {
        final c = _Counter();
        final svc = _makeService(c);
        svc.markForeground();
        svc.markForeground();
        svc.markForeground();

        async.elapse(const Duration(seconds: 25));

        // Three calls would have stacked three concurrent timers and
        // produced ~3× the dispatch count if the guard didn't work.
        expect(c.announces, lessThanOrEqualTo(2));
        expect(c.prunes, lessThanOrEqualTo(4));
      });
    });
  });

  group('LanLivenessService.markBackground', () {
    test('cancels timers and broadcasts a goodbye', () {
      fakeAsync((async) {
        final c = _Counter();
        final svc = _makeService(c);
        svc.markForeground();
        async.elapse(const Duration(seconds: 25));
        final beforeBg = c.announces;

        svc.markBackground();
        expect(c.goodbyes, 1);

        async.elapse(const Duration(minutes: 5));
        expect(c.announces, beforeBg, reason: 'no further announces after background');
      });
    });

    test('safe to call before any foreground transition', () {
      final c = _Counter();
      final svc = _makeService(c);
      svc.markBackground();
      expect(c.goodbyes, 1, reason: 'still broadcasts a goodbye even from idle');
    });
  });

  group('LanLivenessService re-foreground', () {
    test('restarts timers after a markBackground', () {
      fakeAsync((async) {
        final c = _Counter();
        final svc = _makeService(c);
        svc.markForeground();
        async.elapse(const Duration(seconds: 25));
        svc.markBackground();
        async.elapse(const Duration(minutes: 1));
        final beforeRefg = c.announces;

        svc.markForeground();
        async.elapse(const Duration(seconds: 25));

        expect(c.announces, greaterThan(beforeRefg));
      });
    });
  });

  group('LanLivenessService dispatch errors', () {
    test('survives a throwing announce dispatch', () {
      fakeAsync((async) {
        var pruneCount = 0;
        final svc = LanLivenessService(
          deps: LanLivenessDeps(
            dispatchAnnounce: () => throw StateError('boom'),
            dispatchPrune: () => pruneCount++,
            dispatchGoodbye: () {},
          ),
        );
        svc.markForeground();
        async.elapse(const Duration(seconds: 50));
        // Prune timer should keep firing even when announce throws.
        expect(pruneCount, greaterThanOrEqualTo(4));
      });
    });
  });
}
