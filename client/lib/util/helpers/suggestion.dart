import 'package:chest/util/helpers/pair.dart';

class Suggestion {
  final String id;
  late PairLang _label;
  late bool _hasLat, _hasLong, _hasScore, _hasLabel;
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

  bool get hasLabel => _hasLabel;
  PairLang get label => _hasLabel ? _label : throw Exception('No label');
  set label(PairLang label) {
    if (label.hasLang) {
      _label = label;
      _hasLabel = true;
    } else {
      throw Exception('Problem with label');
    }
  }
}

class ReSug {
  late ReSugHeader _reSugHeader;
  late ReSugData _reSugData;

  ReSug(response) {
    if (response is Map) {
      _reSugHeader = response.containsKey('responseHeader')
          ? ReSugHeader(response['responseHeader'])
          : throw Exception('No responseHeader');
      _reSugData = response.containsKey('suggest')
          ? ReSugData(response['suggest'])
          : throw Exception('No suggest');
    } else {
      throw Exception('Response is not a Map');
    }
  }

  ReSugHeader get reSugHeader => _reSugHeader;
  ReSugData get reSugData => _reSugData;
}

class ReSugHeader {
  late int _status;
  late int _qTime;

  ReSugHeader(responseHeader) {
    if (responseHeader is Map) {
      _status = responseHeader.containsKey('status')
          ? responseHeader['status']
          : throw Exception('No status');
      _qTime = responseHeader.containsKey('QTime')
          ? responseHeader['QTime']
          : throw Exception('No QTime');
    } else {
      throw Exception('ResponseHeader is not a Map');
    }
  }

  int get status => _status;
  int get qTime => _qTime;
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
                suggestion.label = PairLang(lang, suggestionServer['term']);
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
