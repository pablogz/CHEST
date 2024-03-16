import 'package:chest/util/config.dart';
import 'package:chest/util/helpers/pair.dart';
import 'package:flutter/foundation.dart';

class Task {
  final String _idFeature;
  late String _id, _author;
  final List<Space> _space = [];
  late AnswerType aT;
  late bool _hasLabel,
      _correctTF,
      _hasCorrectTF,
      _hasCorrectMCQ,
      _hasExpectedAnswer,
      singleSelection,
      isEmpty;
  final List<PairLang> _label = [],
      _comment = [],
      _distractors = [],
      _correctAnswer = [];

  Task.empty(this._idFeature) {
    _id = '';
    _author = '';
    aT = AnswerType.noAnswer;
    _hasLabel = false;
    _hasCorrectTF = false;
    _hasCorrectMCQ = false;
    _hasExpectedAnswer = false;
    singleSelection = true;
    isEmpty = true;
  }

  Task(dynamic data, this._idFeature) {
    try {
      if (data != null && data is Map) {
        if (data.containsKey('task') &&
            data['task'] is String &&
            data['task'].toString().isNotEmpty) {
          _id = data['task'];
        } else {
          throw Exception('Problem with key "task" in Task constructor');
        }

        if (data.containsKey('comment')) {
          if (data['comment'] is String) {
            data['comment'] = {'value': data['comment']};
          }
          setComments(data['comment']);
        } else {
          throw Exception('Problem with key "comment" in Task constructor');
        }

        if (data.containsKey('author') &&
            data['author'] is String &&
            data['author'].toString().isNotEmpty) {
          _author = data['author'];
        } else {
          throw Exception('Problem with key "author" in Task constructor');
        }

        if (data.containsKey('space')) {
          if (data['space'] is String && data['space'].toString().isNotEmpty) {
            data['space'] = [data['space']];
          }
          if (data['space'] is List) {
            for (var s in data['space']) {
              switch (s) {
                case 'http://moult.gsic.uva.es/ontology/PhysicalSpace':
                  _space.add(Space.physical);
                  break;
                case 'http://moult.gsic.uva.es/ontology/VirtualSpace':
                  _space.add(Space.virtual);
                  break;
                case 'http://moult.gsic.uva.es/ontology/Web':
                  _space.add(Space.web);
                  break;
                default:
                  throw Exception(
                      'Problem with key "space" in Task constructor');
              }
            }
            _space.sort((Space a, Space b) => a.name.compareTo(b.name));
          } else {
            throw Exception('Problem with key "space" in Task constructor');
          }
        } else {
          throw Exception('Problem with key "space" in Task constructor');
        }

        if (data.containsKey('at') &&
            data['at'] is String &&
            data['at'].toString().isNotEmpty) {
          switch (data['at']) {
            case 'http://moult.gsic.uva.es/ontology/mcq':
            case 'http://moult.gsic.uva.es/ontology/MCQ':
              aT = AnswerType.mcq;
              break;
            case 'http://moult.gsic.uva.es/ontology/tf':
            case 'http://moult.gsic.uva.es/ontology/TF':
              aT = AnswerType.tf;
              break;
            case 'http://moult.gsic.uva.es/ontology/photo':
            case 'http://moult.gsic.uva.es/ontology/Photo':
              aT = AnswerType.photo;
              break;
            case 'http://moult.gsic.uva.es/ontology/multiplePhotos':
            case 'http://moult.gsic.uva.es/ontology/MultiplePhotos':
              aT = AnswerType.multiplePhotos;
              break;
            case 'http://moult.gsic.uva.es/ontology/video':
            case 'http://moult.gsic.uva.es/ontology/Video':
              aT = AnswerType.video;
              break;
            case 'http://moult.gsic.uva.es/ontology/photoText':
            case 'http://moult.gsic.uva.es/ontology/PhotoText':
              aT = AnswerType.photoText;
              break;
            case 'http://moult.gsic.uva.es/ontology/videoText':
            case 'http://moult.gsic.uva.es/ontology/VideoText':
              aT = AnswerType.videoText;
              break;
            case 'http://moult.gsic.uva.es/ontology/multiplePhotosText':
            case 'http://moult.gsic.uva.es/ontology/MultiplePhotosText':
              aT = AnswerType.multiplePhotosText;
              break;
            case 'http://moult.gsic.uva.es/ontology/text':
            case 'http://moult.gsic.uva.es/ontology/Text':
              aT = AnswerType.text;
              break;
            case 'http://moult.gsic.uva.es/ontology/noAnswer':
            case 'http://moult.gsic.uva.es/ontology/NoAnswer':
              aT = AnswerType.noAnswer;
              break;
            default:
              throw Exception('Problem with key "at" in Task constructor');
          }
        } else {
          throw Exception('Problem with key "at" in Task constructor');
        }
      } else {
        throw Exception('Object is null or different of a Map');
      }

      // OPTIONALS
      if (data.containsKey('label')) {
        if (data['label'] is String) {
          data['label'] = {'value': data['label']};
        }
        try {
          setLabels(data['label']);
        } catch (error) {
          if (Config.development) debugPrint(error.toString());
          _hasLabel = false;
        }
      } else {
        _hasLabel = false;
      }
      switch (aT) {
        case AnswerType.tf:
          singleSelection = true;
          if (_hasCorrectTF =
              (data.containsKey('correct') && data['correct'] is bool)) {
            _correctTF = data['correct'];
          }
          break;
        case AnswerType.mcq:
          if (_hasCorrectMCQ = data.containsKey('correct')) {
            setCorrectMCQ(data['correct']);
          }
          if (data.containsKey('distractor')) {
            setDistractorMCQ(data['distractor']);
          }
          singleSelection = data.containsKey('singleSelection') &&
              data['singleSelection'] is bool &&
              data['singleSelection'];
          break;
        default:
          _hasCorrectTF = false;
          _hasCorrectMCQ = false;
          _hasExpectedAnswer = false;
          singleSelection = true;
      }
      isEmpty = false;
    } on Exception catch (e) {
      throw Exception('${e.toString()} in Task constructor');
    }
  }

  // Task(idS, commentS, authorS, spaceS, aTs, poiS) {
  //   if (idS is String && idS.isNotEmpty) {
  //     _id = idS;
  //   } else {
  //     throw Exception('Problem with idS');
  //   }
  //   if (poiS is String && poiS.isNotEmpty) {
  //     _poi = poiS;
  //   } else {
  //     throw Exception('Problem with poiS');
  //   }
  //   if (authorS is String && authorS.isNotEmpty) {
  //     _author = authorS;
  //   } else {
  //     throw Exception('Problem with authorS');
  //   }
  //   if (spaceS is String && spaceS.isNotEmpty) {
  //     spaceS = [spaceS];
  //   }
  //   if (spaceS is List) {
  //     for (var s in spaceS) {
  //       switch (s) {
  //         case 'http://chest.gsic.uva.es/ontology/PhysicalSpace':
  //           _space.add(Space.physical);
  //           break;
  //         case 'http://chest.gsic.uva.es/ontology/VirtualSpace':
  //           _space.add(Space.virtual);
  //           break;
  //         case 'http://chest.gsic.uva.es/ontology/Web':
  //           _space.add(Space.web);
  //           break;
  //         default:
  //           throw Exception('Problem with spaceS');
  //       }
  //     }
  //   } else {
  //     throw Exception('Problem with spaceS');
  //   }
  //   if (commentS is Map) {
  //     commentS = [commentS];
  //   }
  //   if (commentS is List) {
  //     for (var element in commentS) {
  //       if (element is Map && element.containsKey('value')) {
  //         if (element.containsKey('lang')) {
  //           _comment.add(PairLang(element['lang'], element['value']));
  //         } else {
  //           _comment.add(PairLang.withoutLang(element['value']));
  //         }
  //       } else {
  //         throw Exception('Problem with commentS');
  //       }
  //     }
  //   } else {
  //     throw Exception('Problem with commentS');
  //   }
  //   if (aTs is String && aTs.isNotEmpty) {
  //     switch (aTs) {
  //       case 'http://chest.gsic.uva.es/ontology/mcq':
  //         _aT = AnswerType.mcq;
  //         break;
  //       case 'http://chest.gsic.uva.es/ontology/tf':
  //         _aT = AnswerType.tf;
  //         break;
  //       case 'http://chest.gsic.uva.es/ontology/photo':
  //         _aT = AnswerType.photo;
  //         break;
  //       case 'http://chest.gsic.uva.es/ontology/multiplePhotos':
  //         _aT = AnswerType.multiplePhotos;
  //         break;
  //       case 'http://chest.gsic.uva.es/ontology/video':
  //         _aT = AnswerType.video;
  //         break;
  //       case 'http://chest.gsic.uva.es/ontology/photoText':
  //         _aT = AnswerType.photoText;
  //         break;
  //       case 'http://chest.gsic.uva.es/ontology/videoText':
  //         _aT = AnswerType.videoText;
  //         break;
  //       case 'http://chest.gsic.uva.es/ontology/multiplePhotosText':
  //         _aT = AnswerType.multiplePhotosText;
  //         break;
  //       case 'http://chest.gsic.uva.es/ontology/text':
  //         _aT = AnswerType.text;
  //         break;
  //       case 'http://chest.gsic.uva.es/ontology/noAnswer':
  //         _aT = AnswerType.noAnswer;
  //         break;
  //       default:
  //         throw Exception('Problem with aTs');
  //     }
  //   } else {
  //     throw Exception('Problem with aTs');
  //   }
  //   _hasLabel = false;
  //   _hasCorrectTF = false;
  //   _hasCorrectMCQ = false;
  //   _hasExpectedAnswer = false;
  //   singleSelection = true;
  // }

  String get id => _id;
  set id(String id) => id.trim().isEmpty ? throw Exception() : _id = id;
  String get author => _author;
  set author(String author) =>
      author.trim().isEmpty ? throw Exception() : _author = author;
  String get idFeature => _idFeature;
  List<Space> get spaces => _space;
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

  List<PairLang> get correctMCQ =>
      _hasCorrectMCQ ? _correctAnswer : throw Exception();
  set correctMCQ(List<PairLang> correctMCQ) {
    if (correctMCQ.isNotEmpty) {
      for (PairLang cMCQ in correctMCQ) {
        if (_correctAnswer
                .indexWhere((PairLang element) => element.value == cMCQ.value) >
            -1) {
          _correctAnswer.add(cMCQ);
        }
      }
      _hasCorrectMCQ = _correctAnswer.isNotEmpty;
    }
  }

  void setCorrectMCQ(cMCQS) {
    if (cMCQS is Map) {
      cMCQS = [cMCQS];
    }
    if (cMCQS is List) {
      for (var element in cMCQS) {
        if (element is Map && element.containsKey('value')) {
          element.containsKey('lang')
              ? addCorrectMCQ(element['value'], lang: element['lang'])
              : addCorrectMCQ(element['value']);
        } else {
          throw Exception('Problem with cMCQS');
        }
      }
    } else {
      throw Exception('Problem with cMCQS');
    }
  }

  void addCorrectMCQ(String value, {String? lang}) {
    String c = value.trim();
    if (c.isNotEmpty) {
      if (_correctAnswer.indexWhere((PairLang pl) => pl.value == c) == -1) {
        _correctAnswer.add(
            lang != null ? PairLang(lang, value) : PairLang.withoutLang(value));
        _hasCorrectMCQ = _correctAnswer.isNotEmpty;
      }
    }
  }

  removeCorrect(PairLang correctMCQ) {
    _correctAnswer.remove(correctMCQ);
    _hasCorrectMCQ = _correctAnswer.isNotEmpty;
  }

  List<PairLang> get expectedAnswer =>
      _hasExpectedAnswer ? _correctAnswer : throw Exception();
  set expectedAnswer(List<PairLang> expectedAnswer) {
    if (expectedAnswer.isNotEmpty) {
      for (PairLang eA in expectedAnswer) {
        if (_correctAnswer.indexWhere((PairLang ele) => ele.value == eA.value) >
            -1) {
          _correctAnswer.add(eA);
        }
      }
      _hasExpectedAnswer = _correctAnswer.isNotEmpty;
    }
  }

  void addSpace(spaceS) => setSpaces(spaceS);
  void setSpaces(spaceS) {
    if (spaceS is Space) {
      spaceS = [spaceS];
    }
    if (spaceS is String) {
      switch (spaceS) {
        case 'http://moult.gsic.uva.es/ontology/PhysicalSpace':
          spaceS = [Space.physical];
          break;
        case 'http://moult.gsic.uva.es/ontology/VirtualSpace':
          spaceS = [Space.virtual];
          break;
        case 'http://moult.gsic.uva.es/ontology/Web':
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

  List<PairLang> get distractors => _distractors;

  void setDistractorMCQ(dMCQS) {
    if (dMCQS is Map) {
      dMCQS = [dMCQS];
    }
    if (dMCQS is List) {
      for (var element in dMCQS) {
        if (element is Map && element.containsKey('value')) {
          element.containsKey('lang')
              ? addDistractor(PairLang(element['lang'], element['value']))
              : addDistractor(PairLang.withoutLang(element['value']));
        } else {
          throw Exception('Problem with dMCQS');
        }
      }
    } else {
      throw Exception('Problem with dMCQS');
    }
  }

  addDistractor(PairLang distractor) {
    if (_distractors.indexWhere(
            (PairLang element) => element.value == distractor.value) ==
        -1) {
      _distractors.add(distractor);
    }
  }

  removeDistractor(PairLang distractor) {
    _distractors.removeWhere((element) => element.value == distractor.value);
  }

  List<Map<String, String>> comments2List() => _object2List(comments);

  List<Map<String, String>> labels2List() => _object2List(labels);

  List<Map<String, String>> correctsMCQ2List() => _object2List(correctMCQ);

  List<Map<String, String>> distractorsMCQ2List() => _object2List(distractors);

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
        return 'http://moult.gsic.uva.es/ontology/PhysicalSpace';
      case Space.virtual:
        return 'http://moult.gsic.uva.es/ontology/VirtualSpace';
      case Space.web:
        return 'http://moult.gsic.uva.es/ontology/Web';
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
