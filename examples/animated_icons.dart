import 'dart:math';

import 'package:flutter/material.dart';
import 'package:floop/floop.dart';

import 'constants.dart';

// Create your own store from ObservedMap instead of using `floop` (it's the same)
Map<String, dynamic> store = ObservedMap();
List<Repeater> repeaters = [];

void main() {
  initializeStoreValues();
  initializeRepeaters();
  runApp(MaterialApp(
      title: 'Animated Icons',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: IconThumbnails()));
}

initializeStoreValues() {
  // The following map values will update widgets on change
  store['showBig'] = false;
  store['animate'] = false;
  store['iconsShift'] = 0;
  store['colorOffset'] = 0;
  store['angle'] = 0.0;
  store['speedUpPressed'] = false;
  store['speedDownPressed'] = false;

  // The following values are used for general storage purposes
  store['rotationSpeed'] = 0.1;
  store['iconWidgets'] = icons.map((ic) => AnimatedIconButton(ic)).toList();
}

initializeRepeaters() {
  // Remember to have a dispose method to stop the Repeaters in the case of
  // an app where the window can change.
  repeaters = [
    Repeater((Repeater per) => store['angle'] += store['rotationSpeed']),
    Repeater((Repeater per) =>
        store['colorOffset'] = per.periodicLinearInt(5000, 256)),
    Repeater(
        (Repeater per) => store['iconsShift'] =
            per.periodicLinearInt(1000 * 1000, icons.length),
        200),
  ];
  store['speedUp'] = Repeater(
      (_) => store['rotationSpeed'] =
          min(0.4, (store['rotationSpeed'] as double) + 0.01),
      100);
  store['speedDown'] = Repeater(
      (_) => store['rotationSpeed'] =
          max(-0.4, (store['rotationSpeed'] as double) - 0.01),
      100);
}

shiftRight(List list, int shift) {
  return list.sublist(list.length - shift) +
      list.sublist(0, list.length - shift);
}

startAnimations() {
  store['animate'] = true;
  for (Repeater rep in repeaters) {
    rep.start();
  }
}

stopAnimations() {
  store['animate'] = false;
  repeaters.forEach((Repeater rep) => rep.stop());
}

rotateWidget(Widget widget, [speed = 1]) {
  return Transform.rotate(angle: store['angle'] ?? 0, child: widget);
}

class IconThumbnails extends StatelessWidget with Floop {
  reset() {
    for (Repeater rep in repeaters) {
      rep.reset();
    }
    (store['speedUp'] as Repeater).reset();
    (store['speedDown'] as Repeater).reset();
    initializeStoreValues();
  }

  @override
  Widget buildWithFloop(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        store['showBig'] ? DisplayBox() : Container(),
        Expanded(
            child: GridView.count(
                crossAxisCount: 4,
                padding: EdgeInsets.all(5.0),
                children:
                    shiftRight(store['iconWidgets'], store['iconsShift'] ?? 0)
                        .cast<Widget>()))
      ]),
      bottomNavigationBar: BottomNavigationBar(
        iconSize: 32,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            title: Container(),
            icon: IconButton(
              icon: Icon(
                store['animate'] ? Icons.pause : Icons.play_arrow,
              ),
              iconSize: 32,
              onPressed: store['animate'] ? stopAnimations : startAnimations,
            ),
          ),
          BottomNavigationBarItem(
            title: Container(),
            icon: GestureDetector(
              child: Icon(Icons.fast_rewind,
                  color: store['speedDownPressed']
                      ? Colors.red
                      : Colors.indigoAccent),
              onTap: () => store['rotationSpeed'] -= 0.1,
              onLongPress: () {
                (store['speedDown'] as Repeater).start();
                store['speedDownPressed'] = true;
              },
              onLongPressUp: () {
                (store['speedDown'] as Repeater).stop();
                store['speedDownPressed'] = false;
              },
            ),
          ),
          BottomNavigationBarItem(
            title: Container(),
            icon: GestureDetector(
              child: Icon(
                Icons.fast_forward,
                color:
                    store['speedUpPressed'] ? Colors.red : Colors.indigoAccent,
              ),
              onTap: () => store['rotationSpeed'] += 0.1,
              onLongPress: () {
                (store['speedUp'] as Repeater).start();
                store['speedUpPressed'] = true;
              },
              onLongPressUp: () {
                (store['speedUp'] as Repeater).stop();
                store['speedUpPressed'] = false;
              },
            ),
          ),
          BottomNavigationBarItem(
            title: Container(),
            icon: IconButton(
              icon: Icon(Icons.refresh),
              iconSize: 32,
              onPressed: reset,
            ),
          ),
        ],
      ),
    );
  }
}

class DisplayBox extends StatelessWidget with Floop {
  @override
  Widget buildWithFloop(BuildContext context) {
    return Container(
      height: 300.0,
      child: Center(
        child: rotateWidget(
            AnimatedIconButton(store['selectedIcon'], size: 200.0), 2),
      ),
    );
  }
}

class AnimatedIconButton extends StatelessWidget with Floop {
  final IconData iconData;
  final double size;

  const AnimatedIconButton(this.iconData, {this.size = 40.0});

  updateAnimations() {
    var sameIcon = store['selectedIcon'] == iconData;
    var animationRunning = store['animate'];
    var shouldHide = !animationRunning && sameIcon && store['showBig'];
    var shouldStartAnimation =
        (!animationRunning && !shouldHide) || !store['showBig'];
    var shouldAnimate = !sameIcon || !store['showBig'];

    if (shouldStartAnimation) startAnimations();
    if (!shouldAnimate) stopAnimations();
    store['showBig'] = !shouldHide;
    store['selectedIcon'] = iconData;
  }

  @override
  Widget buildWithFloop(BuildContext context) {
    int c = store['colorOffset'] ?? 0;
    var color = store['animate']
        ? Color.fromRGBO(c + 90, c + 180, Random().nextInt(256), 1.0)
        : IconTheme.of(context).color;
    return IconButton(
      color: iconData == icons[0] ? Colors.red : color,
      splashColor: Colors.blue,
      iconSize: size,
      icon: Icon(iconData),
      onPressed: updateAnimations,
    );
  }
}
