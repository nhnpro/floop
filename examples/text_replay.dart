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
      home: Clicker()));
}

class Clicker extends StatelessWidget with Floop {
  @override
  Widget buildWithFloop(BuildContext context) {
    double widthFactor = 50;
    int ms = 800;
    // floop['text'];
    // floop['noBorder'];
    // floop['inputText'];
    // floop['inputText'];
    transition(2000, key: Key('k'));
    // return Builder(builder: (context) {
    return Scaffold(
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
              height: 200,
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
            Expanded(
              child: Align(
                // Align(
                // alignment: Alignment(0, 0),
                child: Container(
                  decoration: BoxDecoration(
                    border: floop['noBorder'] ??
                        // Border.all(
                        //     color: Colors.blue[900],
                        //     width: widthFactor * transition(null, key: Key('k'))),
                        Border(
                          left: BorderSide(
                            color: Colors.blue[900],
                            width: widthFactor * transition(ms),
                          ),
                          top: BorderSide(
                              color: Colors.blue[900],
                              width: widthFactor *
                                  transition(ms, delayMillis: ms)),
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
                      if (floop['noBorder'] != null) {
                        clearTransitions();
                        floop['noBorder'] = null;
                        String text = floop['text'];
                        transitionEval(ms * 3, (ratio) {
                          floop['text'] =
                              text.substring(0, (text.length * ratio).toInt());
                        });
                      } else {
                        floop['noBorder'] =
                            const Border.fromBorderSide(BorderSide.none);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        // );
        // }),
      ),
      // floatingActionButton: FloatingActionButton(
      //     child:
      //         Icon(floop['noBorder'] != null ? Icons.play_arrow : Icons.stop),
      //     onPressed: () {
      //       if(floop['noBorder'] != null) {
      //         clearTransitions();
      //         floop['noBorder'] = floop['noBorder'] == null
      //           ? const Border.fromBorderSide(BorderSide.none)
      //           : null;
      //       }

      //     }),
    );
    // });
  }
}

class TransitionSideBox extends FloopStatelessWidget {
  @override
  Widget buildWithFloop(BuildContext context) {
    // TODO: implement buildWithFloop
    return null;
  }
}
