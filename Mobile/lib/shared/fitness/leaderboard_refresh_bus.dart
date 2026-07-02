import 'dart:async';

/// Notifies listeners when step sync completes so leaderboard can refresh.
class LeaderboardRefreshBus {
  LeaderboardRefreshBus._();

  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  static Stream<void> get stream => _controller.stream;

  static void notify() {
    if (_controller.isClosed) return;
    _controller.add(null);
  }
}
