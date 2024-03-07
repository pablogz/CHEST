import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mustache_template/mustache.dart';

import 'package:chest/util/config.dart';
import 'package:chest/util/auxiliar.dart';

class Queries {
  /*+++++++++++++++++++++++++++++++++++
  + USERS
  +++++++++++++++++++++++++++++++++++*/
  // GET info user
  Uri signIn() => Uri.parse(Template('{{{addServer}}}/users/user')
      .renderString({'addServer': Config.addServer}));
  Uri getUser() => signIn();
  // PUT user: new user or edit user.
  Uri putUser() => Uri.parse(Template('{{{addServer}}}/users/user')
      .renderString({'addServer': Config.addServer}));
  // POST answer: new answer
  Uri newAnswer() => Uri.parse(Template('{{{addServer}}}/users/user/answers')
      .renderString({'addServer': Config.addServer}));
  // GET/PUT PREFERENCES
  Uri preferences() {
    return Uri.parse(
        Template('{{{addServer}}}/users/user/preferences').renderString({
      'addServer': Config.addServer,
    }));
  }

  /*+++++++++++++++++++++++++++++++++++
  + POIs
  +++++++++++++++++++++++++++++++++++*/

  static LayerType layerType = LayerType.ch;

  //GET info POIs bounds
  Uri getFeatures(Map<String, dynamic> parameters) {
    String lType;
    switch (layerType) {
      case LayerType.forest:
      case LayerType.schools:
        lType = '&type=${layerType.name}';
        break;
      default:
        lType = '';
    }
    return Uri.parse(Template(
            '{{{dirAdd}}}/features?north={{{north}}}&west={{{west}}}&south={{{south}}}&east={{{east}}}&group={{{group}}}{{{type}}}')
        .renderString({
      'dirAdd': Config.addServer,
      'north': parameters['north'],
      'south': parameters['south'],
      'west': parameters['west'],
      'east': parameters['east'],
      'group': parameters['group'],
      'type': lType,
    }));
  }

  //POST
  Uri newPoi() {
    return Uri.parse(Template('{{{addr}}}/features')
        .renderString({'addr': Config.addServer}));
  }

  /*+++++++++++++++++++++++++++++++++++
  + POI
  +++++++++++++++++++++++++++++++++++*/
  //DELETE
  Uri deletePOI(idPoi) {
    return Uri.parse(Template('{{{dirAdd}}}/features/{{{poi}}}').renderString({
      'dirAdd': Config.addServer,
      'poi': Auxiliar.getIdFromIri(idPoi),
    }));
  }

  Uri getFeatureInfo(idPoi) {
    return Uri.parse(
        Template('{{{dirAdd}}}/features/{{{feature}}}').renderString({
      'dirAdd': Config.addServer,
      'feature': Auxiliar.getIdFromIri(idPoi),
    }));
  }

  /*+++++++++++++++++++++++++++++++++++
  + Learning tasks
  +++++++++++++++++++++++++++++++++++*/
  //GET
  Uri getTasks(String shortIdFeature) {
    return Uri.parse(
        Template('{{{dirAdd}}}/features/{{{feature}}}/learningTasks')
            .renderString({
      'dirAdd': Config.addServer,
      'feature': shortIdFeature,
    }));
  }

  /*+++++++++++++++++++++++++++++++++++
  + Learning task
  +++++++++++++++++++++++++++++++++++*/
  Uri deleteTask(String shortIdFeature, String shortIdTask) {
    return Uri.parse(
        Template('{{{dirAdd}}}/features/{{{feature}}}/learningTasks/{{{task}}}')
            .renderString({
      'dirAdd': Config.addServer,
      'feature': shortIdFeature,
      'task': shortIdTask
    }));
  }

  Uri newTask(String shortIdFeature) {
    return Uri.parse(
        Template('{{{dirAdd}}}/features/{{{feature}}}/learningTasks')
            .renderString({
      'dirAdd': Config.addServer,
      'feature': shortIdFeature,
    }));
  }

  Uri getTask(String shortIdFeature, String shortIdTask) {
    return Uri.parse(
        '${Config.addServer}/features/$shortIdFeature/learningTasks/$shortIdTask');
  }

  /*+++++++++++++++++++++++++++++++++++
  + Info POI LOD
  +++++++++++++++++++++++++++++++++++*/
  //GET
  Uri getPoisLod(LatLng point, LatLngBounds bounds) {
    return Uri.parse(
      Template(
              '{{{dirAdd}}}/features/lod?lat={{{lat}}}&long={{{long}}}&incr={{{incr}}}')
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
      }),
    );
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

  /*+++++++++++++++++++++++++++++++++++
  + Itinerary
  +++++++++++++++++++++++++++++++++++*/
  //GET
  Uri getItinerary(String idIt) {
    return Uri.parse(
        Template('{{{dirAdd}}}/itineraries/{{{id}}}').renderString({
      'dirAdd': Config.addServer,
      'id': Auxiliar.getIdFromIri(idIt),
    }));
  }

  //DELETE
  Uri deleteIt(String idIt) {
    return getItinerary(idIt);
  }

  //Tasks Feature It
  Uri getTasksFeatureIt(String idIt, String idFeature) {
    return Uri.parse(
        Template('{{{dirAdd}}}/itineraries/{{{id}}}/features/{{{idF}}}')
            .renderString({
      'dirAdd': Config.addServer,
      'id': Auxiliar.getIdFromIri(idIt),
      'idF': Auxiliar.getIdFromIri(idFeature),
    }));
  }

  Uri getSuggestions(String q, {Object? dict}) {
    if (dict == null) {
      return Uri.parse(
          Template('{{{dirSolr}}}/suggest?q={{{query}}}').renderString({
        'dirSolr': Config.addSolr,
        'query': q,
      }));
    } else {
      if (dict is String) {
        dict = [dict];
      }
      if (dict is List) {
        String suggestDict = '';
        for (String d in dict) {
          String lbl;
          switch (d.toLowerCase()) {
            case 'es':
              lbl = 'chestEs';
              break;
            case 'pt':
              lbl = 'chestPt';
              break;
            default:
              lbl = 'chestEn';
          }
          if (suggestDict.isEmpty) {
            suggestDict = 'suggest.dictionary=$lbl';
          } else {
            suggestDict = '$suggestDict&suggest.dictionary=$lbl';
          }
        }
        return Uri.parse(
            Template('{{{dirSolr}}}/suggest?{{{sDict}}}&q={{{query}}}')
                .renderString({
          'dirSolr': Config.addSolr,
          'sDict': suggestDict,
          'query': q,
        }));
      } else {
        return Uri.parse(
            Template('{{{dirSolr}}}/suggest?q={{{query}}}').renderString({
          'dirSolr': Config.addSolr,
          'query': q,
        }));
      }
    }
  }

  Uri getSuggestion(String id) {
    return Uri.parse(
        Template('{{{dirSolr}}}/select?q=id:"{{{id}}}"').renderString({
      'dirSolr': Config.addSolr,
      'id': id,
    }));
  }
}

enum LayerType { ch, schools, forest }
