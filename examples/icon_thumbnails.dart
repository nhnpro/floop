import 'package:flutter/material.dart';
import 'package:floop/floop.dart';

import 'constants.dart';

// Create your own store from DynMap instead of using `floop` (it's the same)
Map<String, dynamic> store = DynMap();

void main() {
  store['iconWidgets'] = icons.map(createIconButton).toList();
  store['hide'] = true;
  runApp(MaterialApp(
      title: 'Icon display demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: IconThumbnails()));
}

createIconButton(IconData iconData, {double size = 40.0}) => IconButton(
      iconSize: size,
      icon: Icon(iconData),
      onPressed: () {
        bool shouldHide = !store['hide'] && store['selectedIcon'] == iconData;
        store['hide'] = shouldHide;
        store['selectedIcon'] = iconData;
      },
    );

class IconThumbnails extends StatelessWidget with Floop {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        store['hide'] ? Container() : DisplayBox(),
        Expanded(
            child: GridView.count(
                crossAxisCount: 4,
                padding: EdgeInsets.all(5.0),
                children: (store['iconWidgets'] as List).cast<Widget>()))
      ]),
    );
  }
}

class DisplayBox extends StatelessWidget with Floop {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300.0,
      child: Center(
        child: createIconButton(store['selectedIcon'], size: 200.0),
      ),
    );
  }
}
