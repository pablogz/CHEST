import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'auxiliar.dart';

class POI {
  late String _id, _author;
  final List<PairLang> _label = [], _comment = [];
  late PairImage _thumbnail;
  final List<PairImage> _image = [];
  late double _latitude, _longitude;
  late bool _hasThumbnail;

  POI(idServer, labelServer, commentServer, latServer, longServer,
      authorServer) {
    if (idServer is String && idServer.isNotEmpty) {
      _id = idServer;
    } else {
      throw Exception('Problem with idServer');
    }

    if (authorServer is String && authorServer.isNotEmpty) {
      _author = authorServer;
    } else {
      throw Exception('Problem with authorServer');
    }

    if (labelServer is Map) {
      labelServer = [labelServer];
    }
    if (labelServer is List) {
      for (var element in labelServer) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _label.add(PairLang(element['lang'], element['value']));
          } else {
            _label.add(PairLang.withoutLang(element['value']));
          }
        } else {
          throw Exception('Problem with labelServer');
        }
      }
    } else {
      throw Exception('Problem with labelServer');
    }
    if (commentServer is Map) {
      commentServer = [commentServer];
    }
    if (commentServer is List) {
      for (var element in commentServer) {
        if (element is Map && element.containsKey('value')) {
          if (element.containsKey('lang')) {
            _comment.add(PairLang(element['lang'], element['value']));
          } else {
            _comment.add(PairLang.withoutLang(element['value']));
          }
        } else {
          throw Exception('Problem with commentServer');
        }
      }
    } else {
      throw Exception('Problem with commentServer');
    }
    if (latServer is double && latServer >= 0 && latServer <= 90) {
      _latitude = latServer;
    } else {
      throw Exception('Problem with latitudeServer');
    }
    if (longServer is double && longServer >= -180 && longServer <= 180) {
      _longitude = longServer;
    } else {
      throw Exception('Problem with longServer');
    }

    _hasThumbnail = false;
  }

  String get id => _id;
  String get author => _author;
  List<PairLang> get labels => _label;
  List<PairLang> get comments => _comment;
  double get lat => _latitude;
  double get long => _longitude;
  LatLng get point => LatLng(_latitude, _longitude);
  bool get hasThumbnail => _hasThumbnail;
  PairImage get thumbnail =>
      _hasThumbnail ? _thumbnail : throw Exception('POI has not thumbnail');

  String? labelLang(String lang) => _objLang('label', lang);

  String? commentLang(String lang) => _objLang('comment', lang);

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
      }
    }
    return null;
  }

  void setThumbnail(String image, String? license) {
    if (image.trim().isNotEmpty) {
      if (license == null) {
        _thumbnail = PairImage.withoutLicense(image);
      } else {
        _thumbnail = PairImage(image, license);
      }
    } else {
      throw Exception('Promble with empty image in setThumbnail');
    }
  }
}

class NPOI {
  late String _id;
  late double _lat, _long;
  late int _npois;

  NPOI(idZoneServer, latServer, longServer, npoisServer) {
    if (idZoneServer is String && idZoneServer.isNotEmpty) {
      _id = idZoneServer;
    } else {
      throw Exception('Problem with idZoneServer');
    }
    if (latServer is double && latServer >= 0 && latServer <= 90) {
      _lat = latServer;
    } else {
      throw Exception('Problem with latitudeServer');
    }
    if (longServer is double && longServer >= -180 && longServer <= 180) {
      _long = longServer;
    } else {
      throw Exception('Problem with longServer');
    }
    if (npoisServer is int && npoisServer >= 0) {
      _npois = npoisServer;
    } else {
      throw Exception('Problem with npoisServer');
    }
  }

  String get id => _id;
  double get lat => _lat;
  double get long => _long;
  int get npois => _npois;
}

class TeselaPoi {
  final double _lado = 0.0254;
  final int _unDia = 1000 * 60 * 60 * 24;
  late List<POI> _pois;
  late double _north, _west;
  late DateTime _update;
  late LatLngBounds _bounds;
  TeselaPoi(this._north, this._west, pois) {
    _bounds = LatLngBounds(
        LatLng(_north, _west), LatLng(_north - _lado, _west + _lado));
    _update = DateTime.now();
    _pois = [...pois];
  }

  TeselaPoi.withoutPois(double north, double west) {
    TeselaPoi(north, west, <POI>[]);
  }

  updateED() {
    _update = DateTime.now();
  }

  bool isValid() {
    return DateTime.now().isBefore(DateTime.fromMillisecondsSinceEpoch(
        _update.millisecondsSinceEpoch + _unDia));
  }

  List<POI> getPois() {
    return _pois;
  }

  bool isEqual(LatLng punto) {
    return (punto.latitude == _north && punto.longitude == _west);
  }

  bool checkIfContains(pointOrBound) {
    if (pointOrBound is LatLng) {
      return _bounds.contains(pointOrBound);
    } else {
      if (pointOrBound is LatLngBounds) {
        return _bounds.containsBounds(pointOrBound);
      } else {
        return false;
      }
    }
  }
}
