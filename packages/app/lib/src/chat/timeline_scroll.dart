import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Where to put the timeline, as a scroll offset for a viewport of the
/// given height. The offset is clamped to the content.
typedef TimelineTarget = double Function(double viewport);

/// Scrolls the chat timeline, which grows both ways from a message (see
/// `TimelineView`): offset 0 puts that message at the bottom edge, older
/// messages above it and newer ones below.
///
/// Two things are applied while the viewport lays out, so they land in
/// the same frame as the content they depend on, without a visible jump:
/// a [request] for one offset, and [pinned], which keeps the newest
/// message at the bottom as messages arrive.
class TimelineScrollController extends ScrollController {
  TimelineScrollController();

  TimelineTarget? _request;
  var _requestFrames = 0;

  /// Whether the view follows the newest message. Scrolling sets it from
  /// where the user leaves the view; the app sets it when it jumps.
  bool pinned = true;

  /// Puts the timeline at [target] on the next layouts, until the content
  /// it measures has settled.
  void request(TimelineTarget target) {
    _request = target;
    _requestFrames = 0;
    for (final position in positions) {
      (position as _TimelinePosition).poke();
    }
    _scheduleRelease();
  }

  /// Pins the view to the newest message.
  void pinToBottom() {
    pinned = true;
    request((_) => double.negativeInfinity);
  }

  // Lazily built rows change their measured size over the first frames,
  // so a request holds for two of them.
  void _scheduleRelease() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_request == null) return;
      if (++_requestFrames >= 2) {
        _request = null;
      } else {
        _scheduleRelease();
      }
    });
  }

  double? _wanted(double viewport, {required bool idle}) {
    if (_request case final request?) return request(viewport);
    if (pinned && idle) return double.negativeInfinity;
    return null;
  }

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _TimelinePosition(
    owner: this,
    physics: physics,
    context: context,
    oldPosition: oldPosition,
  );
}

class _TimelinePosition extends ScrollPositionWithSingleContext {
  _TimelinePosition({
    required this.owner,
    required super.physics,
    required super.context,
    super.oldPosition,
  });

  final TimelineScrollController owner;

  /// Asks the viewport for a layout, which applies the request. Not while
  /// a frame is being built, where the change of content does it anyway.
  void poke() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
    }
  }

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (hasViewportDimension) {
      final wanted = owner._wanted(
        viewportDimension,
        idle: activity is IdleScrollActivity,
      );
      if (wanted != null) {
        final target = wanted.clamp(minScrollExtent, maxScrollExtent);
        if ((target - pixels).abs() > 0.5) {
          correctPixels(target);
          super.applyContentDimensions(minScrollExtent, maxScrollExtent);
          return false;
        }
      }
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
