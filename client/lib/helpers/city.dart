import 'package:chest/helpers/pair.dart';
import 'package:latlong2/latlong.dart';

class City {
  late List<PairLang> _listValues;
  late bool _hasLatLng;
  late LatLng _point;

  City(pairLangValue, point) {
    if (pairLangValue is String) {
      pairLangValue = [PairLang.withoutLang(pairLangValue)];
    }
    if (pairLangValue is Map &&
        pairLangValue.containsKey('lang') &&
        pairLangValue.containsKey('value')) {
      pairLangValue = [PairLang(pairLangValue['lang'], pairLangValue['value'])];
    }
    if (pairLangValue is List<PairLang>) {
      _listValues = pairLangValue;
    } else {
      throw Exception('Data error pairLangValue');
    }
    if (point is LatLng) {
      _point = point;
      _hasLatLng = true;
    } else {
      throw Exception('Data error point');
    }
  }

  City.withoutPoint(pairLangValue) {
    if (pairLangValue is String) {
      pairLangValue = [PairLang.withoutLang(pairLangValue)];
    }
    if (pairLangValue is Map &&
        pairLangValue.containsKey('lang') &&
        pairLangValue.containsKey('value')) {
      pairLangValue = [PairLang(pairLangValue['lang'], pairLangValue['value'])];
    }
    if (pairLangValue is List<PairLang>) {
      _listValues = pairLangValue;
    } else {
      throw Exception('Data error');
    }
    _hasLatLng = false;
  }

  bool get hasLatLng => _hasLatLng;

  LatLng get point =>
      _hasLatLng ? _point : throw Exception('LatLng doest not set!');
  set point(LatLng point) {
    _point = point;
    _hasLatLng = true;
  }

  String? label({String? lang}) {
    for (PairLang pairLang in _listValues) {
      if (lang == null) {
        if (!pairLang.hasLang) {
          return pairLang.value;
        }
      } else {
        if (pairLang.hasLang && pairLang.lang == lang) {
          return pairLang.value;
        }
      }
    }
    return _listValues.isNotEmpty ? _listValues.first.value : null;
  }
}
