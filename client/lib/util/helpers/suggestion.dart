import 'package:chest/util/helpers/pair.dart';

class Suggestion {
  final String id;
  //late PairLang _label;
  final List<PairLang> _labels = [];
  late bool _hasLat, _hasLong, _hasScore;
  late double _lat, _long;
  late int _score;

  Suggestion(this.id) {
    _hasLat = false;
    _hasLong = false;
    _hasScore = false;
  }

  bool get hasLat => _hasLat;
  double get lat => _hasLat ? _lat : throw Exception('No lat');
  set lat(double lat) {
    if (lat < -90 || lat > 90) throw Exception('Invalid latitude');
    _lat = lat;
    _hasLat = true;
  }

  bool get hasLong => _hasLong;
  double get long => _hasLong ? _long : throw Exception('No long');
  set long(double long) {
    if (long < -180 || long > 180) throw Exception('Invalid longitude');
    _long = long;
    _hasLong = true;
  }

  bool get hasScore => _hasScore;
  int get score => _hasScore ? _score : throw Exception('No score');
  set score(int score) {
    if (score < 0) throw Exception('Invalid score');
    _score = score;
    _hasScore = true;
  }

  // bool get hasLabel => _hasLabel;
  // PairLang get label => _hasLabel ? _label : throw Exception('No label');
  // set label(PairLang label) {
  //   if (label.hasLang) {
  //     _label = label;
  //     _hasLabel = true;
  //   } else {
  //     throw Exception('Problem with label');
  //   }
  // }

  List<PairLang> get labels => _labels;
  PairLang? label(lang) {
    int index = _labels.indexWhere((p) => p.lang == lang);
    return index != -1 ? _labels[index] : null;
  }

  PairLang? addLabel(PairLang pairLang) {
    if (_labels.indexWhere((p) => p.lang == pairLang.lang) == -1) {
      _labels.add(pairLang);
      return pairLang;
    }
    return null;
  }
}

class ReSug {
  late ReSugHeader _reSugHeader;
  late bool _hasReSugData, _hasReSelData;
  late ReSugData _reSugData;
  late ReSelData _reSelData;

  ReSug(response) {
    if (response is Map) {
      _reSugHeader = response.containsKey('responseHeader')
          ? ReSugHeader(response['responseHeader'])
          : throw Exception('No responseHeader');
      if (response.containsKey('suggest')) {
        _reSugData = ReSugData(response['suggest']);
        _hasReSelData = false;
        _hasReSugData = true;
      } else {
        if (response.containsKey('response')) {
          _reSelData = ReSelData(response['response']);
          _hasReSelData = true;
          _hasReSugData = false;
        } else {
          throw Exception('No suggest or response');
        }
      }
    } else {
      throw Exception('Response is not a Map');
    }
  }

  ReSugHeader get reSugHeader => _reSugHeader;
  bool get hasReSugData => _hasReSugData;
  ReSugData get reSugData =>
      _hasReSugData ? _reSugData : throw Exception('No reSugData');
  bool get hasReSelData => _hasReSelData;
  ReSelData get reSelData =>
      _hasReSelData ? _reSelData : throw Exception('No reSelData');
}

class ReSugHeader {
  late int _status;
  late int _qTime;
  late Map<String, dynamic> _params;

  ReSugHeader(responseHeader) {
    if (responseHeader is Map) {
      _status = responseHeader.containsKey('status')
          ? responseHeader['status']
          : throw Exception('No status');
      _qTime = responseHeader.containsKey('QTime')
          ? responseHeader['QTime']
          : throw Exception('No QTime');
      _params =
          responseHeader.containsKey('params') ? responseHeader['params'] : {};
    } else {
      throw Exception('ResponseHeader is not a Map');
    }
  }

  int get status => _status;
  int get qTime => _qTime;
  Map<String, dynamic> get params => _params;
}

class ReSugData {
  late List<ReSugDic> _reSugDics;
  late List<String> _langDics;

  ReSugData(suggestData) {
    if (suggestData is Map) {
      _reSugDics = [];
      _langDics = [];
      for (var key in suggestData.keys) {
        String? langKey = key == 'chestEn'
            ? 'en'
            : key == 'chestEs'
                ? 'es'
                : key == 'chestPt'
                    ? 'pt'
                    : null;
        if (langKey != null && !_langDics.contains(langKey)) {
          _reSugDics.add(ReSugDic(suggestData[key], langKey));
          _langDics.add(langKey);
        }
      }
    } else {
      throw Exception('SuggestData is not a Map');
    }
  }

  List<String> get langDics => _langDics;
  ReSugDic? getReSugDic(String lang) =>
      _langDics.contains(lang) ? _reSugDics[_langDics.indexOf(lang)] : null;
}

class ReSelData {
  late int _numFound, _start;
  late bool _numFoundExact;
  late List<Suggestion> _docs;

  ReSelData(responseData) {
    if (responseData is Map) {
      _numFound = responseData.containsKey('numFound')
          ? responseData['numFound']
          : throw Exception('No numFound');
      _start = responseData.containsKey('start')
          ? responseData['start']
          : throw Exception('No start');
      _numFoundExact = responseData.containsKey('numFoundExact')
          ? responseData['numFoundExact']
          : throw Exception('No numFoundExact');
      _docs =
          responseData.containsKey('docs') ? [] : throw Exception('No docs');
      for (var docServer in responseData['docs']) {
        if (docServer is Map) {
          Suggestion suggestion = docServer.containsKey('id')
              ? Suggestion(docServer['id'])
              : throw Exception('No id');
          if (docServer.containsKey('labelEn')) {
            suggestion.addLabel(PairLang('en', docServer['labelEn']));
          }
          if (docServer.containsKey('labelEs')) {
            suggestion.addLabel(PairLang('es', docServer['labelEs']));
          }
          if (docServer.containsKey('labelPt')) {
            suggestion.addLabel(PairLang('pt', docServer['labelPt']));
          }
          if (docServer.containsKey('score')) {
            suggestion.score = docServer['score'];
          } else {
            throw Exception('No score');
          }
          if (docServer.containsKey('lat')) {
            suggestion.lat = docServer['lat'];
          } else {
            throw Exception('No lat');
          }
          if (docServer.containsKey('long')) {
            suggestion.long = docServer['long'];
          } else {
            throw Exception('No long');
          }
          _docs.add(suggestion);
        } else {
          throw Exception('Doc is not a Map');
        }
      }
    } else {
      throw Exception('ResponseData is not a Map');
    }
  }

  int get numFound => _numFound;
  int get start => _start;
  bool get numFoundExact => _numFoundExact;
  List<Suggestion> get docs => _docs;
}

class ReSugDic {
  late int _numFound;
  late List<Suggestion> _suggestions;
  final String lang;

  ReSugDic(suggestDict, this.lang) {
    if (suggestDict is Map) {
      if (suggestDict.keys.length == 1) {
        suggestDict = suggestDict[suggestDict.keys.first];
        if (suggestDict is Map) {
          _numFound = suggestDict.containsKey('numFound')
              ? suggestDict['numFound']
              : throw Exception('No numFound');
          _suggestions = suggestDict.containsKey('suggestions')
              ? []
              : throw Exception('No suggestions');
          for (var suggestionServer in suggestDict['suggestions']) {
            if (suggestionServer is Map) {
              Suggestion suggestion = suggestionServer.containsKey('payload')
                  ? Suggestion(suggestionServer['payload'])
                  : throw Exception('No payload');
              if (suggestionServer.containsKey('term')) {
                suggestion.addLabel(PairLang(lang, suggestionServer['term']));
              } else {
                throw Exception('No term');
              }
              if (suggestionServer.containsKey('weight')) {
                suggestion.score = suggestionServer['weight'];
              } else {
                throw Exception('No weight');
              }
              _suggestions.add(suggestion);
            } else {
              throw Exception('Suggestion is not a Map');
            }
          }
        } else {
          throw Exception('SuggestDictData is not a Map');
        }
      } else {
        throw Exception('More than one key');
      }
    } else {
      throw Exception('SuggestDict is not a Map');
    }
  }

  int get numFound => _numFound;
  List<Suggestion> get suggestions => _suggestions;
}
