import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:floop/floop.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lorem Picsum Images Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DisplayImages(),
    );
  }
}

class DisplayImages extends StatelessWidget with Floop {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Interactive Images List')),
      body: floop['loading'] != true && floop['images'] == null
          ? Center(
              child: Container(
              width: 300,
              child: Text(
                'Press the cloud to download the images list',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ))
          : floop['loading'] == true
              ? Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 50,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : ListView(
                  children: floop['images']
                      .map((im) => ImageItem(im))
                      .toList()
                      .cast<Widget>()),
      floatingActionButton: FloatingActionButton(
        child: Icon(
            floop['images'] == null ? Icons.cloud_download : Icons.refresh),
        onPressed: () async {
          if (floop['images'] == null) {
            floop['loading'] = true;
            var response = await http.get('https://picsum.photos/v2/list');
            floop['images'] = json.decode(response.body);
          } else {
            floop['images'] = null;
          }
          floop['loading'] = false;
        },
      ),
    );
  }
}

class ImageItem extends StatelessWidget with Floop {
  final Map image;

  ImageItem(this.image) {
    image['display'] = false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          child: ListTile(
              title: Text(image['author']),
              subtitle: Text(image['url']),
              selected: image['display'],
              leading: CircleAvatar(
                child: Text(
                  image['id'],
                ),
              ),
              onTap: () {
                if (image['display']) {
                  image['display'] = false;
                } else {
                  image['display'] = true;
                }
              }),
          decoration: BoxDecoration(
            color: image['display'] ? Colors.red : Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(1.0),
          ),
        ),
        !image['display']
            ? Container()
            : Image.network(
                image['download_url'],
                height: 300,
              ),
      ],
    );
  }
}
