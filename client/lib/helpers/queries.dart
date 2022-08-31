import 'package:mustache_template/mustache.dart';

import '../config.dart';

class Queries {
  /*+++++++++++++++++++++++++++++++++++
  + USERS
  +++++++++++++++++++++++++++++++++++*/
  //GET info user
  Uri signIn() => Uri.parse(Template('{{{addServer}}}/users/user')
      .renderString({'addServer': Config.addServer}));
  /*+++++++++++++++++++++++++++++++++++
  + POIs
  +++++++++++++++++++++++++++++++++++*/
  //GET info POIs bounds
  Uri getPOIs(Map<String, dynamic> parameters) => Uri.parse(Template(
              '{{{dirAdd}}}/pois?north={{{north}}}&west={{{west}}}&south={{{south}}}&east={{{east}}}&group={{{group}}}')
          .renderString({
        'dirAdd': parameters['dirAdd'],
        'north': parameters['north'],
        'south': parameters['south'],
        'west': parameters['west'],
        'east': parameters['east'],
        'group': parameters['group']
      }));
}
