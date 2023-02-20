import 'package:chest/helpers/pois.dart';
import 'package:chest/helpers/tasks.dart';

import 'package:chest/helpers/mobile_functions.dart'
    if (dart.library.html) 'package:chest/helpers/web_functions.dart';

class Answer {
  late String _id, _idPoi, _idTask, _labelPoi, _commentTask;
  late AnswerType _answerType;
  late bool _hasId,
      _hasPoi,
      _hasTask,
      _hasAnswerType,
      _hasAnswer,
      _hasExtraText,
      _hasLabelPoi,
      _hasCommentTask,
      _hasCompleteTask,
      _hasCompletePoi;
  final Map<String, dynamic> _answer = {};
  late int _timestamp, _time2Complete;
  late Task _task;
  late POI _poi;

  Answer(String? idS, String? idPoiS, String? idTaskS, AnswerType? answerTypeS,
      answerS) {
    _hasLabelPoi = false;
    _hasCommentTask = false;
    if (idS is String && idS.trim().isNotEmpty) {
      _id = idS.trim();
      _hasId = true;
    } else {
      throw Exception("Problem with idS");
    }

    if (idPoiS is String && idPoiS.trim().isNotEmpty) {
      _idPoi = idPoiS.trim();
      _hasPoi = true;
    } else {
      throw Exception("Problem with idPoiS");
    }

    if (idTaskS is String && idTaskS.trim().isNotEmpty) {
      _idTask = idTaskS.trim();
      _hasTask = true;
    } else {
      throw Exception("Problem with idTaskS");
    }

    if (answerTypeS is AnswerType) {
      _answerType = answerTypeS;
      _hasAnswerType = true;
    } else {
      throw Exception("Problem with idTaskS");
    }

    if (answerS is bool) {
      _answer['answer'] = answerS;
      _answer['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      _hasExtraText = false;
    } else {
      if (answerS is String && answerS.trim().isNotEmpty) {
        _answer['answer'] = answerS.trim();
        _answer['timestamp'] = DateTime.now().millisecondsSinceEpoch;
        _hasExtraText = false;
      } else {
        if (answerS is Map) {
          _answer['answer'] = answerS['answer'];
          _answer['timestamp'] = answerS['timestamp'];
          if (answerS['extraText'] != null) {
            _answer['extraText'] = answerS['extraText'];
            _hasExtraText = true;
          }
        } else {
          throw Exception("Problem with answerS");
        }
      }
    }
    _hasAnswer = true;
    _time2Complete = -1;
    _timestamp = -1;
    _hasCompleteTask = false;
    _hasCompletePoi = false;
  }

  Answer.withoutAnswer(
      String? idPoiS, String? idTaskS, AnswerType? answerTypeS) {
    _hasLabelPoi = false;
    _hasCommentTask = false;
    if (idPoiS is String && idPoiS.trim().isNotEmpty) {
      _idPoi = idPoiS.trim();
      _hasPoi = true;
    } else {
      throw Exception("Problem with idPoiS");
    }

    if (idTaskS is String && idTaskS.trim().isNotEmpty) {
      _idTask = idTaskS.trim();
      _hasTask = true;
    } else {
      throw Exception("Problem with idTaskS");
    }

    if (answerTypeS is AnswerType) {
      _answerType = answerTypeS;
      _hasAnswerType = true;
    } else {
      throw Exception("Problem with idTaskS");
    }
    _hasAnswer = false;
    _hasId = false;
    _hasExtraText = false;
    _time2Complete = -1;
    _timestamp = -1;
    _hasCompleteTask = false;
    _hasCompletePoi = false;
  }

  Answer.empty() {
    _hasLabelPoi = false;
    _hasCommentTask = false;
    _hasId = false;
    _hasPoi = false;
    _hasTask = false;
    _hasAnswerType = false;
    _hasAnswer = false;
    _hasExtraText = false;
    _time2Complete = -1;
    _timestamp = -1;
    _hasCompleteTask = false;
    _hasCompletePoi = false;
  }

  String get id => _hasId ? _id : throw Exception('Answer does not have id!');
  set id(String idS) {
    if (idS.trim().isNotEmpty) {
      _id = idS.trim();
      _hasId = true;
    } else {
      throw Exception("Problem with idS");
    }
  }

  String get idPoi =>
      _hasPoi ? _idPoi : throw Exception('Answer does not have idPoi!');
  set idPoi(String idPoiS) {
    if (idPoiS.trim().isNotEmpty) {
      _idPoi = idPoiS.trim();
      _hasPoi = true;
    } else {
      throw Exception("Problem with idPoiS");
    }
  }

  String get idTask =>
      _hasTask ? _idTask : throw Exception('Answer does not have idTask!');
  set idTask(String idTaskS) {
    if (idTaskS.trim().isNotEmpty) {
      _idTask = idTaskS.trim();
      _hasTask = true;
    } else {
      throw Exception("Problem with idTaskS");
    }
  }

  AnswerType get answerType => _hasAnswerType
      ? _answerType
      : throw Exception('Answer does not have AnswerType!');
  set answerType(AnswerType answerTypeS) {
    _answerType = answerTypeS;
    _hasAnswerType = true;
  }

  Map get answer =>
      _hasAnswer ? _answer : throw Exception('Answer does not have answer');
  set answer(dynamic answerS) {
    if (answerS is bool) {
      _answer['answer'] = answerS;
      _answer['timestamp'] = DateTime.now().millisecondsSinceEpoch;
      _hasAnswer = true;
      _hasExtraText = false;
    } else {
      if (answerS is String && answerS.trim().isNotEmpty) {
        _answer['answer'] = answerS.trim();
        _answer['timestamp'] = DateTime.now().millisecondsSinceEpoch;
        _hasAnswer = true;
        _hasExtraText = false;
      } else {
        if (answerS is Map) {
          _answer['answer'] = answerS['answer'];
          _answer['timestamp'] = answerS['timestamp'];
          _hasAnswer = true;
          if (answerS['extraText'] != null) {
            _answer['extraText'] = answerS['extraText'];
            _hasExtraText = true;
          }
        } else {
          throw Exception("Problem with answerS");
        }
      }
    }
  }

  String get labelPoi => _hasLabelPoi
      ? _labelPoi
      : throw Exception('Answer does not have labelPoi');
  set labelPoi(String labelPoi) {
    _labelPoi = labelPoi;
    _hasLabelPoi = true;
  }

  String get commentTask => _hasCommentTask
      ? _commentTask
      : throw Exception('Answer does not have commentTask');
  set commentTask(String commentTask) {
    _commentTask = commentTask;
    _hasCommentTask = true;
  }

  bool get hasId => _hasId;
  bool get hasPoi => _hasPoi;
  bool get hasTask => _hasTask;
  bool get hasAnswerType => _hasAnswerType;
  bool get hasAnswer => _hasAnswer;
  bool get hasExtraText => _hasExtraText;
  bool get hasLabelPoi => _hasLabelPoi;
  bool get hasCommentTask => _hasCommentTask;

  int get timestamp => _timestamp;
  set timestamp(int timestamp) {
    _timestamp = timestamp > 0
        ? timestamp
        : throw Exception('timestamp must be positive');
  }

  int get time2Complete => _time2Complete;
  set time2Complete(int time2Complete) {
    _time2Complete = time2Complete > 0
        ? time2Complete
        : throw Exception('time2Complete must be positive');
  }

  Task get task =>
      _hasCompleteTask ? _task : Task.empty(_hasPoi ? _poi.id : 'noId');
  set task(Task task) {
    _task = task;
    _hasCompleteTask = true;
  }

  POI get poi => _hasCompletePoi ? _poi : POI.point(0, 0);
  set poi(POI poi) {
    _poi = poi;
    _hasCompletePoi = true;
  }

  Map<String, dynamic> answer2CHESTServer() {
    Map<String, dynamic> body = {
      "idUser": AuxiliarFunctions.getIdUser(),
      "idPoi": idPoi,
      "idTask": idTask,
      "answerMetadata": {
        "hasOptionalText": hasExtraText,
        "finishClient": timestamp,
        "time2Complete": time2Complete
      }
    };
    return body;
  }
}
