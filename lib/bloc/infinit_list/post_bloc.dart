import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:flutter_infinite_list/bloc/infinit_list/bloc.dart';
import 'package:flutter_infinite_list/models/post.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

class PostBloc extends Bloc<PostEvent, PostState> {
  final http.Client httpClient;

  PostBloc({@required this.httpClient});

  @override
  get initialState => PostUninitialized();

  @override
  Stream<PostState> transform(Stream<PostEvent> events,
      Stream<PostState> Function(PostEvent event) next) {
    return super.transform(
      (events as Observable<PostEvent>)
          .debounceTime(Duration(microseconds: 500)),
      next,
    );
  }

  @override
  Stream<PostState> mapEventToState(PostEvent event) async* {
    if (event is Fetch && !_hasReachedMax(currentState)) {
      print("mapEventToState=$currentState");
      try {
        if (currentState is PostUninitialized) {
          final posts = await _fetchPosts(0, 20);
          yield PostLoaded(posts: posts, hasReachedMax: false);
        }
        if (currentState is PostLoaded) {
          PostLoaded state = currentState as PostLoaded;
          final posts = await _fetchPosts(state.posts.length, 20);
          yield posts.isEmpty
              ? state.copyWith(hasReachedMax: true)
              : PostLoaded(
                  posts: state.posts + posts,
                  hasReachedMax: false,
                );
        }
      } catch (_) {
        yield PostError();
      }
    }
  }

  bool _hasReachedMax(PostState state) =>
      state is PostLoaded && state.hasReachedMax;

  Future<List<Post>> _fetchPosts(int startIndex, int limit) async {
    final response = await httpClient.get(
        'https://jsonplaceholder.typicode.com/posts?_start=$startIndex&_limit=$limit');

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      return data.map((rawPost) {
        return Post(
          id: rawPost['id'],
          title: rawPost['title'],
          body: rawPost['body'],
        );
      }).toList();
    } else {
      throw Exception('error fetching posts');
    }
  }
}
