import 'package:chest/helpers/tasks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/helpers/user.dart';

class Auxiliar {
  static const double maxWidth = 1000;
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

  // TODO
  static const double maxZoom = 18;
  // static const double maxZoom = 20; // mapbox
  static TileLayer tileLayerWidget({Brightness brightness = Brightness.light}) {
    return TileLayer(
      minZoom: 1,
      maxZoom: 18,
      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c'],
      backgroundColor: Colors.grey,
    );
    // TODO
    // return brightness == Brightness.light
    //     ? TileLayer(
    //         maxZoom: 20,
    //         minZoom: 1,
    //         backgroundColor: Colors.white54,
    //         urlTemplate:
    //             "https://api.mapbox.com/styles/v1/pablogz/ckvpj1ed92f7u14phfhfdvkor/tiles/256/{z}/{x}/{y}@2x?access_token={access_token}",
    //         additionalOptions: const {
    //           "access_token":
    //               "pk.eyJ1IjoicGFibG9neiIsImEiOiJja3ExMWcxajQwMTN4MnVsYTJtMmdpOXc2In0.S9rtoLY8TYoI-4D8oy8F8A"
    //         },
    //       )
    //     : TileLayer(
    //         maxZoom: 20,
    //         minZoom: 1,
    //         backgroundColor: Colors.black54,
    //         urlTemplate:
    //             "https://api.mapbox.com/styles/v1/pablogz/cldjhznv8000o01o9icwqto27/tiles/256/{z}/{x}/{y}@2x?access_token={access_token}",
    //         additionalOptions: const {
    //             "access_token":
    //                 "pk.eyJ1IjoicGFibG9neiIsImEiOiJja3ExMWcxajQwMTN4MnVsYTJtMmdpOXc2In0.S9rtoLY8TYoI-4D8oy8F8A"
    //           });
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
            ),
          ),
        );
      },
    );
  }

  static double distance(LatLng p0, LatLng p1) {
    const Distance d = Distance();
    return d.as(LengthUnit.Meter, p0, p1);
  }

  static checkPermissionsLocation(
      BuildContext context, TargetPlatform defaultTargetPlatform) async {
    ThemeData td = Theme.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      smState.showSnackBar(
        SnackBar(
          backgroundColor: td.colorScheme.error,
          content: Text(
            appLoca!.serviciosLocalizacionDescativados,
            style: td.textTheme.bodyMedium!
                .copyWith(color: td.colorScheme.onError),
          ),
        ),
      );
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        smState.showSnackBar(SnackBar(
          backgroundColor: td.colorScheme.error,
          content: Text(
            appLoca!.aceptarPermisosUbicacion,
            style: td.textTheme.bodyMedium!
                .copyWith(color: td.colorScheme.onError),
          ),
        ));
      }
    }
    if (permission == LocationPermission.deniedForever) {
      smState.showSnackBar(SnackBar(
        backgroundColor: td.colorScheme.error,
        content: Text(
          appLoca!.aceptarPermisosUbicacion,
          style:
              td.textTheme.bodyMedium!.copyWith(color: td.colorScheme.onError),
        ),
      ));
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

  static String getLabelAnswerType(BuildContext context, AnswerType aT) {
    late String out;
    switch (aT) {
      case AnswerType.mcq:
        out = AppLocalizations.of(context)!.mcqTitle;
        break;
      case AnswerType.multiplePhotos:
        out = AppLocalizations.of(context)!.multiplePhotosTitle;
        break;
      case AnswerType.multiplePhotosText:
        out = AppLocalizations.of(context)!.multiplePhotosTextTitle;
        break;
      case AnswerType.noAnswer:
        out = AppLocalizations.of(context)!.noAnswerTitle;
        break;
      case AnswerType.photo:
        out = AppLocalizations.of(context)!.photoTitle;
        break;
      case AnswerType.photoText:
        out = AppLocalizations.of(context)!.photoTextTitle;
        break;
      case AnswerType.text:
        out = AppLocalizations.of(context)!.textTitle;
        break;
      case AnswerType.tf:
        out = AppLocalizations.of(context)!.tfTitle;
        break;
      case AnswerType.video:
        out = AppLocalizations.of(context)!.videoTitle;
        break;
      case AnswerType.videoText:
        out = AppLocalizations.of(context)!.videoTextTitle;
        break;
      default:
        out = '';
    }
    return out;
  }

  static Future<bool?> deleteDialog(
      BuildContext context, String title, String content) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          // contentPadding: EdgeInsets.zero,
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppLocalizations.of(context)!.borrar)),
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context)!.cancelar)),
          ],
        );
      },
    );
  }
}
