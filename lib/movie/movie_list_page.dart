import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_app_profile/movie/movie_item_model.dart';


class EventMovieListPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return EventMovieListPageState();
  }
}

class EventMovieListPageState extends State<EventMovieListPage> {
  List<MovieItem> movieList = [];

  void _fetchData() async {
    movieList = await Future.delayed(Duration(milliseconds: 800), (){
      List<MovieItem> temp = [];
      String body = '{ "list": [{ "name": "Hello, shanghai"}, {"name": "hello, beijing"},{"name": "hello, tianjin"}, {"name": "hello, chengdu"}, {"name": "hello, beijing"},{"name": "hello, tianjin"}, {"name": "hello, chengdu"}, {"name": "hello, beijing"},{"name": "hello, tianjin"}, {"name": "hello, chengdu"}, {"name": "hello, beijing"},{"name": "hello, tianjin"}, {"name": "hello, chengdu"}, {"name": "hello, beijing"},{"name": "hello, tianjin"}, {"name": "hello, chengdu"}]}';
      Map<String, dynamic> parsedJson = json.decode(body);
      for (int i = 0; i < parsedJson['list'].length; i++) {
        Map<String, dynamic> movieItemJson = parsedJson['list'][i];
        MovieItem result = MovieItem(movieItemJson['name'] as String);
        temp.add(result);
      }
      return temp;
    });
    setState(() {
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Popular Movies'),
        ),
        body: buildList(),
        floatingActionButton: FloatingActionButton(
          child: Icon(Icons.list),
          onPressed: () async {
          },
        ));
  }

  Widget buildList() {
    if(movieList.isEmpty) {
       return Text("nothing");
    }
    return ListView.builder(
        itemCount: movieList.length,
        itemBuilder: (BuildContext context, int index) {
          MovieItem movieItem = movieList[index];
          return ListTile(
            title: Text(movieItem.name),
            trailing: new MovieItemWidget(movieItem),
          );
        });
  }


}

class MovieItemWidget extends StatefulWidget {

  MovieItem movieItem;

  MovieItemWidget(this.movieItem);

  @override
  State<StatefulWidget> createState() {
    return MovieItemWidgetState(movieItem);
  }
}

class MovieItemWidgetState extends State<MovieItemWidget> {
  
  MovieItem movieItem;
  
  MovieItemWidgetState(this.movieItem);

  @override
  Widget build(BuildContext context) {
    Timeline.startSync("item build wangkai");
    sleep(Duration(milliseconds: 20));
    Timeline.finishSync();
    return GestureDetector(
      onTap: () {
        movieItem.selected = !movieItem.selected;
        // TODO
        setState(() {});
      },
      child: Icon(movieItem.selected ? Icons.star : Icons.star_border),
    );
  }
}