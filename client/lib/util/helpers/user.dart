import 'package:chest/util/helpers/answers.dart';
import 'package:chest/util/helpers/pair.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class UserCHEST {
  late String _id, _uri;
  late String? _alias, _email;
  late Set<Rol> _rol;
  late List<PairLang>? _comment;
  late Rol _cRol;
  List<Answer> answers = [];
  late LastPosition lastMapView;

  UserCHEST.guest() {
    _id = '';
    _alias = null;
    _comment = null;
    _email = null;
    _rol = {Rol.guest};
    _cRol = _rol.first;
    lastMapView = LastPosition.empty();
  }

  UserCHEST(dynamic data) {
    try {
      if (data != null && data is Map) {
        if (data.containsKey('id') &&
            data['id'] is String &&
            data['id'].toString().trim().isNotEmpty) {
          _id = data['id'].toString().trim();
        } else {
          throw Exception("User data: problem with id");
        }

        if (data.containsKey('rol') &&
            (data['rol'] is String ||
                data['rol'] is Set ||
                data['rol'] is List)) {
          _rol = {};
          if (data['rol'] is String) {
            data['rol'] = {data['rol']};
          }
          for (String rS in data['rol']) {
            switch (rS) {
              case 'USER':
              case 'STUDENT':
                _rol.add(Rol.user);
                break;
              case 'TEACHER':
                _rol.add(Rol.teacher);
                break;
              case 'ADMIN':
                _rol.add(Rol.admin);
                break;
              default:
                throw Exception('User data: problem with rol');
            }
          }
          _cRol = _rol.contains(Rol.admin)
              ? Rol.admin
              : _rol.contains(Rol.teacher)
                  ? Rol.teacher
                  : _rol.contains(Rol.user)
                      ? Rol.user
                      : throw Exception('User data: problem with crol');
        } else {
          throw Exception('User data: problem with rol');
        }

        // Opcionales
        _alias = data.containsKey('alias') && data['alias'] is String
            ? trim(data['alias'])
            : null;
        if (data.containsKey('comment')) {
          if (data['comment'] is Map) {
            data['comment'] = [data['comment']];
          }
          if (data['comment'] is List) {
            for (Map<String, dynamic> d in data['comment']) {
              if (d['comment'].containsKey('value') &&
                  d['comment'].containsKey('lang')) {
                _comment ??= [];
                _comment!
                    .add(PairLang(d['comment']['lang'], d['comment']['value']));
              } else {
                if (d['comment'].containsKey('value')) {
                  _comment ??= [];
                  _comment!.add(PairLang.withoutLang(d['comment']['value']));
                } else {
                  if (_comment != null && _comment!.isEmpty) {
                    _comment = null;
                  }
                }
              }
            }
          }
        } else {
          _comment = null;
        }
        if (data.containsKey('lastMapView') &&
            data['lastMapView'] is Map &&
            (data['lastMapView'] as Map).containsKey('lat') &&
            (data['lastMapView'] as Map)['lat'] is double &&
            (data['lastMapView'] as Map).containsKey('long') &&
            (data['lastMapView'] as Map)['long'] is double &&
            (data['lastMapView'] as Map).containsKey('zoom') &&
            (data['lastMapView'] as Map)['zoom'] is double) {
          lastMapView = LastPosition(
              (data['lastMapView'] as Map)['lat'],
              (data['lastMapView'] as Map)['long'],
              (data['lastMapView'] as Map)['zoom']);
        } else {
          lastMapView = LastPosition.empty();
        }
        // _email = data.containsKey('email') && data['email'] is String
        //     ? trim(data['email'])
        //     : null;
      } else {
        throw Exception('User data: it is null or is not a Map');
      }
    } catch (e) {
      debugPrint(e.toString());
      throw Exception(e);
    }
  }

  String get id => _id;
  String get iri => 'http://moult.gsic.uva.es/data/$_id';
  Rol get crol => _cRol;
  set crol(Rol rol) {
    if (_rol.contains(rol)) {
      _cRol = rol;
    } else {
      throw Exception('Forbidden');
    }
  }

  Set<Rol> get rol => _rol;

  String? get alias => _alias;
  set alias(String? alias) {
    _alias = trim(alias);
  }

  List<PairLang>? get comment => _comment;
  // set comment(List<PairLang>? comment) {
  //   _comment = comment;
  // }
  bool addComment(PairLang pairLang) {
    if (_comment != null) {
      bool encontrado = false;
      for (PairLang c in _comment!) {
        if (c.hasLang && pairLang.lang == c.lang) {
          encontrado = true;
          break;
        }
      }
      if (!encontrado) {
        _comment ??= [];
        _comment!.add(pairLang);
      }
      return !encontrado;
    } else {
      _comment = [pairLang];
      return true;
    }
  }

  String? getComment(String lang) {
    if (_comment != null) {
      int index = _comment!
          .indexWhere((element) => element.hasLang && element.lang == lang);
      return index > -1 ? _comment!.elementAt(index).value : null;
    }
    return null;
  }

  String? get email => _email;
  set email(String? email) {
    _email = trim(email);
  }

  String? trim(String? s) {
    if (s == null) {
      return s;
    }
    String t = s.trim();
    return t.isNotEmpty ? t : '';
  }

  bool get isNotGuest => !_rol.contains(Rol.guest);
}

enum Rol { user, teacher, admin, guest }

class LastPosition {
  late LatLng _point;
  late double _zoom;
  late bool _init;

  LastPosition.empty() {
    _init = false;
  }

  LastPosition(double lat, double long, double zoom) {
    _point = LatLng(lat, long);
    _zoom = zoom;
    _init = true;
  }

  double? get lat => _init ? _point.latitude : null;
  double? get long => _init ? _point.longitude : null;
  LatLng? get point => _init ? _point : null;
  double? get zoom => _init ? _zoom : null;
  bool get init => _init;

  Map<String, dynamic>? toJSON() {
    return _init
        ? {
            'lat': lat,
            'long': long,
            'zoom': zoom,
          }
        : null;
  }
}
