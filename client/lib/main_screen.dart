import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:chest/helpers/tasks.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'helpers/answers.dart';
import 'helpers/auxiliar.dart';
import 'helpers/itineraries.dart';
import 'helpers/pois.dart';
import 'helpers/queries.dart';
import 'helpers/user.dart';
import 'itineraries.dart';
import 'main.dart';
import 'more_info.dart';
import 'pois.dart';
import 'users.dart';

class MyMap extends StatefulWidget {
  const MyMap({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _MyMap();
}

class _MyMap extends State<MyMap> {
  int currentPageIndex = 0, faltan = 0;
  bool _userIded = false,
      _locationON = false,
      _mapCenterInUser = false,
      _cargaInicial = true;
  late bool _banner, _perfilProfe, _esProfe;
  final double lado = 0.0254;
  List<Marker> _myMarkers = <Marker>[], _myMarkersNPi = <Marker>[];
  List<POI> _currentPOIs = <POI>[];
  List<NPOI> _currentNPOIs = <NPOI>[];
  List<CircleMarker> _userCirclePosition = <CircleMarker>[];
  late MapController mapController;
  late StreamSubscription<MapEvent> strSubMap;
  late StreamSubscription<Position> _strLocationUser;
  List<TeselaPoi> lpoi = <TeselaPoi>[];
  List<Widget> pages = [];
  late LatLng _lastCenter;
  late double _lastZoom;
  late int _lastMapEventScrollWheelZoom;
  Position? _locationUser;
  late IconData iconLocation;
  late List<Itinerary> itineraries;

  @override
  void initState() {
    _lastMapEventScrollWheelZoom = 0;
    _banner = false;
    _lastCenter = LatLng(41.6529, -4.72839);
    _lastZoom = 15.0;
    itineraries = [];
    checkUserLogin();
    super.initState();
  }

  @override
  void dispose() {
    strSubMap.cancel();
    if (_locationON) {
      _strLocationUser.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    pages = [
      widgetMap(),
      widgetItineraries(),
      widgetAnswers(),
      widgetProfile(),
    ];
    bool barraAlLado =
        MediaQuery.of(context).orientation == Orientation.landscape &&
            MediaQuery.of(context).size.aspectRatio > 0.9;
    return Scaffold(
        bottomNavigationBar: barraAlLado
            ? null
            : NavigationBar(
                onDestinationSelected: (int index) => changePage(index),
                selectedIndex: currentPageIndex,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.map_outlined),
                    selectedIcon: const Icon(Icons.map),
                    label: AppLocalizations.of(context)!.mapa,
                    tooltip: AppLocalizations.of(context)!.mapa,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.route_outlined),
                    selectedIcon: const Icon(Icons.route),
                    label: AppLocalizations.of(context)!.itinerarios,
                    tooltip: AppLocalizations.of(context)!.itinerarios,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.my_library_books_outlined),
                    selectedIcon: const Icon(Icons.my_library_books),
                    label: AppLocalizations.of(context)!.respuestas,
                    tooltip: AppLocalizations.of(context)!.respuestas,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_pin_outlined),
                    selectedIcon: const Icon(Icons.person_pin),
                    label: AppLocalizations.of(context)!.perfil,
                    tooltip: AppLocalizations.of(context)!.perfil,
                  ),
                ],
              ),
        floatingActionButton: widgetFab(),
        body: barraAlLado
            ? Row(children: [
                NavigationRail(
                  selectedIndex: currentPageIndex,
                  leading: SvgPicture.asset(
                    'images/logo.svg',
                    height: 46,
                  ),
                  groupAlignment: -1,
                  onDestinationSelected: (int index) => changePage(index),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.map_outlined),
                      selectedIcon: const Icon(Icons.map),
                      label: Text(AppLocalizations.of(context)!.mapa),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.route_outlined),
                      selectedIcon: const Icon(Icons.route),
                      label: Text(AppLocalizations.of(context)!.itinerarios),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.my_library_books_outlined),
                      selectedIcon: const Icon(Icons.my_library_books),
                      label: Text(AppLocalizations.of(context)!.respuestas),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person_pin_outlined),
                      selectedIcon: const Icon(Icons.person_pin),
                      label: Text(AppLocalizations.of(context)!.perfil),
                    ),
                  ],
                ),
                const VerticalDivider(
                  thickness: 1,
                  width: 1,
                ),
                Expanded(child: pages[currentPageIndex])
              ])
            : pages[currentPageIndex]);
  }

  void checkUserLogin() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() => _userIded = user != null);
    });
  }

  Widget widgetMap() {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
              maxZoom: 18,
              // maxZoom: 20, //Con mapbox
              minZoom: 8,
              center: _lastCenter,
              zoom: _lastZoom,
              keepAlive: false,
              interactiveFlags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.pinchMove,
              enableScrollWheel: true,
              onPositionChanged: (mapPos, vF) => funIni(mapPos, vF),
              onLongPress: (tapPosition, point) => onLongPressMap(point),
              onMapCreated: (mC) {
                mapController = mC;
                mapController.onReady.then((value) => {});
                strSubMap = mapController.mapEventStream
                    .where((event) =>
                        event is MapEventMoveEnd ||
                        event is MapEventDoubleTapZoomEnd ||
                        event is MapEventScrollWheelZoom)
                    .listen((event) {
                  if (event is MapEventScrollWheelZoom) {
                    int current = DateTime.now().millisecondsSinceEpoch;
                    if (_lastMapEventScrollWheelZoom + 200 < current) {
                      _lastMapEventScrollWheelZoom = current;
                      checkMarkerType();
                    }
                  } else {
                    checkMarkerType();
                  }
                });
              },
              pinchZoomThreshold: 2.0,
              plugins: [
                MarkerClusterPlugin(),
              ]),
          //mapController: mapController,
          children: [
            Auxiliar.tileLayerWidget(),
            Auxiliar.atributionWidget(),
            CircleLayerWidget(
                options: CircleLayerOptions(circles: _userCirclePosition)),
            MarkerLayerWidget(
                options: MarkerLayerOptions(markers: _myMarkersNPi)),
            MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
              maxClusterRadius: 75,
              centerMarkerOnClick: false,
              disableClusteringAtZoom: 19,
              size: const Size(52, 52),
              markers: _myMarkers,
              circleSpiralSwitchover: 6,
              spiderfySpiralDistanceMultiplier: 2,
              fitBoundsOptions:
                  const FitBoundsOptions(padding: EdgeInsets.all(0)),
              polygonOptions: PolygonOptions(
                  borderColor: Theme.of(context).primaryColor,
                  color: Theme.of(context).primaryColorLight,
                  borderStrokeWidth: 1),
              builder: (context, markers) {
                int tama = markers.length;
                Color intensidad;
                if (tama <= 5) {
                  intensidad = Theme.of(context).primaryColorLight;
                } else {
                  if (tama <= 15) {
                    intensidad = Theme.of(context).primaryColor;
                  } else {
                    intensidad = Theme.of(context).primaryColorDark;
                  }
                }
                return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(52),
                      color: intensidad,
                      border: Border.all(
                          color: Theme.of(context).primaryColorDark, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        markers.length.toString(),
                        style: TextStyle(
                            color: (tama <= 5) ? Colors.black : Colors.white),
                      ),
                    ));
              },
            )),
          ],
        ),
      ],
    );
  }

  Widget widgetItineraries() {
    return SafeArea(
      minimum: const EdgeInsets.only(top: 30, right: 10, left: 10, bottom: 10),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: itineraries.length,
                itemBuilder: (context, index) {
                  Itinerary it = itineraries[index];
                  return Card(
                      child: ListTile(
                    title: Text(
                      it.labelLang(MyApp.currentLang) ??
                          it.labelLang("es") ??
                          "",
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      it.commentLang(MyApp.currentLang) ??
                          it.commentLang("es") ??
                          "",
                      maxLines: 7,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (BuildContext context) =>
                                  InfoItinerary(it),
                              fullscreenDialog: true));
                    },
                  ));
                },
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<List> _getItineraries() {
    return http.get(Queries().getItineraries()).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Widget widgetAnswers() {
    List<Widget> lista = [];
    for (Answer answer in Auxiliar.userCHEST.answers) {
      Widget? titulo, subtitulo;

      String? date;
      if (answer.hasAnswer) {
        date = DateFormat('H:m d/M/y').format(
            DateTime.fromMillisecondsSinceEpoch(answer.answer['timestamp']));
      }
      String? labelPlace = answer.hasLabelPoi ? answer.labelPoi : null;

      if (labelPlace == null && date == null) {
        titulo = null;
      } else {
        if (labelPlace == null) {
          titulo = Text(date!);
        } else {
          if (date == null) {
            titulo = Text(labelPlace);
          } else {
            titulo = Text(Template('{{{place}}} - {{{date}}}')
                .renderString({'place': labelPlace, 'date': date}));
          }
        }
      }
      switch (answer.answerType) {
        case AnswerType.text:
          if (answer.hasAnswer) {
            subtitulo = Text(answer.answer['answer']);
          } else {
            subtitulo = const Text('');
          }
          break;
        case AnswerType.tf:
          if (answer.hasAnswer) {
            subtitulo = Text(Template('{{{vF}}}{{{extra}}}').renderString({
              'vF': answer.answer['answer']
                  ? AppLocalizations.of(context)!.rbVFVNTVLabel
                  : AppLocalizations.of(context)!.rbVFFNTLabel,
              'extra': answer.hasExtraText
                  ? Template('\n{{{extraT}}}')
                      .renderString({'extraT': answer.answer['extraText']})
                  : ''
            }));
          } else {
            subtitulo = const Text('');
          }
          break;
        default:
          subtitulo = const Text('');
      }
      lista.add(Card(
          child: ListTile(
        title: titulo,
        subtitle: subtitulo,
      )));
    }

    return SafeArea(
        minimum: const EdgeInsets.all(10),
        child: SingleChildScrollView(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
              child: _userIded && Auxiliar.userCHEST.answers.isNotEmpty
                  ? ListView(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      children: lista,
                    )
                  : Text(AppLocalizations.of(context)!.sinRespuestas),
            )
          ],
        )));
  }

  Widget widgetProfile() {
    final items = [
      widgetCurrentUser(),
      Container(
          padding: const EdgeInsets.only(left: 10),
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _userIded ? () {} : null,
            label: Text(AppLocalizations.of(context)!.infoGestion),
            icon: const Icon(Icons.person),
          )),
      Container(
          padding: const EdgeInsets.only(left: 10),
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
              onPressed: !_userIded
                  ? null
                  : () {
                      FirebaseAuth.instance.signOut();
                      Auxiliar.userCHEST = UserCHEST.guest();
                    },
              label: Text(AppLocalizations.of(context)!.cerrarSes),
              icon: const Icon(Icons.output))),
      Container(
          padding: const EdgeInsets.only(left: 10),
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _userIded ? () {} : null,
            label: Text(AppLocalizations.of(context)!.ajustesCHEST),
            icon: const Icon(Icons.settings),
          )),
      Container(
          padding: const EdgeInsets.only(left: 10),
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
              onPressed: _userIded ? () {} : null,
              label: Text(AppLocalizations.of(context)!.ayudaOpinando),
              icon: const Icon(Icons.feedback))),
      Container(
          padding: const EdgeInsets.only(left: 10),
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
              onPressed: () {},
              label: Text(AppLocalizations.of(context)!.politica),
              icon: const Icon(Icons.policy))),
      Container(
          padding: const EdgeInsets.only(left: 10),
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
              onPressed: () {},
              label: Text(AppLocalizations.of(context)!.comparteApp),
              icon: const Icon(Icons.share))),
      Container(
          padding: const EdgeInsets.only(left: 10),
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (BuildContext context) => const MoreInfo(),
                        fullscreenDialog: false));
              },
              label: Text(AppLocalizations.of(context)!.masInfo),
              icon: const Icon(Icons.info))),
    ];
    return ListView.builder(
        itemCount: items.length,
        itemBuilder: ((context, i) {
          return items[i];
        }));
  }

  Widget widgetCurrentUser() {
    if (_userIded) {
      return Container(
          height: 200,
          color: Theme.of(context).primaryColorDark,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'images/logo.svg',
                height: 100,
              ),
              SizedBox(
                  child: Text(
                'Cultural Heritage Educational Semantic Tool',
                style: Theme.of(context)
                    .textTheme
                    .headline5
                    ?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              )),
            ],
          ));
    } else {
      return Container(
          height: 200,
          color: Theme.of(context).primaryColorDark,
          child: Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SvgPicture.asset(
                'images/logo.svg',
                height: 100,
              ),
              ElevatedButton(
                child:
                    Text(AppLocalizations.of(context)!.iniciarSesionRegistro),
                onPressed: () async {
                  _banner = false;
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                  await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (BuildContext context) => const LoginUsers(),
                          fullscreenDialog: false));
                },
              )
            ],
          )));
    }
  }

  void iconFabCenter() {
    setState(() {
      iconLocation = _locationON
          ? _mapCenterInUser
              ? Icons.my_location
              : Icons.location_searching
          : Icons.location_disabled;
      _perfilProfe = Auxiliar.userCHEST.crol == Rol.teacher ||
          Auxiliar.userCHEST.crol == Rol.admin;
      _esProfe = Auxiliar.userCHEST.rol == Rol.teacher ||
          Auxiliar.userCHEST.rol == Rol.admin;
    });
  }

  Widget? widgetFab() {
    switch (currentPageIndex) {
      case 0:
        iconFabCenter();
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Visibility(
                visible: _esProfe,
                child: FloatingActionButton.small(
                  heroTag: null,
                  onPressed: () {
                    Auxiliar.userCHEST.crol =
                        _perfilProfe ? Rol.user : Auxiliar.userCHEST.rol;
                    iconFabCenter();
                  },
                  backgroundColor: _perfilProfe
                      ? Theme.of(context)
                          .floatingActionButtonTheme
                          .foregroundColor
                      : Theme.of(context).disabledColor,
                  child: const Icon(Icons.school),
                )),
            Visibility(
                visible: _esProfe,
                child: const SizedBox(
                  height: 10,
                )),
            FloatingActionButton(
              heroTag: Auxiliar.mainFabHero,
              onPressed: () => getLocationUser(true),
              child: Icon(iconLocation),
            ),
            const SizedBox(
              height: 10,
            ),
          ],
        );
      case 1:
        return _perfilProfe
            ? FloatingActionButton.extended(
                heroTag: Auxiliar.mainFabHero,
                onPressed: () async {
                  List<POI> pois = [];
                  for (TeselaPoi tp in lpoi) {
                    // pois.addAll(tp.getPois());
                    List<POI> tpPois = tp.getPois();
                    for (POI poi in tpPois) {
                      if (pois.indexWhere((POI p) => poi.id == p.id) == -1) {
                        pois.add(poi);
                      }
                    }
                  }
                  // pois.sort((POI a, POI b) {
                  //   String ta = a.labelLang(MyApp.currentLang) ??
                  //       a.labelLang("es") ??
                  //       '';
                  //   String tb = b.labelLang(MyApp.currentLang) ??
                  //       b.labelLang("es") ??
                  //       '';
                  //   return ta.compareTo(tb);
                  // });
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (BuildContext context) => NewItinerary(
                              pois,
                              _lastCenter,
                              _lastZoom,
                            ),
                        fullscreenDialog: true),
                  );
                },
                label: Text(AppLocalizations.of(context)!.agregarIt))
            : null;
      default:
        return null;
    }
  }

  void checkMarkerType() {
    if (_locationON) {
      setState(() {
        _mapCenterInUser =
            mapController.center.latitude == _locationUser!.latitude &&
                mapController.center.longitude == _locationUser!.longitude;
      });
    }
    if (mapController.zoom >= 13) {
      if (_currentPOIs.isEmpty) {
        _currentNPOIs = [];
      }
      checkCurrentMap(mapController.bounds, false);
    } else {
      if (_currentNPOIs.isEmpty) {
        _currentPOIs = [];
      }
      checkCurrentMap(mapController.bounds, true);
    }
  }

  void checkCurrentMap(mapBounds, group) {
    //return;
    _myMarkers = <Marker>[];
    _myMarkersNPi = <Marker>[];
    _currentPOIs = <POI>[];
    if (mapBounds is LatLngBounds) {
      if (group) {
        faltan = 0;
        newZone(null, mapBounds, group);
      } else {
        LatLng pI = startPointCheck(mapBounds.northWest, group);
        HashMap c = buildTeselas(pI, mapBounds.southEast, group);
        double pLng, pLat;
        LatLng puntoComprobacion;
        bool encontrado;
        faltan = 0;

        for (int i = 0; i < c["ch"]; i++) {
          pLng = pI.longitude + (i * lado);
          for (int j = 0; j < c["cv"]; j++) {
            pLat = pI.latitude - (j * lado);
            puntoComprobacion = LatLng(pLat, pLng);
            if (group) {
              newZone(puntoComprobacion, mapBounds, group);
            } else {
              encontrado = false;
              late TeselaPoi tp;
              for (tp in lpoi) {
                if (tp.isEqual(puntoComprobacion)) {
                  encontrado = true;
                  break;
                }
              }
              if (!encontrado || !tp.isValid()) {
                ++faltan;
                newZone(puntoComprobacion, mapBounds, group);
              } else {
                addMarkers2Map(tp.getPois(), mapBounds);
              }
            }
          }
        }
      }
    }
  }

  LatLng startPointCheck(final LatLng nW, bool group) {
    final LatLng posRef = LatLng(41.6529, -4.72839);
    double esquina, gradosMax;

    var s = <double>[];
    for (var i = 0; i < 2; i++) {
      esquina = (i == 0)
          ? posRef.latitude -
              (((posRef.latitude - nW.latitude) / lado)).floor() * lado
          : posRef.longitude -
              (((posRef.longitude - nW.longitude) / lado)).ceil() * lado;
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

  /// Calcula el número de teselas que se van a mostrar en la pantalla actual
  /// nw Noroeste
  /// se Sureste
  HashMap<String, int> buildTeselas(LatLng nw, LatLng se, group) {
    HashMap<String, int> hm = HashMap<String, int>();
    hm["cv"] = ((nw.latitude - se.latitude) / lado).ceil();
    hm["ch"] = ((se.longitude - nw.longitude) / lado).ceil();
    return hm;
  }

  void newZone(LatLng? nW, LatLngBounds mapBounds, group) {
    http
        .get(Queries().getPOIs({
      'north': group ? mapBounds.north : nW!.latitude,
      'south': group ? mapBounds.south : nW!.latitude - lado,
      'west': group ? mapBounds.west : nW!.longitude,
      'east': group ? mapBounds.east : nW!.longitude + lado,
      'group': group
    }))
        .then((response) {
      switch (response.statusCode) {
        case 200:
          return json.decode(response.body);
        default:
          return null;
      }
    }).then((data) {
      if (data != null) {
        if (group) {
          List<NPOI> npois = <NPOI>[];
          for (var p in data) {
            try {
              npois.add(NPOI(p['id'], p['lat'], p['long'], p['pois']));
            } catch (e) {
              //print(e.toString());
            }
          }
          faltan = (faltan > 0) ? faltan - 1 : 0;
          //lpoi.add(TeselaPoi(nW.latitude, nW.longitude, pois));
          addMarkers2MapNPOIS(npois, mapBounds);
        } else {
          List<POI> pois = <POI>[];
          for (var p in data) {
            try {
              final POI poi = POI(p['poi'], p['label'], p['comment'], p['lat'],
                  p['lng'], p['author']);
              if (p['thumbnailImg'] != null &&
                  p['thumbnailImg'].toString().isNotEmpty) {
                if (p['thumbnailLic'] != null &&
                    p['thumbnailImg'].toString().isNotEmpty) {
                  poi.setThumbnail(p['thumbnailImg'], p['thumbnailImg']);
                } else {
                  poi.setThumbnail(p['thumbnailImg'], null);
                }
              }
              pois.add(poi);
            } catch (e) {
              //El poi está mal formado
              //print(e.toString());
            }
          }
          faltan = (faltan > 0) ? faltan - 1 : 0;
          lpoi.add(TeselaPoi(nW!.latitude, nW.longitude, pois));
          addMarkers2Map(pois, mapBounds);
        }
      }
    }).onError((error, stackTrace) {
      //print(error.toString());
      return null;
    });
  }

  addMarkers2MapNPOIS(List<NPOI> npois, LatLngBounds mapBounds) {
    List<NPOI> visibles = <NPOI>[];
    for (NPOI npoi in npois) {
      if (mapBounds.contains(LatLng(npoi.lat, npoi.long))) {
        visibles.add(npoi);
      }
    }
    if (visibles.isNotEmpty) {
      for (NPOI npoi in visibles) {
        Container icono = Container(
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: (Theme.of(context).primaryColorDark), width: 2),
              color: Theme.of(context).primaryColor),
          width: 52,
          height: 52,
          child: Center(child: Text(npoi.npois.toString())),
        );
        _currentNPOIs.add(npoi);
        _myMarkersNPi.add(
          Marker(
            width: 52,
            height: 52,
            point: LatLng(npoi.lat, npoi.long),
            builder: (context) => InkWell(
                onTap: () {
                  mapController.move(
                      LatLng(npoi.lat, npoi.long), mapController.zoom + 1);
                  checkMarkerType();
                },
                child: icono),
          ),
        );
      }
    }
    if (faltan == 0) {
      setState(() {});
    }
  }

  addMarkers2Map(List<POI> pois, LatLngBounds mapBounds) {
    List<POI> visiblePois = <POI>[];
    for (POI poi in pois) {
      if (mapBounds.contains(LatLng(poi.lat, poi.long))) {
        visiblePois.add(poi);
      }
    }
    if (visiblePois.isNotEmpty) {
      for (POI poi in visiblePois) {
        final String intermedio =
            poi.labels[0].value.replaceAllMapped(RegExp(r'[^A-Z]'), (m) => "");
        final String iniciales =
            intermedio.substring(0, min(3, intermedio.length));
        late Container icono;
        if (poi.hasThumbnail == true &&
            poi.thumbnail.image
                .contains('commons.wikimedia.org/wiki/Special:FilePath/')) {
          String imagen = poi.thumbnail.image;
          if (!imagen.contains('width=')) {
            imagen = Template('{{{url}}}?width=50&height=50')
                .renderString({'url': imagen});
          }
          icono = Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: (Theme.of(context).primaryColorDark), width: 2),
                image: DecorationImage(
                    image: Image.network(
                      imagen,
                      errorBuilder: (context, error, stack) => Center(
                          child: Text(iniciales, textAlign: TextAlign.center)),
                    ).image,
                    fit: BoxFit.cover)),
          );
        } else {
          icono = Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: (Theme.of(context).primaryColorDark), width: 2),
                color: Theme.of(context).primaryColor),
            width: 52,
            height: 52,
            child: Center(
                child: Text(
              iniciales,
              textAlign: TextAlign.center,
            )),
          );
        }
        _currentPOIs.add(poi);
        _myMarkers.add(
          Marker(
            width: 52,
            height: 52,
            point: LatLng(poi.lat, poi.long),
            builder: (context) => Tooltip(
              message: poi.labelLang(MyApp.currentLang) ?? poi.labelLang("es"),
              child: InkWell(
                onTap: () async {
                  mapController.move(
                      LatLng(poi.lat, poi.long), mapController.zoom);
                  bool reactivar = _locationON;
                  if (_locationON) {
                    _locationON = false;
                    _strLocationUser.cancel();
                  }
                  _lastCenter = mapController.center;
                  _lastZoom = mapController.zoom;
                  bool? recargarTodo = await Navigator.push(
                      context,
                      MaterialPageRoute<bool>(
                          builder: (BuildContext context) => InfoPOI(poi,
                              locationUser: _locationUser, iconMarker: icono),
                          fullscreenDialog: false));
                  if (recargarTodo != null && recargarTodo) {
                    lpoi = [];
                    checkMarkerType();
                  }
                  if (reactivar) {
                    getLocationUser(false);
                    _locationON = true;
                    _mapCenterInUser = false;
                  }
                  iconFabCenter();
                },
                child: icono,
              ),
            ),
          ),
        );
      }
    }
    if (faltan == 0) {
      setState(() {});
    }
  }

  funIni(MapPosition mapPos, bool vF) {
    if (!vF && _cargaInicial) {
      _cargaInicial = false;
      checkMarkerType();
    }
  }

  changePage(index) async {
    setState(() {
      currentPageIndex = index;
    });
    if (index == 0) {
      iconFabCenter();
      checkMarkerType();
    }
    if (index != 0) {
      _lastCenter = mapController.center;
      _lastZoom = mapController.zoom;
      if (_locationON) {
        _locationON = false;
        _userCirclePosition = [];
        _strLocationUser.cancel();
      }
    }
    if (index == 1) {
      //Obtengo los itinearios
      await _getItineraries().then((data) {
        setState(() {
          itineraries = [];
          for (var element in data) {
            try {
              Itinerary itinerary = Itinerary.withoutPoints(
                  element["it"],
                  element["type"],
                  element["label"],
                  element["comment"],
                  element["author"]);
              itineraries.add(itinerary);
            } catch (error) {
              //print(error);
            }
          }
        });
      }).onError((error, stackTrace) {
        itineraries = [];
        //print(error.toString());
      });
    }
    if (!_userIded && index != 3) {
      if (!_userIded && !_banner) {
        _banner = true;
        ScaffoldMessenger.of(context).showMaterialBanner(MaterialBanner(
          content: Text(AppLocalizations.of(context)!.iniciaParaRealizar),
          actions: [
            TextButton(
              onPressed: () async {
                _banner = false;
                ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                _lastCenter = mapController.center;
                _lastZoom = mapController.zoom;
                await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (BuildContext context) => const LoginUsers(),
                        fullscreenDialog: true));
              },
              child: Text(
                AppLocalizations.of(context)!.iniciarSesionRegistro,
              ),
            ),
            TextButton(
                onPressed: () {
                  _banner = false;
                  ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
                },
                child: Text(
                  AppLocalizations.of(context)!.masTarde,
                  //style: const TextStyle(color: Colors.white)
                ))
          ],
        ));
      }
    }
  }

  void getLocationUser(bool centerPosition) async {
    if (_locationON) {
      if (_mapCenterInUser) {
        //Desactivo el seguimiento
        setState(() {
          _locationON = false;
          _mapCenterInUser = false;
          _userCirclePosition = [];
          _locationUser = null;
        });
        _strLocationUser.cancel();
      } else {
        setState(() {
          _mapCenterInUser = true;
        });
        if (centerPosition) {
          mapController.move(
              LatLng(_locationUser!.latitude, _locationUser!.longitude),
              max(mapController.zoom, 16));
        }
      }
    } else {
      LocationSettings locationSettings =
          await Auxiliar.checkPermissionsLocation(
              context, defaultTargetPlatform);

      _strLocationUser =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position? point) {
        if (point != null) {
          _locationUser = point;
          if (!_locationON) {
            setState(() {
              _locationON = true;
            });
            if (centerPosition) {
              mapController.move(LatLng(point.latitude, point.longitude),
                  max(mapController.zoom, 16));
              checkMarkerType();
              setState(() {
                _mapCenterInUser = true;
              });
            }
          } else {
            if (_mapCenterInUser) {
              setState(() {
                _mapCenterInUser = mapController.center.latitude ==
                        _locationUser!.latitude &&
                    mapController.center.longitude == _locationUser!.longitude;
              });
            }
          }
          setState(() {
            _userCirclePosition = [];
            _userCirclePosition.add(CircleMarker(
                point: LatLng(point.latitude, point.longitude),
                radius: max(point.accuracy, 50),
                color: Theme.of(context).primaryColor.withOpacity(0.5),
                useRadiusInMeter: true,
                borderColor: Colors.white,
                borderStrokeWidth: 2));
          });
        }
      });
    }
    checkMarkerType();
  }

  void onLongPressMap(LatLng point) async {
    switch (Auxiliar.userCHEST.rol) {
      case Rol.teacher:
      case Rol.admin:
        if (Auxiliar.userCHEST.crol == Rol.user) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppLocalizations.of(context)!.vuelveATuPerfil),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                  label: AppLocalizations.of(context)!.activar,
                  onPressed: () {
                    Auxiliar.userCHEST.crol = Auxiliar.userCHEST.rol;
                    iconFabCenter();
                  })));
        } else {
          if (mapController.zoom < 16) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                AppLocalizations.of(context)!.aumentaZum,
              ),
              action: SnackBarAction(
                  label: AppLocalizations.of(context)!.aumentaZumShort,
                  onPressed: () => mapController.move(point, 16)),
            ));
          } else {
            POI? poiNewPoi = await Navigator.push(
              context,
              MaterialPageRoute<POI>(
                builder: (BuildContext context) =>
                    NewPoi(point, mapController.bounds!, _currentPOIs),
                fullscreenDialog: true,
              ),
            );
            if (poiNewPoi != null) {
              POI? resetPois = await Navigator.push(
                  context,
                  MaterialPageRoute<POI>(
                      builder: (BuildContext context) => FormPOI(poiNewPoi),
                      fullscreenDialog: false));
              if (resetPois is POI) {
                lpoi = [];
                checkMarkerType();
              }
            }
          }
        }
        break;
      default:
        break;
    }
  }
}
