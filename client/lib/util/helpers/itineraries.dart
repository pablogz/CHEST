import 'package:chest/util/config.dart';
import 'package:chest/util/exceptions.dart';
import 'package:chest/util/helpers/pair.dart';
import 'package:chest/util/helpers/feature.dart';
import 'package:chest/util/helpers/tasks.dart';
import 'package:chest/util/helpers/track.dart';
import 'package:flutter/material.dart';

class Itinerary {
  late String? _id, _author;
  List<PairLang> _labels = [], _comments = [];
  late List<PointItinerary> _points;
  late ItineraryType? _type;
  late List<Task> _taskIt;
  Track? _track;

  Itinerary(dynamic data) {
    if (data is Map) {
      if (data.containsKey('id') &&
          data['id'] is String &&
          (data['id'] as String).isNotEmpty) {
        _id = (data['id'] as String);
      } else {
        throw ItineraryException('id');
      }

      if (data.containsKey('type') && data['type'] is String) {
        _type = _string2Type(data['type']);
      } else {
        throw ItineraryException('type');
      }

      if (data.containsKey('label')) {
        if (data['label'] is Map) {
          data['label'] = [data['label']];
        }

        if (data['label'] is List) {
          for (var element in (data['label'] as List)) {
            if (element is Map && element.containsKey('value')) {
              if (element.containsKey('lang')) {
                _labels.add(PairLang(element['lang'], element['value']));
              } else {
                _labels.add(PairLang.withoutLang(element['value']));
              }
            } else {
              throw ItineraryException('label');
            }
          }
        } else {
          throw ItineraryException('label');
        }
      } else {
        throw ItineraryException('label');
      }

      if (data['comment'] is List) {
        for (var element in (data['comment'] as List)) {
          if (element is Map && element.containsKey('value')) {
            if (element.containsKey('lang')) {
              _comments.add(PairLang(element['lang'], element['value']));
            } else {
              _comments.add(PairLang.withoutLang(element['value']));
            }
          } else {
            throw ItineraryException('comment');
          }
        }
      } else {
        throw ItineraryException('comment');
      }

      if (data.containsKey('author') && data['author'] is String) {
        _author = data['author'];
      } else {
        throw ItineraryException('author');
      }

      if (data.containsKey('points') && data['points'] is PointItinerary) {
        data['points'] = [data['points']];
      }

      if (data.containsKey('points') && data['points'] is List) {
        _points = [];
        for (var element in data['points']) {
          _points.add(PointItinerary(element));
        }
      } else {
        _points = [];
      }

      if (data.containsKey('track') && data['track'] is Map) {
        _track = Track.server(data['track']);
      } else {
        _track = null;
      }

      _taskIt = [];
      if (data.containsKey('tasksIt') && data['tasksIt'] is List) {
        for (var element in data['tasksIt']) {
          try {
            _taskIt.add(Task(
              element,
              containerType: ContainerTask.itinerary,
              idContainer: _id,
            ));
          } catch (error) {
            if (Config.development) debugPrint(error.toString());
          }
        }
      }
    } else {
      throw ItineraryException('it is not a Map');
    }
  }

  Itinerary.empty() {
    _id = null;
    _author = null;
    _type = null;
    _track = null;
    _points = [];
    _taskIt = [];
  }

  String? get id => _id;
  set id(String? idIt) {
    if (idIt is String && idIt.isNotEmpty) {
      _id = idIt;
    } else {
      throw ItineraryException('id');
    }
  }

  String? get author => _author;
  set author(String? authorIt) {
    if (authorIt is String && authorIt.isNotEmpty) {
      _author = authorIt;
    } else {
      throw ItineraryException('author');
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
          throw ItineraryException('label');
        }
      }
    } else {
      throw ItineraryException('label');
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
        throw ItineraryException('label');
      }
    }
  }

  String getALabel({String? lang}) {
    String out = '';
    if (lang != null) {
      out = labelLang(lang) != null ? labelLang(lang)! : '';
    }
    if (out.isEmpty) {
      out = labelLang('en') != null
          ? labelLang('en')!
          : _labels.isNotEmpty
              ? _labels.first.value
              : '';
    }
    return out;
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
          throw ItineraryException('comments');
        }
      }
    } else {
      throw ItineraryException('comments');
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
        throw ItineraryException('comment');
      }
    }
  }

  String getAComment({String? lang}) {
    String out = '';
    if (lang != null) {
      out = commentLang(lang) != null ? commentLang(lang)! : '';
    }
    if (out.isEmpty) {
      out = commentLang('en') != null
          ? commentLang('en')!
          : _comments.isNotEmpty
              ? _comments.first.value
              : '';
    }
    return out;
  }

  ItineraryType? get type => _type;
  set type(dynamic typeIt) {
    if (typeIt is String) {
      _type = _string2Type(typeIt);
    } else {
      if (typeIt is ItineraryType) {
        _type = typeIt;
      } else {
        throw ItineraryException("type");
      }
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
          if (element is Map &&
              element.containsKey('id') &&
              element.containsKey('tasks')) {
            _points.add(PointItinerary(element));
          } else {
            throw ItineraryException('points map ${element.toString()}');
          }
        }
      }
    } else {
      throw ItineraryException('points');
    }
  }

  void addPoints(PointItinerary pit) {
    _points.add(pit);
  }

  bool removePoint(PointItinerary pit) {
    _points.removeWhere((element) => element.id == pit.id);
    bool existe = false;
    for (var point in _points) {
      if (point.id == pit.id) {
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

  List<Map<String, String>> _comments2List() => _object2List(comments);

  List<Map<String, String>> _labels2List() => _object2List(labels);

  List<Map<String, String>> _object2List(obj) {
    List<Map<String, String>> out = [];
    for (var element in obj) {
      out.add(element.toMap());
    }
    return out;
  }

  List<Map<String, dynamic>> _points2List() {
    List<Map<String, dynamic>> out = [];
    for (PointItinerary point in points) {
      out.add(point.toMap());
    }
    return out;
  }

  Track? get track => _track;
  set track(Track? track) {
    _track = track;
  }

  void addTask(Task task) {
    _taskIt.add(task);
  }

  bool removeTask(Task task) {
    return _taskIt.remove(task);
  }

  List<Task> get tasks => _taskIt;

  @override
  String toString() {
    return toMap().toString();
  }

  Map<String, dynamic> toMap() {
    Map<String, dynamic> out = {
      'type': _type2String(type!),
      'label': _labels2List(),
      'comment': _comments2List(),
      'points': _points2List()
    };
    if (track != null) {
      out['track'] = track!.toMap()['track'];
    }
    if (tasks.isNotEmpty) {
      out['tasks'] = [];
      for (Task t in tasks) {
        (out['tasks'] as List).add(t.toMap());
      }
    }
    return out;
  }

  String _type2String(ItineraryType type) {
    Map<ItineraryType, String> lst = {
      ItineraryType.bag: 'Bag',
      ItineraryType.bagSTsListTasks: 'BagSTsListTasks',
      ItineraryType.list: 'List',
      ItineraryType.listSTsBagTasks: 'ListSTsBagTasks'
    };
    return lst.containsKey(type)
        ? '${lst[type]}Itinerary'
        : throw ItineraryException('ItineraryType not allow');
  }

  ItineraryType _string2Type(String type) {
    Map<String, ItineraryType> lst = {
      'Bag': ItineraryType.bag,
      'BagSTsListTasks': ItineraryType.bagSTsListTasks,
      'List': ItineraryType.list,
      'ListSTsBagTasks': ItineraryType.listSTsBagTasks
    };
    type = type.split('/').last;
    type = type.split('mo:').last;
    return lst.containsKey(type)
        ? lst[type]!
        : throw ItineraryException('String not allow');
  }
}

class PointItinerary {
  late String _id;
  late List<PairLang>? _comments;
  late List<String> _tasks;
  late Feature _feature;
  late List<Task> _lstTasks;
  late bool _hasFeature, _hasLstTasks;

  PointItinerary(dynamic data) {
    if (data is Map) {
      if (data.containsKey('id') &&
          data['id'] is String &&
          (data['id'] as String).isNotEmpty) {
        _id = (data['id'] as String);
      } else {
        throw PointItineraryException('id');
      }

      if (data.containsKey('tasks') && data['tasks'] is String) {
        data['tasks'] = [data['tasks']];
      }
      if (data.containsKey('tasks') && data['tasks'] is List) {
        _tasks = [];
        for (var element in data['tasks']) {
          if (element is String && element.isNotEmpty) {
            _tasks.add(element);
          } else {
            throw PointItineraryException('task');
          }
        }
      } else {
        _tasks = [];
      }

      if (data.containsKey('altComment')) {
        if (data['altComment'] is Map) {
          data['altComment'] = [data['altComment']];
        }
        if (data['altComment'] is List) {
          _comments = [];
          for (var element in data['altComment']) {
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
        }
      } else {
        _comments = null;
      }

      _lstTasks = [];

      _hasFeature = false;
      _hasLstTasks = false;
    } else {
      throw PointItineraryException('It is not a map');
    }
  }

  String get id => _id;
  set id(dynamic id) {
    if (id is String && id.isNotEmpty) {
      _id = id;
    } else {
      throw PointItineraryException("Problem idFeature");
    }
  }

  List<PairLang>? get altComments => _comments;
  List<String> get tasks => _tasks;

  bool get hasFeature => _hasFeature;
  bool get hasLstTasks => _hasLstTasks;

  Feature get feature => _hasFeature
      ? _feature
      : throw PointItineraryException("The itinerary does not have feature");
  set feature(Feature feature) {
    _feature = feature;
    _hasFeature = true;
  }

  List<Task> get tasksObj => _hasLstTasks
      ? _lstTasks
      : throw PointItineraryException("Itinerary does not have tasksObj");
  set tasksObj(List<Task> tasks) {
    _lstTasks = tasks;
    _hasLstTasks = true;
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
            throw PointItineraryException('Problem with altComment');
          }
        }
      } else {
        throw PointItineraryException('Problem with commentServer');
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
          throw PointItineraryException('Problem with tasks');
        }
      }
    } else {
      throw PointItineraryException('Problem with tasks');
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
      ? {'id': id, 'tasks': tasks, 'altComment': _comment2List()}
      : {'id': id, 'tasks': tasks};

  List<Map<String, String>> _comment2List() {
    List<Map<String, String>> out = [];
    for (var element in altComments!) {
      out.add(element.toMap());
    }
    return out;
  }
}

enum ItineraryType { list, listSTsBagTasks, bag, bagSTsListTasks }
