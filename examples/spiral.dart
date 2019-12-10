import 'dart:math';

import 'package:floop/floop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide GestureDetector;
import 'package:http/http.dart' as http;

class Dyn {
  static final dyn = ObservedMap();

  static List<Widget> get spiralAnimatedWidgets =>
      (dyn[#spiralImages] ??= List<Widget>()).cast<Widget>();
  static set spiralAnimatedWidgets(List<Widget> updatedList) =>
      dyn[#spiralImages] = updatedList;

  static String get activeTag => dyn[#activeTag];
  static set activeTag(String tag) => dyn[#activeTag] = tag;
}

void main() {
  // floop['circleWidgets'] = circleWidgets;
  runApp(MaterialApp(
      title: 'Spiral',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Spiral()));
}

class Spiral extends DynamicWidget {
  @override
  void initContext(BuildContext context) {
    Dyn.spiralAnimatedWidgets ??= List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Spiral'),
      ),
      body: Stack(
        children: Dyn.spiralAnimatedWidgets,
      ),
      floatingActionButton: FloatingActionButton(
        child: IconButton(
          icon: Icon(
            Icons.add,
          ),
          onPressed: () async {
            Dyn.spiralAnimatedWidgets = await Dyn.spiralAnimatedWidgets.toList()
              ..add(SpiralingWidget());
          },
        ),
      ),
      bottomNavigationBar: PlaybackOptions(),
    );
  }
}

class SpiralingWidget extends DynamicWidget {
  final Widget child;
  SpiralingWidget({this.child});
  @override
  Widget build(BuildContext context) {
    var t = transition(20000, repeatAfterMillis: 3000);
    return Positioned.fill(
      child: Align(
        alignment: spiralAlignment(t),
        child: MultiGestureDetector(
          child: ImageCircle(t),
          onTap: () => {
            // Transitions.reset(context: context),
            Transitions.resumeOrPause(context: context),
          },
        ),
      ),
    );
  }
}

final colorTag = 'colorTag';

class Oscillators {
  static triangle(double t) {
    var r = t % 1;
    if (r > 0.5) {
      r = 1 - r;
    }
    return 2 * r;
  }
}

class ImageCircle extends DynamicWidget {
  final double diameter;

  ImageCircle(double scale) : diameter = 10 + 60 * scale;

  Color get baseColor => dyn[#baseColor] ??= randomColor();
  set baseColor(Color color) => dyn[#baseColor] = color;

  Color get color => dyn[#color] ??= randomColor();
  set color(Color color) => dyn[#color] = color;

  Widget get image => dyn[#image];
  set image(Widget widget) => dyn[#image] = widget;

  double colorTransition() {
    return sin(
        2 * pi * (transition(3000, repeatAfterMillis: 2000, tag: colorTag)));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        child: Container(
          alignment: Alignment.center,
          // padding: EdgeInsets.all(5),
          height: diameter,
          width: diameter,
          decoration: BoxDecoration(
            color: Color.lerp(baseColor, color, colorTransition()),
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.hardEdge,
          child: SizedBox.expand(
            child: RandomImage(),
          ),
        ),
        onTap: () {
          baseColor = color;
          color = randomColor();
          Transitions.restart(context: context);
        });
  }
}

Alignment spiralAlignment(double t) {
  var a = 0.1; // a constant
  var b = 0.1; // another constant
  var h = 0.2 * b / (a * sqrt(1 + b * b));
  var theta = 0.0;
  for (int i = 0; i < 50 * t; i++) {
    theta = log(h + exp(b * theta)) / b;
  }
  var pX = a * cos(theta) * exp(b * theta);
  var pY = a * sin(theta) * exp(b * theta);
  // print('Position for $t: x is $pX, y is $pY ');
  return Alignment(pX.clamp(-1.0, 1.0), pY.clamp(-1.0, 1.0));
}

var playing = true;

class PlaybackOptions extends FloopWidget {
  Widget get title => Text(
      '${Dyn.activeTag ?? 'All'}'); //Text('On ${Dyn.activeTag ?? 'All'} transitions');

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      iconSize: 26,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          title: title,
          icon: IconButton(
            icon: Icon(
              playing ? Icons.pause : Icons.play_arrow,
            ),
            iconSize: 32,
            onPressed: () => Transitions.resumeOrPause(),
          ),
        ),
        BottomNavigationBarItem(
          title: title,
          icon: GestureDetector(
            child: Icon(Icons.fast_rewind,
                color: true ? Colors.red : Colors.indigoAccent),
            onTap: () => Transitions.shiftTime(shiftMillis: -1000),
            // onLongPress: () {
            //   (store['speedDown'] as Repeater).start();
            //   store['speedDownPressed'] = true;
            // },
            // onLongPressUp: () {
            //   (store['speedDown'] as Repeater).stop();
            //   store['speedDownPressed'] = false;
            // },
          ),
        ),
        BottomNavigationBarItem(
          title: title,
          icon: GestureDetector(
            child: Icon(
              Icons.fast_forward,
              color: true ? Colors.red : Colors.indigoAccent,
            ),
            onTap: () => Transitions.shiftTime(shiftMillis: 1000),
          ),
        ),
        BottomNavigationBarItem(
          title: title,
          icon: IconButton(
            icon: Icon(Icons.refresh),
            iconSize: 32,
            onPressed: () => Transitions.reset(),
          ),
        ),
      ],
    );
  }
}

var _fetchLocked = Set<Object>();

Future<Image> fetchAndUpdateImage(
    [Object lockObject, String url = 'https://picsum.photos/300/200']) async {
  if (_fetchLocked.contains(lockObject)) {
    return null;
  }
  try {
    _fetchLocked.add(lockObject); // locks the fetching function
    final response = await http.get(url);
    final image = Image.memory(
      response.bodyBytes,
      fit: BoxFit.cover,
    );
    print('Fetched image');
    return image;
  } finally {
    _fetchLocked.remove(lockObject);
  }
}

class RandomImage extends DynamicWidget {
  RandomImage();

  initDyn() async {
    image = await fetchAndUpdateImage(dyn);
  }

  Widget get image => dyn[#image];
  set image(Widget widget) => dyn[#image] = widget;

  @override
  Widget build(BuildContext context) {
    return MultiGestureDetector(
      child: Opacity(opacity: transition(3000), child: image),
      onTap: () async {
        if ((image = await fetchAndUpdateImage(dyn)) != null) {
          Transitions.restart(context: context);
        }
      },
    );
  }
}

Color randomColor() {
  const blend = 0xFA000000;
  return Color(Random().nextInt(1 << 32) | blend);
}

class GestureDetector extends StatelessWidget {
  GestureDetector({
    Key key,
    this.child,
    this.onTapDown,
    this.onTapUp,
    this.onTap,
    this.onTapCancel,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onSecondaryTapCancel,
    this.onDoubleTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressUp,
    this.onLongPressEnd,
    this.onVerticalDragDown,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onHorizontalDragDown,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
    this.onForcePressStart,
    this.onForcePressPeak,
    this.onForcePressUpdate,
    this.onForcePressEnd,
    this.onPanDown,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.behavior,
    this.excludeFromSemantics = false,
    this.dragStartBehavior = DragStartBehavior.start,
  })  : assert(excludeFromSemantics != null),
        assert(dragStartBehavior != null),
        assert(() {
          final bool haveVerticalDrag = onVerticalDragStart != null ||
              onVerticalDragUpdate != null ||
              onVerticalDragEnd != null;
          final bool haveHorizontalDrag = onHorizontalDragStart != null ||
              onHorizontalDragUpdate != null ||
              onHorizontalDragEnd != null;
          final bool havePan =
              onPanStart != null || onPanUpdate != null || onPanEnd != null;
          final bool haveScale = onScaleStart != null ||
              onScaleUpdate != null ||
              onScaleEnd != null;
          if (havePan || haveScale) {
            if (havePan && haveScale) {
              throw FlutterError.fromParts(<DiagnosticsNode>[
                ErrorSummary('Incorrect GestureDetector arguments.'),
                ErrorDescription(
                    'Having both a pan gesture recognizer and a scale gesture recognizer is redundant; scale is a superset of pan.'),
                ErrorHint('Just use the scale gesture recognizer.')
              ]);
            }
            final String recognizer = havePan ? 'pan' : 'scale';
            if (haveVerticalDrag && haveHorizontalDrag) {
              throw FlutterError.fromParts(<DiagnosticsNode>[
                ErrorSummary('Incorrect GestureDetector arguments.'),
                ErrorDescription(
                    'Simultaneously having a vertical drag gesture recognizer, a horizontal drag gesture recognizer, and a $recognizer gesture recognizer '
                    'will result in the $recognizer gesture recognizer being ignored, since the other two will catch all drags.')
              ]);
            }
          }
          return true;
        }()),
        super(key: key);

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.child}
  final Widget child;

  /// A pointer that might cause a tap with a primary button has contacted the
  /// screen at a particular location.
  ///
  /// This is called after a short timeout, even if the winning gesture has not
  /// yet been selected. If the tap gesture wins, [onTapUp] will be called,
  /// otherwise [onTapCancel] will be called.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureTapDownCallback onTapDown;

  /// A pointer that will trigger a tap with a primary button has stopped
  /// contacting the screen at a particular location.
  ///
  /// This triggers immediately before [onTap] in the case of the tap gesture
  /// winning. If the tap gesture did not win, [onTapCancel] is called instead.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureTapUpCallback onTapUp;

  /// A tap with a primary button has occurred.
  ///
  /// This triggers when the tap gesture wins. If the tap gesture did not win,
  /// [onTapCancel] is called instead.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [onTapUp], which is called at the same time but includes details
  ///    regarding the pointer position.
  final GestureTapCallback onTap;

  /// The pointer that previously triggered [onTapDown] will not end up causing
  /// a tap.
  ///
  /// This is called after [onTapDown], and instead of [onTapUp] and [onTap], if
  /// the tap gesture did not win.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureTapCancelCallback onTapCancel;

  /// A pointer that might cause a tap with a secondary button has contacted the
  /// screen at a particular location.
  ///
  /// This is called after a short timeout, even if the winning gesture has not
  /// yet been selected. If the tap gesture wins, [onSecondaryTapUp] will be
  /// called, otherwise [onSecondaryTapCancel] will be called.
  ///
  /// See also:
  ///
  ///  * [kSecondaryButton], the button this callback responds to.
  final GestureTapDownCallback onSecondaryTapDown;

  /// A pointer that will trigger a tap with a secondary button has stopped
  /// contacting the screen at a particular location.
  ///
  /// This triggers in the case of the tap gesture winning. If the tap gesture
  /// did not win, [onSecondaryTapCancel] is called instead.
  ///
  /// See also:
  ///
  ///  * [kSecondaryButton], the button this callback responds to.
  final GestureTapUpCallback onSecondaryTapUp;

  /// The pointer that previously triggered [onSecondaryTapDown] will not end up
  /// causing a tap.
  ///
  /// This is called after [onSecondaryTapDown], and instead of
  /// [onSecondaryTapUp], if the tap gesture did not win.
  ///
  /// See also:
  ///
  ///  * [kSecondaryButton], the button this callback responds to.
  final GestureTapCancelCallback onSecondaryTapCancel;

  /// The user has tapped the screen with a primary button at the same location
  /// twice in quick succession.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureTapCallback onDoubleTap;

  /// Called when a long press gesture with a primary button has been recognized.
  ///
  /// Triggered when a pointer has remained in contact with the screen at the
  /// same location for a long period of time.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [onLongPressStart], which has the same timing but has gesture details.
  final GestureLongPressCallback onLongPress;

  /// Called when a long press gesture with a primary button has been recognized.
  ///
  /// Triggered when a pointer has remained in contact with the screen at the
  /// same location for a long period of time.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [onLongPress], which has the same timing but without the gesture details.
  final GestureLongPressStartCallback onLongPressStart;

  /// A pointer has been drag-moved after a long press with a primary button.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;

  /// A pointer that has triggered a long-press with a primary button has
  /// stopped contacting the screen.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [onLongPressEnd], which has the same timing but has gesture details.
  final GestureLongPressUpCallback onLongPressUp;

  /// A pointer that has triggered a long-press with a primary button has
  /// stopped contacting the screen.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  ///  * [onLongPressUp], which has the same timing but without the gesture
  ///    details.
  final GestureLongPressEndCallback onLongPressEnd;

  /// A pointer has contacted the screen with a primary button and might begin
  /// to move vertically.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragDownCallback onVerticalDragDown;

  /// A pointer has contacted the screen with a primary button and has begun to
  /// move vertically.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragStartCallback onVerticalDragStart;

  /// A pointer that is in contact with the screen with a primary button and
  /// moving vertically has moved in the vertical direction.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragUpdateCallback onVerticalDragUpdate;

  /// A pointer that was previously in contact with the screen with a primary
  /// button and moving vertically is no longer in contact with the screen and
  /// was moving at a specific velocity when it stopped contacting the screen.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragEndCallback onVerticalDragEnd;

  /// The pointer that previously triggered [onVerticalDragDown] did not
  /// complete.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragCancelCallback onVerticalDragCancel;

  /// A pointer has contacted the screen with a primary button and might begin
  /// to move horizontally.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragDownCallback onHorizontalDragDown;

  /// A pointer has contacted the screen with a primary button and has begun to
  /// move horizontally.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragStartCallback onHorizontalDragStart;

  /// A pointer that is in contact with the screen with a primary button and
  /// moving horizontally has moved in the horizontal direction.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragUpdateCallback onHorizontalDragUpdate;

  /// A pointer that was previously in contact with the screen with a primary
  /// button and moving horizontally is no longer in contact with the screen and
  /// was moving at a specific velocity when it stopped contacting the screen.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragEndCallback onHorizontalDragEnd;

  /// The pointer that previously triggered [onHorizontalDragDown] did not
  /// complete.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragCancelCallback onHorizontalDragCancel;

  /// A pointer has contacted the screen with a primary button and might begin
  /// to move.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragDownCallback onPanDown;

  /// A pointer has contacted the screen with a primary button and has begun to
  /// move.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragStartCallback onPanStart;

  /// A pointer that is in contact with the screen with a primary button and
  /// moving has moved again.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragUpdateCallback onPanUpdate;

  /// A pointer that was previously in contact with the screen with a primary
  /// button and moving is no longer in contact with the screen and was moving
  /// at a specific velocity when it stopped contacting the screen.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragEndCallback onPanEnd;

  /// The pointer that previously triggered [onPanDown] did not complete.
  ///
  /// See also:
  ///
  ///  * [kPrimaryButton], the button this callback responds to.
  final GestureDragCancelCallback onPanCancel;

  /// The pointers in contact with the screen have established a focal point and
  /// initial scale of 1.0.
  final GestureScaleStartCallback onScaleStart;

  /// The pointers in contact with the screen have indicated a new focal point
  /// and/or scale.
  final GestureScaleUpdateCallback onScaleUpdate;

  /// The pointers are no longer in contact with the screen.
  final GestureScaleEndCallback onScaleEnd;

  /// The pointer is in contact with the screen and has pressed with sufficient
  /// force to initiate a force press. The amount of force is at least
  /// [ForcePressGestureRecognizer.startPressure].
  ///
  /// Note that this callback will only be fired on devices with pressure
  /// detecting screens.
  final GestureForcePressStartCallback onForcePressStart;

  /// The pointer is in contact with the screen and has pressed with the maximum
  /// force. The amount of force is at least
  /// [ForcePressGestureRecognizer.peakPressure].
  ///
  /// Note that this callback will only be fired on devices with pressure
  /// detecting screens.
  final GestureForcePressPeakCallback onForcePressPeak;

  /// A pointer is in contact with the screen, has previously passed the
  /// [ForcePressGestureRecognizer.startPressure] and is either moving on the
  /// plane of the screen, pressing the screen with varying forces or both
  /// simultaneously.
  ///
  /// Note that this callback will only be fired on devices with pressure
  /// detecting screens.
  final GestureForcePressUpdateCallback onForcePressUpdate;

  /// The pointer is no longer in contact with the screen.
  ///
  /// Note that this callback will only be fired on devices with pressure
  /// detecting screens.
  final GestureForcePressEndCallback onForcePressEnd;

  /// How this gesture detector should behave during hit testing.
  ///
  /// This defaults to [HitTestBehavior.deferToChild] if [child] is not null and
  /// [HitTestBehavior.translucent] if child is null.
  final HitTestBehavior behavior;

  /// Whether to exclude these gestures from the semantics tree. For
  /// example, the long-press gesture for showing a tooltip is
  /// excluded because the tooltip itself is included in the semantics
  /// tree directly and so having a gesture to show it would result in
  /// duplication of information.
  final bool excludeFromSemantics;

  /// Determines the way that drag start behavior is handled.
  ///
  /// If set to [DragStartBehavior.start], gesture drag behavior will
  /// begin upon the detection of a drag gesture. If set to
  /// [DragStartBehavior.down] it will begin when a down event is first detected.
  ///
  /// In general, setting this to [DragStartBehavior.start] will make drag
  /// animation smoother and setting it to [DragStartBehavior.down] will make
  /// drag behavior feel slightly more reactive.
  ///
  /// By default, the drag start behavior is [DragStartBehavior.start].
  ///
  /// Only the [onStart] callbacks for the [VerticalDragGestureRecognizer],
  /// [HorizontalDragGestureRecognizer] and [PanGestureRecognizer] are affected
  /// by this setting.
  ///
  /// See also:
  ///
  ///  * [DragGestureRecognizer.dragStartBehavior], which gives an example for the different behaviors.
  final DragStartBehavior dragStartBehavior;

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures =
        <Type, GestureRecognizerFactory>{};

    if (onTapDown != null ||
        onTapUp != null ||
        onTap != null ||
        onTapCancel != null ||
        onSecondaryTapDown != null ||
        onSecondaryTapUp != null ||
        onSecondaryTapCancel != null) {
      gestures[AllowMultipleGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<AllowMultipleGestureRecognizer>(
        () => AllowMultipleGestureRecognizer(debugOwner: this),
        (TapGestureRecognizer instance) {
          instance
            ..onTapDown = onTapDown
            ..onTapUp = onTapUp
            ..onTap = onTap
            ..onTapCancel = onTapCancel
            ..onSecondaryTapDown = onSecondaryTapDown
            ..onSecondaryTapUp = onSecondaryTapUp
            ..onSecondaryTapCancel = onSecondaryTapCancel;
        },
      );
    }

    if (onDoubleTap != null) {
      gestures[DoubleTapGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
        () => DoubleTapGestureRecognizer(debugOwner: this),
        (DoubleTapGestureRecognizer instance) {
          instance..onDoubleTap = onDoubleTap;
        },
      );
    }

    if (onLongPress != null ||
        onLongPressUp != null ||
        onLongPressStart != null ||
        onLongPressMoveUpdate != null ||
        onLongPressEnd != null) {
      gestures[LongPressGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
        () => LongPressGestureRecognizer(debugOwner: this),
        (LongPressGestureRecognizer instance) {
          instance
            ..onLongPress = onLongPress
            ..onLongPressStart = onLongPressStart
            ..onLongPressMoveUpdate = onLongPressMoveUpdate
            ..onLongPressEnd = onLongPressEnd
            ..onLongPressUp = onLongPressUp;
        },
      );
    }

    if (onVerticalDragDown != null ||
        onVerticalDragStart != null ||
        onVerticalDragUpdate != null ||
        onVerticalDragEnd != null ||
        onVerticalDragCancel != null) {
      gestures[VerticalDragGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
        () => VerticalDragGestureRecognizer(debugOwner: this),
        (VerticalDragGestureRecognizer instance) {
          instance
            ..onDown = onVerticalDragDown
            ..onStart = onVerticalDragStart
            ..onUpdate = onVerticalDragUpdate
            ..onEnd = onVerticalDragEnd
            ..onCancel = onVerticalDragCancel
            ..dragStartBehavior = dragStartBehavior;
        },
      );
    }

    if (onHorizontalDragDown != null ||
        onHorizontalDragStart != null ||
        onHorizontalDragUpdate != null ||
        onHorizontalDragEnd != null ||
        onHorizontalDragCancel != null) {
      gestures[HorizontalDragGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
        () => HorizontalDragGestureRecognizer(debugOwner: this),
        (HorizontalDragGestureRecognizer instance) {
          instance
            ..onDown = onHorizontalDragDown
            ..onStart = onHorizontalDragStart
            ..onUpdate = onHorizontalDragUpdate
            ..onEnd = onHorizontalDragEnd
            ..onCancel = onHorizontalDragCancel
            ..dragStartBehavior = dragStartBehavior;
        },
      );
    }

    if (onPanDown != null ||
        onPanStart != null ||
        onPanUpdate != null ||
        onPanEnd != null ||
        onPanCancel != null) {
      gestures[PanGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
        () => PanGestureRecognizer(debugOwner: this),
        (PanGestureRecognizer instance) {
          instance
            ..onDown = onPanDown
            ..onStart = onPanStart
            ..onUpdate = onPanUpdate
            ..onEnd = onPanEnd
            ..onCancel = onPanCancel
            ..dragStartBehavior = dragStartBehavior;
        },
      );
    }

    if (onScaleStart != null || onScaleUpdate != null || onScaleEnd != null) {
      gestures[ScaleGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
        () => ScaleGestureRecognizer(debugOwner: this),
        (ScaleGestureRecognizer instance) {
          instance
            ..onStart = onScaleStart
            ..onUpdate = onScaleUpdate
            ..onEnd = onScaleEnd;
        },
      );
    }

    if (onForcePressStart != null ||
        onForcePressPeak != null ||
        onForcePressUpdate != null ||
        onForcePressEnd != null) {
      gestures[ForcePressGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<ForcePressGestureRecognizer>(
        () => ForcePressGestureRecognizer(debugOwner: this),
        (ForcePressGestureRecognizer instance) {
          instance
            ..onStart = onForcePressStart
            ..onPeak = onForcePressPeak
            ..onUpdate = onForcePressUpdate
            ..onEnd = onForcePressEnd;
        },
      );
    }

    return RawGestureDetector(
      gestures: gestures,
      behavior: behavior,
      excludeFromSemantics: excludeFromSemantics,
      child: child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        EnumProperty<DragStartBehavior>('startBehavior', dragStartBehavior));
  }
}

class MultiGestureDetector extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  MultiGestureDetector({this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      child: child,
      gestures: {
        AllowMultipleGestureRecognizer: GestureRecognizerFactoryWithHandlers<
            AllowMultipleGestureRecognizer>(
          () => AllowMultipleGestureRecognizer(),
          (AllowMultipleGestureRecognizer instance) {
            instance.onTap = onTap;
          },
        )
      },
    );
  }
}

class AllowMultipleGestureRecognizer extends TapGestureRecognizer {
  AllowMultipleGestureRecognizer({Object debugOwner})
      : super(debugOwner: debugOwner);

  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}

class MultiGestureRecognizer extends GestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }

  @override
  void acceptGesture(int pointer) {
    // TODO: implement acceptGesture
  }

  @override
  // TODO: implement debugDescription
  String get debugDescription => 'Custom gesture recognizer';
}
