import 'dart:math';
import 'dart:typed_data';

import 'package:floop/floop.dart';
import 'package:floop/transition.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MaterialApp(
      title: 'Spiral',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Spiral()));
}

class Spiral extends StatelessWidget with Floop {
  static int _totalSpawned = 0;

  static void spawnSpiralingWidget() {
    var widgets = Dyn.spiralingWidgets.toList();
    widgets.add(
        SpiralingWidget(key: ValueKey(_totalSpawned++), child: ImageCircle()));
    Dyn.spiralingWidgets = widgets;
  }

  static void deleteSpiralingWidget(Key key) {
    var widgets = Dyn.spiralingWidgets.toList();
    widgets.removeWhere((widget) => widget.key == key);
    Dyn.spiralingWidgets = widgets;
  }

  static void putWidgetOnTop(Key key) {
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

  @override
  void initContext(BuildContext context) {
    Dyn.spiralingWidgets ??= List();
  }

  String get targetTransitions => tagAsName();

  @override
  Widget build(BuildContext context) {
    theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: ListTile(
          title: Text(
            'Playback tageting: ${targetTransitions} transitions',
            style: theme.primaryTextTheme.body1,
          ),
          onTap: nextTag,
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: const ActionCanceler()),
          Align(
            alignment: Alignment.topLeft,
            child: Text(
                'Target refresh rate: ${(1000 ~/ TransitionsConfig.refreshPeriodicityMillis)}'),
          ),
          ...Dyn.spiralingWidgets,
          Align(
              alignment: Alignment.topRight,
              child: Text(
                  'Refresh rate: ${Transitions.currentRefreshRateDynamic()?.toStringAsFixed(2)}')),
          Align(
              alignment: Alignment.bottomCenter,
              child: const SelectTransitionButton()),
          Align(
            alignment: TrashBin.alignment,
            child: const TrashBin(),
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

// class SpiralingWidget extends StatelessWidget with Floop {
class SpiralingWidget extends DynamicWidget {
  static final spiralAlignments = computeSpiralAlignments();

  static List<Alignment> computeSpiralAlignments() {
    // https://math.stackexchange.com/questions/877044/keeping-the-arc-length-constant-between-points-in-a-spiral
    final alignments = List<Alignment>(1000);
    var a = 0.1; // a constant
    var b = 0.1; // another constant
    var h = 0.01 * b / (a * sqrt(1 + b * b));
    var theta = 0.0;
    for (int i = 0; i < 1000; i++) {
      theta = log(h + exp(b * theta)) / b;
      var pX = a * cos(theta) * exp(b * theta);
      var pY = a * sin(theta) * exp(b * theta);
      alignments[i] = Alignment(pX.clamp(-1.0, 1.0), pY.clamp(-1.0, 1.0));
    }
    return alignments;
  }

  getSpiralAlignment(double t) {
    return spiralAlignments[(t * 1000).toInt().clamp(0, 999)];
  }

  static const minSize = 10.0;
  static const growSize = 100.0;

  static Size largeSize = Size(imageWidth.toDouble(), imageHeight.toDouble());

  final Widget child;

  SpiralingWidget({Key key, @required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // The spiral animation transition.
    var t = transition(20000, repeatAfterMillis: 3000, tag: Tags.spiral);
    final currentAlignment = getSpiralAlignment(t);
    final size = minSize + t * growSize;
    return Positioned.fill(
      child: DragInteraction(
        key: key,
        alignment: currentAlignment,
        child: DefererGestureDetector(
          child: ExpandInteraction(
            key: key,
            child: child,
            normalSize: Size(size, size),
            extraSize: largeSize - Size(size, size),
          ),
          onDoubleTap: () => {
            Transitions.resumeOrPause(context: context, applyToChildren: true),
          },
          onTap: () => {
            Spiral.putWidgetOnTop(key),
          },
          onPanCancel: () => Transitions.reverse(context: context),
        ),
      ),
    );
  }
}

class DragInteraction extends DynamicWidget {
  static BuildContext refereceContext;

  final Widget child;
  final Alignment alignment;

  /// The key used to reference the move back animation.
  final Object moveBackKey;

  /// The key used to reference the delete animation.
  final Object deleteKey;

  DragInteraction({Key key, this.child, this.alignment})
      : moveBackKey = 'moveBack$SpiralingWidget$key',
        deleteKey = 'delete$SpiralingWidget$key',
        super(key: key);

  Alignment get dragAlignment => dyn[#dragAlignment];
  set dragAlignment(Alignment drag) => dyn[#dragAlignment] = drag;

  /// The evaluation function used to trigger the widget delete operation once
  /// the delete transition finishes.
  double deleteEvaluate(double progressRatio) {
    if (progressRatio == 1) {
      // When the ratio is 1 the transition is finished.
      Spiral.deleteSpiralingWidget(key);
    }
    return progressRatio;
  }

  void moveBack() {
    Dyn.dragWidget = null;
    // A transition without context is automatically deleted when it finishes.
    transition(3000, key: moveBackKey);
  }

  delete(BuildContext context) {
    assert(trashBin.active);
    // bindContext is provided to cause the transition persists.
    transitionEval(1500, deleteEvaluate, key: deleteKey, bindContext: context);
    trashBin.deactivate();
  }

  void updateDragAlignment(DragUpdateDetails details) {
    if (transitionOf(deleteKey) != null) {
      // Widget being deleted.
      return;
    }
    Dyn.dragWidget = this;
    Transitions.cancel(key: moveBackKey);
    // Keep updating referenceSize in case the app changes it's layout.
    stackCanvasSize = refereceContext.size;
    final newAlignment = dragAlignment +
        offsetDeltaToAlignmentDelta(details.delta, refereceContext.size);
    if (trashBin.alignmentWithinDeletionBounds(newAlignment)) {
      trashBin.activate();
    } else {
      trashBin.deactivate();
    }
    dragAlignment = newAlignment;
  }

  bool get beingDragged => Dyn.dragWidget?.key == key;

  Alignment interactiveAlignment() {
    final moveBackProgress = transitionOf(moveBackKey);
    Alignment resultAlignment;
    if (moveBackProgress != null) {
      resultAlignment =
          Alignment.lerp(dragAlignment, alignment, moveBackProgress);
    } else if (beingDragged || transitionOf(deleteKey) != null) {
      resultAlignment = dragAlignment;
    }
    return resultAlignment;
  }

  @override
  Widget build(BuildContext context) {
    final currentAlignment = interactiveAlignment() ?? alignment;
    return SizedBox.expand(
      child: Align(
        alignment: currentAlignment,
        child: DefererGestureDetector(
          child: Opacity(
            opacity: 1 - (transitionOf(deleteKey) ?? 0.0),
            child: child,
          ),
          onPanDown: (details) {
            refereceContext = context;
            Dyn.dragWidget = this;
            stackCanvasSize = context.size;
            dragAlignment = currentAlignment;
            revertTransientTransitions();
          },
          onPanCancel: () => Dyn.dragWidget = null,
          onPanUpdate: updateDragAlignment,
          onPanEnd: (_) {
            if (trashBin.active) {
              delete(context);
            } else {
              moveBack();
            }
          },
        ),
      ),
    );
  }
}

revertTransientTransitions() {
  Dyn.expandingWidget?.contract();
}

class ExpandInteraction extends StatelessWidget with Floop {
  final Widget child;
  final Size normalSize;
  final Offset extraSize;
  const ExpandInteraction(
      {@required key,
      this.child,
      @required this.normalSize,
      @required this.extraSize})
      : sizeKey = '$ExpandInteraction$key',
        super(key: key);

  double get lerpValue => transitionOf(sizeKey) ?? 0.0;

  // The key that is used for the expanding animation.
  final Object sizeKey;

  Size get size => normalSize + extraSize * lerpValue;

  expand(BuildContext context) {
    // The transition is identified with a key to be referenced from within
    // the build method.
    //
    // The transition is bound to the context to prevent it from being deleted
    // when it finishes. This way the widget remains large.
    transition(700, key: sizeKey, bindContext: context, tag: Tags.transient);
    Dyn.expandingWidget = this;
  }

  contract() {
    final lastExpandingLerpValue = transitionOf(sizeKey) ?? 0;
    // Cancel deletes the transition.
    Transitions.cancel(key: sizeKey);
    // Context is not provided so that the transition is deleted when
    // it finishes.
    transitionEval(400, (r) => (1 - r) * lastExpandingLerpValue, key: sizeKey);
    Dyn.expandingWidget = null;
  }

  @override
  Widget build(BuildContext context) {
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
          var expanding = Dyn.expandingWidget;
          expanding?.contract();
          if (expanding?.sizeKey != sizeKey) {
            expand(context);
          }
        },
      ),
    );
  }
}

class ImageCircle extends DynamicWidget {
  initDyn() {
    dyn[#baseColor] ??= randomColor();
    dyn[#color] ??= randomColor();
    dyn[#transitionKey] = UniqueKey();
  }

  Key get transitionKey => dyn[#transitionKey];

  Color get baseColor => dyn[#baseColor] ??= randomColor();
  set baseColor(Color color) => dyn[#baseColor] = color;

  Color get color => dyn[#color] ??= randomColor();
  set color(Color color) => dyn[#color] = color;

  Color get transitionedColor {
    // Because the transition repeats, an oscillator is used make the value
    // continous.
    final t = sin(2 *
        pi *
        transition(5000,
            repeatAfterMillis: 0, key: transitionKey, tag: Tags.color));
    return Color.lerp(baseColor, color, t);
  }

  @override
  Widget build(BuildContext context) {
    return DefererGestureDetector(
        child: Container(
          color: transitionedColor,
          child: RandomImage(),
        ),
        onTap: () {
          baseColor = transitionedColor;
          color = randomColor();
          Transitions.reset(context: context);
        });
  }
}

var _fetchLocked = Set<Object>();

Future<Uint8List> fetchImage(
    [Object lockObject,
    String url = 'https://picsum.photos/${imageWidth}/${imageHeight}']) async {
  if (_fetchLocked.contains(lockObject)) {
    return null;
  }
  try {
    _fetchLocked.add(lockObject); // locks the fetching function
    final response = await http.get(url);
    return response.bodyBytes;
  } catch (e) {
    return null;
  } finally {
    _fetchLocked.remove(lockObject);
  }
}

class RandomImage extends DynamicWidget {
  RandomImage();

  initDyn() {
    // dyn member is persistant on rebuilds.
    dyn[#lockKey] = Object();
    fetchAndLoadImage();
  }

  Object get lockKey => dyn[#lockKey];

  Widget get image => dyn[#image];
  set image(Widget widget) => dyn[#image] = widget;

  Uint8List get lastFetchedImageBytes =>
      Uint8List.fromList(dyn[#imageBytes]?.cast<int>());
  set lastFetchedImageBytes(Uint8List bytes) => dyn[#imageBytes] = bytes;

  loadImage() {
    image = Image.memory(
      lastFetchedImageBytes,
      fit: BoxFit.cover,
    );
  }

  fetchAndLoadImage() async {
    image = null;
    final imageBytes = await fetchImage(lockKey);
    if (imageBytes != null) {
      lastFetchedImageBytes = imageBytes;
      loadImage();
    }
  }

  double get rotationAngle =>
      2 *
      pi *
      transition(1000,
          delayMillis: 5000, repeatAfterMillis: -2000, tag: Tags.image);

  @override
  Widget build(BuildContext context) {
    return DefererGestureDetector(
      child: image == null
          ? null
          : Opacity(
              opacity: transition(3000, tag: Tags.image),
              child: Transform.rotate(
                child: image,
                angle: rotationAngle,
              )),
      onLongPress: () async {
        await fetchAndLoadImage();
        Transitions.reset(context: context);
      },
    );
  }
}

Color randomColor() {
  const blend = 0xFA000000;
  return Color(Random().nextInt(1 << 32) | blend);
}

class PlaybackOptions extends FloopWidget {
  static const baseMiilis = 1;
  static const maxMillis = 40;
  static var _shiftMillis = baseMiilis;

  static _shiftTime(_) {
    Transitions.shiftTime(shiftMillis: _shiftMillis, tag: Dyn.activeTag);
    _shiftMillis +=
        (_shiftMillis + 1 * _shiftMillis.sign).clamp(-maxMillis, maxMillis);
  }

  static Repeater repeater = Repeater(_shiftTime, 50);

  final titleWidget = Text('${tagAsName() ?? 'All'}');

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
                color: Dyn.shiftDirection == ShiftDirection.backwards
                    ? Colors.red
                    : Colors.indigoAccent),
            onTap: () => Transitions.shiftTime(
                shiftType: ShiftType.begin, tag: Dyn.activeTag),
            onLongPress: () {
              Dyn.shiftDirection = ShiftDirection.backwards;
              _shiftMillis = -baseMiilis;
              repeater.start();
            },
            onLongPressUp: () {
              Dyn.shiftDirection = ShiftDirection.none;
              repeater.stop();
            },
          ),
        ),
        BottomNavigationBarItem(
          title: titleWidget,
          icon: GestureDetector(
            child: Icon(
              Icons.fast_forward,
              color: Dyn.shiftDirection == ShiftDirection.forward
                  ? Colors.red
                  : Colors.indigoAccent,
            ),
            onTap: () => Transitions.shiftTime(
                shiftType: ShiftType.end, tag: Dyn.activeTag),
            onLongPress: () {
              Dyn.shiftDirection = ShiftDirection.forward;
              _shiftMillis = baseMiilis;
              repeater.start();
            },
            onLongPressUp: () {
              Dyn.shiftDirection = ShiftDirection.none;
              repeater.stop();
            },
          ),
        ),
        BottomNavigationBarItem(
          title: titleWidget,
          icon: IconButton(
            icon: Icon(Icons.swap_horiz),
            iconSize: 32,
            onPressed: () => Transitions.reverse(tag: Dyn.activeTag),
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

class ActionCanceler extends StatelessWidget {
  const ActionCanceler();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: revertTransientTransitions,
    );
  }
}

class SelectTransitionButton extends StatelessWidget with Floop {
  const SelectTransitionButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      width: 155,
      height: 60,
      padding: EdgeInsets.only(top: 10, bottom: 10, right: 10),
      child: SizedBox.expand(
        child: RaisedButton(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5.0,
          color: theme.buttonTheme.colorScheme.onPrimary,
          textTheme: theme.buttonTheme.textTheme,
          child: Text(
            '${tagAsName()}',
          ),
          onPressed: nextTag,
        ),
      ),
    );
  }
}

nextTag() {
  final active = Dyn.activeTag;
  final index = selectableTags.indexOf(active) + 1;
  var tag;
  if (index < selectableTags.length) {
    tag = selectableTags[index];
  }
  // Null tag implies all transitions.
  Dyn.activeTag = tag;
}

class TrashBin extends StatelessWidget with Floop {
  static const trashBinSize = 32.0;
  static const trashBinPadding = 15.0;
  static const interactionSize = trashBinSize + trashBinPadding;

  static final alignment = Alignment.bottomLeft;

  static Alignment get limitAligment =>
      Alignment.bottomLeft +
      offsetDeltaToAlignmentDelta(
          Offset(TrashBin.interactionSize, -TrashBin.interactionSize),
          stackCanvasSize);

  static get trashBinKey => #trashBin;

  const TrashBin();

  bool get active => Dyn.trashBinActive;

  bool alignmentWithinDeletionBounds(Alignment alignment) {
    return (alignment.x < limitAligment.x && alignment.y > limitAligment.y);
  }

  activate() {
    Dyn.trashBinActive = true;
    transition(700, key: trashBinKey);
  }

  deactivate() {
    Transitions.cancel(key: trashBinKey);
    Dyn.trashBinActive = false;
  }

  double get lerpValue {
    double value = transitionOf(trashBinKey);
    if (value == null && active) {
      value = 1.0;
    }
    return value ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(15),
      child: Icon(
        Icons.delete,
        size: 32,
        color: Color.lerp(Colors.grey[400], Colors.red, lerpValue),
      ),
    );
  }
}

Alignment offsetDeltaToAlignmentDelta(Offset offset, Size size) {
  final alignment =
      Alignment(offset.dx / size.width, offset.dy / size.height) * 2;
  return alignment;
}

Alignment offsetToAlignment(Offset offset, Size size) {
  var alignment = Alignment.topLeft +
      Alignment(offset.dx / size.width, offset.dy / size.height) * 2;
  return alignment;
}

/// DefererGestureDetector implementation.

enum Gesture {
  onTap,
  onDoubleTap,
  onLongPress,
  onLongPressUp,
  onPanDown,
  onPanCancel,
  onPanUpdate,
  onPanEnd,
}

typedef GestureCallback = void Function(dynamic);

/// Gesture detector that propagates the gesture to ancestor gesture detectors.
class DefererGestureDetector extends GestureDetector {
  final Widget child;

  DefererGestureDetector(
      {this.child,
      onTap,
      onDoubleTap,
      onLongPress,
      onLongPressUp,
      onPanDown,
      onPanCancel,
      onPanUpdate,
      onPanEnd})
      : super(
            child: child,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            onLongPress: onLongPress,
            onLongPressUp: onLongPressUp,
            onPanDown: onPanDown,
            onPanUpdate: onPanUpdate,
            onPanEnd: onPanEnd,
            onPanCancel: onPanCancel);

  static triggerGestureAction(GestureDetector gestureDetector, Gesture gesture,
      [details]) {
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
      case Gesture.onPanCancel:
        if (gestureDetector.onPanCancel != null) {
          gestureDetector.onPanCancel();
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
      onPanCancel: createGestureCallback(context, Gesture.onPanCancel),
      onPanUpdate: createGestureCallback(context, Gesture.onPanUpdate),
      onPanEnd: createGestureCallback(context, Gesture.onPanEnd),
    );
  }
}

/// Shared dynamic values
class Dyn {
  static final dyn = DynMap();

  static bool get trashBinActive => dyn[#trashBinActive] ??= false;
  static set trashBinActive(bool active) => dyn[#trashBinActive] = active;

  static DragInteraction get dragWidget => dyn[#dragStartWidget];
  static set dragWidget(DragInteraction widget) =>
      dyn[#dragStartWidget] = widget;

  static List<Widget> get spiralingWidgets =>
      (dyn[#spiralImages] ??= List<Widget>()).cast<Widget>();
  static set spiralingWidgets(List<Widget> updatedList) =>
      dyn[#spiralImages] = updatedList;

  static Tags get activeTag => dyn[#activeTag];
  static set activeTag(Tags tag) => dyn[#activeTag] = tag;

  static bool get optionsBarPaused => dyn[#optionsBarPaused] ??= false;
  static set optionsBarPaused(bool paused) => dyn[#optionsBarPaused] = paused;

  static ExpandInteraction get expandingWidget => dyn[#expandingKey];
  static set expandingWidget(ExpandInteraction key) => dyn[#expandingKey] = key;

  static ShiftDirection get shiftDirection =>
      dyn[#shiftDirection] ??= ShiftDirection.none;
  static set shiftDirection(ShiftDirection direction) =>
      dyn[#shiftDirection] = direction;
}

/// Constants and global scope variables.

enum Tags {
  color,
  rotation,
  image,
  spiral,
  grow,
  transient,
  all,
}

enum ShiftDirection {
  none,
  backwards,
  forward,
}

const num imageHeight = 200;
const num imageWidth = 300;

const trashBin = TrashBin();

// This value is set from the interaction event handlers.
Size stackCanvasSize = Size.zero;

ThemeData theme;

const tagToName = {
  Tags.color: 'Color',
  Tags.image: 'Image',
  Tags.spiral: 'Spiral',
};

final selectableTags = tagToName.keys.toList();

tagAsName([tag]) {
  return tagToName[tag ?? Dyn.activeTag] ?? 'All';
}
