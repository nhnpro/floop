import 'package:flutter/material.dart';
import 'package:floop/floop.dart';

void main() {
  floop['circle'] = {'x': 100.0, 'y': 100.0};
  floop['radius'] = 20.0;
  floop['animate'] = false;
  floop['scalePx'] = 2.0;
  runApp(
    MaterialApp(
      title: 'Task Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DragCircle()
    )
  );
}

class DragCircle extends StatelessWidget with Floop {

  final radiusMax;
  final radiusMin;
  
  DragCircle([this.radiusMin=10.0, this.radiusMax=35.0]);

  void animate() {
    if(!floop['animate']) return;
    double radius = floop['radius'] + floop['scalePx'];
    if(radius>radiusMax) {
      radius = radiusMax;
      floop['scalePx'] = -2.0;
    }
    else if(radius<radiusMin) {
      radius = radiusMax;
      floop['scalePx'] = 2.0;
    }
    floop['radius'] = radius;
  
    Future.delayed(
      Duration(milliseconds: 50),
      () => animate()
    );
  }

  void onDrag(DragUpdateDetails dragInfo) {
    Map position = floop['circle'];
    position['x'] = dragInfo.globalPosition.dx;
    position['y'] = dragInfo.globalPosition.dy;
  }

  void startAnimation([_]) {
    floop['animate'] = true;
    animate();
  }

  void stopAnimation([_]) {
    floop['animate'] = false;
  }

  @override
  Widget buildWithFloop(BuildContext context) {
    Map position = floop['circle'];
    
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            left: position['x'],  // equivalent to floop['circle']['x']
            top: position['y'],
            child: GestureDetector(
              child: CircleAvatar(
                backgroundColor: Colors.red,
                radius: floop['radius'],
              ),
              onPanDown: startAnimation,
              onPanUpdate: onDrag,
              onPanEnd: stopAnimation,
            )
          )
        ]
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.refresh),
        onPressed: () {
          floop['circle']['x'] = 100.0;
          floop['circle']['y'] = 100.0;
        },
      ),
    );
  }
}
