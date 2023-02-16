import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:chest/helpers/pair.dart';
import 'package:chest/helpers/category.dart';

class POI {
  late String _id, _author;
  final List<PairLang> _label = [], _comment = [];
  late PairImage _thumbnail;
  final List<PairImage> _image = [];
  late double _latitude, _longitude;
  late bool _hasThumbnail, inItinerary, _hasSource;
  late String _source;
  final List<Category> _categories = [];

  POI.point(this._latitude, this._longitude) {
    _id = '';
    _author = '';
    _hasThumbnail = false;
    inItinerary = false;
    _hasSource = false;
  }

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
    _hasSource = false;
    inItinerary = false;
  }

  String get id => _id;
  set id(String idServer) {
    if (idServer.isNotEmpty) {
      _id = idServer;
    } else {
      throw Exception('Problem with idServer');
    }
  }

  String get author => _author;
  set author(String authorServer) {
    if (authorServer.isNotEmpty) {
      _author = authorServer;
    } else {
      throw Exception('Problem with authorServer');
    }
  }

  List<PairLang> get labels => _label;
  List<PairLang> get comments => _comment;
  double get lat => _latitude;
  set lat(double lat) {
    if (lat <= 90 && lat >= -90) {
      _latitude = lat;
    } else {
      throw Exception('Latitude problem!!');
    }
  }

  double get long => _longitude;
  set long(double long) {
    if (long <= 180 && lat >= -180) {
      _longitude = long;
    } else {
      throw Exception('Longitude problem!!');
    }
  }

  LatLng get point => LatLng(_latitude, _longitude);
  bool get hasThumbnail => _hasThumbnail;
  bool get hasSource => _hasSource;

  String get source =>
      _hasSource ? _source : throw Exception('POI has not source!!');
  set source(source) {
    _source = source;
    _hasSource = true;
  }

  PairImage get thumbnail =>
      _hasThumbnail ? _thumbnail : throw Exception('POI has not thumbnail');

  String? labelLang(String lang) => _objLang('label', lang);
  void addLabelLang(PairLang newLabel) {
    if (newLabel.hasLang) {
      for (var e in _label) {
        if (e.hasLang && e.lang == newLabel.lang) {
          _label.remove(e);
          break;
        }
      }
    }
    _label.add(newLabel);
  }

  String? commentLang(String lang) => _objLang('comment', lang);
  void addCommentLang(PairLang newComment) {
    if (newComment.hasLang) {
      for (var e in _comment) {
        if (e.hasLang && e.lang == newComment.lang) {
          _comment.remove(e);
          break;
        }
      }
    }
    _comment.add(newComment);
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

  void setThumbnail(String image, String? license) {
    if (image.trim().isNotEmpty) {
      _hasThumbnail = true;
      if (license == null) {
        _thumbnail = PairImage.withoutLicense(image);
      } else {
        _thumbnail = PairImage(image, license);
      }
    } else {
      throw Exception('Problem with empty image in setThumbnail');
    }
  }

  List<Map<String, String>> comments2List() => _object2List(comments);

  List<Map<String, String>> labels2List() => _object2List(labels);

  Map<String, dynamic> thumbnail2Map() => thumbnail.toMap(true);

  List<Map<String, String>> _object2List(obj) {
    List<Map<String, String>> out = [];
    for (var element in obj) {
      out.add(element.toMap());
    }
    return out;
  }

  List<Category> get categories => _categories;
  set categories(categories) {
    if (categories is Map) {
      categories = [categories];
    }
    if (categories is List) {
      for (var category in categories) {
        addCategory(category);
      }
    }
  }

  void addCategory(category) {
    if (category is Category) {
      int index = _categories.indexWhere((Category c) => c.iri == category.iri);
      if (index == -1) {
        _categories.add(category);
      }
    } else {
      if (category['iri'] != null) {
        Category aux = Category(category['iri']);
        if (category['label'] != null) {
          aux.label = category['label'];
        }
        if (category['broader'] != null) {
          aux.broader = category['broader'];
        }
        _categories.add(aux);
      } else {
        throw Exception('Problem with category (No iri)');
      }
    }
  }

  void deleteCategory(Category category) {
    int index = _categories.indexWhere((Category c) => c.iri == category.iri);
    if (index > -1) {
      _categories.removeWhere((element) => element.iri == category.iri);
    }
  }

  List<Map<String, dynamic>> categoriesToList() {
    List<Map<String, dynamic>> out = [];
    for (Category c in categories) {
      out.add(c.toMap());
    }
    return out;
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

  bool isEqualPoint(LatLng punto) {
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

  void addPoi(POI poi) {
    if (indexPoi(poi) == -1) {
      _pois.add(poi);
    }
  }

  void removePoi(POI poi) {
    int index = indexPoi(poi);
    if (index > -1) {
      _pois.removeAt(index);
    }
  }

  int indexPoi(POI poi) => _pois.indexWhere((POI p) => p.id == poi.id);
}
