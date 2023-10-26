import 'package:chest/util/helpers/answers.dart';

class UserCHEST {
  late String _id, _firstname, _lastname;
  late Rol _rol, _cRol;
  List<Answer> answers = [];

  UserCHEST.guest() {
    _id = '';
    _firstname = '';
    _lastname = '';
    _rol = Rol.guest;
    _cRol = _rol;
  }

  UserCHEST(idServer, rolServer) {
    if (idServer is String && idServer.isNotEmpty) {
      _id = idServer;
    } else {
      throw Exception('Problem with user id');
    }
    if (rolServer is String && rolServer.isNotEmpty) {
      switch (rolServer) {
        case 'user':
          _rol = Rol.user;
          break;
        case 'teacher':
          _rol = Rol.teacher;
          break;
        case 'admin':
          _rol = Rol.admin;
          break;
        default:
          throw Exception('Problem with user rol');
      }
      _cRol = _rol;
    } else {
      throw Exception('Problem with user rol');
    }
    _firstname = '';
    _lastname = '';
  }

  String get id => _id;
  Rol get crol => _cRol;
  set crol(Rol rol) {
    switch (_rol) {
      case Rol.admin:
        _cRol = rol;
        break;
      case Rol.teacher:
        if (rol == Rol.user || rol == Rol.teacher) {
          _cRol = rol;
        } else {
          throw Exception('Forbidden');
        }
        break;
      default:
        throw Exception('Forbidden');
    }
  }

  Rol get rol => _rol;

  String get firstname => _firstname;
  set firstname(String firstname) {
    _firstname = firstname.trim().isNotEmpty ? firstname.trim() : '';
  }

  String get lastname => _lastname;
  set lastname(String lastname) {
    _lastname = lastname.trim().isNotEmpty ? lastname.trim() : '';
  }
}

enum Rol { user, teacher, admin, guest }
