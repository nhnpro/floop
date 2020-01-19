import 'dart:math';
import 'dart:typed_data';

import 'package:floop/floop.dart';
import 'package:floop/transition.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  theme = ThemeData(
    primarySwatch: Colors.blue,
  );
  runApp(MaterialApp(title: 'Spiral', theme: theme, home: Spiral()));
}

class Spiral extends StatelessWidget with Floop {
  static int _totalSpawned = 0;

  static void spawnSpiralingWidget() {
    addSpiralingWidget(
        SpiralingWidget(key: ValueKey(_totalSpawned++), child: ImageCircle()));
  }

  static Widget _removeWidgetWithKey(List<Widget> widgets, Key key) {
    Widget targetWidget;
    widgets.removeWhere((widget) {
      if (widget.key == key) {
        targetWidget = widget;
        return true;
      }
      return false;
    });
    assert(targetWidget != null);
    return targetWidget;
  }

  static void deleteSpiralingWidget(Key key) {
    var removedWidget = _removeWidgetWithKey(Dyn.spiralingWidgets, key);
    trashBin.putInRecycleBin(removedWidget);
  }

  static void addSpiralingWidget(SpiralingWidget widget) {
    Dyn.spiralingWidgets.add(widget);
  }

  static void putWidgetOnTop(Key key) {
    final widgets = Dyn.spiralingWidgets;
    Widget targetWidget = _removeWidgetWithKey(widgets, key);
    widgets.add(targetWidget);
  }

  // initContext can be used to initialize dynamic values in Floop widgets.
  @override
  void initContext(BuildContext context) {
    Dyn.spiralingWidgets ??= List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ListTile(
          title: Text(
            Dyn.titleType == TitleType.tag
                ? 'Playback tageting: ${tagAsName()} transitions'
                : 'Animations speed: ${TransitionsConfig.timeDilationFactor.toStringAsFixed(2)}',
            style: theme.primaryTextTheme.body1,
          ),
          onTap: nextTag,
        ),
        actions: <Widget>[const Info()],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: const ActionCanceler()),
          Align(
            alignment: Alignment.topLeft,
            child: Text(
                'Target refresh rate: ${(1000 ~/ TransitionsConfig.refreshPeriodicityMillis)} Hz'),
          ),
          ...Dyn.spiralingWidgets,
          Align(
              alignment: Alignment.topRight,
              child: Text(
                  'Refresh rate: ${TransitionGroup.currentRefreshRateDynamic()?.toStringAsFixed(2)}')),
          Align(
              alignment: Alignment.bottomCenter,
              child: const SelectAnimationButton()),
          Align(
            alignment: TrashBin.alignment,
            child: trashBin,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: const AnimationSpeedSideBar(),
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

class SpiralingWidget extends StatelessWidget with Floop {
  static final spiralAlignments = computeSpiralAlignments();

  static List<Alignment> computeSpiralAlignments() {
    // https://math.stackexchange.com/questions/877044/keeping-the-arc-length-constant-between-points-in-a-spiral
    final alignments = List<Alignment>(1000);
    var a = 0.1;
    var b = 0.1;
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
    var t =
        transition(20000, repeatAfterMillis: 3000, tag: AnimationTag.spiral);
    final currentAlignment = getSpiralAlignment(t);
    final size = Size.fromRadius((minSize + t * growSize) / 2);
    return Positioned.fill(
      child: GestureDetector(
        child: DragInteraction(
          key: key,
          childSize: size,
          baseAlignment: currentAlignment,
          child: ExpandInteraction(
            key: key,
            child: child,
            normalSize: size,
            extraSize: largeSize - size,
          ),
        ),
        onDoubleTap: () =>
            TransitionGroup().resumeOrPause(rootContext: context),
        onPanDown: (_) => Spiral.putWidgetOnTop(key),
        onPanEnd: (_) => TransitionGroup(context: context).reverse(),
      ),
    );
  }
}

// Each of these widgets need to store the drag position. DynamicWidget has a
// DynMap [dyn] for storage and it can be used instead of a StatefulWidget.
class DragInteraction extends DynamicWidget {
  final Widget child;
  final Size childSize;
  final Alignment baseAlignment;

  /// The key used to reference the move back animation.
  final Object moveBackKey;

  /// The key used to reference the delete animation.
  final Object deleteKey;

  DragInteraction(
      {Key key, this.child, this.baseAlignment, this.childSize = Size.zero})
      : moveBackKey = 'moveBack$SpiralingWidget$key',
        deleteKey = 'delete$SpiralingWidget$key',
        super(key: key);

  Size get dragCanvasSize =>
      stackCanvasSize - Offset(childSize.width, childSize.height);

  Alignment get dragAlignment => dyn[#dragAlignment];
  set dragAlignment(Alignment drag) => dyn[#dragAlignment] = drag;

  void moveBack() {
    // A key must be provided to transition calls outside build methods. This
    // way their value can be retrieved.
    // A transition without context is automatically deleted when it finishes.
    transition(3000, key: moveBackKey);
  }

  double deleteEvaluate(double progressRatio) {
    if (progressRatio >= 1) {
      // When the ratio is 1 the transition has finished.
      // This condition can only evaluate to true one time, Because the
      // transition is deleted when it finishes.
      Spiral.deleteSpiralingWidget(key);
    }
    return progressRatio;
  }

  delete(BuildContext context) {
    assert(trashBin.active);
    // transitionEval accepts an evaluation function, but it cannot be used
    // inside build methods.
    transitionEval(1500, deleteEvaluate,
        key: deleteKey, tag: AnimationTag.aesthetic);
    trashBin.deactivateSmooth();
  }

  void updateDragAlignment(DragUpdateDetails details) {
    TransitionGroup(key: moveBackKey).cancel();
    final newAlignment = dragAlignment +
        offsetDeltaToAlignmentDelta(details.delta, dragCanvasSize);
    if (trashBin.alignmentWithinDeletionBounds(newAlignment)) {
      trashBin.activate();
    } else {
      trashBin.deactivate();
    }
    dragAlignment = newAlignment;
  }

  bool get beingDragged => Dyn.dragWidget?.key == key;

  bool get beingDeleted => transitionOf(deleteKey) != null;

  Alignment interactiveAlignment() {
    final moveBackProgress = transitionOf(moveBackKey);
    Alignment resultAlignment;
    if (moveBackProgress != null) {
      resultAlignment =
          Alignment.lerp(dragAlignment, baseAlignment, moveBackProgress);
    } else if (beingDragged || beingDeleted) {
      resultAlignment = dragAlignment;
    }
    return resultAlignment;
  }

  @override
  Widget build(BuildContext context) {
    final currentAlignment = interactiveAlignment() ?? baseAlignment;
    return SizedBox.expand(
      child: Align(
        alignment: currentAlignment,
        child: DefererGestureDetector(
          child: Opacity(
            opacity: 1 - (transitionOf(deleteKey) ?? 0.0),
            child: child,
          ),
          onPanCancel: () => Dyn.dragWidget = null,
          onPanUpdate: (details) {
            if (beingDeleted) {
              return;
            }
            if (!beingDragged) {
              Dyn.dragWidget = this;
              dragAlignment = currentAlignment;
            }
            // Keep updating stackCanvasSize in case the app changes its layout.
            stackCanvasSize = context.size;
            updateDragAlignment(details);
          },
          onPanEnd: (_) {
            if (trashBin.active) {
              delete(context);
            } else if (!beingDeleted) {
              moveBack();
            }
            Dyn.dragWidget = null;
          },
        ),
      ),
    );
  }
}

class ExpandInteraction extends StatelessWidget with Floop {
  static contractCurrent([_]) {
    Dyn.expandingWidget?.contract();
  }

  final Widget child;
  final Size normalSize;
  final Offset extraSize;
  const ExpandInteraction(
      {@required Key key,
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
    // bindContext is provided to make transitions persist after they finish.
    // In this case it is desired that the widget remains expanded when the
    // transition finishes.
    transition(700, key: sizeKey, bindContext: context, tag: AnimationTag.grow);
    Dyn.expandingWidget = this;
  }

  contract() {
    var lastExpandingLerpValue = transitionOf(sizeKey) ?? 0;
    // Cancel deletes the transition.
    TransitionGroup(key: sizeKey).cancel();
    // transitionEval accepts an evaluation function.
    transitionEval(400, (r) => (1 - r) * lastExpandingLerpValue, key: sizeKey);
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
          if (expanding?.key != key) {
            expand(context);
          } else {
            Dyn.expandingWidget = null;
          }
          expanding?.contract();
        },
        onPanDown: contractCurrent,
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

  Key get colorAnimationKey => dyn[#transitionKey];

  Color get baseColor => dyn[#baseColor] ??= randomColor();
  set baseColor(Color color) => dyn[#baseColor] = color;

  Color get color => dyn[#color] ??= randomColor();
  set color(Color color) => dyn[#color] = color;

  Color get transitionedColor {
    var t = transition(3000,
        repeatAfterMillis: 0, key: colorAnimationKey, tag: AnimationTag.color);
    // An oscillator makes the value of a repeating transition continous.
    t = sin(2 * pi * t);
    // t = 2 * (t > 0.5 ? (1 - t) : t); // triangle oscillator
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
          TransitionGroup(context: context).reset();
        });
  }
}

var _fetchLocked = Set<Object>();

Future<Uint8List> fetchImage(
    [Object lockObject,
    String url = 'https://picsum.photos/$imageWidth/$imageHeight']) async {
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
    dyn[#key] = Object();
    fetchAndLoadImage();
  }

  Object get lockKey => dyn[#lockKey];

  Widget get image => dyn[#image];
  set image(Widget widget) => dyn[#image] = widget;

  Uint8List get lastFetchedImageBytes =>
      Uint8List.fromList(dyn[#imageBytes].cast<int>());
  // [DynMap.setValue] is alternative to operator `[]=`, it sets the list
  // as it is without copying it to a [DynList].
  set lastFetchedImageBytes(Uint8List bytes) =>
      dyn.setValue(#imageBytes, bytes); // dyn[#imageBytes] = bytes;

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
      // A negative repeatAfter time substracts the delay on repetition.
      transition(1000,
          delayMillis: 5000, repeatAfterMillis: -2000, tag: AnimationTag.image);

  @override
  Widget build(BuildContext context) {
    return DefererGestureDetector(
      child: image == null
          ? null
          : Opacity(
              opacity: transition(3000, tag: AnimationTag.image),
              child: Transform.rotate(
                child: image,
                angle: rotationAngle,
              )),
      onLongPress: () async {
        await fetchAndLoadImage();
        TransitionGroup(context: context).reset();
      },
    );
  }
}

class Info extends StatelessWidget {
  const Info();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.info),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.blueGrey[0],
            title: Text('Actions\n'),
            content: Text(
              'On spiraling widgets:\n'
              '* Tap to enlarge and change background color\n'
              '* Double tap to pause\n'
              '* Long press to fetch a new image\n'
              '* Drag to reverse direction\n'
              '* Drag to trash bin to delete\n'
              '\nOn trash bin:\n'
              '* Tap to restore last deleted widget\n'
              '* Long press to empty the bin\n',
              strutStyle: StrutStyle(height: 1.8),
            ),
          ),
        );
      },
    );
  }
}

class PlaybackOptions extends StatelessWidget with Floop {
  static TransitionGroup transitionGroup = newTransitionGroup();

  static TransitionGroup newTransitionGroup() {
    final activeTag = Dyn.activeTag;
    if (activeTag == AnimationTag.all) {
      // A matcher is used to filter out aesthetic animations.
      transitionGroup = TransitionGroup(
          matcher: (transitionView) =>
              transitionView.tag != AnimationTag.aesthetic);
    } else {
      transitionGroup = TransitionGroup(tag: activeTag);
    }
    return transitionGroup;
  }

  final titleWidget = Text('${tagAsName() ?? 'All'}');

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
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
                  transitionGroup.resume();
                  Dyn.optionsBarPaused = false;
                } else {
                  transitionGroup.pause();
                  Dyn.optionsBarPaused = true;
                }
              }),
        ),
        BottomNavigationBarItem(
          title: titleWidget,
          icon: IncreaseIconButton(
            child: Icon(
              Icons.fast_rewind,
              size: 26,
            ),
            key: ValueKey(#rewindAnimations),
            onPressed: () =>
                transitionGroup.shiftTime(shiftType: ShiftType.begin),
            pressedAmount: 0,
            increment: (time) => transitionGroup.shiftTime(shiftMillis: time),
            longPressedIncrementalAmount: -15,
          ),
        ),
        BottomNavigationBarItem(
          title: titleWidget,
          icon: IncreaseIconButton(
            child: Icon(
              Icons.fast_forward,
              size: 26,
            ),
            key: ValueKey(#advanceAnimations),
            onPressed: () =>
                transitionGroup.shiftTime(shiftType: ShiftType.end),
            increment: (time) => transitionGroup.shiftTime(shiftMillis: time),
            longPressedIncrementalAmount: 15,
          ),
        ),
        BottomNavigationBarItem(
          title: titleWidget,
          icon: IconButton(
            icon: Icon(Icons.swap_horiz),
            iconSize: 32,
            onPressed: () => transitionGroup.reverse(),
          ),
        ),
        BottomNavigationBarItem(
          title: titleWidget,
          icon: IconButton(
            icon: Icon(Icons.refresh),
            iconSize: 32,
            onPressed: () {
              cancelInteractiveStates();
              transitionGroup.reset();
              TransitionsConfig.timeDilationFactor = 1.0;
            },
          ),
        ),
      ],
    );
  }
}

class AnimationSpeedSideBar extends StatelessWidget with Floop {
  static const incrementalAmount = 0.005;
  static const tapAmount = 0.1;
  static final baseIconColor = Colors.green[700];

  const AnimationSpeedSideBar();

  updateSpeed(num deltaSpeed) {
    TransitionsConfig.timeDilationFactor += deltaSpeed;
  }

  Widget iconButton(IconData icon, int sign) {
    final onPressedAnimationKey = 'AnimationSpeedSideBar$sign';
    return Container(
      padding: EdgeInsets.all(5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(0),
        color: Color.lerp(
          Colors.indigo[300],
          theme.primaryColorLight,
          transitionOf(onPressedAnimationKey) ?? 1.0,
        ),
      ),
      child: IncreaseIconButton(
        child: Icon(
          icon,
        ),
        iconBaseColor: baseIconColor,
        key: ValueKey(onPressedAnimationKey),
        increment: updateSpeed,
        pressedAmount: sign * tapAmount,
        longPressedIncrementalAmount: sign * incrementalAmount,
        onPressed: () {
          Dyn.titleType = TitleType.speed;
          restartedTransientTransition(onPressedAnimationKey);
        },
        onLongPressStart: () {
          Dyn.titleType = TitleType.speed;
          pausedTransientTransition(onPressedAnimationKey);
        },
        onLongPressEnd: () =>
            restartedTransientTransition(onPressedAnimationKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        iconButton(Icons.add, 1),
        iconButton(Icons.remove, -1),
        Container(
          width: 0,
          height: 10,
        ),
        Container(
          padding: EdgeInsets.only(right: 5),
          child: GestureDetector(
            child: Text(
              '${TransitionsConfig.timeDilationFactor.toStringAsFixed(1)}',
            ),
            onTap: () => TransitionsConfig.timeDilationFactor = 1.0,
          ),
        )
      ],
    );
  }
}

typedef IncrementCallback = Function(num increaseAmount);

class IncreaseIconButton extends StatelessWidget with Floop {
  static num currentIncreaseAmount = 0;
  static Repeater repeater = Repeater(doNothing);

  static const limitIncrease = 50;

  final Widget child;
  final IncrementCallback increment;
  final VoidCallback onPressed;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;
  final num pressedAmount,
      longPressedIncrementalAmount,
      longPressedBaseAmount,
      longPressedMaxAmount;
  final Color iconBaseColor;
  final Object colorAnimationKey;
  IncreaseIconButton(
      {this.child,
      @required Key key,
      @required this.increment,
      @required this.longPressedIncrementalAmount,
      this.pressedAmount = 0,
      this.onPressed = doNothing,
      this.onLongPressStart = doNothing,
      this.onLongPressEnd = doNothing,
      this.iconBaseColor = Colors.indigoAccent,
      this.longPressedBaseAmount = 0})
      : longPressedMaxAmount = longPressedIncrementalAmount.abs() * 50,
        colorAnimationKey = '$IncreaseIconButton-$key',
        super(key: key);

  stopIncreasing() {
    repeater.stop();
    restartedTransientTransition(colorAnimationKey);
    onLongPressEnd();
  }

  _increaseCallback(_) {
    currentIncreaseAmount =
        (currentIncreaseAmount + longPressedIncrementalAmount)
            .clamp(-longPressedMaxAmount, longPressedMaxAmount);
    increment(currentIncreaseAmount);
  }

  startIncreasing() {
    pausedTransientTransition(colorAnimationKey);
    currentIncreaseAmount = longPressedBaseAmount;
    repeater = Repeater(_increaseCallback, periodicityMilliseconds: 50);
    repeater.start();
    onLongPressStart();
  }

  Color get iconColor {
    return Color.lerp(
        Colors.red, iconBaseColor, transitionOf(colorAnimationKey) ?? 1.0);
  }

  tapIncrease() {
    onPressed();
    increment(pressedAmount);
    restartedTransientTransition(colorAnimationKey);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Theme(
        data: theme.copyWith(
            iconTheme: theme.iconTheme.copyWith(color: iconColor)),
        child: child,
      ),
      onTap: tapIncrease,
      onLongPress: startIncreasing,
      onLongPressUp: stopIncreasing,
    );
  }
}

class ActionCanceler extends StatelessWidget {
  const ActionCanceler();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        cancelInteractiveStates();
        Dyn.expandingWidget = null;
      },
      onDoubleTap: () {
        TransitionGroup(tag: AnimationTag.grow).cancel();
        Dyn.expandingWidget = null;
      },
    );
  }
}

class SelectAnimationButton extends StatelessWidget with Floop {
  static final Object changeTagAnimationKey = 'changeTag$SelectAnimationButton';

  const SelectAnimationButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      width: 155,
      height: 60,
      padding: EdgeInsets.all(10),
      child: SizedBox.expand(
        child: RaisedButton(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 5.0,
          color: Color.lerp(
              Colors.indigo[300],
              theme.buttonTheme.colorScheme.onPrimary,
              transitionOf(changeTagAnimationKey) ?? 1.0),
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

typedef RestoreWidget = Function(SpiralingWidget widget);

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

  static get colorAnimationKey => #trashBin;

  static List<Color> colors = [Colors.grey[400]]
    ..addAll(List.generate(8, (i) => Colors.green[200 + i * 100]));

  final storedWidgets = List<Widget>();
  final RestoreWidget restoreWidget;

  static final colorTransition = TransitionGroup(key: colorAnimationKey);

  static _startColorTransition(Color color) {
    restartedTransientTransition(colorAnimationKey, durationMillis: 700);
    transientColor = color;
  }

  static _pausedColorTransition() {
    _startColorTransition(Colors.red);
    colorTransition.pause();
  }

  static Color transientColor;

  TrashBin({this.restoreWidget = doNothing});

  Color get baseColor =>
      colors[storedWidgets.length.clamp(0, colors.length - 1)];

  bool get active => transitionOf(colorAnimationKey) != null;

  bool alignmentWithinDeletionBounds(Alignment alignment) {
    return (alignment.x < limitAligment.x && alignment.y > limitAligment.y);
  }

  void putInRecycleBin(Widget widget) {
    _startColorTransition(baseColor);
    storedWidgets.add(widget);
  }

  void popLastDeleted() {
    _startColorTransition(baseColor);
    if (storedWidgets.isNotEmpty) {
      restoreWidget(storedWidgets.removeLast());
    }
  }

  void empty() {
    _startColorTransition(baseColor);
    storedWidgets.clear();
  }

  void activate() => _pausedColorTransition();

  void deactivateSmooth() => colorTransition.restart();

  void deactivate() => colorTransition.cancel();

  @override
  Widget build(BuildContext context) {
    Row(children: []);
    return Container(
      padding: EdgeInsets.all(15),
      child: GestureDetector(
        child: Icon(
          Icons.delete,
          size: 32,
          color: Color.lerp(transientColor, baseColor,
              transitionOf(colorAnimationKey) ?? 1.0),
        ),
        onTap: popLastDeleted,
        onLongPress: empty,
      ),
    );
  }
}

/// Shared dynamic values
class Dyn {
  static final dyn = DynMap();

  static TitleType get titleType => dyn[#title] ??= TitleType.tag;
  static set titleType(TitleType title) => dyn[#title] = title;

  static DragInteraction get dragWidget => dyn[#dragStartWidget];
  static set dragWidget(DragInteraction widget) =>
      dyn[#dragStartWidget] = widget;

  static List<Widget> get spiralingWidgets =>
      (dyn[#spiralImages] ??= List<Widget>()).cast<Widget>();
  static set spiralingWidgets(List<Widget> updatedList) =>
      dyn[#spiralImages] = updatedList;

  static AnimationTag get activeTag => dyn[#activeTag] ??= AnimationTag.all;
  static set activeTag(AnimationTag tag) => dyn[#activeTag] = tag;

  static bool get optionsBarPaused => dyn[#optionsBarPaused] ??= false;
  static set optionsBarPaused(bool paused) => dyn[#optionsBarPaused] = paused;

  static ExpandInteraction get expandingWidget => dyn[#expandingKey];
  static set expandingWidget(ExpandInteraction key) => dyn[#expandingKey] = key;
}

/// Constants and global scope variables.

const num imageHeight = 200;
const num imageWidth = 300;

final trashBin = TrashBin(restoreWidget: Spiral.addSpiralingWidget);

// This value is set from the UI interaction event handlers.
Size stackCanvasSize = Size.zero;

ThemeData theme;

const tagToName = {
  AnimationTag.all: 'All',
  AnimationTag.color: 'Color',
  AnimationTag.image: 'Image',
  AnimationTag.spiral: 'Spiral',
};

restartedTransientTransition(Object key,
    {durationMillis = 400, tag = AnimationTag.aesthetic}) {
  // Cancel the transition in case it already exists.
  TransitionGroup(key: key).cancel();
  // Create the transition.
  transition(durationMillis, key: key, tag: tag);
}

pausedTransientTransition(Object key,
    {durationMillis = 400, tag = AnimationTag.aesthetic}) {
  restartedTransientTransition(key, durationMillis: durationMillis, tag: tag);
  TransitionGroup(key: key).pause();
}

final selectableTags = tagToName.keys.toList();

tagAsName([tag]) => tagToName[tag ?? Dyn.activeTag];

doNothing([_]) {}

var _tagIndex = 0;

nextTag() {
  final tagIndex = (++_tagIndex) % selectableTags.length;
  var selectedTag = selectableTags[tagIndex];
  Dyn.optionsBarPaused = false;
  Dyn.activeTag = selectedTag;
  Dyn.titleType = TitleType.tag;
  PlaybackOptions.newTransitionGroup();
  // Restart the button animation in case it is on going.
  TransitionGroup(key: SelectAnimationButton.changeTagAnimationKey).restart();
  transition(500,
      key: SelectAnimationButton.changeTagAnimationKey,
      tag: AnimationTag.aesthetic);
}

cancelInteractiveStates() {
  ExpandInteraction.contractCurrent();
  Dyn.expandingWidget = null;
}

Color randomColor() {
  const blend = 0xFA000000;
  return Color(Random().nextInt(1 << 32) | blend);
}

Alignment offsetDeltaToAlignmentDelta(Offset offset, Size size) {
  final alignment =
      Alignment(offset.dx / size.width, offset.dy / size.height) * 2;
  return alignment;
}

enum AnimationTag {
  color,
  image,
  spiral,
  grow,
  aesthetic,
  all,
}

enum TitleType {
  tag,
  speed,
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

typedef DetailsVoidCallback = void Function([dynamic]);

/// Gesture detector that propagates the gesture to ancestor gesture detectors.
class DefererGestureDetector extends GestureDetector {
  final Widget child;

  DefererGestureDetector(
      {this.child,
      VoidCallback onTap,
      VoidCallback onDoubleTap,
      VoidCallback onLongPress,
      VoidCallback onLongPressUp,
      GestureDragDownCallback onPanDown,
      VoidCallback onPanCancel,
      GestureDragUpdateCallback onPanUpdate,
      GestureDragEndCallback onPanEnd})
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
