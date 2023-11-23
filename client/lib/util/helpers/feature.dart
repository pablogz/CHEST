import 'dart:convert';

import 'package:chest/util/helpers/providers/dbpedia.dart';
import 'package:chest/util/helpers/providers/jcyl.dart';
import 'package:chest/util/helpers/providers/local_repo.dart';
import 'package:chest/util/helpers/providers/osm.dart';
import 'package:chest/util/helpers/providers/wikidata.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:chest/util/helpers/category.dart';
import 'package:chest/util/helpers/pair.dart';

class Feature {
  late String _id, _author, _shortId;
  final List<PairLang> _label = [], _comment = [];
  late PairImage _thumbnail;
  final List<PairImage> _image = [];
  late double _latitude, _longitude;
  late bool _hasThumbnail, inItinerary, _hasSource, _hasLocation;
  late String _source;
  final List<Category> _categories = [];
  final List<TagOSM> _tags = [];
  final List<LatLng> _geometry = [];
  final List<Provider> _providers = [];
  late bool ask4Resource;

  Feature.empty(this._shortId) {
    _id = '';
    _author = '';
    _hasThumbnail = false;
    inItinerary = false;
    _hasSource = false;
    _hasLocation = false;
    ask4Resource = false;
  }

  Feature.point(this._latitude, this._longitude) {
    _id = '';
    _author = '';
    _hasThumbnail = false;
    inItinerary = false;
    _hasSource = false;
    _hasLocation = true;
    ask4Resource = false;
  }

  Feature.fromJSON(Map<String, dynamic> data) {
    Feature(data);
  }

  Feature(dynamic data) {
    try {
      if (data != null && data is Map) {
        if (data.containsKey('id') &&
            data['id'] is String &&
            data['id'].toString().isNotEmpty) {
          _id = data['id'];
        } else {
          throw Exception('Problem with key "id".');
        }

        if (data.containsKey('shortId') &&
            data['shortId'] is String &&
            data['shortId'].toString().isNotEmpty) {
          _shortId = data['shortId'];
        } else {
          throw Exception('Problem with key "shortId".');
        }

        if (data.containsKey('labels')) {
          if (data['labels'] is String) {
            data['labels'] = {'value': data['labels']};
          }
          setLabels(data['labels']);
        } else {
          throw Exception('Problem with key "labels".');
        }

        if (data.containsKey('lat') && data['lat'] is double) {
          double latTemp = data['lat'];
          if (latTemp >= -90 && latTemp <= 90) {
            _hasLocation = true;
            _latitude = latTemp;
          } else {
            throw Exception('Problem with key "lat". [-90, 90].');
          }
        } else {
          throw Exception('Problem with key "lat"');
        }

        if (data.containsKey('long')) {
          double longTemp = data['long'];
          if (longTemp >= -180 && longTemp <= 180) {
            _longitude = longTemp;
          } else {
            throw Exception('Problem with key "long". [-180, 180].');
          }
        } else {
          throw Exception('Problem with key "long".');
        }

        if (data.containsKey('author')) {
          _author = data['author'].toString();
        } else {
          throw Exception('Problem with key "author".');
        }

        //OPTIONALS
        if (data.containsKey('descriptions')) {
          data['comments'] = data['descriptions'];
        }
        if (data.containsKey('comment')) {
          data['comments'] = data['comment'];
        }

        if (data.containsKey('comments')) {
          if (data['comments'] is String) {
            data['comments'] = {'value': data['comments']};
          }
          setComments(data['comments']);
        } else {
          setComments(data['labels']);
        }

        if (data.containsKey('thumbnailImg') &&
            data['thumbnailImg'].toString().isNotEmpty) {
          String imgTmp = data['thumbnailImg'].toString();
          String? licTmp;
          if (data.containsKey('thumbnailLic')) {
            licTmp = data['thumbnailLic'];
          } else {
            if (imgTmp.contains('commons.wikimedia.org/wiki/File:')) {
              licTmp = imgTmp;
              imgTmp = imgTmp
                  .replaceFirst('http://', 'https://')
                  .replaceFirst('File:', 'Special:FilePath/');
            }
          }
          setThumbnail(imgTmp, licTmp);
        } else {
          _hasThumbnail = false;
        }

        if (data.containsKey('tags')) {
          if (data['tags'] is Map) {
            for (var key in (data['tags'] as Map).keys) {
              _tags.add(TagOSM(key, data['tags'][key.toString()]));
            }
          }
        }

        if (_hasSource = data.containsKey('source')) {
          _source = data['source'];
          _hasSource = true;
        } else {
          _hasSource = false;
        }

        inItinerary = false;

        if (data.containsKey('categories')) {
          categories = data['categories'];
        }

        if (data.containsKey('geometry') && data['geometry'] is List) {
          bool sinErrores = true;
          List<LatLng> temp = [];
          for (int i = 0, tama = (data['geometry'] as List).length;
              i < tama;
              i++) {
            var ele = data['geometry'][i];
            if (ele is Map &&
                ele.containsKey('lat') &&
                ele['lat'] is double &&
                ele.containsKey('long') &&
                ele['long'] is double &&
                ele['lat'] <= 90 &&
                ele['lat'] >= -90 &&
                ele['long'] <= 180 &&
                ele['long'] >= -180) {
              temp.add(LatLng(ele['lat'], ele['long']));
            } else {
              sinErrores = false;
              break;
            }
          }
          if (sinErrores) {
            _geometry.addAll(temp);
          }
        }

        if (data.containsKey('provider')) {
          addProvider(data['provider'], data);
        } else {
          if (data.containsKey('providers') && data['providers'] is List) {
            for (Map<String, dynamic> provider in data[providers]) {
              providers.add(Provider(
                provider['id'],
                provider['data'].fromJSON(),
                timestamp:
                    DateTime.fromMicrosecondsSinceEpoch(provider['timestamp']),
              ));
            }
          }
        }

        ask4Resource = false;
      }
    } catch (error) {
      throw Exception('Proble in Feature constructor: ${error.toString()}');
    }
  }

  String get id => _id;
  set id(String idServer) {
    if (idServer.isNotEmpty) {
      _id = idServer;
    } else {
      throw Exception('Problem with idServer');
    }
  }

  String get shortId => _shortId;
  set shortId(String shortIdServer) {
    if (shortIdServer.isNotEmpty) {
      _shortId = shortIdServer;
    } else {
      throw Exception('Problem with shortIdServer');
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
  bool get hasLocation => _hasLocation;
  List<LatLng> get geometry => _geometry;

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
    // if (newLabel.hasLang) {
    //   for (var e in _label) {
    //     if (e.hasLang && e.lang == newLabel.lang) {
    //       _label.remove(e);
    //       break;
    //     }
    //   }
    // }
    _label.add(newLabel);
  }

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
    } else {
      throw Exception('Problem with labelS');
    }
  }

  String? commentLang(String lang) => _objLang('comment', lang);
  void addCommentLang(PairLang newComment) {
    // if (newComment.hasLang) {
    //   for (var e in _comment) {
    //     if (e.hasLang && e.lang == newComment.lang) {
    //       _comment.remove(e);
    //       break;
    //     }
    //   }
    // }
    _comment.add(newComment);
  }

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
      _hasThumbnail = false;
    }
  }

  void addImage(String urlImage, {String? license}) {
    if (urlImage.trim().isNotEmpty) {
      _image.add(license == null
          ? PairImage.withoutLicense(urlImage)
          : PairImage(urlImage, license));
      if (!_hasThumbnail) {
        setThumbnail(urlImage, license);
      }
    }
  }

  List<Map<String, String>> comments2List() => _object2List(comments);

  List<Map<String, String>> labels2List() => _object2List(labels);

  Map<String, dynamic> thumbnail2Map() => thumbnail.toMap(isThumb: true);

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

  set tags(listTags) {
    if (listTags is Map) {
      for (String key in listTags.keys) {
        _tags.add(TagOSM(key, listTags[key]));
      }
    } else {
      throw Exception('Problem with tags');
    }
  }

  List<TagOSM> get tags => _tags;

  List<Provider> get providers => _providers;

  addProvider(String providerId, dynamic data) {
    dynamic obj;
    switch (providerId) {
      case 'osm':
        obj = data is OSM ? data : OSM((data as Map<String, dynamic>));
        break;
      case 'wikidata':
        obj =
            data is Wikidata ? data : Wikidata((data as Map<String, dynamic>));
        break;
      case 'jcyl':
        obj = data is JCyL ? data : JCyL((data as Map<String, dynamic>));
        break;
      case 'dbpedia':
      case 'esDBpedia':
        obj = data is DBpedia
            ? data
            : DBpedia((data as Map<String, dynamic>), providerId);
        break;
      case 'localRepo':
        obj =
            data is LocalRepo ? data : LocalRepo(data as Map<String, dynamic>);
        break;
      default:
        obj = null;
    }
    if (obj != null) {
      int index = _providers.indexWhere((Provider p) => p.id == providerId);
      if (index >= 0) {
        _providers.removeAt(index);
      }
      _providers.add(Provider(providerId, obj));
    } else {
      throw Exception('Provider unknown');
    }
  }

  Object? getProvider(String providerId) {
    int index =
        providers.indexWhere((Provider provider) => provider.id == providerId);
    return index < 0 ? null : providers.elementAt(index);
  }

  Map<String, dynamic> toJSON() {
    Map<String, dynamic> out = {
      'id': id,
      'shortId': shortId,
      'lat': lat,
      'long': long,
      'author': author,
    };
    List<String> lists = [];
    for (PairLang label in labels) {
      lists.add(jsonEncode(label.toMap()));
    }
    out['labels'] = lists;
    lists = [];
    for (PairLang comment in comments) {
      lists.add(jsonEncode(comment.toMap()));
    }
    out['descriptions'] = lists;

    if (hasThumbnail) {
      out['thumnailImg'] = thumbnail.image.toString();
      if (thumbnail.hasLicense) {
        out['thumbnailLic'] = thumbnail.license.toString();
      }
    }

    if (tags.isNotEmpty) {
      lists = [];
      for (TagOSM tag in tags) {
        lists.add(jsonEncode(tag.toMap()));
      }
      out['tags'] = lists;
    }

    if (hasSource) {
      out['source'] = source;
    }

    if (categories.isNotEmpty) {
      lists = [];
      for (Category category in categories) {
        lists.add(jsonEncode(category.toMap()));
      }
      out['categories'] = lists;
    }

    if (geometry.isNotEmpty) {
      lists = [];
      for (LatLng geo in geometry) {
        lists.add(jsonEncode({'lat': geo.latitude, 'long': geo.longitude}));
      }
      out['geometry'] = lists;
    }

    if (providers.isNotEmpty) {
      lists = [];
      for (Provider provider in providers) {
        lists.add(jsonEncode(provider.toJSON()));
      }
      out['providers'] = lists;
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

class TeselaFeature {
  final double _lado = 0.09;
  final int _unDia = 1000 * 60 * 60 * 24;
  late List<Feature> _features;
  late double _north, _west;
  late DateTime _update;
  late LatLngBounds _bounds;

  TeselaFeature(this._north, this._west, features, {DateTime? update}) {
    _bounds = LatLngBounds(
        LatLng(_north, _west), LatLng(_north - _lado, _west + _lado));
    _update = update ?? DateTime.now();
    _features = [...features];
  }

  TeselaFeature.withoutFeatures(double north, double west) {
    TeselaFeature(north, west, <Feature>[]);
  }

  TeselaFeature.fromJSON(Map<String, dynamic> data) {
    if (data.containsKey('north') &&
        data['north'] is double &&
        data['north'] <= 90 &&
        data['north'] >= -90 &&
        data.containsKey('west') &&
        data['west'] is double &&
        data['west'] <= 180 &&
        data['west'] >= -180 &&
        data.containsKey('update') &&
        data['update'] is int &&
        data.containsKey('features') &&
        data['features'] is List) {
      List<Feature> lstFeatures = [];
      Map<String, dynamic> dataFeature;
      for (String f in data['features']) {
        dataFeature = jsonDecode(f) as Map<String, dynamic>;
        lstFeatures.add(Feature.fromJSON(dataFeature));
      }
      TeselaFeature(
        data['north'],
        data['west'],
        lstFeatures,
        update: DateTime.fromMicrosecondsSinceEpoch(data['update']),
      );
    }
  }

  updateED() {
    _update = DateTime.now();
  }

  bool isValid() {
    return DateTime.now().isBefore(DateTime.fromMillisecondsSinceEpoch(
        _update.millisecondsSinceEpoch + _unDia));
  }

  List<Feature> get features => _features;
  double get north => _north;
  double get west => _west;
  DateTime get update => _update;

  // List<Feature> getPois() {
  //   return _pois;
  // }

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

  void addFeature(Feature feature) {
    if (indexFeature(feature) == -1) {
      _features.add(feature);
    }
  }

  void removeFeature(Feature feature) {
    int index = indexFeature(feature);
    if (index > -1) {
      _features.removeAt(index);
    }
  }

  int indexFeature(Feature feature) =>
      features.indexWhere((Feature f) => f.id == feature.id);

  Map<String, dynamic> toJSON() {
    Map<String, dynamic> out = {
      'north': north,
      'west': west,
      'update': update.microsecondsSinceEpoch,
    };
    List<String> lstFeatures = [];
    for (Feature f in features) {
      lstFeatures.add(jsonEncode(f.toJSON()));
    }
    out['features'] = lstFeatures;
    return out;
  }
}

class Provider {
  final String _id;
  late DateTime _timestamp;
  final dynamic _data;

  Provider(this._id, this._data, {DateTime? timestamp}) {
    _timestamp = timestamp ?? DateTime.now();
  }

  String get id => _id;
  DateTime get timestamp => _timestamp;
  dynamic get data => _data;

  Map<String, dynamic> toJSON() {
    return {
      'id': id,
      'data': data.toJSON(),
      'timestamp': timestamp.microsecondsSinceEpoch
    };
  }
}
