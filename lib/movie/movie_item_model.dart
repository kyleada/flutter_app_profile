
class MovieItem {
  String name;
  bool _selected = false;

  MovieItem(this.name);

  bool get selected => _selected;

  set selected(bool value) {
    _selected = value;
  }
}