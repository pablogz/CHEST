import 'package:chest/util/helpers/answers.dart';
import 'package:flutter/foundation.dart';

class UserCHEST {
  late String _id;
  late String? _alias, _comment, _email;
  late Set<Rol> _rol;
  late Rol _cRol;
  List<Answer> answers = [];

  UserCHEST.guest() {
    _id = '';
    _alias = null;
    _comment = null;
    _email = null;
    _rol = {Rol.guest};
    _cRol = _rol.first;
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
            (data['rol'] is String || data['rol'] is Set)) {
          if (data['rol'] is String) {
            data['rol'] = {data['rol']};
          }
          for (String rS in data['rol']) {
            switch (rS) {
              case 'user':
                _rol.add(Rol.user);
                break;
              case 'teacher':
                _rol.add(Rol.teacher);
                break;
              case 'admin':
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
        _comment = data.containsKey('comment') && data['comment'] is String
            ? trim(data['comment'])
            : null;
        _email = data.containsKey('email') && data['email'] is String
            ? trim(data['email'])
            : null;
      } else {
        throw Exception('User data: it is null or is not a Map');
      }
    } catch (e) {
      debugPrint(e.toString());
      throw Exception(e);
    }
  }

  String get id => _id;
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

  String? get comment => _comment;
  set comment(String? comment) {
    _comment = trim(comment);
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
}

enum Rol { user, teacher, admin, guest }
