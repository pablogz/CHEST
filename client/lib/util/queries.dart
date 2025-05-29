import 'dart:math';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:chest/util/config.dart';
import 'package:chest/util/auxiliar.dart';

class Queries {
  /*+++++++++++++++++++++++++++++++++++
  + USERS                             +
  +++++++++++++++++++++++++++++++++++*/
  // GET info user
  static Uri signIn() => Uri.parse('${Config.addServer}/users/user');
  static Uri getUser() => signIn();
  // PUT user: new user or edit user.
  static Uri putUser() => signIn();
  // DELETE user
  static Uri deleteUser() => signIn();
  // POST answer: new answer
  static Uri newAnswer() => Uri.parse('${Config.addServer}/users/user/answers');
  static Uri getAnswers() => newAnswer();
  // GET/PUT PREFERENCES
  static Uri preferences() =>
      Uri.parse('${Config.addServer}/users/user/preferences');

  /*+++++++++++++++++++++++++++++++++++
  + Features                          +
  +++++++++++++++++++++++++++++++++++*/

  static LayerType get layerType => LayerType.ch;

  //GET info features bounds
  static Uri getFeatures(Map<String, dynamic> parameters) {
    String lType;
    switch (layerType) {
      case LayerType.forest:
      case LayerType.schools:
        lType = '&type=${layerType.name}';
        break;
      default:
        lType = '';
    }
    return Uri.parse(
        '${Config.addServer}/features?north=${parameters['north']}&west=${parameters['west']}&south=${parameters['south']}&east=${parameters['east']}&group=${parameters['group']}$lType');
  }

  //POST
  static Uri newFeature() => Uri.parse('${Config.addServer}/features');

  /*+++++++++++++++++++++++++++++++++++
  + Features                          +
  +++++++++++++++++++++++++++++++++++*/
  //DELETE
  static Uri deleteFeature(idFeature) => Uri.parse(
      '${Config.addServer}/features/${Auxiliar.getIdFromIri(idFeature)}');

  static Uri getFeatureInfo(idFeature) => Uri.parse(
      '${Config.addServer}/features/${Auxiliar.getIdFromIri(idFeature)}');

  /*+++++++++++++++++++++++++++++++++++
  + Learning tasks
  +++++++++++++++++++++++++++++++++++*/
  //GET
  static Uri getTasks(String shortIdFeature) =>
      Uri.parse('${Config.addServer}/features/$shortIdFeature/learningTasks');

  /*+++++++++++++++++++++++++++++++++++
  + Learning task
  +++++++++++++++++++++++++++++++++++*/
  static Uri deleteTask(String shortIdFeature, String shortIdTask) => Uri.parse(
      '${Config.addServer}/features/$shortIdFeature/learningTasks/$shortIdTask');

  static Uri newTask(String shortIdFeature) =>
      Uri.parse('${Config.addServer}/features/$shortIdFeature/learningTasks');

  static Uri getTask(String shortIdFeature, String shortIdTask) => Uri.parse(
      '${Config.addServer}/features/$shortIdFeature/learningTasks/$shortIdTask');

  /*+++++++++++++++++++++++++++++++++++
  + Info POI LOD
  +++++++++++++++++++++++++++++++++++*/
  //GET
  static Uri getFeaturesLod(LatLng point, LatLngBounds bounds) => Uri.parse(
      '${Config.addServer}/features/lod?lat=${point.latitude}&long=${point.longitude}&incr=${max(0.2, min(1, max(bounds.north - bounds.south, (bounds.east - bounds.west).abs())))}');

  /*+++++++++++++++++++++++++++++++++++
  + Itineraries                       +
  +++++++++++++++++++++++++++++++++++*/
  //GET
  static Uri getItineraries() => Uri.parse('${Config.addServer}/itineraries');

  //POST
  static Uri newItinerary() => Uri.parse('${Config.addServer}/itineraries');

  /*+++++++++++++++++++++++++++++++++++
  + Itinerary                         +
  +++++++++++++++++++++++++++++++++++*/
  //GET
  static Uri getItinerary(String idIt) => Uri.parse(
      '${Config.addServer}/itineraries/${Auxiliar.getIdFromIri(idIt)}');

  static Uri getItineraryFeatures(String idIt) => Uri.parse(
      '${Config.addServer}/itineraries/${Auxiliar.getIdFromIri(idIt)}/features');

  static Uri getItineraryTask(String idIt) => Uri.parse(
      '${Config.addServer}/itineraries/${Auxiliar.getIdFromIri(idIt)}/learningTasks');

  static Uri getItineraryTrack(String idIt) => Uri.parse(
      '${Config.addServer}/itineraries/${Auxiliar.getIdFromIri(idIt)}/track');

  //DELETE
  static Uri deleteIt(String idIt) => getItinerary(idIt);

  //Tasks Feature It
  static Uri getTasksFeatureIt(String idIt, String idFeature) => Uri.parse(
      '${Config.addServer}/itineraries/${Auxiliar.getIdFromIri(idIt)}/features/$idFeature/learningTasks');

  static Uri getSuggestions(String q, {Object? dict}) {
    if (dict == null) {
      return Uri.parse('${Config.addSolr}/suggest?q=$q');
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
        return Uri.parse('${Config.addSolr}/suggest?$suggestDict&q=$q');
      }
      return Uri.parse('${Config.addSolr}/suggest?q=$q');
    }
  }

  static Uri getSuggestion(String id) =>
      Uri.parse('${Config.addSolr}/select?q=id:"$id"');

  /*+++++++++++++++++++++++++++++++++++
  + Feeds                             +
  +++++++++++++++++++++++++++++++++++*/
  // GET, POST
  static Uri feeds() => Uri.parse('${Config.addClient}/feeds/');
  // GET, PUT, DELETE
  static Uri feed(String idFeed) =>
      Uri.parse('${Config.addClient}/feeds/$idFeed/');
  // GET
  static Uri feedSubscribers(String idFeed) =>
      Uri.parse('${Config.addClient}/feeds/$idFeed/subscribers/');
  // POST
  static Uri feedSubscription(String idFeed, ActionSubcription action) => Uri.parse(
      '${Config.addClient}/feeds/$idFeed/subscribers/subcription?action=${action.name}');
  // GET, POST
  static Uri feedAnswers(String idFeed) =>
      Uri.parse('${Config.addClient}/feeds/$idFeed/subscribers/answers/');
  // GET, PUT, DELETE
  static Uri feedAnswer(String idFeed, String idAnswer) => Uri.parse(
      '${Config.addClient}/feeds/$idFeed/subscribers/answers/$idAnswer/');
}

enum ActionSubcription { unsubscribe }

enum LayerType { ch, schools, forest }
