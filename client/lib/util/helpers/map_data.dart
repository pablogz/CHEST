import 'dart:convert';
import 'dart:math';

import 'package:chest/util/helpers/providers/osm.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

import 'package:chest/util/helpers/pois.dart';
import 'package:chest/util/helpers/queries.dart';

class MapData {
  static const double tileSide = 0.09;
  static final List<TeselaPoi> _teselaPoi = [];
  static const LatLng _posRef = LatLng(41.66, -4.71);
  static int pendingTiles = 0;
  static int totalTiles = 0;
  static ValueNotifier valueNotifier = ValueNotifier<double?>(0);

  /// Remove all cache data
  static void resetLocalCache() => _teselaPoi.removeRange(0, _teselaPoi.length);

  /// Ask to the server for the number of POIs inside [mapBounds]
  static Future<List<NPOI>> checkCurrentMapBounds(
      LatLngBounds mapBounds) async {
    try {
      Future<List<NPOI>> out = http
          .get(Queries().getPOIs({
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
            } catch (e) {
              debugPrint(e.toString());
            }
          }
          return npois;
        } else {
          return [];
        }
      });
      return out;
    } catch (e) {
      debugPrint(e.toString());
      return [];
    }
  }

  /// Split [mapBounds] and check the POIs inside each split. For this,
  /// First check the local cache [_teselaPoi]. If it does not have the
  /// POIs for the zone, or they are not valid, asks the server.
  static Future<List<POI>> checkCurrentMapSplit(LatLngBounds mapBounds,
      {List<String>? filters}) async {
    try {
      LatLng pI = _startPointCHeck(mapBounds.northWest);
      NumberTile c = _buildTeselas(pI, mapBounds.southEast);
      _teselaPoi.removeWhere((TeselaPoi tp) => !tp.isValid());
      List<POI> out = [];

      double pLng, pLat;
      LatLng puntoComprobacion;
      bool encontrado;
      List<Future<TeselaPoi?>> peticiones = [];
      pendingTiles = 0;
      totalTiles = 0;
      valueNotifier.value = 0.0;
      for (int i = 0; i < c.ch; i++) {
        pLng = pI.longitude + (i * tileSide);
        for (int j = 0; j < c.cv; j++) {
          pLat = pI.latitude - (j * tileSide);
          puntoComprobacion = LatLng(pLat, pLng);
          encontrado = false;
          late TeselaPoi tp;
          for (tp in _teselaPoi) {
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
            out.addAll(tp.getPois());
          }
        }
        //Cuando todos los futuros se hayan completado agrego y se lo devuelvo
      }
      List<TeselaPoi?> newTeselaPois = await Future.wait(peticiones);
      for (TeselaPoi? tp in newTeselaPois) {
        if (tp != null) {
          _teselaPoi.add(tp);
          out.addAll(tp.getPois());
        }
      }
      if (filters != null) {
        List<String> filtersUP = [];
        for (String filter in filters) {
          filtersUP.add(filter.toUpperCase());
        }
        out.removeWhere((POI p) {
          List<TagOSM> tags = p.tags;
          bool encontrado = false;
          for (TagOSM tag in tags) {
            encontrado = filtersUP.contains(tag.key.toUpperCase());
            if (encontrado) {
              break;
            }
          }
          return !encontrado;
        });
      }
      return out;
    } catch (e) {
      debugPrint(e.toString());
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

  static Future<TeselaPoi?> _newZone(
      LatLng? point, LatLngBounds mapBounds) async {
    try {
      return http
          .get(Queries().getPOIs({
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
      }).then((data) {
        if (pendingTiles > 0) {
          pendingTiles = max(0, pendingTiles - 1);
          valueNotifier.value = (totalTiles - pendingTiles) / totalTiles;
        }
        if (data == null) {
          return null;
        } else {
          List<POI> pois = <POI>[];
          for (var p in data) {
            try {
              final POI poi = POI(
                p['id'],
                p['labels'],
                p['labels'],
                p['lat'],
                p['lng'],
                p['author'],
              );
              if (p['thumbnailImg'] != null &&
                  p['thumbnailImg'].toString().isNotEmpty) {
                if (p['thumbnailImg']
                    .contains('commons.wikimedia.org/wiki/File:')) {
                  p['thumbnailLic'] = p['thumbnailImg'];
                  p['thumbnailImg'] = p['thumbnailImg']
                      .replace('http://', 'https://')
                      .replace('File:', 'Special:FilePath/');
                }
                if (p['thumbnailLic'] != null &&
                    p['thumbnailImg'].toString().isNotEmpty) {
                  poi.setThumbnail(p['thumbnailImg'], p['thumbnailImg']);
                } else {
                  poi.setThumbnail(p['thumbnailImg'], null);
                }
              }

              if (p['tags'] != null) {
                poi.tags = p['tags'];
              }
              pois.add(poi);
            } catch (e) {
              //El poi está mal formado
              debugPrint(e.toString());
            }
          }
          return TeselaPoi(point.latitude, point.longitude, pois);
        }
      });
    } catch (e) {
      return null;
    }
  }

  static void addPoi2Tile(POI poi) {
    // Primero busco en las teselas existentes
    int index = _findPOITile(poi);
    if (index > -1) {
      _teselaPoi[index].addPoi(poi);
    } else {
      // Si ninguna de las que tengo está el POI la creo y la agrego a la caché
      LatLng pI = _startPointCHeck(poi.point);
      TeselaPoi nTp = TeselaPoi.withoutPois(pI.latitude, pI.longitude);
      nTp.addPoi(poi);
      _teselaPoi.add(nTp);
    }
  }

  static void removePoiFromTile(POI poi) {
    int index = _findPOITile(poi);
    if (index > -1) {
      _teselaPoi[index].removePoi(poi);
    }
  }

  static int _findPOITile(POI poi) {
    return _teselaPoi.indexWhere((TeselaPoi t) {
      return t.checkIfContains(poi.point);
    });
  }
}

class NumberTile {
  late int cv, ch;
  NumberTile(this.cv, this.ch);
}
