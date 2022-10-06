import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:flutter_map/src/geo/latlng_bounds.dart';
import 'package:mustache_template/mustache.dart';

import '../config.dart';
import 'auxiliar.dart';

class Queries {
  /*+++++++++++++++++++++++++++++++++++
  + USERS
  +++++++++++++++++++++++++++++++++++*/
  //GET info user
  Uri signIn() => Uri.parse(Template('{{{addServer}}}/users/user')
      .renderString({'addServer': Config.addServer}));
  //PUT user: new user or edit user.
  Uri putUser() => Uri.parse(Template('{{{addServer}}}/users/user')
      .renderString({'addServer': Config.addServer}));
  /*+++++++++++++++++++++++++++++++++++
  + POIs
  +++++++++++++++++++++++++++++++++++*/
  //GET info POIs bounds
  Uri getPOIs(Map<String, dynamic> parameters) {
    return Uri.parse(Template(
            '{{{dirAdd}}}/pois?north={{{north}}}&west={{{west}}}&south={{{south}}}&east={{{east}}}&group={{{group}}}')
        .renderString({
      'dirAdd': Config.addServer,
      'north': parameters['north'],
      'south': parameters['south'],
      'west': parameters['west'],
      'east': parameters['east'],
      'group': parameters['group']
    }));
  }

  //POST
  Uri newPoi() {
    return Uri.parse(
        Template('{{{addr}}}/pois').renderString({'addr': Config.addServer}));
  }

  /*+++++++++++++++++++++++++++++++++++
  + POI
  +++++++++++++++++++++++++++++++++++*/
  //DELETE
  Uri deletePOI(idPoi) {
    return Uri.parse(Template('{{{dirAdd}}}/pois/{{{poi}}}').renderString({
      'dirAdd': Config.addServer,
      'poi': Auxiliar.getIdFromIri(idPoi),
    }));
  }

  /*+++++++++++++++++++++++++++++++++++
  + Learning tasks
  +++++++++++++++++++++++++++++++++++*/
  //GET
  Uri getTasks(String poi) {
    return Uri.parse(Template('{{{dirAdd}}}/tasks?poi={{{poi}}}').renderString({
      'dirAdd': Config.addServer,
      'poi': poi,
    }));
  }

  /*+++++++++++++++++++++++++++++++++++
  + Info POI LOD
  +++++++++++++++++++++++++++++++++++*/
  //GET
  Uri getPoisLod(LatLng point, LatLngBounds bounds) {
    return Uri.parse(Template(
            '{{{dirAdd}}}/pois/lod?lat={{{lat}}}&long={{{long}}}&incr={{{incr}}}')
        .renderString({
      'dirAdd': Config.addServer,
      'lat': point.latitude,
      'long': point.longitude,
      'incr': max(
          0.2,
          min(
              1,
              max(bounds.north - bounds.south,
                  (bounds.east - bounds.west).abs())))
    }));
  }

  /*+++++++++++++++++++++++++++++++++++
  + Itineraries
  +++++++++++++++++++++++++++++++++++*/
  //GET
  Uri getItineraries() {
    return Uri.parse(Template(
      '{{{dirAdd}}}/itineraries',
    ).renderString({
      'dirAdd': Config.addServer,
    }));
  }

  //POST
  Uri newItinerary() {
    return Uri.parse(Template(
      '{{{dirAdd}}}/itineraries',
    ).renderString({
      'dirAdd': Config.addServer,
    }));
  }
}
