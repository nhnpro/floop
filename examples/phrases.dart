import 'package:flutter/material.dart';
import 'package:floop/floop.dart';
import 'package:floop/transition.dart';

class Phrase {
  String text, autor;
  Phrase(this.text, [this.autor = 'Unknown']);
}

const phrases = [
  'Love For All, Hatred For None. – Khalifatul Masih III',
  'Change the world by being yourself. – Amy Poehler',
  'Every moment is a fresh beginning. – T.S Eliot',
  'Never regret anything that made you smile. – Mark Twain',
  'Die with memories, not dreams. – Unknown',
  'Aspire to inspire before we expire. – Unknown',
  'Everything you can imagine is real. – Pablo Picasso',
  'Simplicity is the ultimate sophistication. – Leonardo da Vinci',
  'Whatever you do, do it well. – Walt Disney',
  'What we think, we become. – Buddha',
];

final List<Widget> phraseWidgets = phrases.map((text) {
  final split = text.split(' – ');
  return PhraseWidget(Phrase(split[0], split[1]), key: Key(text));
}).toList();

void main() {
  floop['phraseWidgets'] = phraseWidgets;
  runApp(MaterialApp(
      title: 'Phrases',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Phrases()));
}

class Phrases extends StatelessWidget with Floop {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inspiring Phrases'),
      ),
      body: ListView(
        children: floop['phraseWidgets'].cast<Widget>(),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.shuffle),
        onPressed: () {
          // When setting a value of type [List] in `floop`, it always gets
          // copied, therefore `floop['phraseWidgets']` is never the same
          // object as `phraseWidgets`.
          Transitions.restart();
          floop['phraseWidgets'] = phraseWidgets..shuffle();
        },
      ),
    );
  }
}

class PhraseWidget extends FloopWidget {
  final Phrase phrase;
  const PhraseWidget(this.phrase, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final text = phrase.text;
    return ListTile(
      title: Text(
        transitionString(text, text.length * 100),
        style: TextStyle(
            color: Color.lerp(
                Colors.red, Colors.black, transition(text.length * 100))),
      ),
      subtitle: Text(phrase.autor),
      onTap: () {
        // Transitions.restart(context: context);
        Transitions.shiftTime(shiftMillis: 300, context: context);
      },
      onLongPress: () => Transitions.restart(context: context),
    );
  }
}
