import 'package:chest/helpers/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class Auxiliar {
  // static UserCHEST userCHEST = UserCHEST.teacher();
  static const double MAX_WIDTH = 1000;
  static UserCHEST userCHEST = UserCHEST.guest();
  static String mainFabHero = "mainFabHero";

  //Acentos en mac: https://github.com/flutter/flutter/issues/75510#issuecomment-861997917
  static void checkAccents(
      String input, TextEditingController textEditingController) {
    if (input.contains('´a') ||
        input.contains('´A') ||
        input.contains('´e') ||
        input.contains('´E') ||
        input.contains('´i') ||
        input.contains('´I') ||
        input.contains('´o') ||
        input.contains('´O') ||
        input.contains('´u') ||
        input.contains('´U')) {
      textEditingController.text = input
          .replaceAll('´a', 'á')
          .replaceAll('´A', 'Á')
          .replaceAll('´e', 'é')
          .replaceAll('´E', 'É')
          .replaceAll('´i', 'í')
          .replaceAll('´I', 'Í')
          .replaceAll('´o', 'ó')
          .replaceAll('´O', 'ó')
          .replaceAll('´u', 'ú')
          .replaceAll('´U', 'Ú');
      textEditingController.selection = TextSelection.fromPosition(
          TextPosition(offset: textEditingController.text.length));
    }
  }

  static TileLayerWidget tileLayerWidget() {
    // return TileLayerWidget(
    //     options: TileLayerOptions(
    //   minZoom: 1,
    //   maxZoom: 18,
    //   urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    //   subdomains: ['a', 'b', 'c'],
    //   backgroundColor: Colors.grey,
    // ));
    // TODO
    return TileLayerWidget(
        options: TileLayerOptions(
            maxZoom: 20,
            minZoom: 1,
            urlTemplate:
                "https://api.mapbox.com/styles/v1/pablogz/ckvpj1ed92f7u14phfhfdvkor/tiles/256/{z}/{x}/{y}@2x?access_token={access_token}",
            additionalOptions: {
          "access_token":
              "pk.eyJ1IjoicGFibG9neiIsImEiOiJja3Z4b3VnaTUwM2VnMzFtdjJ2Mm4zajRvIn0.q0l3ZzhT4BzKafNxdQuSQg"
        }));
  }

  static AttributionWidget atributionWidget() {
    return AttributionWidget(
      attributionBuilder: (context) {
        return Container(
            color: MediaQuery.of(context).platformBrightness == Brightness.light
                ? Colors.white30
                : Colors.black26,
            child: Padding(
                padding: const EdgeInsets.all(1),
                child: Text(
                  AppLocalizations.of(context)!.atribucionMapa,
                  style: const TextStyle(fontSize: 12),
                )));
      },
    );
  }

  static double distance(LatLng p0, LatLng p1) {
    const Distance d = Distance();
    return d.as(LengthUnit.Meter, p0, p1);
  }

  static checkPermissionsLocation(
      BuildContext context, TargetPlatform defaultTargetPlatform) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          content: Text(AppLocalizations.of(context)!
              .serviciosLocalizacionDescativados)));
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red,
            content:
                Text(AppLocalizations.of(context)!.aceptarPermisosUbicacion)));
      }
    }
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          content:
              Text(AppLocalizations.of(context)!.aceptarPermisosUbicacion)));
    }

    LocationSettings locationSettings;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
          forceLocationManager: false,
          intervalDuration: const Duration(seconds: 5),
          //foregroundNotificationConfig:
        );
        break;
      case TargetPlatform.iOS:
        locationSettings = AppleSettings(
            accuracy: LocationAccuracy.high,
            activityType: ActivityType.fitness,
            distanceFilter: 15,
            pauseLocationUpdatesAutomatically: true,
            showBackgroundLocationIndicator: false);
        break;
      default:
        locationSettings = const LocationSettings(
            accuracy: LocationAccuracy.high, distanceFilter: 15);
    }

    return locationSettings;
  }

  static String getIdFromIri(String iri) {
    List<String> parts = iri.split('/');
    return parts[parts.length - 1];
  }
}

class PairLang {
  late String _lang;
  final String _value;
  PairLang(this._lang, this._value);

  PairLang.withoutLang(this._value) {
    _lang = "";
  }

  bool get hasLang => _lang.isNotEmpty;
  String get lang => _lang;
  String get value => _value;

  Map<String, String> toMap() =>
      hasLang ? {'value': value, 'lang': lang} : {'value': value};
}

class Category {
  final String _iri;
  late List<PairLang> _label;
  late List<String> _broader;
  Category(this._iri, label, broader) {
    _label = [];
    if (label is String || label is Map || label is List) {
      if (label is String) {
        _label.add(PairLang.withoutLang(label));
      } else {
        if (label is Map) {
          label.forEach((key, value) => _label.add(PairLang(key, value)));
        } else {
          for (Map<String, String> l in label) {
            l.forEach(
                (String key, String value) => _label.add(PairLang(key, value)));
          }
        }
      }
    } else {
      throw Exception("Problem with label");
    }
    if (broader is List) {
      _broader = [...broader];
    } else {
      _broader = [broader.toString()];
    }
  }

  String get iri => _iri;
  List<PairLang> get label => _label;
  List<String> get broader => _broader;
}

class PairImage {
  late final String _image;
  String _license = "";
  late bool hasLicense;
  PairImage(image, this._license) {
    _image = image.replaceFirst('http://', 'https://');
    hasLicense = (_license.trim().isNotEmpty);
  }

  PairImage.withoutLicense(image) {
    _image = image.replaceFirst('http://', 'https://');
    hasLicense = false;
  }

  String get image => _image;
  String get license => _license;

  Map<String, dynamic> toMap(bool isThumb) => hasLicense
      ? {'image': image, 'license': license, 'thumbnail': isThumb}
      : {'image': image, 'thumbnail': isThumb};
}
