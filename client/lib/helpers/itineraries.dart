import 'package:chest/helpers/auxiliar.dart';

class Itinerary {
  late String? _id, _author;
  List<PairLang> _labels = [], _comments = [];
  late List<PointItinerary> _points;
  late ItineraryType? _type;

  Itinerary(idIt, typeIt, labelIt, commentIt, authorIt, pointsIt) {
    if (idIt is String && idIt.isNotEmpty) {
      _id = idIt;
    } else {
      throw Exception('Proble with idIt');
    }

    if (typeIt is String) {
      switch (typeIt) {
        case "order":
          _type = ItineraryType.order;
          break;
        case "orderPoi":
          _type = ItineraryType.orderPoi;
          break;
        case "noOrder":
          _type = ItineraryType.noOrder;
          break;
        default:
          throw Exception("Problem with typeIt");
      }
    } else {
      throw Exception("Problem with typeIt");
    }

    if (labelIt is Map) {
      labelIt = [labelIt];
    }
    if (labelIt is List) {
      for (var element in labelIt) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _labels.add(PairLang(element['lang'], element['value']));
          } else {
            _labels.add(PairLang.withoutLang(element['value']));
          }
        } else {
          throw Exception('Problem with labelIt');
        }
      }
    } else {
      throw Exception('Problem with labelIt');
    }

    if (commentIt is Map) {
      commentIt = [commentIt];
    }
    if (commentIt is List) {
      for (var element in commentIt) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _comments.add(PairLang(element['lang'], element['value']));
          } else {
            _comments.add(PairLang.withoutLang(element['value']));
          }
        } else {
          throw Exception('Problem with commentIt');
        }
      }
    } else {
      throw Exception('Problem with commentIt');
    }

    if (authorIt is String && authorIt.isNotEmpty) {
      _author = authorIt;
    } else {
      throw Exception('Problem with authorIt');
    }

    if (pointsIt is PointItinerary) {
      pointsIt = [pointsIt];
    }
    if (pointsIt is List) {
      _points = [];
      for (var element in pointsIt) {
        if (element["idPoi"] && element["tasks"]) {
          if (element["altComment"]) {
            _points.add(PointItinerary(
                element["idPoi"], element["tasks"], element["altComment"]));
          } else {
            _points.add(
                PointItinerary.noComment(element["idPoi"], element["tasks"]));
          }
        } else {
          throw Exception('Problem with pointsIt');
        }
      }
    } else {
      throw Exception('Problem with pointsIt');
    }
  }

  Itinerary.withoutPoints(idIt, typeIt, labelIt, commentIt, authorIt) {
    if (idIt is String && idIt.isNotEmpty) {
      _id = idIt;
    } else {
      throw Exception('Proble with idIt');
    }

    if (typeIt is String) {
      switch (typeIt) {
        case "order":
          _type = ItineraryType.order;
          break;
        case "orderPoi":
          _type = ItineraryType.orderPoi;
          break;
        case "noOrder":
          _type = ItineraryType.noOrder;
          break;
        default:
          throw Exception("Problem with typeIt");
      }
    } else {
      throw Exception("Problem with typeIt");
    }

    if (labelIt is Map) {
      labelIt = [labelIt];
    }
    if (labelIt is List) {
      for (var element in labelIt) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _labels.add(PairLang(element['lang'], element['value']));
          } else {
            _labels.add(PairLang.withoutLang(element['value']));
          }
        } else {
          throw Exception('Problem with labelIt');
        }
      }
    } else {
      throw Exception('Problem with labelIt');
    }

    if (commentIt is Map) {
      commentIt = [commentIt];
    }
    if (commentIt is List) {
      for (var element in commentIt) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _comments.add(PairLang(element['lang'], element['value']));
          } else {
            _comments.add(PairLang.withoutLang(element['value']));
          }
        } else {
          throw Exception('Problem with commentIt');
        }
      }
    } else {
      throw Exception('Problem with commentIt');
    }

    if (authorIt is String && authorIt.isNotEmpty) {
      _author = authorIt;
    } else {
      throw Exception('Problem with authorIt');
    }

    _points = [];
  }

  Itinerary.empty() {
    _id = null;
    _author = null;
    _type = null;
    _points = [];
  }

  String? get id => _id;
  set id(String? idIt) {
    if (idIt is String && idIt.isNotEmpty) {
      _id = idIt;
    } else {
      throw Exception('Proble with idIt');
    }
  }

  String? get author => _author;
  set author(String? authorIt) {
    if (authorIt is String && authorIt.isNotEmpty) {
      _author = authorIt;
    } else {
      throw Exception('Problem with authorIt');
    }
  }

  List<PairLang> get labels => _labels;
  set labels(dynamic labelIt) {
    if (labelIt is Map) {
      labelIt = [labelIt];
    }
    if (labelIt is List) {
      _labels = [];
      for (var element in labelIt) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _labels.add(PairLang(element['lang'], element['value']));
          } else {
            _labels.add(PairLang.withoutLang(element['value']));
          }
        } else {
          throw Exception('Problem with labelIt');
        }
      }
    } else {
      throw Exception('Problem with labelIt');
    }
  }

  void addLabel(dynamic label) {
    if (label is Map && label.containsKey('value')) {
      if (label.containsKey('lang')) {
        _labels.add(PairLang(label['lang'], label['value']));
      } else {
        _labels.add(PairLang.withoutLang(label['value']));
      }
    } else {
      if (label is PairLang) {
        _labels.add(label);
      } else {
        throw Exception('Proble with label');
      }
    }
  }

  List<PairLang> get comments => _comments;
  set comments(dynamic commentsIt) {
    if (commentsIt is Map) {
      commentsIt = [commentsIt];
    }
    if (commentsIt is List) {
      _comments = [];
      for (var element in commentsIt) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _comments.add(PairLang(element['lang'], element['value']));
          } else {
            _comments.add(PairLang.withoutLang(element['value']));
          }
        } else {
          throw Exception('Problem with commentsIt');
        }
      }
    } else {
      throw Exception('Problem with commentsIt');
    }
  }

  void addComment(dynamic comment) {
    if (comment is Map && comment.containsKey('value')) {
      if (comment.containsKey('lang')) {
        _comments.add(PairLang(comment['lang'], comment['value']));
      } else {
        _comments.add(PairLang.withoutLang(comment['value']));
      }
    } else {
      if (comment is PairLang) {
        _comments.add(comment);
      } else {
        throw Exception('Proble with comment');
      }
    }
  }

  ItineraryType? get type => _type;
  set type(dynamic typeIt) {
    if (typeIt is String) {
      switch (typeIt) {
        case "order":
          _type = ItineraryType.order;
          break;
        case "orderPoi":
          _type = ItineraryType.orderPoi;
          break;
        case "noOrder":
          _type = ItineraryType.noOrder;
          break;
        default:
          throw Exception("Problem with typeIt");
      }
    } else {
      throw Exception("Problem with typeIt");
    }
  }

  List<PointItinerary> get points => _points;
  set points(dynamic pointsIt) {
    if (pointsIt is PointItinerary) {
      pointsIt = [pointsIt];
    }
    if (pointsIt is List) {
      _points = [];
      for (var element in pointsIt) {
        if (element is PointItinerary) {
          _points.add(element);
        } else {
          if (element["idPoi"] && element["tasks"]) {
            if (element["altComment"]) {
              _points.add(PointItinerary(
                  element["idPoi"], element["tasks"], element["altComment"]));
            } else {
              _points.add(
                  PointItinerary.noComment(element["idPoi"], element["tasks"]));
            }
          } else {
            throw Exception('Problem with pointsIt');
          }
        }
      }
    } else {
      throw Exception('Problem with pointsIt');
    }
  }

  void addPoints(PointItinerary pit) {
    _points.add(pit);
  }

  bool removePoint(PointItinerary pit) {
    _points.removeWhere((element) => element.idPoi == pit.idPoi);
    bool existe = false;
    for (var point in _points) {
      if (point.idPoi == pit.idPoi) {
        existe = true;
        break;
      }
    }
    return !existe;
  }

  String? labelLang(String lang) => _objLang('label', lang);
  String? commentLang(String lang) => _objLang('comment', lang);
  String? _objLang(String opt, String lang) {
    List<PairLang> pl;
    switch (opt) {
      case 'label':
        pl = _labels;
        break;
      case 'comment':
        pl = _comments;
        break;
      default:
        throw Exception('Problem in switch _objLang');
    }
    String auxiliar = pl.isEmpty ? '' : pl[0].value;
    for (var e in pl) {
      if (e.hasLang) {
        if (e.lang == lang) {
          return e.value;
        }
      }
    }
    return auxiliar;
  }

  List<Map<String, String>> comments2List() => _object2List(comments);

  List<Map<String, String>> labels2List() => _object2List(labels);

  List<Map<String, String>> _object2List(obj) {
    List<Map<String, String>> out = [];
    for (var element in obj) {
      out.add(element.toMap());
    }
    return out;
  }

  List<Map<String, dynamic>> points2List() {
    List<Map<String, dynamic>> out = [];
    for (PointItinerary point in points) {
      out.add(point.toMap());
    }
    return out;
  }
}

class PointItinerary {
  late String _id;
  late List<PairLang>? _comments;
  late List<String> _tasks;
  PointItinerary(idPoi, tasks, altComment) {
    if (idPoi is String && idPoi.isNotEmpty) {
      _id = idPoi;
    } else {
      throw Exception("Problem idPoi");
    }

    if (tasks is String) {
      tasks = [tasks];
    }
    if (tasks is List) {
      _tasks = [];
      for (var element in tasks) {
        if (element is String && element.isNotEmpty) {
          _tasks.add(element);
        } else {
          throw Exception('Problem with tasks');
        }
      }
    } else {
      throw Exception('Problem with tasks');
    }

    if (altComment != null) {
      if (altComment is Map) {
        altComment = [altComment];
      }
      if (altComment is List) {
        _comments = [];
        for (var element in altComment) {
          if (element is Map && element.containsKey('value')) {
            if (element.containsKey('lang')) {
              _comments!.add(PairLang(element['lang'], element['value']));
            } else {
              _comments!.add(PairLang.withoutLang(element['value']));
            }
          } else {
            throw Exception('Problem with altComment');
          }
        }
      } else {
        throw Exception('Problem with commentServer');
      }
    } else {
      _comments = null;
    }
  }

  PointItinerary.noComment(idPoi, tasks) {
    PointItinerary(idPoi, tasks, null);
  }

  PointItinerary.onlyPoi(idPoi) {
    if (idPoi is String && idPoi.isNotEmpty) {
      _id = idPoi;
    } else {
      throw Exception("Problem idPoi");
    }
    _tasks = [];
    _comments = null;
  }

  PointItinerary.poiAltComment(idPoi, altComment) {
    if (idPoi is String && idPoi.isNotEmpty) {
      _id = idPoi;
    } else {
      throw Exception("Problem idPoi");
    }
    _tasks = [];
    if (altComment != null) {
      if (altComment is Map) {
        altComment = [altComment];
      }
      if (altComment is List) {
        _comments = [];
        for (var element in altComment) {
          if (element is Map && element.containsKey('value')) {
            if (element.containsKey('lang')) {
              _comments!.add(PairLang(element['lang'], element['value']));
            } else {
              _comments!.add(PairLang.withoutLang(element['value']));
            }
          } else {
            throw Exception('Problem with altComment');
          }
        }
      } else {
        throw Exception('Problem with commentServer');
      }
    } else {
      _comments = null;
    }
  }

  String get idPoi => _id;
  List<PairLang>? get altComments => _comments;
  List<String> get tasks => _tasks;

  set idPoi(dynamic idPoi) {
    if (idPoi is String && idPoi.isNotEmpty) {
      _id = idPoi;
    } else {
      throw Exception("Problem idPoi");
    }
  }

  set altComments(dynamic altComment) {
    if (altComment != null) {
      if (altComment is Map) {
        altComment = [altComment];
      }
      if (altComment is List) {
        _comments = [];
        for (var element in altComment) {
          if (element is Map && element.containsKey('value')) {
            if (element.containsKey('lang')) {
              _comments!.add(PairLang(element['lang'], element['value']));
            } else {
              _comments!.add(PairLang.withoutLang(element['value']));
            }
          } else {
            throw Exception('Problem with altComment');
          }
        }
      } else {
        throw Exception('Problem with commentServer');
      }
    } else {
      _comments = null;
    }
  }

  set tasks(dynamic tasks) {
    if (tasks is String) {
      tasks = [tasks];
    }
    if (tasks is List) {
      _tasks = [];
      for (var element in tasks) {
        if (element is String && element.isNotEmpty) {
          _tasks.add(element);
        } else {
          throw Exception('Problem with tasks');
        }
      }
    } else {
      throw Exception('Problem with tasks');
    }
  }

  void addTask(String task) {
    _tasks.add(task);
  }

  void removeTask(String task) {
    _tasks.remove(task);
  }

  String? altCommentLang(String lang) {
    String? out;
    if (_comments != null) {
      for (var element in _comments!) {
        if (element.hasLang && element.lang == lang) {
          out = element.value;
          break;
        }
      }
    }
    return out;
  }

  Map<String, dynamic> toMap() => altComments != null
      ? {'poi': idPoi, 'tasks': tasks, 'altComment': _comment2List()}
      : {'poi': idPoi, 'tasks': tasks};

  List<Map<String, String>> _comment2List() {
    List<Map<String, String>> out = [];
    for (var element in altComments!) {
      out.add(element.toMap());
    }
    return out;
  }
}

enum ItineraryType { order, orderPoi, noOrder }
