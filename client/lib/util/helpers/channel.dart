import 'package:chest/util/exceptions.dart';
import 'package:chest/util/helpers/answers.dart';
import 'package:chest/util/helpers/pair.dart';

class Channel {
  late String _id;
  late List<PairLang> _labels, _comments;
  late Participant author;
  late List<Participant> _participants;

  /// Constructor de un [Channel]. Puede ser útil para recuperar
  /// datos del servidor.
  // TODO
  Channel.json(Map<String, dynamic> json) {
    if (json.containsKey('id') &&
        json['id'] is String &&
        json['id'].trim().isNotEmpty) {
      _id = json['id'].trim();
    } else {
      ChannelException('Problem with the \'ID\'');
    }
  }

  /// Constructor para iniciar un [Channel] sin contenido.
  Channel.empty() {
    _id = '';
    _labels = [PairLang.withoutLang('')];
    _comments = [PairLang.withoutLang('')];
    author = Participant.empty();
    _participants = [];
  }

  Channel.author(this.author) {
    _id = '';
    _labels = [PairLang.withoutLang('')];
    _comments = [PairLang.withoutLang('')];
    _participants = [];
  }

  String get id => _id;
  set id(String id) {
    if (id.trim().isNotEmpty) {
      _id = id;
    }
  }

  List<PairLang> get labels => _labels;
  set labels(List<PairLang> labels) {
    _labels = [];
    for (PairLang label in labels) {
      _labels.add(label);
    }
  }

  String getLabel({String? lang}) {
    try {
      if (lang is String) {
        return labels
            .firstWhere((PairLang p) => p.hasLang && p.lang == lang)
            .value;
      } else {
        return labels
            .firstWhere((PairLang p) => p.hasLang && p.lang == "en")
            .value;
      }
    } catch (e) {
      return labels.first.value;
    }
  }

  String getComment({String? lang}) {
    try {
      if (lang is String) {
        return comments
            .firstWhere((PairLang p) => p.hasLang && p.lang == lang)
            .value;
      } else {
        return comments
            .firstWhere((PairLang p) => p.hasLang && p.lang == "en")
            .value;
      }
    } catch (e) {
      return comments.first.value;
    }
  }

  List<PairLang> get comments => _comments;
  set comments(List<PairLang> comments) {
    _comments = [];
    for (PairLang comment in comments) {
      _comments.add(comment);
    }
  }

  bool addComment(PairLang comment) {
    Iterable<PairLang> coincidencias = _comments.where((PairLang p) => p.hasLang
        ? comment.hasLang
            ? comment.lang == p.lang && p.value == comment.value
            : false
        : comment.hasLang
            ? false
            : p.value == comment.value);
    if (coincidencias.isEmpty) {
      _comments.add(comment);
      return true;
    }
    return false;
  }

  List<Participant> get participants => _participants;
  set participants(List<Participant> participants) {
    _participants = [];
    for (Participant participant in participants) {
      _participants.add(participant);
    }
  }

  /// Agrega un [participant] a [particpants].
  /// Devuelve true si lo ha conseguido agregar.
  bool addParticipant(Participant participant) {
    Iterable<Participant> coincidencias =
        _participants.where((Participant p) => p.id == participant.id);
    if (coincidencias.isEmpty) {
      _participants.add(participant);
      return true;
    }
    return false;
  }

  /// Borra un usuario ([participant]) de la lista de participantes
  /// ([_participants]). Devuelve true si ha conseguido borrar uno
  /// de los integrantes de [_participants] o false si no lo ha
  /// conseguido.
  bool removeParticipant(Participant participant) {
    int initialLength = participants.length;
    _participants.removeWhere((Participant p) => participant.id == p.id);
    return initialLength > participants.length;
  }
}

class Participant {
  late String _id, _alias;
  late List<PairLang> comments;
  late List<Answer> _answers;

  // TODO
  Participant.json(Map<String, dynamic> json);

  Participant.empty() {
    _id = '';
    _alias = '';
    comments = [PairLang.withoutLang('')];
    _answers = [];
  }

  String get id => _id;
  set id(String id) {
    if (id.trim().isNotEmpty) {
      _id = id;
    }
  }

  String get alias => _alias;
  set alias(String alias) {
    if (alias.trim().isNotEmpty) {
      _alias = alias;
    }
  }

  List<Answer> get answers => _answers;
  set answers(List<Answer> answers) {
    for (Answer answer in answers) {
      _answers.add(answer);
    }
  }

  bool addAnswer(Answer answer) {
    Iterable<Answer> coincidencias =
        _answers.where((Answer a) => a.id == answer.id);
    if (coincidencias.isEmpty) {
      _answers.add(answer);
      return true;
    }
    return false;
  }

  bool removeAnswer(Answer answer) {
    int initialLength = _answers.length;
    _answers.removeWhere((Answer a) => a.id == answer.id);
    return initialLength > _answers.length;
  }
}
