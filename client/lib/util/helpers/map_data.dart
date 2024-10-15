import 'dart:convert';
import 'dart:math';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import 'package:chest/util/config.dart';
import 'package:chest/util/helpers/feature.dart';
import 'package:chest/util/queries.dart';
import 'package:chest/util/helpers/auxiliar_mobile.dart'
    if (dart.libary.html) 'package:chest/util/helpers/auxiliar_web.dart';

class MapData {
  static const double tileSide = 0.09;
  static final List<TeselaFeature> _teselaFeature = [];
  static const LatLng _posRef = LatLng(41.66, -4.71);
  static int pendingTiles = 0;
  static int totalTiles = 0;
  static ValueNotifier valueNotifier = ValueNotifier<double?>(0);

  /// Remove all cache data
  static void resetLocalCache() =>
      _teselaFeature.removeRange(0, _teselaFeature.length);

  /// Ask to the server for the number of Features inside [mapBounds]
  static Future<List<NPOI>> checkCurrentMapBounds(
      LatLngBounds mapBounds) async {
    try {
      Future<List<NPOI>> out = http
          .get(Queries.getFeatures({
        'north': mapBounds.north,
        'south': mapBounds.south,
        'west': mapBounds.west,
        'east': mapBounds.east,
        'group': true
      }))
          .then((response) async {
        switch (response.statusCode) {
          case 200:
            return json.decode(response.body);
          case 204:
            return [];
          default:
            return null;
        }
      }).then((data) async {
        if (data != null) {
          List<NPOI> npois = [];
          for (var p in data) {
            try {
              npois.add(NPOI(p['id'], p['lat'], p['long'], p['pois']));
            } catch (e, stackTrace) {
              if (Config.development) {
                debugPrint(e.toString());
              } else {
                await FirebaseCrashlytics.instance.recordError(e, stackTrace);
              }
            }
          }
          return npois;
        } else {
          return [];
        }
      });
      return out;
    } catch (e, stackTrace) {
      if (Config.development) {
        debugPrint(e.toString());
      } else {
        await FirebaseCrashlytics.instance.recordError(e, stackTrace);
      }
      return [];
    }
  }

  /// Split [mapBounds] and check the POIs inside each split. For this,
  /// First check the local cache [_teselaFeature]. If it does not have the
  /// POIs for the zone, or they are not valid, asks the server.
  static Future<List<Feature>> checkCurrentMapSplit(
    LatLngBounds mapBounds, {
    Set<SpatialThingType>? filters,
  }) async {
    try {
      LatLng pI = _startPointCHeck(mapBounds.northWest);
      NumberTile c = _buildTeselas(pI, mapBounds.southEast);
      _teselaFeature.removeWhere((TeselaFeature tp) => !tp.isValid());
      List<Feature> out = [];

      double pLng, pLat;
      LatLng puntoComprobacion;
      bool encontrado;
      List<Future<TeselaFeature?>> peticiones = [];
      pendingTiles = 0;
      totalTiles = 0;
      valueNotifier.value = 0.0;
      for (int i = 0; i < c.ch; i++) {
        pLng = pI.longitude + (i * tileSide);
        for (int j = 0; j < c.cv; j++) {
          pLat = pI.latitude - (j * tileSide);
          puntoComprobacion = LatLng(pLat, pLng);
          encontrado = false;
          late TeselaFeature tp;
          for (tp in _teselaFeature) {
            if (tp.isEqualPoint(puntoComprobacion)) {
              encontrado = true;
              break;
            }
          }
          ++totalTiles;
          if (!encontrado || !tp.isValid()) {
            ++pendingTiles;
            peticiones.add(_newZone(puntoComprobacion, mapBounds));
          } else {
            //Agrego para devolverselo al usuario
            ++valueNotifier.value;
            if (filters != null) {
              List<Feature> tpFeaturesFiltrado = [];
              for (Feature f in tp.features) {
                bool entra = false;
                if (f.spatialThingTypes != null) {
                  for (SpatialThingType stt in f.spatialThingTypes!) {
                    entra = filters.contains(stt);
                    if (entra) break;
                  }
                }
                if (entra) {
                  tpFeaturesFiltrado.add(f);
                }
              }
              out.addAll(tpFeaturesFiltrado);
            } else {
              out.addAll(tp.features);
            }
          }
        }
        //Cuando todos los futuros se hayan completado agrego y se lo devuelvo
      }
      List<TeselaFeature?> newTeselaFeatures = await Future.wait(peticiones);
      for (TeselaFeature? tp in newTeselaFeatures) {
        if (tp != null) {
          _teselaFeature.add(tp);
          if (filters != null) {
            List<Feature> tpFeaturesFiltrado = [];
            for (Feature f in tp.features) {
              bool entra = false;
              if (f.spatialThingTypes != null) {
                for (SpatialThingType stt in f.spatialThingTypes!) {
                  entra = filters.contains(stt);
                  if (entra) break;
                }
              }
              if (entra) {
                tpFeaturesFiltrado.add(f);
              }
            }
            out.addAll(tpFeaturesFiltrado);
          } else {
            out.addAll(tp.features);
          }
        }
      }
      return out;
    } catch (e, stackTrace) {
      if (Config.development) {
        debugPrint(e.toString());
      } else {
        await FirebaseCrashlytics.instance.recordError(e, stackTrace);
      }
      return [];
    }
  }

  static LatLng _startPointCHeck(LatLng nW) {
    double esquina, gradosMax;
    var s = <double>[];

    for (var i = 0; i < 2; i++) {
      esquina = (i == 0)
          ? _posRef.latitude -
              (((_posRef.latitude - nW.latitude) / tileSide)).floor() * tileSide
          : _posRef.longitude -
              (((_posRef.longitude - nW.longitude) / tileSide)).ceil() *
                  tileSide;
      gradosMax = (i + 1) * 90;
      if (esquina.abs() > gradosMax) {
        if (esquina > gradosMax) {
          esquina = gradosMax;
        } else {
          if (esquina < (-1 * gradosMax)) {
            esquina = (-1 * gradosMax);
          }
        }
      }
      s.add(esquina);
    }
    return LatLng(s[0], s[1]);
  }

  static NumberTile _buildTeselas(LatLng nw, LatLng se) {
    return NumberTile(((nw.latitude - se.latitude) / tileSide).ceil(),
        ((se.longitude - nw.longitude) / tileSide).ceil());
  }

  static Future<TeselaFeature?> _newZone(
    LatLng? point,
    LatLngBounds mapBounds,
  ) async {
    try {
      return http
          .get(Queries.getFeatures({
        'north': point!.latitude,
        'south': point.latitude - tileSide,
        'west': point.longitude,
        'east': point.longitude + tileSide,
        'group': false
      }))
          .then((response) {
        switch (response.statusCode) {
          case 200:
            return json.decode(response.body);
          default:
            return null;
        }
      }).then((data) async {
        if (pendingTiles > 0) {
          pendingTiles = max(0, pendingTiles - 1);
          valueNotifier.value = (totalTiles - pendingTiles) / totalTiles;
        }
        if (data == null) {
          return null;
        } else {
          List<Feature> features = <Feature>[];
          for (var p in data) {
            try {
              features.add(Feature(p));
            } catch (e, stackTrace) {
              //El poi está mal formado
              if (Config.development) {
                debugPrint(e.toString());
              } else {
                await FirebaseCrashlytics.instance.recordError(e, stackTrace);
              }
            }
          }
          return TeselaFeature(point.latitude, point.longitude, features);
        }
      });
    } catch (e) {
      return null;
    }
  }

  static void addFeature2Tile(Feature feature) {
    // Primero busco en las teselas existentes
    int index = _findFeatureTile(feature);
    if (index > -1) {
      _teselaFeature[index].addFeature(feature);
    } else {
      // Si ninguna de las que tengo está el POI la creo y la agrego a la caché
      LatLng pI = _startPointCHeck(feature.point);
      TeselaFeature nTp =
          TeselaFeature.withoutFeatures(pI.latitude, pI.longitude);
      nTp.addFeature(feature);
      _teselaFeature.add(nTp);
    }
  }

  static void removeFeatureFromTile(Feature feature) {
    int index = _findFeatureTile(feature);
    if (index > -1) {
      _teselaFeature[index].removeFeature(feature);
    }
  }

  static int _findFeatureTile(Feature feature) {
    return _teselaFeature.indexWhere((TeselaFeature t) {
      return t.checkIfContains(feature.point);
    });
  }

  static Feature? getFeatureCache(String shortId) {
    List<Feature> features;
    int index;
    for (TeselaFeature tp in _teselaFeature) {
      features = tp.features;
      index = features.indexWhere((Feature p) => p.shortId == shortId);
      if (index > -1) {
        return features[index];
      }
    }
    return null;
  }

  static bool updateFeatureCache(Feature feature) {
    List<Feature> features;
    int indexFeature;
    for (int indexTeselaFeature = 0, tamaTeselaPoi = _teselaFeature.length;
        indexTeselaFeature < tamaTeselaPoi;
        indexTeselaFeature++) {
      features = _teselaFeature[indexTeselaFeature].features;
      indexFeature = features.indexWhere((Feature f) => f.id == feature.id);
      if (indexFeature >= 0) {
        _teselaFeature[indexTeselaFeature]
            .removeFeature(features.elementAt(indexFeature));
        _teselaFeature[indexTeselaFeature].addFeature(feature);
        return true;
      }
    }
    return false;
  }
}

class NumberTile {
  late int cv, ch;
  NumberTile(this.cv, this.ch);
}
