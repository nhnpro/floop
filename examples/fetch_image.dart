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
    return;
  }
  _fetching = true;
  floop['image'] = null; // Set to null while awaiting the response
  final response = await http.get(url);

  /// The image is stored only when this is the last call to fetchImage,
  floop['image'] = TransitionImage(Image.memory(response.bodyBytes));
  _fetching = false;
}

// `extends FloopWidget` is equivalent to `StatelessWidget with Floop`.
class TransitionImage extends FloopWidget {
  final Image image;
  const TransitionImage(this.image);

  @override
  Widget buildWithFloop(BuildContext context) {
    return Opacity(opacity: transition(1500), child: image);
  }
}

class ImageDisplay extends StatelessWidget with Floop {
  @override
  Widget buildWithFloop(BuildContext context) {
    return Scaffold(
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
          await fetchImage();
          Transitions.restart(context: context);
        },
      ),
    );
  }
}
