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

final List<Widget> phraseWidgets = phrases
    .map((text) {
      final split = text.split(' – ');
      return PhraseWidget(Phrase(split[0], split[1]));
    })
    .toList()
    .cast<Widget>();

void main() {
  runApp(MaterialApp(
      title: 'Phrases',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Phrases()));
}

class Phrases extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Replay Text'),
      ),
      body: ListView(
        children: phraseWidgets,
      ),
    );
  }
}

class PhraseWidget extends FloopWidget {
  final Phrase phrase;
  const PhraseWidget(this.phrase);

  @override
  Widget buildWithFloop(BuildContext context) {
    final text = phrase.text;
    return ListTile(
      title: Text(transitionString(text, text.length * 200)),
      subtitle: Text(phrase.autor),
      onTap: () => Transitions.restart(context: context),
    );
  }
}
