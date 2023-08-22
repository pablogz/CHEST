import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:chest/util/helpers/chest_marker.dart';
import 'package:chest/util/helpers/city.dart';
import 'package:chest/util/helpers/pair.dart';
import 'package:chest/util/config.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/util/helpers/answers.dart';
import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/itineraries.dart';
import 'package:chest/util/helpers/map_data.dart';
import 'package:chest/util/helpers/pois.dart';
import 'package:chest/util/helpers/queries.dart';
import 'package:chest/util/helpers/user.dart';
import 'package:chest/util/helpers/tasks.dart';
import 'package:chest/itineraries.dart';
import 'package:chest/main.dart';
import 'package:chest/pois.dart';
import 'package:chest/users.dart';
// https://stackoverflow.com/a/60089273
import 'package:chest/util/helpers/mobile_functions.dart'
    if (dart.library.html) 'package:chest/util/helpers/web_functions.dart';

class MyMap extends StatefulWidget {
  final String? center, zoom;
  const MyMap({Key? key, this.center, this.zoom}) : super(key: key);

  @override
  State<MyMap> createState() => _MyMap();
}

class _MyMap extends State<MyMap> {
  final SearchController searchController = SearchController();
  int currentPageIndex = 0;
  bool _userIded = false,
      _locationON = false,
      _mapCenterInUser = false,
      _cargaInicial = true;
  late bool _perfilProfe, _esProfe, _extendedBar, _filterOpen;
  final double lado = 0.0254;
  List<Marker> _myMarkers = <Marker>[], _myMarkersNPi = <Marker>[];
  List<POI> _currentPOIs = <POI>[];
  List<NPOI> _currentNPOIs = <NPOI>[];
  List<CircleMarker> _userCirclePosition = <CircleMarker>[];
  final MapController mapController = MapController();
  late StreamSubscription<MapEvent> strSubMap;
  late StreamSubscription<Position> _strLocationUser;
  // List<TeselaPoi> lpoi = <TeselaPoi>[];
  List<Widget> pages = [];
  late LatLng _lastCenter;
  late double _lastZoom;
  late int _lastMapEventScrollWheelZoom, _lastBack;
  Position? _locationUser;
  late IconData iconLocation;
  late List<Itinerary> itineraries;
  late bool barraAlLado;
  late bool ini;

  final List<String> keyTags = [
    "Wikidata",
    "Wikipedia",
    "Religion",
    "Heritage",
    "Image"
  ];
  List<String> filtrosActivos = [];

  @override
  void initState() {
    ini = false;
    _filterOpen = false;
    _lastMapEventScrollWheelZoom = 0;
    barraAlLado = false;
    _lastBack = 0;
    if (widget.center != null && widget.center!.split(',').length == 2) {
      List<String> pos = widget.center!.split(',');
      double? latd = double.tryParse(pos.first);
      double? lond = double.tryParse(pos.last);
      if (latd != null &&
          lond != null &&
          (latd >= -90 || latd <= 90) &&
          (lond >= -180 || lond <= 180)) {
        _lastCenter = LatLng(latd, lond);
      } else {
        _lastCenter = LatLng(41.6529, -4.72839);
      }
    } else {
      _lastCenter = LatLng(41.6529, -4.72839);
    }
    if (widget.zoom != null) {
      double? zumd = double.tryParse(widget.zoom!);
      if (zumd != null &&
          zumd <= Auxiliar.maxZoom &&
          zumd >= Auxiliar.minZoom) {
        _lastZoom = zumd;
      } else {
        _lastZoom = 15.0;
      }
    } else {
      _lastZoom = 15.0;
    }
    itineraries = [];
    _extendedBar = false;
    checkUserLogin();
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      strSubMap = mapController.mapEventStream
          .where((event) =>
              event is MapEventMoveEnd ||
              event is MapEventDoubleTapZoomEnd ||
              event is MapEventScrollWheelZoom ||
              event is MapEventMoveStart ||
              event is MapEventDoubleTapZoomStart)
          .listen((event) async {
        LatLng latLng = mapController.center;
        GoRouter.of(context).go(
            '/map?center=${latLng.latitude},${latLng.longitude}&zoom=${mapController.zoom}');
        if ((event is MapEventScrollWheelZoom ||
                event is MapEventMoveStart ||
                event is MapEventDoubleTapZoomStart) &&
            !Auxiliar.onlyIconInfoMap) {
          setState(() => Auxiliar.onlyIconInfoMap = true);
        }
        if (event is MapEventMoveEnd ||
            event is MapEventDoubleTapZoomEnd ||
            event is MapEventScrollWheelZoom) {
          if (event is MapEventScrollWheelZoom) {
            int current = DateTime.now().millisecondsSinceEpoch;
            if (_lastMapEventScrollWheelZoom + 200 < current) {
              _lastMapEventScrollWheelZoom = current;
              checkMarkerType();
            }
          } else {
            checkMarkerType();
          }
        }
      });

      checkMarkerType();
    });
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
    barraAlLado = MediaQuery.of(context).orientation == Orientation.landscape &&
        MediaQuery.of(context).size.shortestSide > 599;
    pages = [
      widgetMap(barraAlLado),
      widgetItineraries(),
      widgetAnswers(),
      widgetProfile(),
    ];
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return WillPopScope(
      onWillPop: () async {
        if (currentPageIndex != 0) {
          currentPageIndex = 0;
          changePage(0);
          return false;
        } else {
          int now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastBack < 2000) {
            return true;
          } else {
            _lastBack = now;
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(appLoca!.atrasSalir),
              duration: const Duration(milliseconds: 1500),
            ));
            return false;
          }
        }
      },
      child: Scaffold(
          bottomNavigationBar: barraAlLado
              ? null
              : NavigationBar(
                  onDestinationSelected: (int index) => changePage(index),
                  selectedIndex: currentPageIndex,
                  destinations: [
                    NavigationDestination(
                      icon: const Icon(Icons.map_outlined),
                      selectedIcon: const Icon(Icons.map),
                      label: appLoca!.mapa,
                      tooltip: appLoca.mapa,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.route_outlined),
                      selectedIcon: const Icon(Icons.route),
                      label: appLoca.itinerarios,
                      tooltip: appLoca.misItinerarios,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.my_library_books_outlined),
                      selectedIcon: const Icon(Icons.my_library_books),
                      label: appLoca.respuestas,
                      tooltip: appLoca.misRespuestas,
                    ),
                    NavigationDestination(
                      icon: FirebaseAuth.instance.currentUser != null &&
                              FirebaseAuth
                                  .instance.currentUser!.emailVerified &&
                              FirebaseAuth.instance.currentUser!.photoURL !=
                                  null
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                    image: Image.network(
                                      FirebaseAuth
                                          .instance.currentUser!.photoURL!,
                                    ).image,
                                    fit: BoxFit.cover),
                              ),
                            )
                          : const Icon(Icons.person_pin_outlined),
                      selectedIcon: FirebaseAuth.instance.currentUser != null &&
                              FirebaseAuth
                                  .instance.currentUser!.emailVerified &&
                              FirebaseAuth.instance.currentUser!.photoURL !=
                                  null
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                    image: Image.network(
                                      FirebaseAuth
                                          .instance.currentUser!.photoURL!,
                                    ).image,
                                    fit: BoxFit.cover),
                              ),
                            )
                          : const Icon(Icons.person_pin),
                      label: appLoca.perfil,
                      tooltip: appLoca.perfil,
                    ),
                  ],
                ),
          floatingActionButton: widgetFab(),
          body: barraAlLado
              ? Row(children: [
                  NavigationRail(
                    // backgroundColor: Theme.of(context)
                    //     .bottomNavigationBarTheme
                    //     .backgroundColor,
                    selectedIndex: currentPageIndex,
                    leading: InkWell(
                      onTap: () => setState(() {
                        _extendedBar = !_extendedBar;
                      }),
                      child: _extendedBar
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                  SvgPicture.asset(
                                    'images/logo.svg',
                                    height: 40,
                                    semanticsLabel: 'CHEST',
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    appLoca!.chest,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                ])
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  'images/logo.svg',
                                  height: 40,
                                  semanticsLabel: 'CHEST',
                                ),
                                const SizedBox(height: 1),
                                Text(appLoca!.chest),
                              ],
                            ),
                    ),
                    groupAlignment: -1,
                    onDestinationSelected: (int index) => changePage(index),
                    useIndicator: true,
                    labelType: _extendedBar
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    extended: _extendedBar,
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.map_outlined),
                        selectedIcon: const Icon(Icons.map),
                        label: Text(appLoca.mapa),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.route_outlined),
                        selectedIcon: const Icon(Icons.route),
                        label: Text(_extendedBar
                            ? appLoca.misItinerarios
                            : appLoca.misItinerarios),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.my_library_books_outlined),
                        selectedIcon: const Icon(Icons.my_library_books),
                        label: Text(_extendedBar
                            ? appLoca.misRespuestas
                            : appLoca.misRespuestas),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.person_pin_outlined),
                        selectedIcon: const Icon(Icons.person_pin),
                        label: Text(appLoca.perfil),
                      ),
                    ],
                    elevation: 1,
                  ),
                  // const VerticalDivider(
                  //   thickness: 1,
                  //   width: 1,
                  // ),
                  Flexible(child: pages[currentPageIndex])
                  //Expanded(child: pages[currentPageIndex])
                ])
              : pages[currentPageIndex]),
    );
  }

  void checkUserLogin() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() => _userIded = user != null);
    });
  }

  Widget widgetMap(bool progresoAbajo) {
    ThemeData td = Theme.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);

    List<Widget> filterbar = [];

    filterbar.add(FloatingActionButton.small(
      onPressed: () {
        setState(() => _filterOpen = !_filterOpen);
      },
      child: Icon(_filterOpen
          ? Icons.close_fullscreen
          : filtrosActivos.isEmpty
              ? Icons.filter_alt_off
              : Icons.filter_alt),
    ));
    filterbar.addAll(
      List<Widget>.generate(keyTags.length, (int index) {
        String s = keyTags.elementAt(index);
        return Visibility(
          visible: _filterOpen,
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: FilterChip(
              label: Text(s),
              selected: filtrosActivos.contains(s),
              onSelected: (bool v) {
                setState(
                    () => v ? filtrosActivos.add(s) : filtrosActivos.remove(s));
                checkMarkerType();
              },
            ),
          ),
        );
      }).toList(),
    );
    return Stack(
      children: [
        RepaintBoundary(
          child: FlutterMap(
            mapController: mapController,
            options: MapOptions(
              maxZoom: Auxiliar.maxZoom,
              minZoom: Auxiliar.minZoom,
              center: _lastCenter,
              zoom: _lastZoom,
              keepAlive: false,
              interactiveFlags: InteractiveFlag.pinchZoom |
                  InteractiveFlag.doubleTapZoom |
                  InteractiveFlag.drag |
                  InteractiveFlag.pinchMove,
              enableScrollWheel: true,
              onPositionChanged: (mapPos, vF) => funIni(mapPos, vF),
              //onLongPress: (tapPosition, point) => onLongPressMap(point),
              onMapReady: () {
                ini = true;
              },
              pinchZoomThreshold: 2.0,
            ),
            children: [
              Auxiliar.tileLayerWidget(brightness: td.brightness),
              Auxiliar.atributionWidget(),
              CircleLayer(circles: _userCirclePosition),
              MarkerLayer(markers: _myMarkersNPi),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 114,
                  centerMarkerOnClick: false,
                  zoomToBoundsOnClick: false,
                  showPolygon: false,
                  onClusterTap: (p0) {
                    // mapController.move(
                    //     p0.bounds.center, min(p0.zoom + 1, Auxiliar.maxZoom));
                    moveMap(
                        p0.bounds.center, min(p0.zoom + 1, Auxiliar.maxZoom));
                  },
                  disableClusteringAtZoom: Auxiliar.maxZoom.toInt() - 1,
                  size: const Size(76, 76),
                  markers: _myMarkers,
                  circleSpiralSwitchover: 6,
                  spiderfySpiralDistanceMultiplier: 1,
                  fitBoundsOptions:
                      const FitBoundsOptions(padding: EdgeInsets.all(0)),
                  polygonOptions: PolygonOptions(
                      borderColor: td.colorScheme.primary,
                      color: td.colorScheme.primaryContainer,
                      borderStrokeWidth: 1),
                  builder: (context, markers) {
                    int tama = markers.length;
                    double sizeMarker;
                    Color intensidad;
                    int multi = Queries.layerType == LayerType.forest ? 100 : 1;
                    ColorScheme colorScheme = Theme.of(context).colorScheme;
                    if (tama <= (5 * multi)) {
                      // intensidad = Colors.lime[100]!;
                      sizeMarker = 56;
                    } else {
                      if (tama <= (8 * multi)) {
                        sizeMarker = 66;
                        // intensidad = Colors.lime;
                      } else {
                        sizeMarker = 76;
                        // intensidad = Colors.lime[800]!;
                      }
                    }
                    intensidad = colorScheme.tertiaryContainer;

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(76),
                        gradient: RadialGradient(
                          tileMode: TileMode.mirror,
                          colors: [
                            Colors.transparent,
                            // Colors.lime[100]!.withOpacity(0.4),
                            colorScheme.tertiary.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: Center(
                        child: SizedBox(
                          height: sizeMarker,
                          width: sizeMarker,
                          child: Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(52),
                                color: intensidad,
                                border: Border.all(
                                    color: colorScheme.tertiary, width: 2)
                                // Border.all(color: Colors.lime[900]!, width: 2),
                                ),
                            child: Center(
                              child: Text(
                                markers.length.toString(),
                                style: TextStyle(
                                    // color: (tama <= (8 * multi))
                                    //     ? Colors.black
                                    //     : Colors.white),
                                    color: colorScheme.onTertiaryContainer),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Padding(
        //   padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        //   child: TextField(
        //     decoration: InputDecoration(
        //       constraints: const BoxConstraints(maxWidth: 600),
        //       border: const OutlineInputBorder(
        //           // borderSide: BorderSide(color: Colors.grey),
        //           ),
        //       focusedBorder: const OutlineInputBorder(
        //           // borderSide: BorderSide(color: Colors.grey),
        //           ),
        //       hintText: appLoca!.realizaBusqueda,
        //       prefixIcon: barraAlLado
        //           ? null
        //           : SvgPicture.asset(
        //               'images/logo.svg',
        //               height: 60,
        //             ),
        //       prefixIconConstraints:
        //           barraAlLado ? null : const BoxConstraints(maxHeight: 36),
        //       isDense: true,
        //       filled: true,
        //     ),
        //     readOnly: true,
        //     autofocus: false,
        //     onTap: () {
        //       // Llamo a la interfaz de búsqeuda de municipios
        //       //TODO
        //       ScaffoldMessenger.of(context).clearSnackBars();
        //       ScaffoldMessenger.of(context).showSnackBar(
        //         SnackBar(
        //           backgroundColor: Theme.of(context).colorScheme.errorContainer,
        //           content: Text(
        //             appLoca.enDesarrollo,
        //             style: Theme.of(context).textTheme.bodyMedium!.copyWith(
        //                   color: Theme.of(context).colorScheme.onErrorContainer,
        //                 ),
        //           ),
        //         ),
        //       );
        //     },
        //   ),
        // ),
        // Padding(
        //   padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        //   child: SearchBar(
        //     leading: const Icon(Icons.search),
        //     hintText: appLoca!.realizaBusqueda,
        //     constraints: const BoxConstraints(maxWidth: 600),
        //     onTap: () {

        //     },
        //   ),
        // ),
        Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: AppBar(
                centerTitle: false,
                clipBehavior: Clip.none,
                shape: const StadiumBorder(),
                scrolledUnderElevation: 0,
                titleSpacing: 0,
                backgroundColor: Colors.transparent,
                title: SearchAnchor(
                  builder: (context, controller) => FloatingActionButton.small(
                    heroTag: Auxiliar.searchHero,
                    onPressed: () => searchController.openView(),
                    child: const Icon(Icons.search),
                  ),
                  searchController: searchController,
                  suggestionsBuilder: (context, controller) =>
                      Auxiliar.recuperaSugerencias(context, controller,
                          mapController: mapController),
                  // {
                  //   //TODO
                  //   //Cuando haya escrito 3 caracteres petición a SOLR para mostrar los lugares.
                  //   //Con cada nuevo caracter vuelvo a solicitar
                  //   //Al seleccionar uno concreto recupero lat/lon y voy al lugar
                  //   List<ListTile> listaSug = [];
                  //   String introducido = controller.text.toUpperCase().trim();

                  //   for (City p in Auxiliar.exCities) {
                  //     String? label =
                  //         p.label(lang: MyApp.currentLang) ?? p.label();
                  //     if (label != null &&
                  //         label.toUpperCase().contains(introducido)) {
                  //       listaSug.add(ListTile(
                  //         title: Text(label),
                  //         onTap: () {
                  //           setState(() {
                  //             // mapController.move(p.point, 13);
                  //             moveMap(p.point, 13);
                  //             checkMarkerType();
                  //             controller.closeView(label);
                  //             controller.clear();
                  //           });
                  //         },
                  //       ));
                  //     }
                  //   }
                  //   return listaSug;
                  // },
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 14, right: 14),
                children: filterbar,
              ),
            ),
          ],
        ),

        Padding(
          padding: const EdgeInsets.only(left: 14, bottom: 46),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FloatingActionButton.small(
                tooltip: appLoca!.layers,
                heroTag: null,
                child: Queries.layerType == LayerType.ch
                    ? const Icon(Icons.castle)
                    : Queries.layerType == LayerType.schools
                        ? const Icon(Icons.school)
                        : const Icon(Icons.forest),
                // child: const Icon(Icons.layers),
                onPressed: () {
                  Auxiliar.showMBS(
                    context,
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: List<Widget>.generate(
                        LayerType.values.length,
                        (int index) {
                          LayerType s = LayerType.values.elementAt(index);
                          if (s == Queries.layerType) {
                            return FilledButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: s == LayerType.ch
                                  ? const Icon(Icons.castle)
                                  : s == LayerType.schools
                                      ? const Icon(Icons.school)
                                      : const Icon(Icons.forest),
                              label: s == LayerType.ch
                                  ? Text(appLoca.ch)
                                  : s == LayerType.schools
                                      ? Text(appLoca.schools)
                                      : Text(appLoca.forest),
                            );
                          } else {
                            return OutlinedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                MapData.resetLocalCache();
                                Queries.layerType = s;
                                //setState(() => Queries.layerType = s);
                                checkMarkerType();
                              },
                              icon: s == LayerType.ch
                                  ? const Icon(Icons.castle_outlined)
                                  : s == LayerType.schools
                                      ? const Icon(Icons.school_outlined)
                                      : const Icon(Icons.forest_outlined),
                              label: s == LayerType.ch
                                  ? Text(appLoca.ch)
                                  : s == LayerType.schools
                                      ? Text(appLoca.schools)
                                      : Text(appLoca.forest),
                            );
                          }
                        },
                      ).toList(),
                    ),
                  );
                  // Auxiliar.showMBS(
                  //   context,
                  //   SegmentedButton<LayerType>(
                  //     multiSelectionEnabled: false,
                  //     segments: <ButtonSegment<LayerType>>[
                  //       ButtonSegment<LayerType>(
                  //         value: LayerType.ch,
                  //         label: Text(appLoca.ch),
                  //         icon: const Icon(Icons.castle_outlined),
                  //       ),
                  //       ButtonSegment<LayerType>(
                  //         value: LayerType.schools,
                  //         label: Text(appLoca.schools),
                  //         icon: const Icon(Icons.school_outlined),
                  //       ),
                  //       ButtonSegment<LayerType>(
                  //         value: LayerType.forest,
                  //         label: Text(appLoca.forest),
                  //         icon: const Icon(Icons.forest_outlined),
                  //       )
                  //     ],
                  //     selected: <LayerType>{Queries.layerType},
                  //     onSelectionChanged: (Set<LayerType> item) {
                  //       Navigator.pop(context);
                  //       MapData.resetLocalCache();
                  //       setState(() {
                  //         Queries.layerType = item.first;
                  //       });
                  //       checkMarkerType();
                  //     },
                  //   ),
                  // );
                },
              ),
            ],
          ),
        ),
        Visibility(
          visible: MapData.pendingTiles > 0,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment:
                progresoAbajo ? MainAxisAlignment.start : MainAxisAlignment.end,
            children: [
              ValueListenableBuilder(
                  valueListenable: MapData.valueNotifier,
                  builder: (BuildContext context, v, Widget? child) {
                    return v is double
                        ? LinearProgressIndicator(
                            minHeight: 10,
                            value: v == 0 ? 0.01 : v,
                            semanticsLabel:
                                'Progress of the download of feature data')
                        : Container();
                  }),
            ],
          ),
        )
      ],
    );
  }

  Widget widgetItineraries() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          centerTitle: true,
          floating: true,
          title: Text(appLoca!.misItinerarios),
        ),
        SliverPadding(
          padding:
              const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 80),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              Itinerary it = itineraries[index];
              String title = it.labelLang(MyApp.currentLang) ??
                  it.labelLang("es") ??
                  it.labels.first.value;
              String comment = it.commentLang(MyApp.currentLang) ??
                  it.commentLang("es") ??
                  it.comments.first.value;
              return Center(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: Card(
                    child: ListTile(
                      title: Text(
                        title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        comment,
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
                      onLongPress: () async {
                        if (FirebaseAuth.instance.currentUser != null) {
                          if ((Auxiliar.userCHEST.crol == Rol.teacher &&
                                  it.author == Auxiliar.userCHEST.id) ||
                              Auxiliar.userCHEST.crol == Rol.admin) {
                            Auxiliar.showMBS(
                              title: title,
                              comment: comment,
                              context,
                              Wrap(
                                spacing: 5,
                                runSpacing: 5,
                                children: [
                                  TextButton.icon(
                                    onPressed: null,
                                    icon: const Icon(Icons.edit),
                                    label: Text(appLoca.editar),
                                  ),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete),
                                    label: Text(appLoca.borrar),
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      bool? delete =
                                          await Auxiliar.deleteDialog(
                                              context,
                                              appLoca.borrarIt,
                                              appLoca.preguntaBorrarIt);
                                      if (delete != null && delete) {
                                        http.delete(Queries().deleteIt(it.id!),
                                            headers: {
                                              'Content-Type':
                                                  'application/json',
                                              'Authorization':
                                                  Template('Bearer {{{token}}}')
                                                      .renderString({
                                                'token': await FirebaseAuth
                                                    .instance.currentUser!
                                                    .getIdToken(),
                                              })
                                            }).then((response) {
                                          switch (response.statusCode) {
                                            case 200:
                                              setState(() => itineraries
                                                  .removeWhere((element) =>
                                                      element.id! == it.id!));
                                              break;
                                            default:
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              );
            }, childCount: itineraries.length),
          ),
        ),
      ],
    );
  }

  Future<List> _getItineraries() {
    return http.get(Queries().getItineraries()).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Widget widgetAnswers() {
    List<Widget> lista = [];
    ThemeData td = Theme.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    for (Answer answer in Auxiliar.userCHEST.answers) {
      String? date;
      if (answer.hasAnswer) {
        date = DateFormat('H:mm d/M/y').format(
            DateTime.fromMillisecondsSinceEpoch(answer.answer['timestamp']));
      }

      String? labelPlace = answer.hasLabelPoi ? answer.labelPoi : null;

      Widget? titulo = labelPlace == null && date == null
          ? null
          : labelPlace == null
              ? Text(date!, style: td.textTheme.titleMedium)
              : date == null
                  ? Text(labelPlace, style: td.textTheme.titleMedium)
                  : Text(
                      Template('{{{place}}} - {{{date}}}')
                          .renderString({'place': labelPlace, 'date': date}),
                      style: td.textTheme.titleMedium);

      Widget? enunciado = answer.hasCommentTask
          ? Align(
              alignment: Alignment.centerLeft,
              child: Text(answer.commentTask, style: td.textTheme.bodySmall))
          : null;

      Widget respuesta;
      switch (answer.answerType) {
        case AnswerType.text:
          respuesta = answer.hasAnswer
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text(answer.answer['answer']))
              : const SizedBox();
          break;
        case AnswerType.tf:
          respuesta = answer.hasAnswer
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text(Template('{{{vF}}}{{{extra}}}').renderString({
                    'vF': answer.answer['answer']
                        ? appLoca!.rbVFVNTVLabel
                        : appLoca!.rbVFFNTLabel,
                    'extra': answer.hasExtraText
                        ? Template('\n{{{extraT}}}').renderString(
                            {'extraT': answer.answer['extraText']})
                        : ''
                  })),
                )
              : const SizedBox();
          break;
        case AnswerType.mcq:
          respuesta = answer.hasAnswer
              ? Align(
                  alignment: Alignment.centerLeft,
                  child: Text(answer.answer['answer'].toString()),
                )
              : const SizedBox();
          break;
        default:
          respuesta = const SizedBox();
      }
      lista.add(
        Card(
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 10, left: 10, right: 10),
                        child: titulo ?? const SizedBox(),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 5, left: 10, right: 10),
                        child: enunciado ?? const SizedBox(),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: respuesta,
                      ),
                    ],
                  ),
                  onLongPress: () {
                    Auxiliar.showMBS(
                      context,
                      TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          if (kIsWeb) {
                            AuxiliarFunctions.downloadAnswerWeb(
                              answer,
                              titlePage: appLoca!.tareaCompletadaCHEST,
                            );
                          }
                        },
                        icon: const Icon(Icons.download),
                        label: Text(appLoca!.descargar),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          centerTitle: true,
          floating: true,
          title: Text(appLoca!.misRespuestas),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(10),
          sliver: SliverList(
            // delegate: _userIded && lista.isNotEmpty
            delegate: lista.isNotEmpty
                ? SliverChildBuilderDelegate((context, index) {
                    return Center(
                      child: Container(
                        constraints:
                            const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                        child: lista.elementAt(index),
                      ),
                    );
                  }, childCount: lista.length)
                : SliverChildListDelegate([
                    Text(
                      appLoca.sinRespuestas,
                      textAlign: TextAlign.left,
                    )
                  ]),
          ),
        )
      ],
    );
  }

  Widget widgetProfile() {
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: Text(AppLocalizations.of(context)!.chest),
          centerTitle: true,
        ),
        widgetCurrentUser(),
        widgetStandarOptions(),
      ],
    );
  }

  Widget widgetCurrentUser() {
    ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);
    // ThemeData td = Theme.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> widgets = [];
    if (!_userIded) {
      widgets.add(FilledButton(
        child: Text(appLoca!.iniciarSesionRegistro),
        onPressed: () async {
          ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          await Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (BuildContext context) => const LoginUsers(),
                  fullscreenDialog: false));
          //setState(() {});
        },
      ));
    }
    widgets.add(TextButton.icon(
      onPressed: _userIded
          ? () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (BuildContext context) => const InfoUser(),
                      fullscreenDialog: false));
            }
          : null,
      label: Text(appLoca!.infoGestion),
      icon: const Icon(Icons.person),
    ));
    widgets.add(TextButton.icon(
      onPressed: _userIded
          ? () {
              FirebaseAuth.instance.signOut();
              Auxiliar.userCHEST = UserCHEST.guest();
            }
          : null,
      label: Text(appLoca.cerrarSes),
      icon: const Icon(Icons.output),
    ));
    widgets.add(TextButton.icon(
      onPressed: _userIded
          ? () {
              //TODO
              sMState.clearSnackBars();
              sMState.showSnackBar(
                SnackBar(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  content: Text(
                    appLoca.enDesarrollo,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                  ),
                ),
              );
            }
          : null,
      label: Text(appLoca.ajustesCHEST),
      icon: const Icon(Icons.settings),
    ));
    widgets.add(TextButton.icon(
      onPressed: _userIded
          ? () {
              //TODO
              sMState.clearSnackBars();
              sMState.showSnackBar(
                SnackBar(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  content: Text(
                    appLoca.enDesarrollo,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                  ),
                ),
              );
            }
          : null,
      label: Text(appLoca.ayudaOpinando),
      icon: const Icon(Icons.feedback),
    ));

    return SliverPadding(
      padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == 0 && !_userIded) {
            return Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              child: widgets.elementAt(index),
            );
          }
          return Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.centerLeft,
            child: widgets.elementAt(index),
          );
        }, childCount: widgets.length),
      ),
    );
  }

  Widget widgetStandarOptions() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    List<Widget> lst = [
      TextButton.icon(
        onPressed: () {
          //TODO
          sMState.clearSnackBars();
          sMState.showSnackBar(
            SnackBar(
              backgroundColor: colorScheme.errorContainer,
              content: Text(
                appLoca!.enDesarrollo,
                style: td.textTheme.bodyMedium!
                    .copyWith(color: colorScheme.onErrorContainer),
              ),
            ),
          );
        },
        label: Text(appLoca!.politica),
        icon: const Icon(Icons.policy),
      ),
      TextButton.icon(
        onPressed: () {
          //TODO
          sMState.clearSnackBars();
          sMState.showSnackBar(
            SnackBar(
              backgroundColor: colorScheme.errorContainer,
              content: Text(
                appLoca.enDesarrollo,
                style: td.textTheme.bodyMedium!
                    .copyWith(color: colorScheme.onErrorContainer),
              ),
            ),
          );
        },
        label: Text(appLoca.comparteApp),
        icon: const Icon(Icons.share),
      ),
      TextButton.icon(
        onPressed: () {
          // Navigator.pushNamed(context, '/about');
          GoRouter.of(context).go('/about');
        },
        label: Text(appLoca.masInfo),
        icon: const Icon(Icons.info),
      ),
    ];

    return SliverPadding(
      padding: const EdgeInsets.all(10),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
            (context, index) => Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.centerLeft,
                child: lst.elementAt(
                  index,
                )),
            childCount: lst.length),
      ),
    );
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
    ThemeData td = Theme.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ColorScheme colorScheme = td.colorScheme;
    switch (currentPageIndex) {
      case 0:
        iconFabCenter();
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Visibility(
              visible: _esProfe && Auxiliar.userCHEST.crol == Rol.teacher,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FloatingActionButton(
                  heroTag: _esProfe && Auxiliar.userCHEST.crol == Rol.teacher
                      ? Auxiliar.mainFabHero
                      : null,
                  tooltip: appLoca!.tNPoi,
                  onPressed: () async {
                    LatLng point = mapController.center;
                    if (mapController.zoom < 16) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(appLoca.aumentaZum),
                        action: SnackBarAction(
                            label: appLoca.aumentaZumShort,
                            onPressed: () => setState(() =>
                                // mapController.move(mapController.center, 16)
                                moveMap(mapController.center, 16))),
                      ));
                    } else {
                      await Navigator.push(
                        context,
                        MaterialPageRoute<POI>(
                          builder: (BuildContext context) => NewPoi(
                              point, mapController.bounds!, _currentPOIs),
                          fullscreenDialog: true,
                        ),
                      ).then((poiNewPoi) async {
                        if (poiNewPoi != null) {
                          POI? resetPois = await Navigator.push(
                              context,
                              MaterialPageRoute<POI>(
                                  builder: (BuildContext context) =>
                                      FormPOI(poiNewPoi),
                                  fullscreenDialog: false));
                          if (resetPois is POI) {
                            //lpoi = [];
                            MapData.addPoi2Tile(resetPois);
                            checkMarkerType();
                          }
                        }
                      });
                    }
                  },
                  child: Icon(Icons.add,
                      color: ini && mapController.zoom < 16
                          ? Colors.grey
                          : colorScheme.onPrimaryContainer),
                ),
              ),
            ),
            Visibility(
              visible: _esProfe,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FloatingActionButton.small(
                  heroTag: null,
                  onPressed: () {
                    Auxiliar.userCHEST.crol =
                        _perfilProfe ? Rol.user : Auxiliar.userCHEST.rol;
                    checkMarkerType();
                    iconFabCenter();
                  },
                  backgroundColor: _perfilProfe
                      ? colorScheme.primaryContainer
                      : td.disabledColor,
                  child: Icon(Icons.power_settings_new,
                      color: colorScheme.onPrimaryContainer),
                ),
              ),
            ),
            Visibility(
              visible: kIsWeb,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  direction: Axis.vertical,
                  spacing: 3,
                  children: [
                    FloatingActionButton.small(
                      heroTag: null,
                      onPressed: () {
                        // double newZum =
                        //     min(mapController.zoom + 1, Auxiliar.maxZoom);
                        // LatLng latLng = mapController.center;
                        // mapController.move(latLng, newZum);
                        // GoRouter.of(context).go(
                        //     '/map?center=${latLng.latitude},${latLng.longitude}&zoom=$newZum');
                        moveMap(mapController.center,
                            min(mapController.zoom + 1, Auxiliar.maxZoom));
                        checkMarkerType();
                      },
                      tooltip: 'Zoom in',
                      child: const Icon(Icons.zoom_in),
                    ),
                    FloatingActionButton.small(
                      heroTag: null,
                      onPressed: () {
                        // LatLng latLng = mapController.center;
                        // double newZum =
                        //     max(mapController.zoom - 1, Auxiliar.minZoom);
                        // mapController.move(latLng, newZum);
                        // GoRouter.of(context).go(
                        //     '/map?center=${latLng.latitude},${latLng.longitude}&zoom=$newZum');
                        moveMap(mapController.center,
                            max(mapController.zoom - 1, Auxiliar.minZoom));
                        checkMarkerType();
                      },
                      tooltip: 'Zoom out',
                      child: const Icon(Icons.zoom_out),
                    )
                  ],
                ),
              ),
            ),
            FloatingActionButton(
              heroTag: _esProfe && Auxiliar.userCHEST.crol == Rol.teacher
                  ? null
                  : Auxiliar.mainFabHero,
              onPressed: () => getLocationUser(true),
              mini: _esProfe && Auxiliar.userCHEST.crol == Rol.teacher,
              child: Icon(iconLocation),
            ),
          ],
        );
      case 1:
        return _perfilProfe
            ? FloatingActionButton.extended(
                heroTag: Auxiliar.mainFabHero,
                onPressed: () async {
                  Itinerary? newIt = await Navigator.push(
                    context,
                    MaterialPageRoute<Itinerary>(
                        builder: (BuildContext context) =>
                            NewItinerary(_lastCenter, _lastZoom),
                        fullscreenDialog: true),
                  );
                  if (newIt != null) {
                    setState(() => itineraries.add(newIt));
                  }
                },
                label: Text(appLoca!.agregarIt),
                icon: const Icon(Icons.add),
                tooltip: appLoca.agregarIt,
              )
            : null;
      default:
        return null;
    }
  }

  void checkMarkerType() async {
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

  void checkCurrentMap(LatLngBounds? mapBounds, bool group) async {
    _myMarkers = <Marker>[];
    _myMarkersNPi = <Marker>[];
    _currentPOIs = <POI>[];
    if (group) {
      addMarkers2MapNPOIS(
          await MapData.checkCurrentMapBounds(mapBounds!), mapBounds);
    } else {
      addMarkers2Map(
          await MapData.checkCurrentMapSplit(mapBounds!,
              filters: filtrosActivos.isEmpty ? null : filtrosActivos),
          mapBounds);
    }
    //setState(() {});
  }

  void addMarkers2MapNPOIS(List<NPOI> npois, LatLngBounds mapBounds) {
    List<NPOI> visibles = <NPOI>[];
    for (NPOI npoi in npois) {
      if (mapBounds.contains(LatLng(npoi.lat, npoi.long))) {
        visibles.add(npoi);
      }
    }
    if (visibles.isNotEmpty) {
      ColorScheme colorScheme = Theme.of(context).colorScheme;
      for (NPOI npoi in visibles) {
        Container icono = Container(
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: (colorScheme.primary), width: 2),
              color: colorScheme.primaryContainer),
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
                onTap: () async {
                  // mapController.move(
                  //     LatLng(npoi.lat, npoi.long), mapController.zoom + 1);
                  moveMap(LatLng(npoi.lat, npoi.long), mapController.zoom + 1);
                  checkMarkerType();
                },
                child: icono),
          ),
        );
      }
    }
    setState(() {});
  }

  void addMarkers2Map(List<POI> pois, LatLngBounds mapBounds) {
    List<POI> visiblePois = <POI>[];
    for (POI poi in pois) {
      if (mapBounds.contains(LatLng(poi.lat, poi.long))) {
        visiblePois.add(poi);
      }
    }
    if (visiblePois.isNotEmpty) {
      ColorScheme colorScheme = Theme.of(context).colorScheme;
      for (POI poi in visiblePois) {
        // final String intermedio = poi.labels.first.value
        //     .replaceAllMapped(RegExp(r'[^A-Z]'), (m) => "");
        // final String iniciales =
        //     intermedio.substring(0, min(3, intermedio.length));
        final String iniciales = Auxiliar.capitalLetters(
            poi.labelLang(MyApp.currentLang) ?? poi.labels.first.value);
        Widget icono;
        TextStyle bodyL = Theme.of(context).textTheme.bodyLarge!;
        if (poi.hasThumbnail == true &&
            poi.thumbnail.image
                .contains('commons.wikimedia.org/wiki/Special:FilePath/')) {
          String imagen = poi.thumbnail.image;
          if (!imagen.contains('width=') && !imagen.contains('height=')) {
            imagen = Template('{{{url}}}?width=50&height=50')
                .renderString({'url': imagen});
          }
          icono = Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                  image: Image.network(
                    imagen,
                    errorBuilder: (context, error, stack) => Center(
                      child: Text(
                        iniciales,
                        textAlign: TextAlign.center,
                        style: bodyL.copyWith(color: Colors.white),
                      ),
                    ),
                  ).image,
                  fit: BoxFit.cover),
            ),
          );
        } else {
          icono = Center(
            child: iniciales.isNotEmpty
                ? Text(
                    iniciales,
                    textAlign: TextAlign.center,
                    style:
                        bodyL.copyWith(color: colorScheme.onPrimaryContainer),
                  )
                : Icon(
                    Queries.layerType == LayerType.ch
                        ? Icons.castle_outlined
                        : Queries.layerType == LayerType.schools
                            ? Icons.school_outlined
                            : Icons.forest_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
          );
        }

        if (Auxiliar.userCHEST.crol == Rol.teacher ||
            iniciales.isNotEmpty ||
            Queries.layerType == LayerType.forest) {
          _currentPOIs.add(poi);
          _myMarkers.add(CHESTMarker(
              poi: poi,
              icon: icono,
              visibleTooltip: true,
              onTap: () async {
                moveMap(LatLng(poi.lat, poi.long), mapController.zoom);
                bool reactivar = _locationON;
                if (_locationON) {
                  _locationON = false;
                  _strLocationUser.cancel();
                }
                _lastCenter = mapController.center;
                _lastZoom = mapController.zoom;
                if (!Config.debug) {
                  await FirebaseAnalytics.instance.logEvent(
                    name: "seenPoi",
                    parameters: {"iri": poi.id.split('/').last},
                  ).then((value) async {
                    bool? recargarTodo = await Navigator.push(
                      context,
                      MaterialPageRoute<bool>(
                          builder: (BuildContext context) => InfoPOI(poi,
                              locationUser: _locationUser, iconMarker: icono),
                          fullscreenDialog: false),
                    );
                    checkMarkerType();
                    if (reactivar) {
                      getLocationUser(false);
                      _locationON = true;
                      _mapCenterInUser = false;
                    }
                    iconFabCenter();
                    if (recargarTodo != null && recargarTodo) {
                      checkMarkerType();
                    }
                  }).onError((error, stackTrace) async {
                    debugPrint(error.toString());
                    bool? recargarTodo = await Navigator.push(
                      context,
                      MaterialPageRoute<bool>(
                          builder: (BuildContext context) => InfoPOI(poi,
                              locationUser: _locationUser, iconMarker: icono),
                          fullscreenDialog: false),
                    );
                    if (reactivar) {
                      getLocationUser(false);
                      _locationON = true;
                      _mapCenterInUser = false;
                    }
                    iconFabCenter();
                    if (recargarTodo != null && recargarTodo) {
                      checkMarkerType();
                    }
                  });
                } else {
                  bool? recargarTodo = await Navigator.push(
                    context,
                    MaterialPageRoute<bool>(
                        builder: (BuildContext context) => InfoPOI(poi,
                            locationUser: _locationUser, iconMarker: icono),
                        fullscreenDialog: false),
                  );
                  if (reactivar) {
                    getLocationUser(false);
                    _locationON = true;
                    _mapCenterInUser = false;
                  }
                  iconFabCenter();
                  if (recargarTodo != null && recargarTodo) {
                    //lpoi = [];
                    checkMarkerType();
                  }
                }
              }));
        }
      }
    }
    setState(() {});
  }

  void funIni(MapPosition mapPos, bool vF) async {
    if (!vF && _cargaInicial) {
      _cargaInicial = false;
      checkMarkerType();
    }
  }

  void changePage(index) async {
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

    // if (!_userIded && index != 3) {
    //   if (!_userIded && !_banner) {
    //     _banner = true;
    //     ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    //     AppLocalizations? appLoca = AppLocalizations.of(context);
    //     smState.showMaterialBanner(
    //       MaterialBanner(
    //         content: Text(appLoca!.iniciaParaRealizar),
    //         actions: [
    //           TextButton(
    //             onPressed: () async {
    //               _banner = false;
    //               smState.hideCurrentMaterialBanner();
    //               _lastCenter = mapController.center;
    //               _lastZoom = mapController.zoom;
    //               await Navigator.push(
    //                 context,
    //                 MaterialPageRoute<void>(
    //                     builder: (BuildContext context) => const LoginUsers(),
    //                     fullscreenDialog: true),
    //               );
    //             },
    //             child: Text(appLoca.iniciarSesionRegistro),
    //           ),
    //           TextButton(
    //             onPressed: () {
    //               _banner = false;
    //               smState.hideCurrentMaterialBanner();
    //             },
    //             child: Text(appLoca.masTarde),
    //           )
    //         ],
    //       ),
    //     );
    //   }
    // }
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
          // mapController.move(
          //     LatLng(_locationUser!.latitude, _locationUser!.longitude),
          //     max(mapController.zoom, 16));
          // LatLng latLng = mapController.center;
          // GoRouter.of(context).go(
          //     '/map?center=${latLng.latitude},${latLng.longitude}&zoom=${mapController.zoom}');
          moveMap(LatLng(_locationUser!.latitude, _locationUser!.longitude),
              mapController.zoom);
        }
      }
    } else {
      LocationSettings locationSettings =
          await Auxiliar.checkPermissionsLocation(
              context, defaultTargetPlatform);

      _strLocationUser =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen((Position? point) async {
        if (point != null) {
          _locationUser = point;
          if (!_locationON) {
            setState(() {
              _locationON = true;
            });
            if (centerPosition) {
              // mapController.move(LatLng(point.latitude, point.longitude),
              //     max(mapController.zoom, 16));
              // LatLng latLng = mapController.center;
              // GoRouter.of(context).go(
              //     '/map?center=${latLng.latitude},${latLng.longitude}&zoom=${mapController.zoom}');
              moveMap(mapController.center, 16);
              setState(() {
                _mapCenterInUser = true;
              });
              //checkMarkerType();
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
                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
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
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    switch (Auxiliar.userCHEST.rol) {
      case Rol.teacher:
      case Rol.admin:
        if (Auxiliar.userCHEST.crol == Rol.user) {
          smState.clearSnackBars();
          smState.showSnackBar(SnackBar(
              content: Text(appLoca!.vuelveATuPerfil),
              duration: const Duration(seconds: 8),
              action: SnackBarAction(
                  label: appLoca.activar,
                  onPressed: () {
                    Auxiliar.userCHEST.crol = Auxiliar.userCHEST.rol;
                    iconFabCenter();
                  })));
        } else {
          if (mapController.zoom < 16) {
            smState.clearSnackBars();
            smState.showSnackBar(SnackBar(
              content: Text(
                appLoca!.aumentaZum,
              ),
              action: SnackBarAction(
                  label: appLoca.aumentaZumShort,
                  onPressed: () =>
                      // mapController.move(point, 16)
                      moveMap(point, 16)),
            ));
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute<POI>(
                builder: (BuildContext context) =>
                    NewPoi(point, mapController.bounds!, _currentPOIs),
                fullscreenDialog: true,
              ),
            ).then((POI? poiNewPoi) async {
              if (poiNewPoi != null) {
                POI? resetPois = await Navigator.push(
                    context,
                    MaterialPageRoute<POI>(
                        builder: (BuildContext context) => FormPOI(poiNewPoi),
                        fullscreenDialog: false));
                if (resetPois is POI) {
                  //lpoi = [];
                  MapData.addPoi2Tile(resetPois);
                  checkMarkerType();
                }
              }
            });
          }
        }
        break;
      default:
        break;
    }
  }

  void moveMap(LatLng center, double zoom) {
    mapController.move(center, zoom);
    GoRouter.of(context)
        .go('/map?center=${center.latitude},${center.longitude}&zoom=$zoom');
  }
}
