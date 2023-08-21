import 'package:chest/util/helpers/city.dart';
import 'package:chest/util/helpers/pair.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/util/helpers/user.dart';
import 'package:chest/util/config.dart';
import 'package:chest/util/helpers/tasks.dart';

class Auxiliar {
  static const double maxWidth = 1000;
  static UserCHEST userCHEST = UserCHEST.guest();
  static String mainFabHero = "mainFabHero";
  static String searchHero = 'searchHero';

  static List<City> exCities = [
    City([
      PairLang('es', 'Valladolid'),
      PairLang('en', 'Valladolid'),
      PairLang('pt', 'Valladolid')
    ], LatLng(41.662319, -4.705917)),
    City([
      PairLang('es', 'Salamanca'),
      PairLang('en', 'Salamanca'),
      PairLang('pt', 'Salamanca'),
    ], LatLng(40.965, -5.664167)),
    City([
      PairLang('es', 'Madrid'),
      PairLang('en', 'Madrid'),
      PairLang('pt', 'Madrid')
    ], LatLng(40.416944, -3.703333)),
    City([
      PairLang('es', 'Barcelona'),
      PairLang('en', 'Barcelona'),
      PairLang('pt', 'Barcelona')
    ], LatLng(41.382778, 2.176944)),
    City([
      PairLang('es', 'Lisboa'),
      PairLang('en', 'Lisbon'),
      PairLang('pt', 'Lisboa')
    ], LatLng(38.708042, -9.139016)),
    City([
      PairLang('es', 'Aveiro'),
      PairLang('en', 'Aveiro'),
      PairLang('pt', 'Aveiro')
    ], LatLng(40.638889, -8.655278)),
    City([
      PairLang('es', 'Atenas'),
      PairLang('en', 'Athens'),
      PairLang('pt', 'Atenas'),
    ], LatLng(37.984167, 23.728056)),
    City([
      PairLang('es', 'París'),
      PairLang('en', 'Paris'),
      PairLang('pt', 'Paris')
    ], LatLng(48.856667, 2.350833)),
    City([
      PairLang('es', 'Florencia'),
      PairLang('en', 'Florence'),
      PairLang('pt', 'Florença')
    ], LatLng(43.771389, 11.254167)),
    City([
      PairLang('es', 'Nueva York'),
      PairLang('en', 'New York City'),
      PairLang('pt', 'Nova Iorque')
    ], LatLng(40.712778, -74.006111)),
    City([
      PairLang('es', 'Antananarivo'),
      PairLang('en', 'Antananarivo'),
      PairLang('pt', 'Antananarivo')
    ], LatLng(-18.938611, 47.521389)),
    City([
      PairLang('es', 'Seúl'),
      PairLang('en', 'Seoul'),
      PairLang('pt', 'Seul'),
    ], LatLng(37.56, 126.99)),
    City([
      PairLang('es', 'Kiev'),
      PairLang('en', 'Kyiv'),
      PairLang('pt', 'Kiev')
    ], LatLng(50.45, 30.523611))
  ];

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

  static const double maxZoom = Config.debug ? 18 : 20;
  static const double minZoom = 8;
  static TileLayer tileLayerWidget({Brightness brightness = Brightness.light}) {
    if (Config.debug) {
      // if (false) {
      return TileLayer(
        minZoom: 1,
        maxZoom: 18,
        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
        subdomains: const ['a', 'b', 'c'],
        backgroundColor: Colors.grey,
      );
    } else {
      return brightness == Brightness.light
          ? TileLayer(
              maxZoom: 20,
              minZoom: 1,
              backgroundColor: Colors.white54,
              urlTemplate: "https://api.mapbox.com/styles/v1/pablogz/ckvpj1ed92f7u14phfhfdvkor/tiles/256/{z}/{x}/{y}@2x?access_token={access_token}",
              additionalOptions: const {
                  "access_token": Config.tokenMapbox
                })
          : TileLayer(
              maxZoom: 20,
              minZoom: 1,
              backgroundColor: Colors.black54,
              urlTemplate:
                  "https://api.mapbox.com/styles/v1/pablogz/cldjhznv8000o01o9icwqto27/tiles/256/{z}/{x}/{y}@2x?access_token={access_token}",
              additionalOptions: const {"access_token": Config.tokenMapbox});
    }
  }

  static bool onlyIconInfoMap = false;

  static IconButton _infoBt(BuildContext context) {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return IconButton(
      icon: const Icon(Icons.info_outline),
      color: Theme.of(context).colorScheme.onBackground,
      tooltip: appLoca!.mapInfoTitle,
      onPressed: () {
        Auxiliar.showMBS(
          title: appLoca.mapInfoTitle,
          context,
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              OutlinedButton(
                child: Text(appLoca.atribucionMapaCHEST),
                onPressed: () {},
              ),
              OutlinedButton(
                child: Text(appLoca.atribucionMapaOSM),
                onPressed: () async {
                  if (!await launchUrl(
                      Uri.parse("https://www.openstreetmap.org/copyright"))) {
                    debugPrint('OSM copyright url problem!');
                  }
                },
              ),
              OutlinedButton(
                child: Text(appLoca.atribucionMapaMapbox),
                onPressed: () async {
                  if (!await launchUrl(
                      Uri.parse("https://www.mapbox.com/about/maps/"))) {
                    debugPrint('mapbox url problem!');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget atributionWidget() {
    return Container(
      alignment: Alignment.bottomLeft,
      child: Builder(
        builder: (context) {
          if (onlyIconInfoMap) {
            return _infoBt(context);
          } else {
            return FutureBuilder(
                future: Future.delayed(const Duration(seconds: 5)),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    ThemeData td = Theme.of(context);
                    ColorScheme colorScheme = td.colorScheme;
                    return Container(
                      color: colorScheme.background,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Text(
                          AppLocalizations.of(context)!.atribucionMapa,
                          style: td.textTheme.bodySmall!
                              .copyWith(color: colorScheme.onBackground),
                        ),
                      ),
                    );
                  } else {
                    onlyIconInfoMap = true;
                    return _infoBt(context);
                  }
                });
          }
        },
      ),
    );
  }

  static double distance(LatLng p0, LatLng p1) {
    const Distance d = Distance();
    return d.as(LengthUnit.Meter, p0, p1);
  }

  static checkPermissionsLocation(
      BuildContext context, TargetPlatform defaultTargetPlatform) async {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      smState.showSnackBar(
        SnackBar(
          backgroundColor: colorScheme.errorContainer,
          content: Text(
            appLoca!.serviciosLocalizacionDescativados,
            style: td.textTheme.bodyMedium!
                .copyWith(color: colorScheme.onErrorContainer),
          ),
        ),
      );
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        smState.showSnackBar(SnackBar(
          backgroundColor: colorScheme.errorContainer,
          content: Text(
            appLoca!.aceptarPermisosUbicacion,
            style: td.textTheme.bodyMedium!
                .copyWith(color: colorScheme.onErrorContainer),
          ),
        ));
      }
    }
    if (permission == LocationPermission.deniedForever) {
      smState.showSnackBar(SnackBar(
        backgroundColor: colorScheme.errorContainer,
        content: Text(
          appLoca!.aceptarPermisosUbicacion,
          style: td.textTheme.bodyMedium!
              .copyWith(color: colorScheme.onErrorContainer),
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

  static String getLabelAnswerType(AppLocalizations? appLoca, AnswerType aT) {
    late String out;
    switch (aT) {
      case AnswerType.mcq:
        out = appLoca!.mcqTitle;
        break;
      case AnswerType.multiplePhotos:
        out = appLoca!.multiplePhotosTitle;
        break;
      case AnswerType.multiplePhotosText:
        out = appLoca!.multiplePhotosTextTitle;
        break;
      case AnswerType.noAnswer:
        out = appLoca!.noAnswerTitle;
        break;
      case AnswerType.photo:
        out = appLoca!.photoTitle;
        break;
      case AnswerType.photoText:
        out = appLoca!.photoTextTitle;
        break;
      case AnswerType.text:
        out = appLoca!.textTitle;
        break;
      case AnswerType.tf:
        out = appLoca!.tfTitle;
        break;
      case AnswerType.video:
        out = appLoca!.videoTitle;
        break;
      case AnswerType.videoText:
        out = appLoca!.videoTextTitle;
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

  static void showMBS(BuildContext context, Widget child,
      {String? title, String? comment, bool divider = false}) {
    showModalBottomSheet(
      useSafeArea: true,
      context: context,
      constraints: const BoxConstraints(maxWidth: 640),
      showDragHandle: true,
      isScrollControlled: true,
      // shape: const RoundedRectangleBorder(
      //     borderRadius: BorderRadius.vertical(top: Radius.circular(10))),
      builder: (context) => Padding(
        padding: const EdgeInsets.only(right: 10, left: 10, bottom: 10),
        child: _contentMBS(Theme.of(context), title, comment, divider, child),
      ),
    );
  }

  static Widget _contentMBS(
    ThemeData td,
    String? title,
    String? comment,
    bool divider,
    Widget child,
  ) {
    return title == null
        ? child
        : comment == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: td.textTheme.titleMedium,
                  ),
                  divider ? const Divider() : const SizedBox(height: 8),
                  child
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    comment,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  divider ? const Divider() : const SizedBox(height: 8),
                  child
                ],
              );
  }

  /// Returns the upper case of each word in [label]. The number of capital letters return can be controlled with [nCL] (default = 3). If [nCL] is 0 or less, all are returned.
  static String capitalLetters(String label, {int nCL = 3}) {
    List<String> parts = label.split(' ');
    String cL = '';
    late String c;
    late bool upper, lower;
    for (String part in parts) {
      for (int i = 0, tama = part.length; i < tama; i++) {
        c = part[i];
        upper = c.toUpperCase() == c;
        lower = c.toLowerCase() == c;
        if (upper && lower) {
          continue;
        } else {
          if (upper && !lower) {
            cL += c;
          }
          break;
        }
      }
      if (nCL > 0 && cL.length == nCL) {
        break;
      }
    }
    return cL;
  }
}
