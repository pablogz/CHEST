import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';
import 'dart:math';

import 'package:chest/helpers/queries.dart';
import 'package:chest/users.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'config.dart';
import 'helpers/pois.dart';
import 'helpers/user.dart';

class MyMap extends StatefulWidget {
  const MyMap({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _MyMap();
}

class _MyMap extends State<MyMap> {
  int currentPageIndex = 0;
  late bool _userIded;
  late bool _banner;
  late final UserCHEST userCHEST;
  final double lado = 0.0254;
  List<Marker> _myMarkers = <Marker>[];
  List<POI> _currentPOIs = <POI>[];
  List<NPOI> _currentNPOIs = <NPOI>[];
  List<Marker> _myPosition = <Marker>[];
  late int _faltan;
  bool _cargaInicial = true;
  bool _profe = true;
  int faltan = 0;
  late MapController mapController;
  late StreamSubscription<MapEvent> strSubMap;
  List<TeselaPoi> lpoi = <TeselaPoi>[];

  @override
  void initState() {
    _banner = false;
    checkUserLogin();
    mapController = MapController();
    mapController.onReady.then((value) => {});
    strSubMap = mapController.mapEventStream
        .where((event) =>
            event is MapEventMoveEnd || event is MapEventDoubleTapZoomEnd)
        .listen((event) => checkMarkerType());
    super.initState();
  }

  @override
  void dispose() {
    strSubMap.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool barraAlLado =
        MediaQuery.of(context).orientation == Orientation.landscape &&
            MediaQuery.of(context).size.aspectRatio > 0.9;
    return Scaffold(
        bottomNavigationBar: barraAlLado
            ? null
            : NavigationBar(
                onDestinationSelected: (int index) {
                  setState(() {
                    currentPageIndex = index;
                  });
                  if (!_userIded && index != 2) {
                    if (!_userIded && !_banner) {
                      _banner = true;
                      ScaffoldMessenger.of(context)
                          .showMaterialBanner(MaterialBanner(
                        content: Text(
                            AppLocalizations.of(context)!.iniciaParaRealizar),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              _banner = false;
                              ScaffoldMessenger.of(context)
                                  .hideCurrentMaterialBanner();
                              UserCHEST? userAux = await Navigator.push(
                                  context,
                                  MaterialPageRoute<UserCHEST>(
                                      builder: (BuildContext context) =>
                                          const LoginUsers(),
                                      fullscreenDialog: true));
                              if (userAux != null) {
                                userCHEST = userAux;
                              }
                              checkUserLogin();
                            },
                            child: Text(
                              AppLocalizations.of(context)!
                                  .iniciarSesionRegistro,
                            ),
                          ),
                          TextButton(
                              onPressed: () {
                                _banner = false;
                                ScaffoldMessenger.of(context)
                                    .hideCurrentMaterialBanner();
                              },
                              child: Text(
                                AppLocalizations.of(context)!.masTarde,
                                //style: const TextStyle(color: Colors.white)
                              ))
                        ],
                      ));
                    }
                  }
                },
                selectedIndex: currentPageIndex,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.map_outlined),
                    selectedIcon: const Icon(Icons.map),
                    label: AppLocalizations.of(context)!.mapa,
                    tooltip: AppLocalizations.of(context)!.mapa,
                  ),
                  NavigationDestination(
                      icon: const Icon(Icons.my_library_books_outlined),
                      selectedIcon: const Icon(Icons.my_library_books),
                      label: AppLocalizations.of(context)!.respuestas,
                      tooltip: AppLocalizations.of(context)!.respuestas),
                  NavigationDestination(
                      icon: const Icon(Icons.person_pin_outlined),
                      selectedIcon: const Icon(Icons.person_pin),
                      label: AppLocalizations.of(context)!.perfil,
                      tooltip: AppLocalizations.of(context)!.perfil),
                ],
              ),
        floatingActionButton: widgetFab(),
        body: barraAlLado
            ? Row(children: [
                NavigationRail(
                  selectedIndex: currentPageIndex,
                  groupAlignment: -1.0,
                  onDestinationSelected: (int index) {
                    setState(() {
                      currentPageIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.map_outlined),
                      selectedIcon: const Icon(Icons.map),
                      label: Text(AppLocalizations.of(context)!.mapa),
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
                Expanded(
                    child: [
                  widgetMap(),
                  widgetAnswers(),
                  widgetProfile()
                ][currentPageIndex])
              ])
            : [
                widgetMap(),
                widgetAnswers(),
                widgetProfile()
              ][currentPageIndex]);
  }

  void checkUserLogin() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        if (user == null) {
          _userIded = false;
        } else {
          _userIded = true;
        }
      });
    });
  }

  Widget widgetMap() {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
              maxZoom: 18,
              //maxZoom: 20, //Con mapbox
              minZoom: 12,
              center: LatLng(41.6529, -4.72839),
              zoom: 15.0,
              keepAlive: true,
              interactiveFlags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.pinchMove,
              enableScrollWheel: false,
              onPositionChanged: (mapPos, vF) => funIni(mapPos, vF),
              pinchZoomThreshold: 2.0,
              plugins: [
                MarkerClusterPlugin(),
              ]),
          mapController: mapController,
          children: [
            TileLayerWidget(
                options: TileLayerOptions(
              minZoom: 1,
              maxZoom: 18,
              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
              subdomains: ['a', 'b', 'c'],
              backgroundColor: Colors.grey,
            )),
            /*TileLayerWidget(
                  options: TileLayerOptions(
                      maxZoom: 20,
                      minZoom: 1,
                      urlTemplate:
                          "https://api.mapbox.com/styles/v1/pablogz/ckvpj1ed92f7u14phfhfdvkor/tiles/256/{z}/{x}/{y}@2x?access_token={access_token}",
                      additionalOptions: {
                    "access_token":
                        "token"
                  })),*/
            AttributionWidget(
              attributionBuilder: (context) {
                return ColoredBox(
                    color: Colors.white30,
                    child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: Text(
                          AppLocalizations.of(context)!.atribucionMapa,
                          style: const TextStyle(fontSize: 12),
                        )));
              },
            ),
            MarkerLayerWidget(
              options: MarkerLayerOptions(markers: _myPosition),
            ),
            MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
              maxClusterRadius: 75,
              centerMarkerOnClick: false,
              disableClusteringAtZoom: 19,
              size: const Size(52, 52),
              markers: _myMarkers,
              fitBoundsOptions:
                  const FitBoundsOptions(padding: EdgeInsets.all(0)),
              polygonOptions: PolygonOptions(
                  borderColor: Color.fromRGBO(33, 150, 243, 1),
                  color: Color.fromRGBO(187, 222, 251, 1),
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

  Widget widgetAnswers() {
    return SafeArea(
        minimum: const EdgeInsets.all(10),
        child: _userIded
            ? Text(
                //En vez de esto tendría que cargar las respuestas del usuario
                AppLocalizations.of(context)!.sinRespuestas,
                style: Theme.of(context).textTheme.headline6,
              )
            : Text(
                AppLocalizations.of(context)!.sinRespuestas,
                style: Theme.of(context).textTheme.headline6,
              ));
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
                      checkUserLogin();
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
              onPressed: () {},
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
                  UserCHEST? userAux = await Navigator.push(
                      context,
                      MaterialPageRoute<UserCHEST>(
                          builder: (BuildContext context) => const LoginUsers(),
                          fullscreenDialog: true));
                  if (userAux != null) {
                    userCHEST = userAux;
                  }
                  checkUserLogin();
                },
              )
            ],
          )));
    }
  }

  Widget? widgetFab() {
    if (currentPageIndex == 0) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: const [
          FloatingActionButton(onPressed: null, child: Icon(Icons.adjust)),
          SizedBox(
            height: 10,
          ),
        ],
      );
    } else {
      return null;
    }
  }

  void checkMarkerType() {
    if (mapController.zoom >= 14) {
      checkCurrentMap(mapController.bounds);
    } else {
      if (_myMarkers.isNotEmpty) {
        setState(() {
          _myMarkers = [];
          _currentPOIs = [];
        });
      }
    }
  }

  void checkCurrentMap(mapBounds) {
    //return;
    _myMarkers = <Marker>[];
    _currentPOIs = <POI>[];
    if (mapBounds is LatLngBounds) {
      LatLng pI = startPointCheck(mapBounds.northWest);
      HashMap c = buildTeselas(pI, mapBounds.southEast);
      double pLng, pLat;
      LatLng puntoComprobacion;
      bool encontrado;
      faltan = 0;

      for (int i = 0; i < c["ch"]; i++) {
        pLng = pI.longitude + (i * lado);
        for (int j = 0; j < c["cv"]; j++) {
          pLat = pI.latitude - (j * lado);
          puntoComprobacion = LatLng(pLat, pLng);
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
            newZone(puntoComprobacion, mapBounds);
          } else {
            addMarkers2Map(tp.getPois(), mapBounds);
          }
        }
      }
    }
  }

  LatLng startPointCheck(final LatLng nW) {
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
  HashMap<String, int> buildTeselas(LatLng nw, LatLng se) {
    HashMap<String, int> hm = HashMap<String, int>();
    hm["cv"] = ((nw.latitude - se.latitude) / lado).ceil();
    hm["ch"] = ((se.longitude - nw.longitude) / lado).ceil();
    return hm;
  }

  void newZone(LatLng nW, LatLngBounds mapBounds) {
    http
        .get(Queries().getPOIs({
      'dirAdd': Config().addressServer,
      'north': nW.latitude,
      'south': nW.latitude - lado,
      'west': nW.longitude,
      'east': nW.longitude + lado,
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
      if (data != null) {
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
            print(e.toString());
          }
        }
        faltan = (faltan > 0) ? faltan - 1 : 0;
        lpoi.add(TeselaPoi(nW.latitude, nW.longitude, pois));
        addMarkers2Map(pois, mapBounds);
      }
    }).onError((error, stackTrace) {
      //print(error.toString());
      return null;
    });
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
                color: Theme.of(context).primaryColorDark),
            width: 52,
            height: 52,
            child: Center(child: Text(iniciales, textAlign: TextAlign.center)),
          );
        }
        _currentPOIs.add(poi);
        _myMarkers.add(Marker(
            width: 52,
            height: 52,
            point:
                //LatLng(double.parse(p['lat']), double.parse(p['long'])),
                LatLng(poi.lat, poi.long),
            builder: (context) => FloatingActionButton(
                  tooltip: poi.labels[0].value,
                  heroTag: null,
                  elevation: 0,
                  backgroundColor: Theme.of(context).primaryColorDark,
                  onPressed: () {
                    mapController.move(
                        LatLng(poi.lat, poi.long), mapController.zoom);
                  },
                  child: icono,
                )));
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
}
