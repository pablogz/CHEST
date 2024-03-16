import 'package:chest/util/config.dart';
import 'package:flutter/material.dart';
import 'package:gpx/gpx.dart';
import 'package:latlong2/latlong.dart';

class Track {
  late List<LatLngAlt> _points;

  Track(dynamic input) {
    if (input is String) {
      Gpx gpx = GpxReader().fromString(input);
      _points = [];
      if (gpx.trks.length == 1 && gpx.trks.first.trksegs.length == 1) {
        for (Wpt wpt in gpx.trks.first.trksegs.first.trkpts) {
          try {
            _points.add(LatLngAlt(lat: wpt.lat!, long: wpt.lon!, alt: wpt.ele));
          } catch (e) {
            if (Config.development) debugPrint(e.toString());
          }
        }
      } else {
        throw Exception('Problem with gpx.trks.first.trksegs.first.trkpts');
      }
    } else {
      throw Exception('Problem with the input');
    }
  }

  List<LatLngAlt> get points => _points;

  void addPoint(LatLngAlt point) {
    _points.add(point);
  }

  Map<String, dynamic> toJSON() {
    Map<String, dynamic> out = {};
    List<Map<String, double>> puntos = [];
    for (LatLngAlt point in _points) {
      puntos.add(point.toJSON());
    }
    out['track'] = puntos;
    return out;
  }
}

class LatLngAlt {
  late double _lat, _long;
  late double? _alt;
  LatLngAlt({required double lat, required double long, double? alt}) {
    if (lat >= -90 || lat <= 90) {
      _lat = lat;
    } else {
      throw Exception('Problem with the latitude');
    }
    if (long >= -180 || long <= 180) {
      _long = long;
    } else {
      throw Exception('Problem with longitude');
    }
    if (alt != null) {
      _alt = alt;
    } else {
      _alt = null;
    }
  }

  double get lat => _lat;
  double get long => _long;
  double? get alt => _alt;

  Map<String, double> toJSON() {
    Map<String, double> out = {
      'lat': lat,
      'long': long,
    };
    if (alt != null) {
      out['alt'] = alt!;
    }
    return out;
  }
}
