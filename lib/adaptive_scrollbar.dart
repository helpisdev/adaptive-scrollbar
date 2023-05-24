// ignore_for_file: prefer_asserts_with_message

library adaptive_scrollbar;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hovering/hovering.dart';
import 'package:rxdart/rxdart.dart';

// Scrollbar positions.
enum ScrollbarPosition { right, bottom, left, top }

// Scroll direction to the nearest click on bottom.
enum ToClickDirection { up, down }

/// Adaptive desktop-style scrollbar.
///
/// To add a scrollbar, simply wrap the widget that contains your [ScrollView] object
/// in a [AdaptiveScrollbar] and specify the [ScrollController] of your [ScrollView].
///
/// The scrollbar is placed on the specified [ScrollbarPosition]
/// and tracks the scrolls only of its [ScrollView] object,
/// via the specified [ScrollController].
class AdaptiveScrollbar extends StatefulWidget {
  /// Wraps your [child] widget that contains [ScrollView] object,
  /// takes the position indicated by [position]
  /// and tracks scrolls only of this [ScrollView], via the specified [controller].
  AdaptiveScrollbar({
    required this.child,
    required this.controller,
    super.key,
    this.position = ScrollbarPosition.right,
    this.width = 16.0,
    this.sliderHeight,
    this.sliderChild,
    this.sliderDefaultColor = Colors.blueGrey,
    final Color? sliderActiveColor,
    this.underColor = Colors.white,
    this.underSpacing = EdgeInsets.zero,
    this.sliderSpacing = const EdgeInsets.all(2.0),
    this.scrollToClickDelta = 100.0,
    this.scrollToClickFirstDelay = 400,
    this.scrollToClickOtherDelay = 100,
    final BoxDecoration? underDecoration,
    final BoxDecoration? sliderDecoration,
    final BoxDecoration? sliderActiveDecoration,
  })  : assert(sliderSpacing.horizontal < width),
        assert(width > 0),
        assert(scrollToClickDelta >= 0),
        assert(scrollToClickFirstDelay >= 0),
        assert(scrollToClickOtherDelay >= 0) {
    if (sliderActiveColor == null) {
      this.sliderActiveColor = sliderDefaultColor.withRed(10);
    } else {
      this.sliderActiveColor = sliderActiveColor;
    }

    if (underDecoration == null) {
      this.underDecoration = BoxDecoration(color: underColor);
    } else {
      this.underDecoration = underDecoration;
    }

    if (sliderDecoration == null) {
      this.sliderDecoration = BoxDecoration(color: sliderDefaultColor);
    } else {
      this.sliderDecoration = sliderDecoration;
    }

    if (sliderActiveDecoration == null) {
      this.sliderActiveDecoration = BoxDecoration(
        color: this.sliderActiveColor,
      );
    } else {
      this.sliderActiveDecoration = sliderActiveDecoration;
    }
  }

  /// Widget that contains your [ScrollView].
  final Widget child;

  /// [ScrollController] that attached to [ScrollView] object.
  final ScrollController controller;

  /// Position of [AdaptiveScrollbar] on the screen.
  final ScrollbarPosition position;

  /// Width of all [AdaptiveScrollbar].
  final double width;

  /// Height of slider. If you set this value,
  /// there will be this height. If not set, the height
  /// will be calculated based on the content, as usual
  final double? sliderHeight;

  /// Child widget for slider.
  final Widget? sliderChild;

  /// Under the slider part of the scrollbar color.
  final Color underColor;

  /// Default slider color.
  final Color sliderDefaultColor;

  /// Active slider color.
  late final Color sliderActiveColor;

  /// Under the slider part of the scrollbar decoration.
  late final BoxDecoration underDecoration;

  /// Slider decoration.
  late final BoxDecoration sliderDecoration;

  /// Slider decoration during pressing.
  late final BoxDecoration sliderActiveDecoration;

  /// Offset of the slider in the direction of the click.
  final double scrollToClickDelta;

  /// Duration of the first delay between scrolls in the click direction, in milliseconds.
  final int scrollToClickFirstDelay;

  /// Duration of the others delays between scrolls in the click direction, in milliseconds.
  final int scrollToClickOtherDelay;

  /// Under the slider part of the scrollbar spacing.
  /// If you choose [ScrollbarPosition.top] or [ScrollbarPosition.bottom] position,
  /// the scrollbar will be rotated 90 degrees, and the top
  /// will be on the left. Don't forget this when specifying the [underSpacing].
  final EdgeInsetsGeometry underSpacing;

  /// Slider spacing from bottom.
  /// If you choose [ScrollbarPosition.top] or [ScrollbarPosition.bottom] position,
  /// the scrollbar will be rotated 90 degrees, and the top
  /// will be on the left. Don't forget this when specifying the [sliderSpacing].
  final EdgeInsetsGeometry sliderSpacing;

  @override
  State<AdaptiveScrollbar> createState() => _AdaptiveScrollbarState();

  @override
  void debugFillProperties(final DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ScrollController>('controller', controller))
      ..add(EnumProperty<ScrollbarPosition>('position', position))
      ..add(DoubleProperty('width', width))
      ..add(DoubleProperty('sliderHeight', sliderHeight))
      ..add(ColorProperty('underColor', underColor))
      ..add(ColorProperty('sliderDefaultColor', sliderDefaultColor))
      ..add(ColorProperty('sliderActiveColor', sliderActiveColor))
      ..add(
        DiagnosticsProperty<BoxDecoration>('underDecoration', underDecoration),
      )
      ..add(
        DiagnosticsProperty<BoxDecoration>(
          'sliderDecoration',
          sliderDecoration,
        ),
      )
      ..add(
        DiagnosticsProperty<BoxDecoration>(
          'sliderActiveDecoration',
          sliderActiveDecoration,
        ),
      )
      ..add(DoubleProperty('scrollToClickDelta', scrollToClickDelta))
      ..add(IntProperty('scrollToClickFirstDelay', scrollToClickFirstDelay))
      ..add(IntProperty('scrollToClickOtherDelay', scrollToClickOtherDelay))
      ..add(
        DiagnosticsProperty<EdgeInsetsGeometry>('underSpacing', underSpacing),
      )
      ..add(
        DiagnosticsProperty<EdgeInsetsGeometry>(
          'sliderSpacing',
          sliderSpacing,
        ),
      );
  }
}

class _AdaptiveScrollbarState extends State<AdaptiveScrollbar> {
  /// Used for transmitting information about scrolls to the [ScrollSlider].
  BehaviorSubject<bool> scrollSubject = BehaviorSubject<bool>();

  /// Used for transmitting information about clicks to the [ScrollSlider].
  BehaviorSubject<double> clickSubject = BehaviorSubject<double>();

  /// Alignment of scrollbar that depends on [ScrollbarPosition].
  Alignment alignment = Alignment.center;

  /// Quarter turns of scrollbar that depends on [ScrollbarPosition].
  int quarterTurns = 0;

  @override
  void initState() {
    super.initState();
    switch (widget.position) {
      case ScrollbarPosition.right:
        alignment = Alignment.centerRight;
        quarterTurns = 0;
        break;

      case ScrollbarPosition.bottom:
        alignment = Alignment.bottomCenter;
        quarterTurns = 3;
        break;

      case ScrollbarPosition.left:
        alignment = Alignment.centerLeft;
        quarterTurns = 0;
        break;

      case ScrollbarPosition.top:
        alignment = Alignment.topCenter;
        quarterTurns = 3;
        break;
    }
  }

  @override
  void dispose() {
    unawaited(scrollSubject.close());
    unawaited(clickSubject.close());
    super.dispose();
  }

  /// Sending information about scrolls to the [ScrollSlider].
  bool sendToScrollUpdate(final ScrollNotification notification) {
    scrollSubject.sink.add(true);
    return false;
  }

  /// Sending information about clicks to the [ScrollSlider].
  void sendToClickUpdate(final double position) {
    clickSubject.sink.add(position);
  }

  @override
  Widget build(final BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: sendToScrollUpdate,
        child: Stack(
          children: <Widget>[
            widget.child,
            LayoutBuilder(
              builder: (
                final BuildContext context,
                final BoxConstraints constraints,
              ) =>
                  !widget.controller.hasClients ||
                          widget.controller.position.maxScrollExtent == 0
                      ? const SizedBox.shrink()
                      : Align(
                          alignment: alignment,
                          child: RotatedBox(
                            quarterTurns: quarterTurns,
                            child: Padding(
                              padding: widget.underSpacing,
                              child: Semantics(
                                label: 'Scrollbar track',
                                child: GestureDetector(
                                  onTapDown: (final TapDownDetails details) {
                                    sendToClickUpdate(details.localPosition.dy);
                                  },
                                  onTapUp: (final TapUpDetails details) {
                                    sendToClickUpdate(-1);
                                  },
                                  child: Container(
                                    width: widget.width,
                                    decoration: widget.underDecoration,
                                    child: ScrollSlider(
                                      controller: widget.controller,
                                      sliderSpacing: widget.sliderSpacing,
                                      scrollSubject: scrollSubject,
                                      scrollToClickDelta:
                                          widget.scrollToClickDelta,
                                      scrollToClickFirstDelay:
                                          widget.scrollToClickFirstDelay,
                                      scrollToClickOtherDelay:
                                          widget.scrollToClickOtherDelay,
                                      clickSubject: clickSubject,
                                      sliderDecoration: widget.sliderDecoration,
                                      sliderHeight: widget.sliderHeight,
                                      sliderChild: widget.sliderChild,
                                      sliderActiveDecoration:
                                          widget.sliderActiveDecoration,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      );

  @override
  void debugFillProperties(final DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(
        DiagnosticsProperty<BehaviorSubject<bool>>(
          'scrollSubject',
          scrollSubject,
        ),
      )
      ..add(
        DiagnosticsProperty<BehaviorSubject<double>>(
          'clickSubject',
          clickSubject,
        ),
      )
      ..add(DiagnosticsProperty<Alignment>('alignment', alignment))
      ..add(IntProperty('quarterTurns', quarterTurns));
  }
}

class ScrollSlider extends StatefulWidget {
  /// Creates a slider.
  const ScrollSlider({
    required this.controller,
    required this.sliderSpacing,
    required this.sliderDecoration,
    required this.scrollToClickDelta,
    required this.scrollSubject,
    required this.clickSubject,
    required this.scrollToClickFirstDelay,
    required this.scrollToClickOtherDelay,
    required this.sliderHeight,
    required this.sliderChild,
    required this.sliderActiveDecoration,
    super.key,
  });

  /// [ScrollController] that attached to [ScrollView] object.
  final ScrollController controller;

  /// Slider padding from bottom.
  /// If you choose [ScrollbarPosition.top] or [ScrollbarPosition.bottom] position,
  /// the scrollbar will be rotated 90 degrees, and the top
  /// will be on the left. Don't forget this when specifying the [sliderSpacing].
  final EdgeInsetsGeometry sliderSpacing;

  /// Used for receiving information about scrolls.
  final BehaviorSubject<bool> scrollSubject;

  /// Used for receiving information about clicks.
  final BehaviorSubject<double> clickSubject;

  /// Slider decoration.
  final BoxDecoration sliderDecoration;

  /// Slider decoration during pressing.
  final BoxDecoration sliderActiveDecoration;

  /// Offset of the slider in the direction of click.
  final double scrollToClickDelta;

  /// Duration of the first delay between scrolls in the click direction, in milliseconds.
  final int scrollToClickFirstDelay;

  /// Duration of the others delays between scrolls in the click direction, in milliseconds.
  final int scrollToClickOtherDelay;

  /// Height of slider. If you set this value,
  /// there will be this height. If not set, the height
  /// will be calculated based on the content, as usual
  final double? sliderHeight;

  /// Child widget for slider.
  final Widget? sliderChild;

  @override
  State<ScrollSlider> createState() => _ScrollSliderState();

  @override
  void debugFillProperties(final DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ScrollController>('controller', controller))
      ..add(
        DiagnosticsProperty<EdgeInsetsGeometry>(
          'sliderSpacing',
          sliderSpacing,
        ),
      )
      ..add(
        DiagnosticsProperty<BehaviorSubject<bool>>(
          'scrollSubject',
          scrollSubject,
        ),
      )
      ..add(
        DiagnosticsProperty<BehaviorSubject<double>>(
          'clickSubject',
          clickSubject,
        ),
      )
      ..add(
        DiagnosticsProperty<BoxDecoration>(
          'sliderDecoration',
          sliderDecoration,
        ),
      )
      ..add(
        DiagnosticsProperty<BoxDecoration>(
          'sliderActiveDecoration',
          sliderActiveDecoration,
        ),
      )
      ..add(DoubleProperty('scrollToClickDelta', scrollToClickDelta))
      ..add(IntProperty('scrollToClickFirstDelay', scrollToClickFirstDelay))
      ..add(IntProperty('scrollToClickOtherDelay', scrollToClickOtherDelay))
      ..add(DoubleProperty('sliderHeight', sliderHeight));
  }
}

class _ScrollSliderState extends State<ScrollSlider> {
  /// Current slider offset.
  double sliderOffset = 0.0;

  /// Current [ScrollView] offset.
  double viewOffset = 0;

  /// Final slider height, installed or calculated value.
  double finalSliderHeight = 0;

  /// Slider minimal height.
  double minHeightScrollSlider = 10.0;

  /// Is the slider being pulled at the moment.
  bool isDragInProcess = false;

  /// A flag used to determine whether scrollToClick is executed for the first time in a row.
  bool isFirst = true;

  /// A subscription to the [ScrollSlider.scrollSubject].
  late StreamSubscription<bool> streamSubscriptionScroll;

  /// A subscription to the [ScrollSlider.clickSubject].
  late StreamSubscription<double> streamSubscriptionClick;

  /// Timer used for smooth scrolling in the direction of the click.
  Timer timer = Timer(const Duration(milliseconds: 400), () {});

  @override
  void initState() {
    streamSubscriptionScroll = widget.scrollSubject.listen(
      (final bool isScrolling) => onScrollUpdate(isScrolling: isScrolling),
    );
    streamSubscriptionClick = widget.clickSubject.listen(onClickCallback);
    super.initState();
  }

  void onClickCallback(final double value) {
    if (value == -1) {
      timer.cancel();
    } else {
      if (sliderOffset + finalSliderHeight < value) {
        unawaited(scrollToClick(value, ToClickDirection.down));
      } else {
        if (sliderOffset > value) {
          unawaited(scrollToClick(value, ToClickDirection.up));
        }
      }
    }
  }

  @override
  void dispose() {
    unawaited(streamSubscriptionScroll.cancel());
    unawaited(streamSubscriptionClick.cancel());
    super.dispose();
  }

  /// Maximal slider offset.
  double get sliderMaxScroll =>
      context.size!.height - finalSliderHeight - widget.sliderSpacing.vertical;

  /// Minimal slider offset.
  double get sliderMinScroll => 0.0;

  /// Maximal [ScrollView] offset.
  double get viewMaxScroll => widget.controller.position.maxScrollExtent;

  /// Minimal [ScrollView] offset.
  double get viewMinScroll => 0.0;

  /// Maximal slider offset during build.
  double sliderMaxScrollDuringBuild(final double maxHeight) =>
      maxHeight - finalSliderHeight - widget.sliderSpacing.vertical;

  /// Maximal [ScrollView] offset during build.
  double viewMaxScrollDuringBuild(final double maxHeight) =>
      widget.controller.position.maxScrollExtent;

  /// [ScrollView] offset in the direction of click.
  double getScrollViewDelta(
    final double sliderDelta,
    final double sliderMaxScroll,
    final double viewMaxScroll,
  ) =>
      sliderDelta * viewMaxScroll / sliderMaxScroll;

  /// Scrolling in the direction of click
  Future<void> scrollToClick(
    final double position,
    final ToClickDirection direction,
  ) async {
    setState(() {
      if (direction == ToClickDirection.down) {
        sliderOffset += widget.scrollToClickDelta;
      } else {
        sliderOffset -= widget.scrollToClickDelta;
      }
      if (sliderOffset < sliderMinScroll) {
        sliderOffset = sliderMinScroll;
      }

      if (sliderOffset > sliderMaxScroll) {
        sliderOffset = sliderMaxScroll;
      }

      final double viewDelta = getScrollViewDelta(
        direction == ToClickDirection.down
            ? widget.scrollToClickDelta
            : -widget.scrollToClickDelta,
        sliderMaxScroll,
        viewMaxScroll,
      );

      viewOffset = widget.controller.position.pixels + viewDelta;

      if (viewOffset < viewMinScroll) {
        viewOffset = viewMinScroll;
      }

      if (viewOffset > viewMaxScroll) {
        viewOffset = viewMaxScroll;
      }
      widget.controller.jumpTo(viewOffset);
    });

    timer = Timer(
        Duration(
          milliseconds: isFirst
              ? widget.scrollToClickFirstDelay
              : widget.scrollToClickOtherDelay,
        ), () {
      isFirst = false;
      if (sliderOffset + finalSliderHeight < position &&
          direction == ToClickDirection.down) {
        scrollToClick(position, ToClickDirection.down);
      } else {
        if (sliderOffset > position && direction == ToClickDirection.up) {
          scrollToClick(position, ToClickDirection.up);
        } else {
          isFirst = true;
        }
      }
    });
  }

  /// Executed when the slider started to drag.
  void onDragStart(final DragStartDetails details) {
    setState(() {
      isDragInProcess = true;
    });
  }

  /// Executed when the slider ended to drag.
  void onDragEnd(final DragEndDetails details) {
    setState(() {
      isDragInProcess = false;
    });
  }

  /// Executed when the slider is dragged.
  void onDragUpdate(final DragUpdateDetails details) {
    setState(() {
      sliderOffset += details.delta.dy;

      if (sliderOffset < sliderMinScroll) {
        sliderOffset = sliderMinScroll;
      }

      if (sliderOffset > sliderMaxScroll) {
        sliderOffset = sliderMaxScroll;
      }

      final double viewDelta =
          getScrollViewDelta(details.delta.dy, sliderMaxScroll, viewMaxScroll);

      viewOffset = widget.controller.position.pixels + viewDelta;

      if (viewOffset < viewMinScroll) {
        viewOffset = viewMinScroll;
      }

      if (viewOffset > viewMaxScroll) {
        viewOffset = viewMaxScroll;
      }
      widget.controller.jumpTo(viewOffset);
    });
  }

  /// Executed when the [ScrollView] is dragged
  void onScrollUpdate({required final bool isScrolling}) {
    if (isDragInProcess) {
      return;
    }
    super.setState(() {
      setState(() {
        sliderOffset =
            widget.controller.position.pixels / viewMaxScroll * sliderMaxScroll;

        if (sliderOffset < sliderMinScroll) {
          sliderOffset = sliderMinScroll;
        }
        if (sliderOffset > sliderMaxScroll) {
          sliderOffset = sliderMaxScroll;
        }
      });
    });
  }

  @override
  Widget build(final BuildContext context) => LayoutBuilder(
        builder:
            (final BuildContext context, final BoxConstraints constraints) {
          finalSliderHeight = widget.sliderHeight ??
              constraints.maxHeight *
                      constraints.maxHeight /
                      (constraints.maxHeight +
                          viewMaxScrollDuringBuild(constraints.maxHeight)) -
                  widget.sliderSpacing.vertical;

          if (finalSliderHeight < minHeightScrollSlider) {
            finalSliderHeight = minHeightScrollSlider;
          }

          if (viewMaxScrollDuringBuild(constraints.maxHeight) <= 0) {
            sliderOffset = 0;
          } else {
            sliderOffset = sliderMaxScrollDuringBuild(constraints.maxHeight) *
                widget.controller.position.pixels /
                viewMaxScrollDuringBuild(constraints.maxHeight);
          }

          if (sliderOffset < sliderMinScroll) {
            sliderOffset = sliderMinScroll;
          }

          if (sliderOffset >
              sliderMaxScrollDuringBuild(constraints.maxHeight)) {
            sliderOffset = sliderMaxScrollDuringBuild(constraints.maxHeight);
          }

          return Semantics(
            slider: true,
            label: 'Scrollbar thumb',
            child: GestureDetector(
              onVerticalDragUpdate: onDragUpdate,
              onVerticalDragStart: onDragStart,
              onVerticalDragEnd: onDragEnd,
              child: Center(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: widget.sliderSpacing,
                    child: Container(
                      height: finalSliderHeight,
                      margin: EdgeInsets.only(top: sliderOffset),
                      decoration: widget.sliderDecoration,
                      child: HoverContainer(
                        hoverDecoration: widget.sliderActiveDecoration,
                        child: Container(
                          constraints: const BoxConstraints.expand(),
                          child: widget.sliderChild ?? Container(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

  @override
  void debugFillProperties(final DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<Timer>('timer', timer))
      ..add(DoubleProperty('sliderOffset', sliderOffset))
      ..add(DoubleProperty('viewOffset', viewOffset))
      ..add(DoubleProperty('finalSliderHeight', finalSliderHeight))
      ..add(DoubleProperty('minHeightScrollSlider', minHeightScrollSlider))
      ..add(DiagnosticsProperty<bool>('isDragInProcess', isDragInProcess))
      ..add(DiagnosticsProperty<bool>('isFirst', isFirst))
      ..add(
        DiagnosticsProperty<StreamSubscription<bool>>(
          'streamSubscriptionScroll',
          streamSubscriptionScroll,
        ),
      )
      ..add(
        DiagnosticsProperty<StreamSubscription<double>>(
          'streamSubscriptionClick',
          streamSubscriptionClick,
        ),
      )
      ..add(DoubleProperty('sliderMaxScroll', sliderMaxScroll))
      ..add(DoubleProperty('sliderMinScroll', sliderMinScroll))
      ..add(DoubleProperty('viewMaxScroll', viewMaxScroll))
      ..add(DoubleProperty('viewMinScroll', viewMinScroll));
  }
}
