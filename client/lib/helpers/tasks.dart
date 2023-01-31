//?task ?at ?space ?author ?label ?comment
import 'package:chest/helpers/pair.dart';

class Task {
  late String _id, _author, _poi;
  final List<String> _distractors = [], _correctAnswer = [];
  final List<Space> _space = [];
  late AnswerType _aT;
  late bool _hasLabel,
      _correctTF,
      _hasCorrectTF,
      _hasCorrectMCQ,
      _hasExpectedAnswer;
  final List<PairLang> _label = [], _comment = [];
  Task.empty(poiS) {
    _id = '';
    if (poiS is String && poiS.isNotEmpty) {
      _poi = poiS;
    } else {
      throw Exception('Problem with poiS');
    }
    _author = '';
    _aT = AnswerType.noAnswer;
    _hasLabel = false;
    _hasCorrectTF = false;
    _hasCorrectMCQ = false;
    _hasExpectedAnswer = false;
  }

  Task(idS, commentS, authorS, spaceS, aTs, poiS) {
    if (idS is String && idS.isNotEmpty) {
      _id = idS;
    } else {
      throw Exception('Problem with idS');
    }
    if (poiS is String && poiS.isNotEmpty) {
      _poi = poiS;
    } else {
      throw Exception('Problem with poiS');
    }
    if (authorS is String && authorS.isNotEmpty) {
      _author = authorS;
    } else {
      throw Exception('Problem with authorS');
    }
    if (spaceS is String && spaceS.isNotEmpty) {
      spaceS = [spaceS];
    }
    if (spaceS is List) {
      for (var s in spaceS) {
        switch (s) {
          case 'http://chest.gsic.uva.es/ontology/PhysicalSpace':
            _space.add(Space.physical);
            break;
          case 'http://chest.gsic.uva.es/ontology/VirtualSpace':
            _space.add(Space.virtual);
            break;
          case 'http://chest.gsic.uva.es/ontology/Web':
            _space.add(Space.web);
            break;
          default:
            throw Exception('Problem with spaceS');
        }
      }
    } else {
      throw Exception('Problem with spaceS');
    }
    if (commentS is Map) {
      commentS = [commentS];
    }
    if (commentS is List) {
      for (var element in commentS) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _comment.add(PairLang(element['lang'], element['value']));
          } else {
            _comment.add(PairLang.withoutLang(element['value']));
          }
        } else {
          throw Exception('Problem with commentS');
        }
      }
    } else {
      throw Exception('Problem with commentS');
    }
    if (aTs is String && aTs.isNotEmpty) {
      switch (aTs) {
        case 'http://chest.gsic.uva.es/ontology/mcq':
          _aT = AnswerType.mcq;
          break;
        case 'http://chest.gsic.uva.es/ontology/tf':
          _aT = AnswerType.tf;
          break;
        case 'http://chest.gsic.uva.es/ontology/photo':
          _aT = AnswerType.photo;
          break;
        case 'http://chest.gsic.uva.es/ontology/multiplePhotos':
          _aT = AnswerType.multiplePhotos;
          break;
        case 'http://chest.gsic.uva.es/ontology/video':
          _aT = AnswerType.video;
          break;
        case 'http://chest.gsic.uva.es/ontology/photoText':
          _aT = AnswerType.photoText;
          break;
        case 'http://chest.gsic.uva.es/ontology/videoText':
          _aT = AnswerType.videoText;
          break;
        case 'http://chest.gsic.uva.es/ontology/multiplePhotosText':
          _aT = AnswerType.multiplePhotosText;
          break;
        case 'http://chest.gsic.uva.es/ontology/text':
          _aT = AnswerType.text;
          break;
        case 'http://chest.gsic.uva.es/ontology/noAnswer':
          _aT = AnswerType.noAnswer;
          break;
        default:
          throw Exception('Problem with aTs');
      }
    } else {
      throw Exception('Problem with aTs');
    }
    _hasLabel = false;
    _hasCorrectTF = false;
    _hasCorrectMCQ = false;
    _hasExpectedAnswer = false;
  }

  String get id => _id;
  set id(String id) => id.trim().isEmpty ? throw Exception() : _id = id;
  String get author => _author;
  set author(String author) =>
      author.trim().isEmpty ? throw Exception() : _author = author;
  String get poi => _poi;
  List<Space> get spaces => _space;
  AnswerType get aT => _aT;
  set aT(AnswerType aT) => _aT = aT;
  List<PairLang> get comments => _comment;
  List<PairLang> get labels =>
      _hasLabel ? _label : throw Exception('Task has no labels!!');
  String? labelLang(String lang) => _hasLabel
      ? _objLang('label', lang)
      : throw Exception('Task has no label!!');
  String? commentLang(String lang) => _objLang('comment', lang);
  bool get hasLabel => _hasLabel;
  bool get hasCorrectTF => _hasCorrectTF;
  bool get hasCorrectMCQ => _hasCorrectMCQ;
  bool get hasExpectedAnswer => _hasExpectedAnswer;

  bool get correctTF => _hasCorrectTF ? _correctTF : throw Exception();
  set correctTF(bool correcTF) {
    _hasCorrectTF = true;
    _correctTF = correcTF;
  }

  List<String> get correctMCQ =>
      _hasCorrectMCQ ? _correctAnswer : throw Exception();
  set correctMCQ(List<String> correctMCQ) {
    if (correctMCQ.isNotEmpty) {
      _hasCorrectMCQ = true;
      _correctAnswer.addAll(correctMCQ);
    }
  }

  void addCorrectMCQ(String correctMCQ) {
    String c = correctMCQ.trim();
    if (c.isNotEmpty) {
      if (!_correctAnswer.contains(c)) {
        _correctAnswer.add(correctMCQ);
        _hasCorrectMCQ = _correctAnswer.isNotEmpty;
      }
    }
  }

  removeCorrect(String correctMCQ) {
    _correctAnswer.remove(correctMCQ.trim());
    _hasCorrectMCQ = _correctAnswer.isNotEmpty;
  }

  List<String> get expectedAnswer =>
      _hasExpectedAnswer ? _correctAnswer : throw Exception();
  set expectedAnswer(List<String> expectedAnswer) {
    if (expectedAnswer.isNotEmpty) {
      _hasExpectedAnswer = true;
      _correctAnswer.addAll(expectedAnswer);
    }
  }

  void addSpace(spaceS) => setSpaces(spaceS);
  void setSpaces(spaceS) {
    if (spaceS is Space) {
      spaceS = [spaceS];
    }
    if (spaceS is String) {
      switch (spaceS) {
        case 'http://chest.gsic.uva.es/ontology/PhysicalSpace':
          spaceS = [Space.physical];
          break;
        case 'http://chest.gsic.uva.es/ontology/VirtualSpace':
          spaceS = [Space.virtual];
          break;
        case 'http://chest.gsic.uva.es/ontology/Web':
          spaceS = [Space.web];
          break;
        default:
          throw Exception('Problem with spaceS');
      }
    }
    if (spaceS is List) {
      for (var element in spaceS) {
        if (!_space.contains(element)) {
          _space.add(element);
        }
      }
    } else {
      throw Exception('Problem with spaceS');
    }
  }

  void addLabel(Map labelS) => setLabels(labelS);
  void setLabels(labelS) {
    if (labelS is Map) {
      labelS = [labelS];
    }
    if (labelS is List) {
      for (var element in labelS) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _label.removeWhere((lab) => lab.lang == element['lang']);
            _label.add(PairLang(element['lang'], element['value']));
          } else {
            _label.add(PairLang.withoutLang(element['value']));
          }
        } else {
          throw Exception('Problem with labelS');
        }
      }
      _hasLabel = true;
    } else {
      throw Exception('Problem with labelS');
    }
  }

  void addComment(Map commentS) => setComments(commentS);
  void setComments(commentS) {
    if (commentS is Map) {
      commentS = [commentS];
    }
    if (commentS is List) {
      for (var element in commentS) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _comment.removeWhere((com) => com.lang == element['lang']);
            _comment.add(PairLang(element['lang'], element['value']));
          } else {
            _comment.add(PairLang.withoutLang(element['value']));
          }
        } else {
          throw Exception('Problem with commentS');
        }
      }
    } else {
      throw Exception('Problem with commentS');
    }
  }

  String? _objLang(String opt, String lang) {
    List<PairLang> pl;
    switch (opt) {
      case 'label':
        pl = _label;
        break;
      case 'comment':
        pl = _comment;
        break;
      default:
        throw Exception('Problem in switch _objLang');
    }
    for (var e in pl) {
      if (e.hasLang && e.lang == lang) {
        return e.value;
      } else {
        //Las generadas de manera semiauto no tienen idioma
        return e.value;
      }
    }
    return null;
  }

  List<String> get distractors => _distractors;
  set addDistractor(String distractor) {
    String d = distractor.trim();
    if (d.isNotEmpty) {
      if (!distractors.contains(d)) {
        _distractors.add(d);
      }
    }
  }

  removeDistractor(String distractor) {
    _distractors.remove(distractor.trim());
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
}

enum Space { virtual, web, physical }

extension SpaceString on Space {
  String get rdf {
    switch (this) {
      case Space.physical:
        return 'http://chest.gsic.uva.es/ontology/PhysicalSpace';
      case Space.virtual:
        return 'http://chest.gsic.uva.es/ontology/VirtualSpace';
      case Space.web:
        return 'http://chest.gsic.uva.es/ontology/Web';
      default:
        throw Exception('Problem with rdf');
    }
  }
}

enum AnswerType {
  mcq,
  tf,
  photo,
  multiplePhotos,
  video,
  photoText,
  videoText,
  multiplePhotosText,
  text,
  noAnswer
}
