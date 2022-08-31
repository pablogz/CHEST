class UserCHEST {
  late String _id, _rol;
  UserCHEST(idServer, rolServer) {
    if (idServer is String && idServer.isNotEmpty) {
      _id = idServer;
    } else {
      throw Exception('Problem with user id');
    }
    if (rolServer is String && rolServer.isNotEmpty) {
      switch (rolServer) {
        case 'user':
        case 'teacher':
        case 'admin':
          _rol = rolServer;
          break;
        default:
          throw Exception('Problem with user rol');
      }
    } else {
      throw Exception('Problem with user rol');
    }
  }

  String get id => _id;
  set id(String id) {
    if (id.isNotEmpty) {
      _id = id;
    } else {
      throw Exception('Problem with user id');
    }
  }

  String get rol => _rol;
  set rol(String rol) {
    if (rol.isNotEmpty) {
      switch (rol) {
        case 'user':
        case 'teacher':
        case 'admin':
          _rol = rol;
          break;
        default:
          throw Exception('Problem with user rol');
      }
    } else {
      throw Exception('Problem with user rol');
    }
  }

  //Guardaré también las respuestas, notificaciones...
}
