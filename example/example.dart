import 'package:flutter/material.dart';
import 'package:floop/floop.dart';
import 'package:http/http.dart' as http;

void main() {
  fetchAndUpdateImage();
  runApp(MaterialApp(title: 'Fetch image', home: ImageDisplay()));
}

// Dynamic values store.
class Dyn {
  static Widget get image => floop['image'];
  static set image(Widget widget) => floop['image'] = widget;
}

class ImageDisplay extends StatelessWidget with Floop {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Dyn.image == null
          ? Center(
              child: Text(
                'Loading...',
                textScaleFactor: 2,
              ),
            )
          : Align(
              alignment: Alignment(0, transition(2000, delayMillis: 800) - 1),
              child: Dyn.image),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.refresh),
        onPressed: () async {
          Dyn.image = null;
          await fetchAndUpdateImage();
          // Restarting context transitions after the new image has loaded
          // causes the new image to also transition from top to center.
          Transitions.restart(context: context);
        },
      ),
    );
  }
}

class TransitionImage extends FloopWidget {
  final Image image;
  const TransitionImage(this.image);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: Opacity(opacity: transition(1500), child: image),
      onTap: () async {
        if (await fetchAndUpdateImage()) {
          Transitions.restart(context: context);
        }
      },
    );
  }
}

bool _fetching = false;

Future<bool> fetchAndUpdateImage(
    [String url = 'https://picsum.photos/300/200']) async {
  if (_fetching) {
    return false;
  }
  try {
    _fetching = true; // locks the fetching function
    final response = await http.get(url);
    Dyn.image = TransitionImage(Image.memory(response.bodyBytes));
    return true;
  } finally {
    _fetching = false;
  }
}
