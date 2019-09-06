import 'package:flutter/material.dart';
import 'package:floop/floop.dart';
import 'package:http/http.dart' as http;

void main() {
  fetchImage();
  runApp(MaterialApp(title: 'Fetch image', home: ImageDisplay()));
}

var _fetching = false;

fetchImage([String url = 'https://picsum.photos/300/200']) async {
  if (_fetching) {
    return null;
  }
  _fetching = true; // locks the fetching function
  floop['image'] = null; // Set to null while awaiting the response
  final response = await http.get(url);
  _fetching = false;
  return TransitionImage(Image.memory(response.bodyBytes));
}

// `extends FloopWidget` is equivalent to `...StatelessWidget with Floop`.
class TransitionImage extends FloopWidget {
  final Image image;
  const TransitionImage(this.image);

  @override
  Widget build(BuildContext context) {
    // Opacity transitions from 0 to 1 in 1.5 seconds.
    return Opacity(opacity: transition(1500), child: image);
  }
}

class ImageDisplay extends StatelessWidget with Floop {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // `floop['image']` is null while fetching an image. When the
      // imaged is downloaded, an image widget is stored on `floop['image']`
      // and the widget automatically updates.
      body: floop['image'] == null
          ? Center(
              child: Text(
                'Loading...',
                textScaleFactor: 2,
              ),
            )
          : Align(
              alignment: Alignment(0, transition(2000, delayMillis: 800) - 1),
              child: floop['image']),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.refresh),
        onPressed: () async {
          floop['image'] = null;
          floop['image'] = await fetchImage();
          // Restarting context transitions after the new image has loaded
          // causes the new image to also transition from top to center.
          Transitions.restart(context: context);
        },
      ),
    );
  }
}

// Same example but using a class that access the values on `floop`. Serves
// as a model to organize the code in a big app. Shared dynamic values, like
// user data can be stored in a class with static values and access `floop`
// only from there.

class DynamicValues {
  static Widget get image => floop['image'];
  static set image(Widget widget) => floop['image'] = widget;
}

class ImageDisplay2 extends StatelessWidget with Floop {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DynamicValues.image == null
          ? Center(
              child: Text(
                'Loading...',
                textScaleFactor: 2,
              ),
            )
          : Align(
              alignment: Alignment(0, transition(2000, delayMillis: 800) - 1),
              child: DynamicValues.image),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.refresh),
        onPressed: () async {
          DynamicValues.image = null;
          DynamicValues.image = await fetchImage();
          // Restarting context transitions after the new image has loaded
          // causes the new image to also transition from top to center.
          Transitions.restart(context: context);
        },
      ),
    );
  }
}
