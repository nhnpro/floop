import 'dart:math';
import 'dart:typed_data';

import 'package:floop/floop.dart';
import 'package:floop/transition.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const colorTag = 'colorTag';
const rotationTag = 'rotationTag';
const imageTag = 'imageTag';
const spiralTag = 'spiralTag';

const transientTag = 'transientTransitionsTag';

const imageHeight = 200.0;
const imageWidth = 300.0;

class Dyn {
  static final dyn = ObservedMap();

  static SpiralingWidget get dragStartWidget => dyn[#dragStartWidget];
  static set dragStartWidget(SpiralingWidget widget) =>
      dyn[#dragStartWidget] = widget;

  static List<Widget> get spiralingWidgets =>
      (dyn[#spiralImages] ??= List<Widget>()).cast<Widget>();
  static set spiralingWidgets(List<Widget> updatedList) =>
      dyn[#spiralImages] = updatedList;

  static String get activeTag => dyn[#activeTag];
  static set activeTag(String tag) => dyn[#activeTag] = tag;

  static bool get optionsBarPaused => dyn[#optionsBarPaused] ??= false;
  static set optionsBarPaused(bool paused) => dyn[#optionsBarPaused] = paused;

  static SizeInteraction get expanding => dyn[#expandingKey];
  static set expanding(SizeInteraction key) => dyn[#expandingKey] = key;

  static Offset get dragPosition => dyn[#dragPosition];
  static set dragPosition(Offset position) => dyn[#dragPosition] = position;
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

const tagsMap = {
  colorTag: 'Color',
  imageTag: 'Image',
  spiralTag: 'Spiral',
  rotationTag: 'Rotation',
};

nextTag() {
  final active = Dyn.activeTag;
  final tagsList = tagsMap.keys.toList();
  final index = tagsList.indexOf(active) + 1;
  var tag;
  if (index < tagsList.length) {
    tag = tagsList[index];
  }
  Dyn.activeTag = tag;
}

tagAsName([tag]) {
  return tagsMap[tag ?? Dyn.activeTag] ?? 'All';
}

class Spiral extends StatelessWidget with Floop {
  @override
  void initContext(BuildContext context) {
    Dyn.spiralingWidgets ??= List();
  }

  String get targetTransitions => tagAsName();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: ListTile(
          title: Text(
            'Playback tageting: ${targetTransitions} transitions',
            style: Theme.of(context).primaryTextTheme.body1,
          ),
          onTap: nextTag,
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
                onTap: () => {
                      if (Dyn.expanding != null)
                        {
                          Dyn.expanding.contract(),
                        }
                      // Transitions.cancel(tag: transientTag),
                      // print('cancel $transientTag'),
                    }),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: Text(
                'Target refresh rate: ${(1000 ~/ TransitionsConfig.refreshPeriodicityMillis)}'),
          ),
          ...Dyn.spiralingWidgets,
          Align(
              alignment: Alignment.topRight,
              child: Text(
                  'Refresh rate: ${Transitions.currentRefreshRateAsDynamicValue()?.toStringAsFixed(2)}')),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              alignment: Alignment.centerLeft,
              width: 155,
              height: 60,
              padding: EdgeInsets.only(top: 10, bottom: 10, right: 10),
              child: SizedBox.expand(
                child: RaisedButton(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  elevation: 5.0,
                  color: theme.buttonColor,
                  // visualDensity: VisualDensity.standard,
                  // color: Colors.lightGreen[300],
                  child: Text(
                    '${targetTransitions}',
                    // style: theme.primaryTextTheme.caption,
                    // style: TextStyle(
                    // backgroundColor: Colors.lightGreen,
                    // color: Colors.red,
                    // fontSize: 100,
                    // ),
                  ),
                  onPressed: () => nextTag(),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(
          Icons.add,
        ),
        onPressed: spawnSpiralingWidget,
      ),
      bottomNavigationBar: PlaybackOptions(),
    );
  }
}

int _totalSpawned = 0;

void spawnSpiralingWidget() {
  var widgets = Dyn.spiralingWidgets.toList();
  widgets.add(
      SpiralingWidget(key: ValueKey(_totalSpawned++), child: ImageCircle()));
  Dyn.spiralingWidgets = widgets;
}

void removeSpiralingWidget(Key key) {
  var widgets = Dyn.spiralingWidgets.toList()
    ..removeWhere((widget) => widget.key == key);
  Dyn.spiralingWidgets = widgets;
}

void putWidgetOnTop(Key key) {
  Widget targetWidget;
  var widgets = Dyn.spiralingWidgets.toList();
  widgets.removeWhere((widget) {
    if (widget.key == key) {
      targetWidget = widget;
      return true;
    }
    return false;
  });
  widgets.add(targetWidget);
  Dyn.spiralingWidgets = widgets;
}

Alignment positionToAlignment(Offset offset, Size size) {
  var alignment = Alignment.topLeft +
      Alignment(offset.dx / size.width, offset.dy / size.height) * 2;
  print('$alignment');
  return alignment;
}

class SpiralingWidget extends StatelessWidget with Floop {
  static const minSize = 10.0;
  static const growSize = 100.0;

  static const largeSize = Size(imageWidth, imageHeight);

  static Size referenceSize = Size(0, 0);

  final Widget child;
  SpiralingWidget({Key key, @required this.child}) : super(key: key);

  // A key to use in a transition.
  String get tKey => '$SpiralingWidget$key';

  @override
  Widget build(BuildContext context) {
    // The spiral animation transition.
    var t = transition(20000, repeatAfterMillis: 3000, tag: spiralTag);
    final spiralAlignment = computeSpiralAlignment(t);
    final restorePositionProgress = transitionOf(tKey);
    Alignment alignment;
    if (Dyn.dragStartWidget?.tKey == tKey) {
      alignment = positionToAlignment(Dyn.dragPosition, referenceSize);
    } else if (restorePositionProgress != null) {
      // print('restoring position $restorePositionProgress');
      alignment = positionToAlignment(Dyn.dragPosition, referenceSize);
      alignment =
          Alignment.lerp(alignment, spiralAlignment, restorePositionProgress);
    } else {
      alignment = spiralAlignment;
    }
    // alignment = spiralAlignment;
    final size = minSize + t * growSize;
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: GestureDetector(
          // child: ImageCircle(t),
          child: SizeInteraction(
            key: key,
            child: child,
            normalSize: Size(size, size),
            extraSize: largeSize - Size(size, size),
          ),
          onDoubleTap: () => {
            Transitions.resumeOrPause(
                context: context, applyToChildContextsTransitions: true),
          },
          onTap: () => {
            putWidgetOnTop(key),
          },
          // onLongPress: () => removeSpiralingWidget(key),
          onLongPressUp: () {
            // Transitions.cancel(key: dyn);
          },
          onPanDown: (details) {
            Transitions.cancel(key: tKey);
            // Dyn.dragStartWidget = this;
            // print('Pan down: ');
            referenceSize = context.size;
            var position = spiralAlignment.alongSize(referenceSize);
            Dyn.dragPosition =
                // spiralAlignment.alongSize(Offset.zero & context.size);
                spiralAlignment.alongSize(referenceSize);
            print('start alignment: $spiralAlignment');
            Dyn.dragPosition = details.localPosition;
            // Dyn.dragPosition = position;
          },
          onPanCancel: () {
            // print('Pan cancel');
            // Dyn.dragPosition = null;
          },
          onPanUpdate: (details) {
            if (Dyn.dragPosition == null) {
              print('Null drag position');
              return;
            }
            Dyn.dragStartWidget = this;
            // Keep updating referenceSize in case the app changes it's layout.
            referenceSize = context.size;
            Dyn.dragPosition += details.delta;
            // print('${Dyn.dragPosition}');
          },
          onPanEnd: (_) {
            Dyn.dragStartWidget = null;
            // Transition without context is deleted when it finishes.
            transition(3000, key: tKey);
            // .(size, rect).
            // Transitions.cancel(key: tKey);
          },
        ),
      ),
    );
  }
}

class SizeInteraction extends StatelessWidget with Floop {
  final Widget child;
  final Size normalSize;
  final Offset extraSize;
  const SizeInteraction(
      {@required key,
      this.child,
      @required this.normalSize,
      @required this.extraSize})
      : super(key: key);

  // double get lerpValue {
  //   var t = transitionOf(tKey);
  //   if (t != null && Dyn.expanding == null) {
  //     // If expandingKey is null, the widget should shrink.
  //     // t = 1 - t;
  //   }
  //   return t ?? 0;
  // }

  double get lerpValue => transitionOf(tKey) ?? 0.0;

  // A key to use in a transition.
  String get tKey => '$SizeInteraction$key';

  Size get size => normalSize + extraSize * lerpValue;

  expand(BuildContext context) {
    // The transition needs to be identied with a key such that it can be
    // referenced from within the build method.
    //
    // The transition is bound to the context to prevent it from being deleted
    // when it finishes. This way the widget remains large.
    transition(700, key: tKey, bindContext: context, tag: transientTag);
    Dyn.expanding = this;
  }

  contract() {
    final lastExpandingLerpValue = transitionOf(tKey) ?? 0;
    // Cancel deletes the transition. At most one transition can be
    // registered with a certain key at any given time.
    Transitions.cancel(key: tKey);
    // Context is not provided so that the transition is deleted when
    // it finishes.
    transitionEval(400, (r) => (1 - r) * lastExpandingLerpValue, key: tKey);
    // transition(500, key: tKey);
    // null expandingKey is used to represent a shrinking transition.
    Dyn.expanding = null;
  }

  @override
  Widget build(BuildContext context) {
    // final t = lerpValue;
    final size = this.size;
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration.lerp(
          BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(size.shortestSide),
          ),
          BoxDecoration(
            shape: BoxShape.rectangle,
          ),
          lerpValue),
      clipBehavior: Clip.antiAlias,
      child: DefererGestureDetector(
        child: child,
        onTap: () {
          var expanding = Dyn.expanding;
          if (expanding == null) {
            expand(context);
          } else if (expanding.tKey == tKey) {
            contract();
          } else {
            expanding.contract();
            expand(context);
          }
        },
        // onLongPress: () {
        //   // The transition needs to be identied with a key such that it can be
        //   // referenced from within the build method.
        //   //
        //   // The context parameter is passed to bind the transition to the
        //   // context. Transitions without context are deleted when they finish.
        //   // Dyn.expanding = key;
        //   transition(700, key: tKey, bindContext: context, tag: transientTag);
        //   Dyn.expanding = tKey;
        // },
        // onLongPressUp: () {
        //   final lastExpandingLerpValue = transitionOf(tKey);
        //   // print('Last value $lastValue');
        //   // Cancel deletes the transition. At most one transition can be
        //   // registered with a certain key at any given time.
        //   Transitions.cancel(key: tKey);
        //   // Context is not provided so that the transition is deleted when
        //   // it finishes.
        //   transitionEval(400, (r) => (1 - r) * lastExpandingLerpValue,
        //       key: tKey);
        //   // transition(500, key: tKey);
        //   // null expandingKey is used to represent a shrinking transition.
        //   Dyn.expanding = null;
        // },
      ),
      // onDoubleTap: () {
      //   // Because the transition is created by a callback outside of the
      //   // build method, the transition needs to be identied with a key
      //   // so that it can be referenced.
      //   if(transitionOf(key)!=null) {
      //     Transitions.cancel(key: key);
      //     transition(250, key: key);
      //   } else {
      //     // The context parameter is pased so that the transition is not
      //     // deleted after it finishes.
      //     Dyn.expandingKey = key;
      //     transition(700, key: key, context: context);
      //   }
      // },

      // DefererGestureDetector(

      //   child: Container(
      //     child: child,
      //     alignment: Alignment.center,
      //     height: size,
      //     width: size,
      //   ),
      //   onTap: () => {
      //     Transitions.resumeOrPause(context: context),
      //   },
      //   onDoubleTap: () {
      //     if (transitionOf(key) != null) {
      //       Transitions.cancel(key: key);
      //     } else {
      //       // Because the transition is created by a callback outside of the
      //       // build method, the transition needs to be identied with a key
      //       // such that it can be referenced from within the build method.
      //       Dyn.expandingKey = key;
      //       print('Long press detected on $context');
      //       transition(2000, key: key, context: context);
      //     }
      //   },
      //   onLongPress: () {},
      //   onLongPressUp: () {
      //     // Transitions.cancel(key: dyn);
      //   },
      // ),
    );
  }
}

// class DragAndReturn extends DynamicWidget {
//   final Widget child;

//   DragAndReturn(this.child);

//   Offset get position => dyn[#position];
//   set position(Offset position) => dyn[#position];

//   @override
//   Widget build(BuildContext context) {
//     return Positioned(

//         child: GestureDetector(
//       onPanStart: (DragStartDetails dragStartDetails) {
//         // Transitions.clear(context: context);
//         position = dragStartDetails.localPosition;
//         // Transitions.cancel(key: circle.backKey);
//         // circle.targetPosition = circle.position;
//         // placeCircleLast(name);
//         // Transitions.pause(key: goBackKey);
//       },
//       onPanUpdate: (drag) {
//         // Transitions.pause(key: name + 'back');
//         position += drag.delta;
//       },
//       onPanEnd: (_) {

//       },
//     ));
//   }
// }

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
  // final double diameter;

  // ImageCircle(double scale) : diameter = 10 + 90 * scale;
  initDyn() {
    dyn[#baseColor] ??= randomColor();
    dyn[#color] ??= randomColor();
  }

  Color get baseColor => dyn[#baseColor] ??= randomColor();
  set baseColor(Color color) => dyn[#baseColor] = color;

  Color get color => dyn[#color] ??= randomColor();
  set color(Color color) => dyn[#color] = color;

  Widget get image => dyn[#image];
  set image(Widget widget) => dyn[#image] = widget;

  Color get transitionedColor {
    // The `dyn` member remains the same on rebuilds of DynamicWidget, it's ok
    // to use it as a key.
    //
    // Because the transition repeats, an oscillator is used make the value
    // continous.
    final t = sin(2 *
        pi *
        (transition(5000, repeatAfterMillis: 0, key: dyn, tag: colorTag)));
    return Color.lerp(baseColor, color, t);
  }

  @override
  Widget build(BuildContext context) {
    return DefererGestureDetector(
        child: Container(
          // alignment: Alignment.center,
          // // padding: EdgeInsets.all(5),
          // height: diameter,
          // width: diameter,
          color: transitionedColor,
          // decoration: BoxDecoration.lerp(
          //     BoxDecoration(
          //       shape: BoxShape.rectangle,
          //       borderRadius: BorderRadius.circular(100),
          //       color: baseColor,
          //     ),
          //     BoxDecoration(
          //       shape: BoxShape.rectangle,
          //       color: color,
          //     ),
          //     transition(5000, repeatAfterMillis: 0, key: dyn, tag: colorTag)),
          // transition(3000, repeatAfterMillis: 2000, tag: colorTag)),
          //  BoxDecoration(
          //   shape: BoxShape.circle,
          //   color: transitionedColor(),
          // ),
          // clipBehavior: Clip.antiAlias,
          // child: SizedBox.expand(
          child: RandomImage(),
          // ),
        ),
        onTap: () {
          baseColor = transitionedColor;
          color = randomColor();
          Transitions.reset(context: context);
        });
  }
}

Alignment computeSpiralAlignment(double t) {
  var a = 0.1; // a constant
  var b = 0.1; // another constant
  var h = 0.01 * b / (a * sqrt(1 + b * b));
  var theta = 0.0;
  for (int i = 0; i < 1000 * t; i++) {
    theta = log(h + exp(b * theta)) / b;
  }
  var pX = a * cos(theta) * exp(b * theta);
  var pY = a * sin(theta) * exp(b * theta);
  // print('Position for $t: x is $pX, y is $pY ');
  return Alignment(pX.clamp(-1.0, 1.0), pY.clamp(-1.0, 1.0));
}

class PlaybackOptions extends FloopWidget {
  Widget get titleWidget => Text('${tagAsName() ?? 'All'}');

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      iconSize: 26,
      type: BottomNavigationBarType.fixed,
      items: [
        BottomNavigationBarItem(
          title: titleWidget,
          icon: IconButton(
              icon: Icon(
                Dyn.optionsBarPaused ? Icons.play_arrow : Icons.pause,
              ),
              iconSize: 32,
              onPressed: () {
                if (Dyn.optionsBarPaused) {
                  Transitions.resume(tag: Dyn.activeTag);
                  Dyn.optionsBarPaused = false;
                } else {
                  Transitions.pause(tag: Dyn.activeTag);
                  Dyn.optionsBarPaused = true;
                }
              }),
        ),
        BottomNavigationBarItem(
          title: titleWidget,
          icon: GestureDetector(
            child: Icon(Icons.fast_rewind,
                color: true ? Colors.red : Colors.indigoAccent),
            onTap: () =>
                Transitions.shiftTime(shiftMillis: -1000, tag: Dyn.activeTag),
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
          title: titleWidget,
          icon: GestureDetector(
            child: Icon(
              Icons.fast_forward,
              color: true ? Colors.red : Colors.indigoAccent,
            ),
            onTap: () =>
                Transitions.shiftTime(shiftMillis: 1000, tag: Dyn.activeTag),
          ),
        ),
        BottomNavigationBarItem(
          title: titleWidget,
          icon: IconButton(
            icon: Icon(Icons.refresh),
            iconSize: 32,
            onPressed: () => Transitions.reset(tag: Dyn.activeTag),
          ),
        ),
      ],
    );
  }
}

var _fetchLocked = Set<Object>();

Future<Uint8List> fetchAndUpdateImage(
    [Object lockObject, String url = 'https://picsum.photos/300/200']) async {
  if (_fetchLocked.contains(lockObject)) {
    return null;
  }
  try {
    _fetchLocked.add(lockObject); // locks the fetching function
    final response = await http.get(url);
    // final image = Image.memory(
    //   response.bodyBytes,
    //   fit: BoxFit.cover,
    // );
    print('Fetched image');
    return response.bodyBytes;
  } catch (e) {
    return null;
  } finally {
    _fetchLocked.remove(lockObject);
  }
}

final emptyBytes = Uint8List.fromList([]);

class RandomImage extends DynamicWidget {
  RandomImage();

  initDyn() async {
    // imageBytes = emptyBytes;
    lastFetchedImageBytes = await fetchAndUpdateImage(dyn);
    fetchAndLoadImage();
  }

  loadImage() {
    image = Image.memory(
      lastFetchedImageBytes,
      fit: BoxFit.cover,
    );
  }

  Widget get image => dyn[#image];
  set image(Widget widget) => dyn[#image] = widget;

  // Uint8List get imageBytes => Uint8List.fromList(dyn[#imageBytes].cast<int>());
  Uint8List get lastFetchedImageBytes =>
      Uint8List.fromList(dyn[#imageBytes]?.cast<int>());
  set lastFetchedImageBytes(Uint8List bytes) => dyn[#imageBytes] = bytes;

  // Widget heroImage => Hero(
  //           child: image,
  //           tag: context,
  //         );
  fetchAndLoadImage() async {
    image = null;
    final imageBytes = await fetchAndUpdateImage(dyn);
    if (imageBytes != null) {
      lastFetchedImageBytes = imageBytes;
      loadImage();
    }
  }

  double get rotationAngle =>
      2 *
      pi *
      transition(1000,
          delayMillis: 5000, repeatAfterMillis: -2000, tag: rotationTag);

  @override
  Widget build(BuildContext context) {
    return DefererGestureDetector(
      child: image == null
          ? null
          : Opacity(
              opacity: transition(3000, tag: imageTag),
              child: Transform.rotate(
                child: image,
                angle: rotationAngle,
              )),
      onLongPress: () async {
        await fetchAndLoadImage();
        Transitions.reset(context: context);
      },
      // onDoubleTap: () {
      // Navigator.of(context).push(AlertDialog(
      //   content: GestureDetector(
      //       child: Image.memory(lastFetchedImageBytes),
      //       onTap: () {
      //         // Navigator.pop(context);
      //         Navigator.pop(context);
      //       });
      // }));
      // if (image != null) {
      // showDialog(
      //     context: context,
      //     builder: (context) {
      //       return GestureDetector(
      //           child: Hero(
      //             tag: dyn,
      //             child: Image.memory(
      //               lastFetchedImageBytes,
      //             ),
      //           ),
      //           onTap: () {
      //             Navigator.of(context).pop();
      //           });
      //     });
      // }
      // },
    );
  }
}

// class PopUpScreen extends StatelessWidget {
//   final Widget child;
//   PopUpScreen({this.child}): super();

//   @override
//   Widget build(BuildContext context) {
//     return
//   }

// }

Color randomColor() {
  const blend = 0xFA000000;
  return Color(Random().nextInt(1 << 32) | blend);
}

// const gestureToRecognizer = {
//   Gesture.onTap: TapGestureRecognizer,
//   Gesture.onDoubleTap: DoubleTapGestureRecognizer,
//   Gesture.onLongPress: LongPressGestureRecognizer,
//   Gesture.onLongPressUp: LongPressGestureRecognizer,
//   Gesture.onPanDown: PanGestureRecognizer,
//   Gesture.onPanEnd: PanGestureRecognizer,
// };

enum Gesture {
  onTap,
  onDoubleTap,
  onLongPress,
  onLongPressUp,
  onPanDown,
  onPanUpdate,
  onPanEnd,
}

typedef GestureCallback = void Function([dynamic]);

/// Gesture detector that propagates the gesture to ancestor gesture detectors.
class DefererGestureDetector extends GestureDetector {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;
  final VoidCallback onLongPressUp;
  final GestureCallback onPanDown;
  final GestureCallback onPanUpdate;
  final GestureCallback onPanEnd;
  DefererGestureDetector(
      {this.child,
      this.onTap,
      this.onDoubleTap,
      this.onLongPress,
      this.onLongPressUp,
      this.onPanDown,
      this.onPanUpdate,
      this.onPanEnd});

  static triggerGestureAction(GestureDetector gestureDetector, Gesture gesture,
      [details]) {
    // GestureDetector gestureDetector = context.widget;
    switch (gesture) {
      case Gesture.onTap:
        if (gestureDetector.onTap != null) {
          gestureDetector.onTap();
        }
        break;
      case Gesture.onDoubleTap:
        if (gestureDetector.onDoubleTap != null) {
          gestureDetector.onDoubleTap();
        }
        break;
      case Gesture.onLongPress:
        if (gestureDetector.onLongPress != null) {
          gestureDetector.onLongPress();
        }
        break;
      case Gesture.onLongPressUp:
        if (gestureDetector.onLongPressUp != null) {
          gestureDetector.onLongPressUp();
        }
        break;
      case Gesture.onPanDown:
        if (gestureDetector.onPanDown != null) {
          gestureDetector.onPanDown(details);
        }
        break;
      case Gesture.onPanUpdate:
        if (gestureDetector.onPanUpdate != null) {
          gestureDetector.onPanUpdate(details);
        }
        break;
      case Gesture.onPanEnd:
        if (gestureDetector.onPanEnd != null) {
          gestureDetector.onPanEnd(details);
        }
        break;
      default:
        break;
    }
  }

  static BuildContext triggeredBase;

  BuildContext findAncestorGestureDetectorContext(BuildContext context) {
    BuildContext ancestorGestureDetectorContext;
    context.visitAncestorElements((ancestor) {
      if (ancestor.widget is GestureDetector &&
          ancestor.widget is! DefererGestureDetector) {
        ancestorGestureDetectorContext = ancestor;
        return false;
      }
      // if (ancestorGestureDetectorContext != null) {
      //   // Stop if a regular GestureDetector was previously found.
      //   return false;
      // }
      // if (ancestor.widget is GestureDetector) {
      //   // Not stop yet, it could be wrapped by a DerererGestureDetector.
      //   ancestorGestureDetectorContext = ancestor;
      // }
      return true;
    });
    return ancestorGestureDetectorContext;
  }

  createGestureCallback(BuildContext context, Gesture gesture) {
    return ([actionDetails]) {
      triggerGestureAction(context.widget, gesture, actionDetails);
      var ancestorContext = findAncestorGestureDetectorContext(context);
      if (ancestorContext != null) {
        triggerGestureAction(ancestorContext.widget, gesture, actionDetails);
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: child,
      onTap: createGestureCallback(context, Gesture.onTap),
      onDoubleTap: createGestureCallback(context, Gesture.onDoubleTap),
      onLongPress: createGestureCallback(context, Gesture.onLongPress),
      onLongPressUp: createGestureCallback(context, Gesture.onLongPressUp),
      onPanDown: createGestureCallback(context, Gesture.onPanDown),
      onPanUpdate: createGestureCallback(context, Gesture.onPanUpdate),
      onPanEnd: createGestureCallback(context, Gesture.onPanEnd),
    );

    // onTap: onTap == null
    //     ? null
    //     : () {
    //         triggerAndPropageteGestureToParent(context, Gesture.onTap);
    //         onTap();
    //       },
    // onDoubleTap: onDoubleTap == null
    //     ? null
    //     : () {
    //         triggerAndPropageteGestureToParent(
    //             context, Gesture.onDoubleTap);
    //         onDoubleTap();
    //       },
    // onLongPress: onLongPress == null
    //     ? null
    //     : () {
    //         triggerAndPropageteGestureToParent(
    //             context, Gesture.onLongPress);
    //         onLongPress();
    //       },
    // onLongPressUp: onLongPressUp == null
    //     ? null
    //     : () {
    //         triggerAndPropageteGestureToParent(
    //             context, Gesture.onLongPressUp);
    //         onLongPressUp();
    //       },
    // onPanDown: onPanDown == null
    //     ? null
    //     : (dragDetails) {
    //         triggerAndPropageteGestureToParent(context, Gesture.onPanDown);
    //         onPanDown();
    //       },
    // onPanUpdate: onPanUpdate == null
    //     ? null
    //     : (dragDetails) {
    //         triggerAndPropageteGestureToParent(
    //             context, Gesture.onPanUpdate);
    //         onPanUpdate();
    //       },
    // onPanEnd: onPanEnd == null
    //     ? null
    //     : (dragDetails) {
    //         triggerAndPropageteGestureToParent(context, Gesture.onPanEnd);
    //         onPanEnd();
    //       });
  }
}

// class GestureDetector extends StatelessWidget {
//   GestureDetector({
//     Key key,
//     this.child,
//     this.onTapDown,
//     this.onTapUp,
//     this.onTap,
//     this.onTapCancel,
//     this.onSecondaryTapDown,
//     this.onSecondaryTapUp,
//     this.onSecondaryTapCancel,
//     this.onDoubleTap,
//     this.onLongPress,
//     this.onLongPressStart,
//     this.onLongPressMoveUpdate,
//     this.onLongPressUp,
//     this.onLongPressEnd,
//     this.onVerticalDragDown,
//     this.onVerticalDragStart,
//     this.onVerticalDragUpdate,
//     this.onVerticalDragEnd,
//     this.onVerticalDragCancel,
//     this.onHorizontalDragDown,
//     this.onHorizontalDragStart,
//     this.onHorizontalDragUpdate,
//     this.onHorizontalDragEnd,
//     this.onHorizontalDragCancel,
//     this.onForcePressStart,
//     this.onForcePressPeak,
//     this.onForcePressUpdate,
//     this.onForcePressEnd,
//     this.onPanDown,
//     this.onPanStart,
//     this.onPanUpdate,
//     this.onPanEnd,
//     this.onPanCancel,
//     this.onScaleStart,
//     this.onScaleUpdate,
//     this.onScaleEnd,
//     this.behavior,
//     this.excludeFromSemantics = false,
//     this.dragStartBehavior = DragStartBehavior.start,
//   })  : assert(excludeFromSemantics != null),
//         assert(dragStartBehavior != null),
//         assert(() {
//           final bool haveVerticalDrag = onVerticalDragStart != null ||
//               onVerticalDragUpdate != null ||
//               onVerticalDragEnd != null;
//           final bool haveHorizontalDrag = onHorizontalDragStart != null ||
//               onHorizontalDragUpdate != null ||
//               onHorizontalDragEnd != null;
//           final bool havePan =
//               onPanStart != null || onPanUpdate != null || onPanEnd != null;
//           final bool haveScale = onScaleStart != null ||
//               onScaleUpdate != null ||
//               onScaleEnd != null;
//           if (havePan || haveScale) {
//             if (havePan && haveScale) {
//               throw FlutterError.fromParts(<DiagnosticsNode>[
//                 ErrorSummary('Incorrect GestureDetector arguments.'),
//                 ErrorDescription(
//                     'Having both a pan gesture recognizer and a scale gesture recognizer is redundant; scale is a superset of pan.'),
//                 ErrorHint('Just use the scale gesture recognizer.')
//               ]);
//             }
//             final String recognizer = havePan ? 'pan' : 'scale';
//             if (haveVerticalDrag && haveHorizontalDrag) {
//               throw FlutterError.fromParts(<DiagnosticsNode>[
//                 ErrorSummary('Incorrect GestureDetector arguments.'),
//                 ErrorDescription(
//                     'Simultaneously having a vertical drag gesture recognizer, a horizontal drag gesture recognizer, and a $recognizer gesture recognizer '
//                     'will result in the $recognizer gesture recognizer being ignored, since the other two will catch all drags.')
//               ]);
//             }
//           }
//           return true;
//         }()),
//         super(key: key);

//   /// The widget below this widget in the tree.
//   ///
//   /// {@macro flutter.widgets.child}
//   final Widget child;

//   /// A pointer that might cause a tap with a primary button has contacted the
//   /// screen at a particular location.
//   ///
//   /// This is called after a short timeout, even if the winning gesture has not
//   /// yet been selected. If the tap gesture wins, [onTapUp] will be called,
//   /// otherwise [onTapCancel] will be called.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureTapDownCallback onTapDown;

//   /// A pointer that will trigger a tap with a primary button has stopped
//   /// contacting the screen at a particular location.
//   ///
//   /// This triggers immediately before [onTap] in the case of the tap gesture
//   /// winning. If the tap gesture did not win, [onTapCancel] is called instead.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureTapUpCallback onTapUp;

//   /// A tap with a primary button has occurred.
//   ///
//   /// This triggers when the tap gesture wins. If the tap gesture did not win,
//   /// [onTapCancel] is called instead.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   ///  * [onTapUp], which is called at the same time but includes details
//   ///    regarding the pointer position.
//   final GestureTapCallback onTap;

//   /// The pointer that previously triggered [onTapDown] will not end up causing
//   /// a tap.
//   ///
//   /// This is called after [onTapDown], and instead of [onTapUp] and [onTap], if
//   /// the tap gesture did not win.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureTapCancelCallback onTapCancel;

//   /// A pointer that might cause a tap with a secondary button has contacted the
//   /// screen at a particular location.
//   ///
//   /// This is called after a short timeout, even if the winning gesture has not
//   /// yet been selected. If the tap gesture wins, [onSecondaryTapUp] will be
//   /// called, otherwise [onSecondaryTapCancel] will be called.
//   ///
//   /// See also:
//   ///
//   ///  * [kSecondaryButton], the button this callback responds to.
//   final GestureTapDownCallback onSecondaryTapDown;

//   /// A pointer that will trigger a tap with a secondary button has stopped
//   /// contacting the screen at a particular location.
//   ///
//   /// This triggers in the case of the tap gesture winning. If the tap gesture
//   /// did not win, [onSecondaryTapCancel] is called instead.
//   ///
//   /// See also:
//   ///
//   ///  * [kSecondaryButton], the button this callback responds to.
//   final GestureTapUpCallback onSecondaryTapUp;

//   /// The pointer that previously triggered [onSecondaryTapDown] will not end up
//   /// causing a tap.
//   ///
//   /// This is called after [onSecondaryTapDown], and instead of
//   /// [onSecondaryTapUp], if the tap gesture did not win.
//   ///
//   /// See also:
//   ///
//   ///  * [kSecondaryButton], the button this callback responds to.
//   final GestureTapCancelCallback onSecondaryTapCancel;

//   /// The user has tapped the screen with a primary button at the same location
//   /// twice in quick succession.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureTapCallback onDoubleTap;

//   /// Called when a long press gesture with a primary button has been recognized.
//   ///
//   /// Triggered when a pointer has remained in contact with the screen at the
//   /// same location for a long period of time.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   ///  * [onLongPressStart], which has the same timing but has gesture details.
//   final GestureLongPressCallback onLongPress;

//   /// Called when a long press gesture with a primary button has been recognized.
//   ///
//   /// Triggered when a pointer has remained in contact with the screen at the
//   /// same location for a long period of time.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   ///  * [onLongPress], which has the same timing but without the gesture details.
//   final GestureLongPressStartCallback onLongPressStart;

//   /// A pointer has been drag-moved after a long press with a primary button.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureLongPressMoveUpdateCallback onLongPressMoveUpdate;

//   /// A pointer that has triggered a long-press with a primary button has
//   /// stopped contacting the screen.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   ///  * [onLongPressEnd], which has the same timing but has gesture details.
//   final GestureLongPressUpCallback onLongPressUp;

//   /// A pointer that has triggered a long-press with a primary button has
//   /// stopped contacting the screen.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   ///  * [onLongPressUp], which has the same timing but without the gesture
//   ///    details.
//   final GestureLongPressEndCallback onLongPressEnd;

//   /// A pointer has contacted the screen with a primary button and might begin
//   /// to move vertically.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragDownCallback onVerticalDragDown;

//   /// A pointer has contacted the screen with a primary button and has begun to
//   /// move vertically.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragStartCallback onVerticalDragStart;

//   /// A pointer that is in contact with the screen with a primary button and
//   /// moving vertically has moved in the vertical direction.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragUpdateCallback onVerticalDragUpdate;

//   /// A pointer that was previously in contact with the screen with a primary
//   /// button and moving vertically is no longer in contact with the screen and
//   /// was moving at a specific velocity when it stopped contacting the screen.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragEndCallback onVerticalDragEnd;

//   /// The pointer that previously triggered [onVerticalDragDown] did not
//   /// complete.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragCancelCallback onVerticalDragCancel;

//   /// A pointer has contacted the screen with a primary button and might begin
//   /// to move horizontally.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragDownCallback onHorizontalDragDown;

//   /// A pointer has contacted the screen with a primary button and has begun to
//   /// move horizontally.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragStartCallback onHorizontalDragStart;

//   /// A pointer that is in contact with the screen with a primary button and
//   /// moving horizontally has moved in the horizontal direction.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragUpdateCallback onHorizontalDragUpdate;

//   /// A pointer that was previously in contact with the screen with a primary
//   /// button and moving horizontally is no longer in contact with the screen and
//   /// was moving at a specific velocity when it stopped contacting the screen.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragEndCallback onHorizontalDragEnd;

//   /// The pointer that previously triggered [onHorizontalDragDown] did not
//   /// complete.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragCancelCallback onHorizontalDragCancel;

//   /// A pointer has contacted the screen with a primary button and might begin
//   /// to move.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragDownCallback onPanDown;

//   /// A pointer has contacted the screen with a primary button and has begun to
//   /// move.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragStartCallback onPanStart;

//   /// A pointer that is in contact with the screen with a primary button and
//   /// moving has moved again.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragUpdateCallback onPanUpdate;

//   /// A pointer that was previously in contact with the screen with a primary
//   /// button and moving is no longer in contact with the screen and was moving
//   /// at a specific velocity when it stopped contacting the screen.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragEndCallback onPanEnd;

//   /// The pointer that previously triggered [onPanDown] did not complete.
//   ///
//   /// See also:
//   ///
//   ///  * [kPrimaryButton], the button this callback responds to.
//   final GestureDragCancelCallback onPanCancel;

//   /// The pointers in contact with the screen have established a focal point and
//   /// initial scale of 1.0.
//   final GestureScaleStartCallback onScaleStart;

//   /// The pointers in contact with the screen have indicated a new focal point
//   /// and/or scale.
//   final GestureScaleUpdateCallback onScaleUpdate;

//   /// The pointers are no longer in contact with the screen.
//   final GestureScaleEndCallback onScaleEnd;

//   /// The pointer is in contact with the screen and has pressed with sufficient
//   /// force to initiate a force press. The amount of force is at least
//   /// [ForcePressGestureRecognizer.startPressure].
//   ///
//   /// Note that this callback will only be fired on devices with pressure
//   /// detecting screens.
//   final GestureForcePressStartCallback onForcePressStart;

//   /// The pointer is in contact with the screen and has pressed with the maximum
//   /// force. The amount of force is at least
//   /// [ForcePressGestureRecognizer.peakPressure].
//   ///
//   /// Note that this callback will only be fired on devices with pressure
//   /// detecting screens.
//   final GestureForcePressPeakCallback onForcePressPeak;

//   /// A pointer is in contact with the screen, has previously passed the
//   /// [ForcePressGestureRecognizer.startPressure] and is either moving on the
//   /// plane of the screen, pressing the screen with varying forces or both
//   /// simultaneously.
//   ///
//   /// Note that this callback will only be fired on devices with pressure
//   /// detecting screens.
//   final GestureForcePressUpdateCallback onForcePressUpdate;

//   /// The pointer is no longer in contact with the screen.
//   ///
//   /// Note that this callback will only be fired on devices with pressure
//   /// detecting screens.
//   final GestureForcePressEndCallback onForcePressEnd;

//   /// How this gesture detector should behave during hit testing.
//   ///
//   /// This defaults to [HitTestBehavior.deferToChild] if [child] is not null and
//   /// [HitTestBehavior.translucent] if child is null.
//   final HitTestBehavior behavior;

//   /// Whether to exclude these gestures from the semantics tree. For
//   /// example, the long-press gesture for showing a tooltip is
//   /// excluded because the tooltip itself is included in the semantics
//   /// tree directly and so having a gesture to show it would result in
//   /// duplication of information.
//   final bool excludeFromSemantics;

//   /// Determines the way that drag start behavior is handled.
//   ///
//   /// If set to [DragStartBehavior.start], gesture drag behavior will
//   /// begin upon the detection of a drag gesture. If set to
//   /// [DragStartBehavior.down] it will begin when a down event is first detected.
//   ///
//   /// In general, setting this to [DragStartBehavior.start] will make drag
//   /// animation smoother and setting it to [DragStartBehavior.down] will make
//   /// drag behavior feel slightly more reactive.
//   ///
//   /// By default, the drag start behavior is [DragStartBehavior.start].
//   ///
//   /// Only the [onStart] callbacks for the [VerticalDragGestureRecognizer],
//   /// [HorizontalDragGestureRecognizer] and [PanGestureRecognizer] are affected
//   /// by this setting.
//   ///
//   /// See also:
//   ///
//   ///  * [DragGestureRecognizer.dragStartBehavior], which gives an example for the different behaviors.
//   final DragStartBehavior dragStartBehavior;

//   @override
//   Widget build(BuildContext context) {
//     final Map<Type, GestureRecognizerFactory> gestures =
//         <Type, GestureRecognizerFactory>{};

//     if (onTapDown != null ||
//         onTapUp != null ||
//         onTap != null ||
//         onTapCancel != null ||
//         onSecondaryTapDown != null ||
//         onSecondaryTapUp != null ||
//         onSecondaryTapCancel != null) {
//       gestures[AllowMultipleGestureRecognizer] =
//           GestureRecognizerFactoryWithHandlers<AllowMultipleGestureRecognizer>(
//         () => AllowMultipleGestureRecognizer(debugOwner: this),
//         (TapGestureRecognizer instance) {
//           instance
//             ..onTapDown = onTapDown
//             ..onTapUp = onTapUp
//             ..onTap = onTap
//             ..onTapCancel = onTapCancel
//             ..onSecondaryTapDown = onSecondaryTapDown
//             ..onSecondaryTapUp = onSecondaryTapUp
//             ..onSecondaryTapCancel = onSecondaryTapCancel;
//         },
//       );
//     }

//     if (onDoubleTap != null) {
//       gestures[DoubleTapGestureRecognizer] =
//           GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
//         () => DoubleTapGestureRecognizer(debugOwner: this),
//         (DoubleTapGestureRecognizer instance) {
//           instance..onDoubleTap = onDoubleTap;
//         },
//       );
//     }

//     if (onLongPress != null ||
//         onLongPressUp != null ||
//         onLongPressStart != null ||
//         onLongPressMoveUpdate != null ||
//         onLongPressEnd != null) {
//       gestures[LongPressGestureRecognizer] =
//           GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
//         () => LongPressGestureRecognizer(debugOwner: this),
//         (LongPressGestureRecognizer instance) {
//           instance
//             ..onLongPress = onLongPress
//             ..onLongPressStart = onLongPressStart
//             ..onLongPressMoveUpdate = onLongPressMoveUpdate
//             ..onLongPressEnd = onLongPressEnd
//             ..onLongPressUp = onLongPressUp;
//         },
//       );
//     }

//     if (onVerticalDragDown != null ||
//         onVerticalDragStart != null ||
//         onVerticalDragUpdate != null ||
//         onVerticalDragEnd != null ||
//         onVerticalDragCancel != null) {
//       gestures[VerticalDragGestureRecognizer] =
//           GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
//         () => VerticalDragGestureRecognizer(debugOwner: this),
//         (VerticalDragGestureRecognizer instance) {
//           instance
//             ..onDown = onVerticalDragDown
//             ..onStart = onVerticalDragStart
//             ..onUpdate = onVerticalDragUpdate
//             ..onEnd = onVerticalDragEnd
//             ..onCancel = onVerticalDragCancel
//             ..dragStartBehavior = dragStartBehavior;
//         },
//       );
//     }

//     if (onHorizontalDragDown != null ||
//         onHorizontalDragStart != null ||
//         onHorizontalDragUpdate != null ||
//         onHorizontalDragEnd != null ||
//         onHorizontalDragCancel != null) {
//       gestures[HorizontalDragGestureRecognizer] =
//           GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
//         () => HorizontalDragGestureRecognizer(debugOwner: this),
//         (HorizontalDragGestureRecognizer instance) {
//           instance
//             ..onDown = onHorizontalDragDown
//             ..onStart = onHorizontalDragStart
//             ..onUpdate = onHorizontalDragUpdate
//             ..onEnd = onHorizontalDragEnd
//             ..onCancel = onHorizontalDragCancel
//             ..dragStartBehavior = dragStartBehavior;
//         },
//       );
//     }

//     if (onPanDown != null ||
//         onPanStart != null ||
//         onPanUpdate != null ||
//         onPanEnd != null ||
//         onPanCancel != null) {
//       gestures[PanGestureRecognizer] =
//           GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
//         () => PanGestureRecognizer(debugOwner: this),
//         (PanGestureRecognizer instance) {
//           instance
//             ..onDown = onPanDown
//             ..onStart = onPanStart
//             ..onUpdate = onPanUpdate
//             ..onEnd = onPanEnd
//             ..onCancel = onPanCancel
//             ..dragStartBehavior = dragStartBehavior;
//         },
//       );
//     }

//     if (onScaleStart != null || onScaleUpdate != null || onScaleEnd != null) {
//       gestures[ScaleGestureRecognizer] =
//           GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
//         () => ScaleGestureRecognizer(debugOwner: this),
//         (ScaleGestureRecognizer instance) {
//           instance
//             ..onStart = onScaleStart
//             ..onUpdate = onScaleUpdate
//             ..onEnd = onScaleEnd;
//         },
//       );
//     }

//     if (onForcePressStart != null ||
//         onForcePressPeak != null ||
//         onForcePressUpdate != null ||
//         onForcePressEnd != null) {
//       gestures[ForcePressGestureRecognizer] =
//           GestureRecognizerFactoryWithHandlers<ForcePressGestureRecognizer>(
//         () => ForcePressGestureRecognizer(debugOwner: this),
//         (ForcePressGestureRecognizer instance) {
//           instance
//             ..onStart = onForcePressStart
//             ..onPeak = onForcePressPeak
//             ..onUpdate = onForcePressUpdate
//             ..onEnd = onForcePressEnd;
//         },
//       );
//     }

//     return RawGestureDetector(
//       gestures: gestures,
//       behavior: behavior,
//       excludeFromSemantics: excludeFromSemantics,
//       child: child,
//     );
//   }

//   @override
//   void debugFillProperties(DiagnosticPropertiesBuilder properties) {
//     super.debugFillProperties(properties);
//     properties.add(
//         EnumProperty<DragStartBehavior>('startBehavior', dragStartBehavior));
//   }
// }

// class MultiGestureDetector extends StatelessWidget {
//   final Widget child;
//   final VoidCallback onTap;
//   MultiGestureDetector({this.child, this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     return RawGestureDetector(
//       child: child,
//       gestures: {
//         AllowMultipleGestureRecognizer: GestureRecognizerFactoryWithHandlers<
//             AllowMultipleGestureRecognizer>(
//           () => AllowMultipleGestureRecognizer(),
//           (AllowMultipleGestureRecognizer instance) {
//             instance.onTap = onTap;
//           },
//         )
//       },
//     );
//   }
// }

// class AllowMultipleGestureRecognizer extends TapGestureRecognizer {
//   AllowMultipleGestureRecognizer({Object debugOwner})
//       : super(debugOwner: debugOwner);

//   @override
//   void rejectGesture(int pointer) {
//     try {
//       acceptGesture(pointer);
//     } catch (e) {
//       super.rejectGesture(pointer);
//     }
//   }
// }
