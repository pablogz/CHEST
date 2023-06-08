import 'package:latlong2/latlong.dart';

class OSM {
  final TypeOSM _typeOSM;
  final int _id;
  final double _lat, _long;
  late List<TagOSM> _tags;
  String? author, timestamp;
  OSM(this._typeOSM, this._id, this._lat, this._long, tagsServer) {
    try {
      _tags = [];
      if (tagsServer is Map) {
        for (String key in tagsServer.keys) {
          _tags.add(TagOSM(key, tagsServer[key]));
        }
      } else {
        throw Exception('Tags problem');
      }
    } catch (error) {
      throw Exception('Tags problem');
    }
  }

  TypeOSM get type => _typeOSM;
  int get id => _id;
  double get lat => _lat;
  double get long => _long;
  LatLng get point => LatLng(_lat, _long);
}

enum TypeOSM { node, way, relation }

class TagOSM {
  late final String _key;
  late final dynamic _value;
  TagOSM(this._key, this._value);
  String get key => _key;
  String get value => _value.toString();
}
