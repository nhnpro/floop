import 'package:floop/internals.dart';
import 'package:flutter/material.dart';
import 'package:floop/floop.dart';

const timeFactor = 4;

void main() {
  floop['inputText'] = 'Type text here';
  floop['text'] = 'Click me';
  runApp(MaterialApp(
      title: 'Clicker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TextReplay()));
}

class TextReplay extends StatelessWidget with Floop {
  @override
  Widget buildWithFloop(BuildContext context) {
    double height = 100;
    int ms = 1000;
    return Scaffold(
      appBar: AppBar(
        title: Text('Replay Text'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          // crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Opacity(
                opacity: transition(ms, delayMillis: ms),
                child: NumberBox('topBox')),
            // Align(
            //     alignment: Alignment.center,
            //     heightFactor: 1.5,
            //     child: Opacity(
            //         opacity: transition(ms, delayMillis: ms),
            //         child: NumberBox('topBox'))),
            // Expanded(
            // child:
            Align(
              alignment: Alignment.center,
              heightFactor: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                      opacity: transition(ms, delayMillis: ms),
                      child: NumberBox('leftBox')),
                  // Expanded(
                  // child:
                  Padding(
                    padding: EdgeInsets.all(15),
                    child: RaisedButton(
                      child: Text(
                        floop['text'],
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 40, color: Colors.red[700]),
                      ),
                      onPressed: () {
                        clearTransitions();
                        const String text = 'Click me';
                        transitionEval(ms * 2, (ratio) {
                          floop['text'] =
                              text.substring(0, (text.length * ratio).toInt());
                        });
                      },
                    ),
                  ),
                  // ),
                  // Center(
                  //     heightFactor: 1,
                  // child:
                  Opacity(
                      opacity: transition(ms, delayMillis: 2 * ms),
                      child: NumberBox.fromKey('rightBox')),
                ],
              ),
              // ),
              // ),
            ),
            Container(
                height: height,
                // alignment: Alignment.center,
                child: Opacity(
                    opacity: transition(ms, delayMillis: 3 * ms),
                    child: const NumberBox('bottomBox'))),
          ],
        ),
      ),
    );
  }
}

Map<Widget, int> map = Map();

class NumberBox extends FloopStatelessWidget {
  final String name;
  // final Key id;

  // factory NumberBox.fromId(id) {
  //   id = Key('number_box$id');
  //   var name = id.toString();
  //   floop.setValue(name, 0, false);
  //   return NumberBox(id, name);
  // }
  NumberBox.fromKey(key) : name = key.toString() {}

  const NumberBox(this.name);
  // : id = Key('number_box$id'),
  //   name = id.toString() {
  //     floop[name] ==null ? floop.setValue(name, 0, false) : null;
  //   }

  @override
  Widget buildWithFloop(BuildContext context) {
    // map[this] ??= 0;
    // map[this]++;
    // print('rebuild $name: ${map[this]}');
    floop[name] == null ? floop.setValue(name, 0, false) : null;
    // A builder is used although it's not necessary, it's added just to
    // demostranste how to make floop work with a [Builder].
    // The ObservedMap fields and transitions must be accessed outside of the
    // Builder, like it's done below.
    int ms = 500 * floop[name];
    transition(ms, key: Key(name), refreshRateMillis: 300);
    return Builder(
      builder: (context) => Padding(
        padding: EdgeInsets.all(15),
        child: GestureDetector(
          child: Text(
            (transition(null, key: Key(name)) * floop[name]).toInt().toString(),
            style: TextStyle(fontSize: 40, color: Colors.amber[700]),
          ),
          onTap: () {
            floop[name]++;
            clearTransitions(key: Key(name));
          },
          onDoubleTap: () => floop[name] = 0,
        ),
      ),
    );
  }
}

class Clicker extends StatelessWidget with Floop {
  @override
  Widget buildWithFloop(BuildContext context) {
    double widthFactor = 50;
    int ms = 800;
    // floop['text'];
    // floop['border'];
    // floop['inputText'];
    // floop['inputText'];
    transition(2000, key: Key('k'));
    // return Builder(builder: (context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Replay Text'),
      ),
      body: Center(
        // child: LayoutBuilder(
        //     builder: (BuildContext context, BoxConstraints constraints) {
        //   return Container(
        //     height: constraints.maxHeight,
        child: Column(
          children: [
            Container(
              alignment: Alignment.center,
              width: 300,
              height: 100,
              child: TextField(
                decoration: InputDecoration.collapsed(
                  hintText: 'Type text here',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20),
                maxLines: 1,
                onChanged: (inputText) => floop['inputText'] = inputText,
                onEditingComplete: () => floop['text'] = floop['inputText'],
              ),
            ),
            // Container(), // child: LinearGradient()
            // Expanded(
            // child: Align(
            Align(
              // alignment: Alignment(0, 0),
              child: Container(
                decoration: BoxDecoration(
                  border: floop['border'] ??
                      // Border.all( color: Colors.blue[900],
                      // width: widthFactor * transition(null, key: Key('k'))),
                      // Border.merge(
                      Border(
                        left: BorderSide(
                          color: Colors.blue[900],
                          width: widthFactor * transition(ms),
                        ),
                        top: BorderSide(
                            color: Colors.blue[900],
                            width:
                                widthFactor * transition(ms, delayMillis: ms)),
                        right: BorderSide(
                            color: Colors.blue[900],
                            width: widthFactor *
                                transition(ms, delayMillis: 2 * ms)),
                        bottom: BorderSide(
                            color: Colors.blue[900],
                            width: widthFactor *
                                transition(ms, delayMillis: 3 * ms)),
                      ),
                ),
                constraints: BoxConstraints(maxWidth: 300),
                child: GestureDetector(
                  child: Text(
                    floop['text'],
                    style: TextStyle(fontSize: 40, color: Colors.red[700]),
                  ),
                  onTap: () {
                    if (floop['border'] != null) {
                      clearTransitions();
                      floop['border'] = null;
                      String text = floop['inputText'];
                      transitionEval(ms * 3, (ratio) {
                        floop['text'] =
                            text.substring(0, (text.length * ratio).toInt());
                      });
                    } else {
                      floop['border'] =
                          const Border.fromBorderSide(BorderSide.none);
                    }
                  },
                ),
              ),
            ),
            // ),
          ],
        ),
        // );
        // }),
      ),
      // floatingActionButton: FloatingActionButton(
      //     child:
      //         Icon(floop['border'] != null ? Icons.play_arrow : Icons.stop),
      //     onPressed: () {
      //       if(floop['border'] != null) {
      //         clearTransitions();
      //         floop['border'] = floop['border'] == null
      //           ? const Border.fromBorderSide(BorderSide.none)
      //           : null;
      //       }

      //     }),
    );
    // });
  }
}
