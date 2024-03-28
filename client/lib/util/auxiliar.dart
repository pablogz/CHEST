import 'dart:convert';

import 'package:chest/util/helpers/feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:quill_html_editor/quill_html_editor.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/util/helpers/user.dart';
import 'package:chest/util/config.dart';
import 'package:chest/util/helpers/tasks.dart';
import 'package:chest/util/helpers/queries.dart';
import 'package:chest/util/helpers/suggestion.dart';
import 'package:chest/main.dart';
import 'package:chest/util/helpers/city.dart';
import 'package:chest/util/helpers/pair.dart';
import 'package:chest/util/helpers/widget_facto.dart';

class Auxiliar {
  static const double maxWidth = 1000;
  static const double compactMargin = 16;
  static const double mediumMargin = 24;
  static double getLateralMargin(double w) =>
      w > 599 ? mediumMargin : compactMargin;
  static UserCHEST userCHEST = UserCHEST.guest();
  static String mainFabHero = "mainFabHero";
  static String searchHero = 'searchHero';

  static bool allowNewUser = false;
  static bool allowManageUser = false;

  static List<City> exCities = [
    City([
      PairLang('es', 'Valladolid, España'),
      PairLang('en', 'Valladolid, Spain'),
      PairLang('pt', 'Valladolid, Espanha')
    ], const LatLng(41.651980555, -4.728561111)),
    City([
      PairLang('es', 'Salamanca, España'),
      PairLang('en', 'Salamanca, Spain'),
      PairLang('pt', 'Salamanca, Espanha'),
    ], const LatLng(40.965, -5.664166666)),
    City([
      PairLang('es', 'Madrid, España'),
      PairLang('en', 'Madrid, Spain'),
      PairLang('pt', 'Madrid, Espanha')
    ], const LatLng(40.416944444, -3.703333333)),
    City([
      PairLang('es', 'Lisboa, Portugal'),
      PairLang('en', 'Lisbon, Portugal'),
      PairLang('pt', 'Lisboa, Portugal')
    ], const LatLng(38.708042, -9.139016)),
    City([
      PairLang('es', 'Atenas, Grecia'),
      PairLang('en', 'Athens, Greece'),
      PairLang('pt', 'Atenas, Grécia'),
    ], const LatLng(37.984166666, 23.728055555)),
    City([
      PairLang('es', 'Toulouse, Francia'),
      PairLang('en', 'Toulouse, France'),
      PairLang('pt', 'Toulouse, França')
    ], const LatLng(43.604444444, 1.443888888)),
    City([
      PairLang('es', 'Florencia, Italia'),
      PairLang('en', 'Florence, Italy'),
      PairLang('pt', 'Florença, Itália')
    ], const LatLng(43.771388888, 11.254166666)),
    City([
      PairLang('es', 'Nueva York, EE.UU.'),
      PairLang('en', 'New York City, USA'),
      PairLang('pt', 'Nova Iorque, EUA')
    ], const LatLng(40.7, -74.0)),
    City([
      PairLang('es', 'Tokio, Japón'),
      PairLang('en', 'Tokyo, Japan'),
      PairLang('pt', 'Tóquio, Japão'),
    ], const LatLng(35.689722222, 139.692222222)),
    City([
      PairLang('es', 'Johannesburgo, Sudáfrica'),
      PairLang('en', 'Johannesburg, South Africa'),
      PairLang('pt', 'Joanesburgo, África do Sul')
    ], const LatLng(-26.204361111, 28.041638888)),
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

  static Layers? _layer =
      Config.development ? Layers.openstreetmap : Layers.carto;

  static Layers? get layer => _layer;
  static set layer(Layers? layer) {
    if (!Config.development && layer != _layer) {
      onlyIconInfoMap = false;
      _layer = layer;
    }
  }

  static const double maxZoom = 22;
  //     Config.development || layer == Layers.openstreetmap ? 18 : 22;
  // static double get maxZoom => _maxZoom;
  // static set maxZoom(double maxZoom) {
  //   if (Config.development) {
  //     _maxZoom = 18;
  //   } else {
  //     switch (layer) {
  //       case Layers.carto:
  //       case Layers.mapbox:
  //         _maxZoom = 22;
  //         break;
  //       case Layers.satellite:
  //         _maxZoom = 22;
  //         break;
  //       default:
  //         _maxZoom = 18;
  //     }
  //   }
  // }

  // static updateMaxZoom() {
  //   maxZoom = Config.development || layer == Layers.openstreetmap ? 18 : 20;
  // }

  static const double minZoom = 13;

  static TileLayer tileLayerWidget({Brightness brightness = Brightness.light}) {
    // TODO Check userAgent!!! ERROR FIREFOX
    //   tileProvider = tileProvider == null
    // ? NetworkTileProvider(
    //     // headers: {'User-Agent': 'flutter_map ($userAgentPackageName)'},
    //     )
    // : (tileProvider
    //   ..headers = <String, String>{
    //     ...tileProvider.headers,
    //     if (!tileProvider.headers.containsKey('User-Agent'))
    //       'User-Agent': 'flutter_map ($userAgentPackageName)',
    //   }),
    if (Config.development) {
      // if (false) {
      return TileLayer(
        minZoom: 1,
        maxZoom: 22,
        maxNativeZoom: 18,
        userAgentPackageName: 'es.uva.gsic.chest',
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        tileProvider: CancellableNetworkTileProvider(),
        // urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
        // subdomains: const ['a', 'b', 'c'],
      );
    }
    switch (layer) {
      case Layers.satellite:
        return TileLayer(
          maxZoom: 22,
          minZoom: 1,
          maxNativeZoom: 19,
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'es.uva.gsic.chest',
          tileProvider: CancellableNetworkTileProvider(),
        );
      case Layers.carto:
        return TileLayer(
          maxZoom: 22,
          minZoom: 1,
          maxNativeZoom: 20,
          userAgentPackageName: 'es.uva.gsic.chest',
          retinaMode: true,
          urlTemplate: brightness == Brightness.light
              ? 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png'
              : 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          tileProvider: CancellableNetworkTileProvider(),
        );
      case Layers.mapbox:
        return TileLayer(
          maxNativeZoom: 20,
          maxZoom: 22,
          minZoom: 1,
          retinaMode: true,
          userAgentPackageName: 'es.uva.gsic.chest',
          urlTemplate: brightness == Brightness.light
              ? 'https://api.mapbox.com/styles/v1/pablogz/ckvpj1ed92f7u14phfhfdvkor/tiles/256/{z}/{x}/{y}@2x?access_token={access_token}'
              : 'https://api.mapbox.com/styles/v1/pablogz/cldjhznv8000o01o9icwqto27/tiles/256/{z}/{x}/{y}@2x?access_token={access_token}',
          additionalOptions: const {"access_token": Config.tokenMapbox},
          tileProvider: CancellableNetworkTileProvider(),
        );
      default:
        return TileLayer(
          minZoom: 1,
          maxZoom: 22,
          maxNativeZoom: 18,
          userAgentPackageName: 'es.uva.gsic.chest',
          // urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          // subdomains: const ['a', 'b', 'c'],
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          tileProvider: CancellableNetworkTileProvider(),
        );
    }
  }

  static bool onlyIconInfoMap = false;

  static IconButton _infoBt(BuildContext context) {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<OutlinedButton> buttons = [
      OutlinedButton(
        child: Text(appLoca!.atribucionMapaCHEST),
        onPressed: () {},
      ),
      OutlinedButton(
        child: Text(appLoca.atribucionMapaOSM),
        onPressed: () async {
          if (!await launchUrl(
              Uri.parse('https://www.openstreetmap.org/copyright'))) {
            if (Config.development) debugPrint('OSM copyright url problem!');
          }
        },
      ),
    ];
    switch (layer) {
      case Layers.mapbox:
        buttons.add(OutlinedButton(
          child: Text(appLoca.atribucionMapaMapbox),
          onPressed: () async {
            if (!await launchUrl(
                Uri.parse('https://www.mapbox.com/about/maps/'))) {
              if (Config.development) debugPrint('mapbox url problem!');
            }
          },
        ));
        break;
      case Layers.satellite:
        buttons.add(OutlinedButton(
          child: Text(appLoca.atribucionMapaEsri),
          onPressed: () async {
            if (!await launchUrl(Uri.parse(
                'https://www.arcgis.com/home/item.html?id=10df2279f9684e4a9f6a7f08febac2a9'))) {
              if (Config.development) debugPrint('Esri url problem!');
            }
          },
        ));
        break;
      case Layers.carto:
        buttons.add(OutlinedButton(
          child: Text(appLoca.atribucionMapaCarto),
          onPressed: () async {
            if (!await launchUrl(Uri.parse('https://carto.com/attributions'))) {
              if (Config.development) debugPrint('CARTO url problem!');
            }
          },
        ));
        break;
      default:
        break;
    }

    return IconButton(
      icon: const Icon(Icons.info_outline),
      color: Theme.of(context).colorScheme.onPrimaryContainer,
      tooltip: appLoca.mapInfoTitle,
      onPressed: () {
        Auxiliar.showMBS(
          title: appLoca.mapInfoTitle,
          context,
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: buttons,
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
            String frase;
            switch (layer) {
              case Layers.carto:
                frase = AppLocalizations.of(context)!.atribucionMapaFraseCarto;
                break;
              case Layers.mapbox:
                frase = AppLocalizations.of(context)!.atribucionMapaFraseMapbox;
                break;
              case Layers.satellite:
                frase = AppLocalizations.of(context)!.atribucionMapaFraseEsri;
                break;
              default:
                frase = AppLocalizations.of(context)!.atribucionMapa;
            }
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
                          frase,
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

  /// Checks the location permissions and settings for the given [BuildContext] and [TargetPlatform].
  /// If the location service is disabled, shows a snackbar with the error message.
  /// If the location permission is denied or denied forever, shows a snackbar with the error message.
  /// Returns the [LocationSettings] based on the [TargetPlatform].
  static Future<LocationSettings> checkPermissionsLocation(
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

  static const Map<String, String> _idToShortId = {
    'https://www.openstreetmap.org/node/': 'osmn:',
    'https://www.openstreetmap.org/relation/': 'osmr:',
    'https://www.openstreetmap.org/way/': 'osmw:',
    'http://www.wikidata.org/entity/': 'wd:',
    'http://dbpedia.org/resource/': 'dbpedia:',
    'http://es.dbpedia.org/resource/': 'esdbpedia:',
    'http://moult.gsic.uva.es/data/': 'md:',
    'http://moult.gsic.uva.es/ontology/': 'mo:',
  };

  /// Converts a long ID [id] to a short ID [shortId] by looking up the short ID prefix in a map and appending the end of the long ID.
  /// Returns null if the short ID prefix is not found in the map.
  static String? id2shortId(String id) {
    String? shortId;
    String end = id.split('/').last;
    String start = id.substring(0, id.length - end.length);
    shortId = _idToShortId[start];
    if (shortId != null) {
      shortId = '$shortId$end';
    }
    return shortId;
  }

  static const Map<String, String> _prefix2URI = {
    'osmn': 'https://www.openstreetmap.org/node/',
    'osmr': 'https://www.openstreetmap.org/relation/',
    'osmw': 'https://www.openstreetmap.org/way/',
    'wd': 'http://www.wikidata.org/entity/',
    'dbpedia': 'http://dbpedia.org/resource/',
    'esdbpedia': 'http://es.dbpedia.org/resource/',
    'chd': 'http://chest.gsic.uva.es/data/',
    'cho': 'http://chest.gsic.uva.es/ontology/',
  };

  /// Converts a short ID to a full ID by appending the corresponding base URI.
  ///
  /// The short ID is expected to be in the format "prefix:id", where "prefix" is
  /// a key in the `_prefix2URI` map and "id" is the ID to be appended to the
  /// corresponding base URI. If the prefix is not found in the map, or if the
  /// short ID is not in the expected format, this function returns `null`.
  static String? shortId2Id(String shortId) {
    String? id;
    List<String> partsShortId = shortId.split(':');
    if (partsShortId.length == 2) {
      String? baseURI = _prefix2URI[partsShortId[0]];
      if (baseURI != null) {
        id = '$baseURI${partsShortId[1]}';
      }
    }
    return id;
  }

  /// Returns the label for the given [AnswerType] based on the provided [AppLocalizations].
  ///
  /// The [appLoca] parameter is an instance of [AppLocalizations] which contains localized strings for the different [AnswerType]s.
  ///
  /// The [aT] parameter is an instance of [AnswerType] for which the label is to be retrieved.
  ///
  /// Returns an empty string if the [AnswerType] is not found in the [mapAnswerTypeName].
  static String getLabelAnswerType(AppLocalizations? appLoca, AnswerType aT) {
    Map<AnswerType, String> mapAnswerTypeName = {
      AnswerType.mcq: appLoca!.mcqTitle,
      AnswerType.multiplePhotos: appLoca.multiplePhotosTitle,
      AnswerType.multiplePhotosText: appLoca.multiplePhotosTextTitle,
      AnswerType.noAnswer: appLoca.noAnswerTitle,
      AnswerType.photo: appLoca.photoTitle,
      AnswerType.photoText: appLoca.photoTextTitle,
      AnswerType.text: appLoca.textTitle,
      AnswerType.tf: appLoca.tfTitle,
      AnswerType.video: appLoca.videoTitle,
      AnswerType.videoText: appLoca.videoTextTitle,
    };

    return mapAnswerTypeName[aT] ?? '';
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
        padding: const EdgeInsets.only(right: 10, left: 10, bottom: 20),
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

  static Future<Map?> _getSuggestions(String query) async {
    try {
      return http
          .get(
        Queries.getSuggestions(query, dict: MyApp.currentLang),
        // headers: {
        //   "Authorization":
        //       "Basic ${base64Encode(utf8.encode("${Config.userSolr}:${Config.passSolr}"))}",
        // },
      )
          .then((response) {
        return response.statusCode == 200 ? json.decode(response.body) : null;
      });
    } catch (e) {
      return null;
    }
  }

  static Iterable<Widget> recuperaSugerencias(
    BuildContext context,
    SearchController controller, {
    MapController? mapController,
  }) {
    AppLocalizations? appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    String userText = controller.text.trim();
    if (userText.isNotEmpty) {
      // El suggestionsBuilder no puede ser asíncrono.
      // Por eso tengo que hacer la chapuza de devolver un
      // FutureBuilder dentro de un array.
      return [
        FutureBuilder<Map?>(
            future: _getSuggestions(userText),
            builder: (context, snapshot) {
              if (snapshot.hasData && !snapshot.hasError) {
                var data = snapshot.data!;
                ReSug reSug = ReSug(data);
                ReSugDic reSugDic =
                    reSug.reSugData.getReSugDic(MyApp.currentLang) ??
                        reSug.reSugData.getReSugDic('en')!;
                List<Widget> lst = [];
                for (Suggestion suggestion in reSugDic.suggestions) {
                  try {
                    String labelVal =
                        suggestion.label(MyApp.currentLang)?.value ??
                            suggestion.label('en')!.value;
                    List<String> splitLabel = labelVal.split(', ');
                    String country = splitLabel.last;
                    String city = labelVal.replaceFirst(', $country', '');
                    lst.add(
                      ListTile(
                        leading: Icon(
                          Icons.place_rounded,
                          color: colorScheme.primary,
                        ),
                        title: HtmlWidget(
                          city,
                          factoryBuilder: () => MyWidgetFactory(),
                        ),
                        subtitle: HtmlWidget(
                          country,
                          factoryBuilder: () => MyWidgetFactory(),
                        ),
                        onTap: () async {
                          try {
                            Map? response = await http
                                .get(
                                  Queries.getSuggestion(suggestion.id),
                                  // headers: {
                                  //   "Authorization":
                                  //       "Basic ${base64Encode(utf8.encode("${Config.userSolr}:${Config.passSolr}"))}",
                                  // },
                                )
                                .then((value) => value.statusCode == 200
                                    ? json.decode(value.body)
                                    : null)
                                .onError((error, stackTrace) => null);
                            ReSug reSug = ReSug(response);
                            ReSelData reSelData = reSug.reSelData;
                            // Trabajando con el ID solamente debemos tener un resultado. Esto cambia si se utiliza otro campo (por ejemplo las etiquetas).
                            if (reSelData.numFound == 1) {
                              Suggestion suggestion = reSelData.docs.first;
                              if (!context.mounted) return;
                              GoRouter.of(context).go(
                                  '/map?center=${suggestion.lat},${suggestion.long}&zoom=13');
                              if (mapController != null) {
                                mapController.move(
                                  LatLng(suggestion.lat, suggestion.long),
                                  13,
                                );
                                context.pop();
                              }
                            }
                          } catch (e) {
                            if (Config.development) {
                              debugPrint('Error in suggestion: $e');
                            }
                          }
                        },
                      ),
                    );
                  } catch (e) {
                    if (Config.development) {
                      debugPrint('Error in suggestion: $e');
                    }
                  }
                }

                return lst.isNotEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            ListTile.divideTiles(tiles: lst, context: context)
                                .toList(),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(appLoca.sinSugerencias),
                      );
              } else {
                if (snapshot.hasError) {
                  return const SizedBox();
                }
                return const LinearProgressIndicator();
              }
            })
      ];
    } else {
      List<Widget> lst = [];
      for (City c in exCities) {
        String label = c.label(lang: MyApp.currentLang) ?? c.label()!;
        String city = label.split(', ')[0];
        String country = label.split(', ')[1];
        lst.add(ListTile(
            leading: Icon(
              Icons.star_rounded,
              color: colorScheme.primary,
            ),
            title: Text(city),
            subtitle: Text(country),
            onTap: () {
              if (mapController != null) {
                mapController.move(c.point, 13);
                context.pop();
              }
              GoRouter.of(context).go(
                  '/map?center=${c.point.latitude},${c.point.longitude}&zoom=13');
            }));
      }
      List<Widget> lst2 = [
        Padding(
          padding:
              const EdgeInsets.only(top: 15, bottom: 25, left: 10, right: 10),
          child: Text(appLoca.lugaresPopulares,
              style:
                  textTheme.titleSmall!.copyWith(fontWeight: FontWeight.bold)),
        ),
      ];
      lst2.addAll(
        ListTile.divideTiles(tiles: lst, context: context),
      );
      return [
        Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lst2)
      ];
    }
  }

  static Future<void> share(String textToShare, BuildContext context) async {
    bool isUri = Uri.parse(textToShare).isAbsolute;
    final box = context.findRenderObject() as RenderBox?;
    return isUri
        ? await Share.shareUri(Uri.parse(textToShare))
        : await Share.share(
            textToShare,
            // iPad: https://pub.dev/packages/share_plus
            sharePositionOrigin: (box!.localToGlobal(Offset.zero) & box.size),
          );
  }

  static String quill2Html(String input) {
    String output = input.replaceAll(
        '<span class="ql-ui" contenteditable="false"></span>', '');
    // Nos quedamos solo con los <ol>
    String soloOl = '';
    for (String s in output.split(RegExp('<ol>(.+?)</ol>'))) {
      soloOl = soloOl.isEmpty
          ? output.replaceFirst(s, '')
          : soloOl.replaceFirst(s, '');
    }

    List<String> lstOl = soloOl.split('<ol>');
    for (String ol in lstOl) {
      if (ol.isNotEmpty) {
        ol = ol.replaceAll('</ol>', '');
        List<String> lstLi = ol.split('<li data-list="');
        String newOLs = '';
        bool bullet = true;
        String newLis = '';
        for (String li in lstLi) {
          if (li.isNotEmpty) {
            // Tengo que conocer el tipo de este nuevo li
            bool b = li.contains('bullet">');
            // Si está vacío newOLs fijo bullet al tipo
            if (newLis.isEmpty) {
              bullet = b;
            }
            if (b != bullet) {
              newOLs = _ulol(newOLs, newLis, bullet);
              bullet = b;
              newLis = '';
            }
            newLis =
                '$newLis<li>${li.replaceFirst(bullet ? 'bullet">' : 'ordered">', '')}';
          }
        }
        // Última iteración
        if (newLis.isNotEmpty) {
          newOLs = _ulol(newOLs, newLis, bullet);
        }
        // Sustituyo lo que hemos conseguido por lo que teníamos antes
        if (newOLs.isNotEmpty) {
          output = output.replaceFirst('<ol>$ol</ol>', newOLs);
        }
      }
    }
    return output;
  }

  static String _ulol(String currentLists, String list2add, bool unorder) {
    return '$currentLists${unorder ? '<ul>' : '<ol>'}$list2add${unorder ? '</ul>' : '</ol>'}';
  }

  static String html2Quill(String output) {
    // String output = input;
    String soloOl = '';
    for (String s in output.split(RegExp('<ol>(.+?)</ol>'))) {
      soloOl = soloOl.isEmpty
          ? output.replaceFirst(s, '')
          : soloOl.replaceFirst(s, '');
    }
    List<String> lstOl = soloOl.split('<ol>');
    List<String?> lstOlProcesado = _lstQuill(lstOl, true);
    for (int i = 0, tama = lstOl.length; i < tama; i++) {
      if (lstOlProcesado.elementAt(i) != null) {
        output = output.replaceFirst(
            '<ol>${lstOl.elementAt(i)}', lstOlProcesado.elementAt(i)!);
      }
    }

    String soloUl = '';
    for (String s in output.split(RegExp('<ul>(.+?)</ul>'))) {
      soloUl = soloUl.isEmpty
          ? output.replaceFirst(s, '')
          : soloUl.replaceFirst(s, '');
    }
    List<String> lstUl = soloUl.split('<ul>');
    List<String?> lstUlProcesado = _lstQuill(lstUl, false);
    for (int i = 0, tama = lstUl.length; i < tama; i++) {
      if (lstUlProcesado.elementAt(i) != null) {
        output = output.replaceFirst(
            '<ul>${lstUl.elementAt(i)}', lstUlProcesado.elementAt(i)!);
      }
    }

    return output;
  }

  static List<String?> _lstQuill(List<String> lst, bool order) {
    List<String?> output = [];
    for (String ol in lst) {
      if (ol.isNotEmpty) {
        ol = ol.replaceAll('</${order ? 'o' : 'u'}l>', '');
        List<String> lstLi = ol.split('<li>');
        String nLi = '';
        for (String li in lstLi) {
          if (li.isNotEmpty) {
            nLi =
                '$nLi<li data-list="${order ? 'ordered' : 'bullet'}"><span class="ql-ui" contenteditable="false"></span>$li';
          }
        }
        output.add('<ol>$nLi</ol>');
      } else {
        output.add(null);
      }
    }
    return output;
  }

  static List<ToolBarStyle> getToolbarElements() => [
        ToolBarStyle.bold,
        ToolBarStyle.italic,
        ToolBarStyle.underline,
        ToolBarStyle.separator,
        ToolBarStyle.listBullet,
        ToolBarStyle.listOrdered,
        ToolBarStyle.separator,
        ToolBarStyle.undo,
        ToolBarStyle.redo,
        ToolBarStyle.separator,
      ];

  // TODO Cambiar cuando se cambie de dominio
  static String? getSpatialThingTypeNameLoca(
      AppLocalizations appLoca, SpatialThingType type) {
    Map<SpatialThingType, String> t = {
      SpatialThingType.artwork: appLoca.artwork,
      SpatialThingType.attraction: appLoca.attraction,
      SpatialThingType.castle: appLoca.castle,
      SpatialThingType.cathedral: appLoca.cathedral,
      SpatialThingType.church: appLoca.church,
      SpatialThingType.culturalHeritage: appLoca.culturalHeritage,
      SpatialThingType.fountain: appLoca.fountain,
      SpatialThingType.museum: appLoca.museum,
      SpatialThingType.palace: appLoca.palace,
      SpatialThingType.placeOfWorship: appLoca.placeOfWorship,
      SpatialThingType.square: appLoca.square,
    };
    return t[type];
  }

  static SpatialThingType? getSpatialThing(String s) {
    Map<String, SpatialThingType> t = {
      SpatialThingType.artwork.name: SpatialThingType.artwork,
      SpatialThingType.attraction.name: SpatialThingType.attraction,
      SpatialThingType.castle.name: SpatialThingType.castle,
      SpatialThingType.cathedral.name: SpatialThingType.cathedral,
      SpatialThingType.church.name: SpatialThingType.church,
      SpatialThingType.culturalHeritage.name: SpatialThingType.culturalHeritage,
      SpatialThingType.fountain.name: SpatialThingType.fountain,
      SpatialThingType.museum.name: SpatialThingType.museum,
      SpatialThingType.palace.name: SpatialThingType.palace,
      SpatialThingType.placeOfWorship.name: SpatialThingType.placeOfWorship,
      SpatialThingType.square.name: SpatialThingType.square,
    };
    return t[s];
  }

  static isUriResource(String s) {
    Uri? uri = Uri.tryParse(s);
    return uri != null ? uri.hasAbsolutePath && uri.hasScheme : false;
  }
}

enum Layers { satellite, mapbox, openstreetmap, carto }
