import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_network/image_network.dart';
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
import 'package:chest/util/helpers/feature.dart';
import 'package:chest/util/helpers/queries.dart';
import 'package:chest/util/helpers/user.dart';
import 'package:chest/util/helpers/tasks.dart';
import 'package:chest/itineraries.dart';
import 'package:chest/main.dart';
import 'package:chest/features.dart';
// https://stackoverflow.com/a/60089273
import 'package:chest/util/helpers/auxiliar_mobile.dart'
    if (dart.library.html) 'package:chest/util/helpers/auxiliar_web.dart';
import 'package:chest/util/auth/firebase.dart';
import 'package:chest/util/helpers/chest_marker.dart';
import 'package:chest/util/config.dart';

class MyMap extends StatefulWidget {
  final String? center, zoom;
  const MyMap({
    super.key,
    this.center,
    this.zoom,
  });

  @override
  State<MyMap> createState() => _MyMap();
}

class _MyMap extends State<MyMap> {
  final SearchController searchController = SearchController();
  int currentPageIndex = 0;
  bool _userIded = false,
      _locationON = false,
      _mapCenterInUser = false,
      _cargaInicial = true,
      _tryingSignIn = false;
  late bool
      // _perfilProfe,
      // _esProfe,
      _extendedBar,
      _filterOpen,
      _visibleLabel,
      barraAlLado,
      barraAlLadoExpandida,
      ini;
  final double lado = 0.0254;
  List<Marker> _myMarkers = <Marker>[], _myMarkersNPi = <Marker>[];
  List<Feature> _currentPOIs = <Feature>[];
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
    _visibleLabel = true;
    _filterOpen = false;
    _lastMapEventScrollWheelZoom = 0;
    barraAlLado = false;
    barraAlLadoExpandida = false;
    _lastBack = 0;
    if (widget.center != null && widget.center!.split(',').length == 2) {
      List<String> pos = widget.center!.split(',');
      double? latd = double.tryParse(pos.first);
      double? lond = double.tryParse(pos.last);
      if (latd != null &&
          lond != null &&
          latd >= -90 &&
          latd <= 90 &&
          lond >= -180 &&
          lond <= 180) {
        _lastCenter = LatLng(latd, lond);
      } else {
        _lastCenter = const LatLng(41.6529, -4.72839);
      }
    } else {
      _lastCenter = const LatLng(41.6529, -4.72839);
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
    _extendedBar = true;
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
        LatLng latLng = mapController.camera.center;
        GoRouter.of(context).go(
            '/map?center=${latLng.latitude},${latLng.longitude}&zoom=${mapController.camera.zoom}');
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
    double withWindow = MediaQuery.of(context).size.width;
    barraAlLado = withWindow > 599;
    barraAlLadoExpandida = barraAlLado && withWindow > 839;
    pages = [
      widgetMap(barraAlLado),
      widgetItineraries(),
      widgetAnswers(),
      widgetProfile(),
    ];
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (bool popInvoked) async {
        if (currentPageIndex != 0) {
          currentPageIndex = 0;
          changePage(0);
          // return false;
        } else {
          int now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastBack < 2000) {
            SystemNavigator.pop();
          } else {
            _lastBack = now;
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(appLoca!.atrasSalir),
              duration: const Duration(milliseconds: 1500),
            ));
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
                      icon: Icon(
                        Icons.map_outlined,
                        semanticLabel: appLoca!.mapa,
                      ),
                      selectedIcon: Icon(
                        Icons.map,
                        semanticLabel: appLoca.mapa,
                      ),
                      label: appLoca.mapa,
                      tooltip: appLoca.mapa,
                    ),
                    NavigationDestination(
                      icon: Icon(
                        Icons.route_outlined,
                        semanticLabel: appLoca.itinerarios,
                      ),
                      selectedIcon: Icon(
                        Icons.route,
                        semanticLabel: appLoca.itinerarios,
                      ),
                      label: appLoca.itinerarios,
                      tooltip: appLoca.misItinerarios,
                    ),
                    NavigationDestination(
                      icon: Icon(
                        Icons.my_library_books_outlined,
                        semanticLabel: appLoca.respuestas,
                      ),
                      selectedIcon: Icon(
                        Icons.my_library_books,
                        semanticLabel: appLoca.respuestas,
                      ),
                      label: appLoca.respuestas,
                      tooltip: appLoca.misRespuestas,
                    ),
                    NavigationDestination(
                      icon: iconoFotoPerfil(Icon(
                        Auxiliar.userCHEST.isNotGuest
                            ? Icons.person_outline
                            : Icons.person_off_outlined,
                        semanticLabel: appLoca.perfil,
                      )),
                      selectedIcon: iconoFotoPerfil(Icon(
                        Auxiliar.userCHEST.isNotGuest
                            ? Icons.person
                            : Icons.person_off,
                        semanticLabel: appLoca.perfil,
                      )),
                      label: appLoca.perfil,
                      tooltip: appLoca.perfil,
                    ),
                  ],
                ),
          floatingActionButton: widgetFab(),
          body: barraAlLado
              ? Row(children: [
                  NavigationRail(
                    selectedIndex: currentPageIndex,
                    leading: barraAlLadoExpandida
                        ? _extendedBar
                            ? Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 50,
                                children: [
                                  Wrap(
                                    spacing: 15,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      SvgPicture.asset(
                                        'images/logo.svg',
                                        height: 40,
                                        semanticsLabel: appLoca!.chest,
                                      ),
                                      Text(
                                        appLoca.chest,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      semanticLabel: appLoca.cerrarMenu,
                                    ),
                                    onPressed: () => setState(
                                      (() => {_extendedBar = !_extendedBar}),
                                    ),
                                    iconSize: 22,
                                  ),
                                ],
                              )
                            : IconButton(
                                iconSize: 24.0,
                                icon: Icon(
                                  Icons.menu,
                                  semanticLabel: appLoca!.abrirMenu,
                                ),
                                onPressed: () => setState(() {
                                  _extendedBar = !_extendedBar;
                                }),
                              )
                        : Wrap(
                            direction: Axis.vertical,
                            spacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // SvgPicture.asset(
                              //   'images/logo.svg',
                              //   height: 40,
                              //   semanticsLabel: 'CHEST',
                              // ),
                              Text(
                                appLoca!.chest,
                                style: Theme.of(context).textTheme.titleLarge,
                                semanticsLabel: appLoca.chest,
                              ),
                            ],
                          ),
                    groupAlignment: -1,
                    onDestinationSelected: (int index) => changePage(index),
                    useIndicator: true,
                    labelType: barraAlLadoExpandida && _extendedBar
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    extended: barraAlLadoExpandida && _extendedBar,
                    destinations: [
                      NavigationRailDestination(
                        icon: Icon(
                          Icons.map_outlined,
                          semanticLabel: appLoca.mapa,
                        ),
                        selectedIcon: Icon(
                          Icons.map,
                          semanticLabel: appLoca.mapa,
                        ),
                        label: Text(appLoca.mapa),
                      ),
                      NavigationRailDestination(
                        icon: Icon(
                          Icons.route_outlined,
                          semanticLabel: appLoca.misItinerarios,
                        ),
                        selectedIcon: Icon(
                          Icons.route,
                          semanticLabel: appLoca.misItinerarios,
                        ),
                        label: Text(appLoca.misItinerarios),
                      ),
                      NavigationRailDestination(
                        icon: Icon(
                          Icons.my_library_books_outlined,
                          semanticLabel: appLoca.misRespuestas,
                        ),
                        selectedIcon: Icon(
                          Icons.my_library_books,
                          semanticLabel: appLoca.misRespuestas,
                        ),
                        label: Text(appLoca.misRespuestas),
                      ),
                      NavigationRailDestination(
                        icon: iconoFotoPerfil(Icon(
                          Auxiliar.userCHEST.isNotGuest
                              ? Icons.person_outline
                              : Icons.person_off_outlined,
                          semanticLabel: appLoca.perfil,
                        )),
                        selectedIcon: iconoFotoPerfil(Icon(
                          Auxiliar.userCHEST.isNotGuest
                              ? Icons.person
                              : Icons.person_off,
                          semanticLabel: appLoca.perfil,
                        )),
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
      heroTag: null,
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
              initialCenter: _lastCenter,
              initialZoom: _lastZoom,
              keepAlive: false,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.pinchMove,
                enableScrollWheel: true,
                pinchZoomThreshold: 2.0,
              ),
              onPositionChanged: (mapPos, vF) => funIni(mapPos, vF),
              onMapReady: () {
                ini = true;
              },
              backgroundColor: td.brightness == Brightness.light
                  ? Colors.white54
                  : Colors.black54,
            ),
            children: [
              Auxiliar.tileLayerWidget(brightness: td.brightness),
              Auxiliar.atributionWidget(),
              CircleLayer(circles: _userCirclePosition),
              MarkerLayer(markers: _myMarkersNPi),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 120,
                  centerMarkerOnClick: false,
                  zoomToBoundsOnClick: false,
                  showPolygon: false,
                  onClusterTap: (p0) {
                    // mapController.move(
                    //     p0.bounds.center, min(p0.zoom + 1, Auxiliar.maxZoom));
                    moveMap(
                        p0.bounds.center, min(p0.zoom + 1, Auxiliar.maxZoom));
                  },
                  disableClusteringAtZoom: 18,
                  size: const Size(76, 76),
                  markers: _myMarkers,
                  circleSpiralSwitchover: 6,
                  spiderfySpiralDistanceMultiplier: 1,
                  // fitBoundsOptions:
                  //     const FitBoundsOptions(padding: EdgeInsets.all(0)),

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
        Padding(
          padding: EdgeInsets.only(top: barraAlLado ? 10 : 60),
          child: Wrap(
            direction: Axis.vertical,
            alignment: WrapAlignment.start,
            spacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                clipBehavior: Clip.none,
                child: SearchAnchor(
                  builder: (context, controller) => FloatingActionButton.small(
                    heroTag: Auxiliar.searchHero,
                    onPressed: () => searchController.openView(),
                    child: Icon(
                      Icons.search,
                      semanticLabel: appLoca!.realizaBusqueda,
                    ),
                  ),
                  searchController: searchController,
                  suggestionsBuilder: (context, controller) =>
                      Auxiliar.recuperaSugerencias(
                    context,
                    controller,
                    mapController: mapController,
                  ),
                ),
              ),
              Container(
                height: 40,
                constraints:
                    BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
                child: ListView(
                  shrinkWrap: true,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: filterbar,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: FloatingActionButton.small(
                  heroTag: null,
                  onPressed: () => Auxiliar.showMBS(
                      context,
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Wrap(spacing: 10, runSpacing: 10, children: [
                              _botonMapa(
                                Layers.carto,
                                MediaQuery.of(context).platformBrightness ==
                                        Brightness.light
                                    ? 'images/basemap_gallery/estandar_claro.png'
                                    : 'images/basemap_gallery/estandar_oscuro.png',
                                appLoca!.mapaEstandar,
                              ),
                              _botonMapa(
                                Layers.satellite,
                                'images/basemap_gallery/satelite.png',
                                appLoca.mapaSatelite,
                              ),
                            ]),
                          ),
                          const Divider(),
                          SwitchListTile.adaptive(
                            value: _visibleLabel,
                            onChanged: (bool newValue) {
                              setState(() => _visibleLabel = newValue);
                              Navigator.pop(context);
                              checkMarkerType();
                            },
                            title: Text(appLoca.etiquetaMarcadores),
                          ),
                        ],
                      ),
                      title: appLoca.tipoMapa),
                  // child: const Icon(Icons.layers),
                  child: Icon(
                    Icons.settings_applications,
                    semanticLabel: appLoca!.ajustes,
                  ),
                ),
              ),
            ],
          ),
        ),

        // TODO Multidomain
        // Padding(
        //   padding: const EdgeInsets.only(left: 14, bottom: 46),
        //   child: Column(
        //     mainAxisSize: MainAxisSize.max,
        //     mainAxisAlignment: MainAxisAlignment.end,
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       FloatingActionButton.small(
        //         tooltip: appLoca!.layers,
        //         heroTag: null,
        //         child: Queries.layerType == LayerType.ch
        //             ? const Icon(Icons.castle)
        //             : Queries.layerType == LayerType.schools
        //                 ? const Icon(Icons.school)
        //                 : const Icon(Icons.forest),
        //         // child: const Icon(Icons.layers),
        //         onPressed: () {
        //           Auxiliar.showMBS(
        //             context,
        //             Wrap(
        //               spacing: 5,
        //               runSpacing: 5,
        //               children: List<Widget>.generate(
        //                 LayerType.values.length,
        //                 (int index) {
        //                   LayerType s = LayerType.values.elementAt(index);
        //                   if (s == Queries.layerType) {
        //                     return FilledButton.icon(
        //                       onPressed: () => Navigator.pop(context),
        //                       icon: s == LayerType.ch
        //                           ? const Icon(Icons.castle)
        //                           : s == LayerType.schools
        //                               ? const Icon(Icons.school)
        //                               : const Icon(Icons.forest),
        //                       label: s == LayerType.ch
        //                           ? Text(appLoca.ch)
        //                           : s == LayerType.schools
        //                               ? Text(appLoca.schools)
        //                               : Text(appLoca.forest),
        //                     );
        //                   } else {
        //                     return OutlinedButton.icon(
        //                       onPressed: () async {
        //                         Navigator.pop(context);
        //                         MapData.resetLocalCache();
        //                         Queries.layerType = s;
        //                         //setState(() => Queries.layerType = s);
        //                         checkMarkerType();
        //                       },
        //                       icon: s == LayerType.ch
        //                           ? const Icon(Icons.castle_outlined)
        //                           : s == LayerType.schools
        //                               ? const Icon(Icons.school_outlined)
        //                               : const Icon(Icons.forest_outlined),
        //                       label: s == LayerType.ch
        //                           ? Text(appLoca.ch)
        //                           : s == LayerType.schools
        //                               ? Text(appLoca.schools)
        //                               : Text(appLoca.forest),
        //                     );
        //                   }
        //                 },
        //               ).toList(),
        //             ),
        //           );
        //           // Auxiliar.showMBS(
        //           //   context,
        //           //   SegmentedButton<LayerType>(
        //           //     multiSelectionEnabled: false,
        //           //     segments: <ButtonSegment<LayerType>>[
        //           //       ButtonSegment<LayerType>(
        //           //         value: LayerType.ch,
        //           //         label: Text(appLoca.ch),
        //           //         icon: const Icon(Icons.castle_outlined),
        //           //       ),
        //           //       ButtonSegment<LayerType>(
        //           //         value: LayerType.schools,
        //           //         label: Text(appLoca.schools),
        //           //         icon: const Icon(Icons.school_outlined),
        //           //       ),
        //           //       ButtonSegment<LayerType>(
        //           //         value: LayerType.forest,
        //           //         label: Text(appLoca.forest),
        //           //         icon: const Icon(Icons.forest_outlined),
        //           //       )
        //           //     ],
        //           //     selected: <LayerType>{Queries.layerType},
        //           //     onSelectionChanged: (Set<LayerType> item) {
        //           //       Navigator.pop(context);
        //           //       MapData.resetLocalCache();
        //           //       setState(() {
        //           //         Queries.layerType = item.first;
        //           //       });
        //           //       checkMarkerType();
        //           //     },
        //           //   ),
        //           // );
        //         },
        //       ),
        //     ],
        //   ),
        // ),
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

  Widget _botonMapa(Layers layer, String image, String textLabel) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Auxiliar.layer == layer
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 5, top: 10, right: 10, left: 10),
      child: InkWell(
        onTap: Auxiliar.layer != layer ? () => _changeLayer(layer) : () {},
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.all(10),
              width: 100,
              height: 100,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  image,
                  fit: BoxFit.fill,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 10, right: 10, left: 10),
              child: Text(textLabel),
            ),
          ],
        ),
      ),
    );
  }

  void _changeLayer(Layers layer) {
    setState(() {
      Auxiliar.layer = layer;
      // Auxiliar.updateMaxZoom();
      if (mapController.camera.zoom > Auxiliar.maxZoom) {
        moveMap(mapController.camera.center, Auxiliar.maxZoom);
      }
    });
    Navigator.pop(context);
    checkMarkerType();
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
                                  it.author == Auxiliar.userCHEST.iri) ||
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
                                        http.delete(Queries.deleteIt(it.id!),
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
                                              if (Config.development) {
                                                debugPrint(response.statusCode
                                                    .toString());
                                              }
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
    return http.get(Queries.getItineraries()).then((response) =>
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
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        _userIded
            ? SliverAppBar(
                pinned: true,
                stretchTriggerOffset: 300,
                expandedHeight: 200,
                backgroundColor: colorScheme.primary,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    Auxiliar.userCHEST.alias != null
                        ? Auxiliar.userCHEST.alias!
                        : FirebaseAuth.instance.currentUser != null &&
                                FirebaseAuth
                                        .instance.currentUser!.displayName !=
                                    null
                            ? FirebaseAuth.instance.currentUser!.displayName!
                            : appLoca!.perfil,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .copyWith(color: colorScheme.onPrimary),
                  ),
                  titlePadding: const EdgeInsets.only(bottom: 10),
                  collapseMode: CollapseMode.pin,
                  centerTitle: true,
                  background: ImageNetwork(
                    image: FirebaseAuth.instance.currentUser!.photoURL!,
                    height: 96,
                    width: 96,
                    duration: 0,
                    onTap: null,
                    fitAndroidIos: BoxFit.scaleDown,
                    borderRadius: BorderRadius.circular(48),
                    onError: const Icon(Icons.person, size: 96),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: _userIded
                        ? () async => await AuthFirebase.signOutGoogle()
                        : null,
                    tooltip: appLoca!.cerrarSes,
                    icon: Icon(
                      Icons.output,
                      color: colorScheme.onPrimary,
                    ),
                  )
                ],
              )
            : SliverAppBar(
                title: Text(
                  appLoca!.perfil,
                ),
                centerTitle: true,
              ),
        widgetCurrentUser(),
        widgetStandarOptions(),
      ],
    );
  }

  Widget widgetCurrentUser() {
    ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextStyle bodyMedium = td.textTheme.bodyMedium!;
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> widgets = [];
    if (!_userIded) {
      // widgets.add(FilledButton(
      //   child: Text(appLoca!.iniciarSesionRegistro),
      //   onPressed: () async {
      //     ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
      //     await Navigator.push(
      //         context,
      //         MaterialPageRoute<void>(
      //             builder: (BuildContext context) => const LoginUsers(),
      //             fullscreenDialog: false));
      //     //setState(() {});
      //   },
      // ));

      widgets.add(SizedBox(
        height: 40,
        child: OutlinedButton(
          onPressed: _tryingSignIn
              ? null
              : () async {
                  setState(() => _tryingSignIn = true);
                  AuthFirebase.signInGoogle().then(
                    (bool? newUser) async {
                      if (newUser != null) {
                        if (newUser) {
                          // Pantalla para más datos. Desde allí hago la llamada al servidor
                          Auxiliar.allowNewUser = true;
                          setState(() => _tryingSignIn = false);
                          if (!Config.development) {
                            FirebaseAnalytics.instance
                                .logSignUp(signUpMethod: "Google")
                                .then((a) {
                              GoRouter.of(context).go(
                                  '/users/${FirebaseAuth.instance.currentUser!.uid}/newUser',
                                  extra: [
                                    mapController.camera.center.latitude,
                                    mapController.camera.center.longitude,
                                    mapController.camera.zoom
                                  ]);
                            });
                          } else {
                            GoRouter.of(context).go(
                                '/users/${FirebaseAuth.instance.currentUser!.uid}/newUser',
                                extra: [
                                  mapController.camera.center.latitude,
                                  mapController.camera.center.longitude,
                                  mapController.camera.zoom
                                ]);
                          }
                        } else {
                          http.get(Queries.signIn(), headers: {
                            'Authorization': Template('Bearer {{{token}}}')
                                .renderString({
                              'token': await FirebaseAuth.instance.currentUser!
                                  .getIdToken()
                            })
                          }).then((response) async {
                            switch (response.statusCode) {
                              case 200:
                                Map<String, dynamic> data =
                                    json.decode(response.body);
                                setState(
                                    () => Auxiliar.userCHEST = UserCHEST(data));
                                iconFabCenter();
                                if (Auxiliar.userCHEST.alias != null) {
                                  sMState.clearSnackBars();
                                  sMState.showSnackBar(SnackBar(
                                      content: Text(
                                          '${appLoca!.hola} ${Auxiliar.userCHEST.alias}')));
                                }
                                if (!Config.development) {
                                  FirebaseAnalytics.instance
                                      .logLogin(loginMethod: "Google")
                                      .then((a) {
                                    // TODO
                                    // GoRouter.of(context).go(Auxiliar
                                    //         .userCHEST.lastMapView.init
                                    //     ? '/map?center=${Auxiliar.userCHEST.lastMapView.lat!},${Auxiliar.userCHEST.lastMapView.long!}&zoom=${Auxiliar.userCHEST.lastMapView.zoom!}'
                                    //     : '/map');
                                  });
                                }
                                // else {
                                // GoRouter.of(context).go(Auxiliar
                                //         .userCHEST.lastMapView.init
                                //     ? '/map?center=${Auxiliar.userCHEST.lastMapView.lat!},${Auxiliar.userCHEST.lastMapView.long!}&zoom=${Auxiliar.userCHEST.lastMapView.zoom!}'
                                //     : '/map');
                                // }
                                break;
                              default:
                                AuthFirebase.signOutGoogle();
                                sMState.clearSnackBars();
                                sMState.showSnackBar(SnackBar(
                                    backgroundColor: colorScheme.error,
                                    content: Text(
                                        'Error in GET. Status code: ${response.statusCode}',
                                        style: bodyMedium.copyWith(
                                            color: colorScheme.onError))));
                            }
                            setState(() => _tryingSignIn = false);
                          });
                        }
                      } else {
                        setState(() => _tryingSignIn = false);
                      }
                    },
                  ).onError((error, stackTrace) {
                    if (Config.development) debugPrint(error.toString());
                    setState(() => _tryingSignIn = false);
                  });
                },
          // https://developers.google.com/identity/branding-guidelines
          child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  height: 20,
                  width: 20,
                  child: Image.asset(
                    'images/g.png',
                    fit: BoxFit.scaleDown,
                  ),
                ),
                Text(
                  appLoca!.iniciarSesionRegistro,
                  semanticsLabel: appLoca.iniciarSesionRegistro,
                ),
              ]),
        ),
      ));
    }
    widgets.add(TextButton.icon(
      onPressed: _userIded
          ? () => GoRouter.of(context)
              .push('/users/${Auxiliar.userCHEST.id.split('/').last}')
          : null,
      label: Text(
        appLoca!.infoGestion,
        semanticsLabel: appLoca.infoGestion,
      ),
      icon: const Icon(Icons.person),
    ));
    // widgets.add(TextButton.icon(
    //   onPressed:
    //       _userIded ? () async => await AuthFirebase.signOutGoogle() : null,
    //   label: Text(appLoca.cerrarSes),
    //   icon: const Icon(Icons.output),
    // ));
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
      label: Text(appLoca.ajustesCHEST, semanticsLabel: appLoca.ajustesCHEST),
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
      label: Text(appLoca.ayudaOpinando, semanticsLabel: appLoca.ayudaOpinando),
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
        label: Text(appLoca!.politica, semanticsLabel: appLoca.politica),
        icon: const Icon(Icons.policy),
      ),
      Visibility(
        visible: !kIsWeb,
        child: TextButton.icon(
          onPressed: () async => Auxiliar.share(Config.addClient, context),
          label: Text(appLoca.comparteApp, semanticsLabel: appLoca.comparteApp),
          icon: const Icon(Icons.share),
        ),
      ),
      TextButton.icon(
        onPressed: () {
          // Navigator.pushNamed(context, '/about');
          GoRouter.of(context).push('/about');
        },
        label: Text(appLoca.masInfo, semanticsLabel: appLoca.masInfo),
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
      // _perfilProfe = Auxiliar.userCHEST.crol == Rol.teacher ||
      //     Auxiliar.userCHEST.crol == Rol.admin;
      // _esProfe = Auxiliar.userCHEST.rol.contains(Rol.teacher) ||
      //     Auxiliar.userCHEST.rol.contains(Rol.admin);
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
              visible: Auxiliar.userCHEST.canEditNow,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FloatingActionButton(
                  heroTag: Auxiliar.userCHEST.canEditNow
                      ? Auxiliar.mainFabHero
                      : null,
                  tooltip: appLoca!.tNPoi,
                  onPressed: () async {
                    LatLng point = mapController.camera.center;
                    if (mapController.camera.zoom < 16) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(appLoca.aumentaZum),
                        action: SnackBarAction(
                            label: appLoca.aumentaZumShort,
                            onPressed: () => setState(() =>
                                // mapController.move(mapController.center, 16)
                                moveMap(mapController.camera.center, 16))),
                      ));
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute<Feature>(
                          builder: (BuildContext context) => NewPoi(point,
                              mapController.camera.visibleBounds, _currentPOIs),
                          fullscreenDialog: true,
                        ),
                      ).then((poiNewPoi) async {
                        if (poiNewPoi != null) {
                          Navigator.push(
                                  context,
                                  MaterialPageRoute<Feature>(
                                      builder: (BuildContext context) =>
                                          FormPOI(poiNewPoi),
                                      fullscreenDialog: false))
                              .then((Feature? resetPois) {
                            if (resetPois is Feature) {
                              //lpoi = [];
                              MapData.addFeature2Tile(resetPois);
                              checkMarkerType();
                            }
                          });
                        }
                      });
                    }
                  },
                  child: Icon(Icons.add,
                      semanticLabel: appLoca.tNPoi,
                      color: ini && mapController.camera.zoom < 16
                          ? Colors.grey
                          : colorScheme.onPrimaryContainer),
                ),
              ),
            ),
            Visibility(
              visible: Auxiliar.userCHEST.canEdit,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FloatingActionButton.small(
                  heroTag: null,
                  onPressed: () {
                    Auxiliar.userCHEST.crol =
                        Auxiliar.userCHEST.canEditNow ? Rol.user : Rol.teacher;
                    checkMarkerType();
                    iconFabCenter();
                  },
                  backgroundColor: Auxiliar.userCHEST.canEditNow
                      ? colorScheme.primaryContainer
                      : td.disabledColor,
                  child: Icon(Icons.power_settings_new,
                      semanticLabel: appLoca.activarDesactivarProfe,
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
                        moveMap(
                            mapController.camera.center,
                            min(mapController.camera.zoom + 1,
                                Auxiliar.maxZoom));
                        checkMarkerType();
                      },
                      tooltip: appLoca.aumentaZumShort,
                      child: Icon(
                        Icons.zoom_in,
                        semanticLabel: appLoca.aumentaZumShort,
                      ),
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
                        moveMap(
                            mapController.camera.center,
                            max(mapController.camera.zoom - 1,
                                Auxiliar.minZoom));
                        checkMarkerType();
                      },
                      tooltip: appLoca.disminuyeZum,
                      child: Icon(
                        Icons.zoom_out,
                        semanticLabel: appLoca.disminuyeZum,
                      ),
                    )
                  ],
                ),
              ),
            ),
            FloatingActionButton(
              heroTag:
                  Auxiliar.userCHEST.canEditNow ? null : Auxiliar.mainFabHero,
              onPressed: () => getLocationUser(true),
              mini: Auxiliar.userCHEST.canEditNow,
              child: Icon(
                iconLocation,
                semanticLabel: appLoca.mUbicacion,
              ),
            ),
          ],
        );
      case 1:
        return Auxiliar.userCHEST.canEditNow
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
                icon: Icon(
                  Icons.add,
                  semanticLabel: appLoca.agregarIt,
                ),
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
        _mapCenterInUser = mapController.camera.center.latitude ==
                _locationUser!.latitude &&
            mapController.camera.center.longitude == _locationUser!.longitude;
      });
    }
    if (mapController.camera.zoom >= 13) {
      if (_currentPOIs.isEmpty) {
        _currentNPOIs = [];
      }
      checkCurrentMap(mapController.camera.visibleBounds, false);
    } else {
      if (_currentNPOIs.isEmpty) {
        _currentPOIs = [];
      }
      checkCurrentMap(mapController.camera.visibleBounds, true);
    }
  }

  void checkCurrentMap(LatLngBounds? mapBounds, bool group) async {
    _myMarkers = <Marker>[];
    _myMarkersNPi = <Marker>[];
    _currentPOIs = <Feature>[];
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
            child: InkWell(
                onTap: () async {
                  // mapController.move(
                  //     LatLng(npoi.lat, npoi.long), mapController.zoom + 1);
                  moveMap(LatLng(npoi.lat, npoi.long),
                      mapController.camera.zoom + 1);
                  checkMarkerType();
                },
                child: icono),
          ),
        );
      }
    }
    setState(() {});
  }

  void addMarkers2Map(List<Feature> pois, LatLngBounds mapBounds) {
    List<Feature> visiblePois = <Feature>[];
    for (Feature poi in pois) {
      if (mapBounds.contains(LatLng(poi.lat, poi.long))) {
        visiblePois.add(poi);
      }
    }
    if (visiblePois.isNotEmpty) {
      ColorScheme colorScheme = Theme.of(context).colorScheme;
      for (Feature poi in visiblePois) {
        Widget icono;
        if (poi.hasThumbnail == true &&
            poi.thumbnail.image
                .contains('commons.wikimedia.org/wiki/Special:FilePath/')) {
          String imagen = poi.thumbnail.image;
          if (!imagen.contains('width=') && !imagen.contains('height=')) {
            imagen = Template('{{{url}}}?width=50&height=50')
                .renderString({'url': imagen});
          }
          // icono = Container(
          //   decoration: BoxDecoration(
          //     shape: BoxShape.circle,
          //     image: DecorationImage(
          //         image: Image.network(
          //           imagen,
          //           errorBuilder: (context, error, stack) => Center(
          //             child: Icon(
          //               Queries.layerType == LayerType.ch
          //                   ? Icons.castle_outlined
          //                   : Queries.layerType == LayerType.schools
          //                       ? Icons.school_outlined
          //                       : Icons.forest_outlined,
          //               color: colorScheme.onPrimaryContainer,
          //             ),
          //           ),
          //         ).image,
          //         fit: BoxFit.cover),
          //   ),
          // );
          icono = ImageNetwork(
            image: imagen,
            height: 52,
            width: 52,
            duration: 0,
            borderRadius: BorderRadius.circular(52),
            onLoading: Container(),
            onError: Container(),
          );
        } else {
          icono = Center(
            child: Icon(
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
            !((poi.labelLang(MyApp.currentLang) ?? poi.labels.first.value)
                .contains('https://www.openstreetmap.org/')) ||
            Queries.layerType == LayerType.forest) {
          _currentPOIs.add(poi);
          _myMarkers.add(CHESTMarker(context,
              feature: poi,
              icon: icono,
              visibleLabel: _visibleLabel,
              currentLayer: Auxiliar.layer!,
              circleWidthBorder: 2,
              circleWidthColor: colorScheme.primary,
              circleContainerColor: colorScheme.primaryContainer,
              onTap: () async {
            moveMap(LatLng(poi.lat, poi.long), mapController.camera.zoom);
            bool reactivar = _locationON;
            if (_locationON) {
              _locationON = false;
              _strLocationUser.cancel();
            }
            _lastCenter = mapController.camera.center;
            _lastZoom = mapController.camera.zoom;
            if (!Config.development) {
              FirebaseAnalytics.instance.logEvent(
                name: "seenFeature",
                parameters: {"iri": poi.shortId},
              ).then((value) async {
                // bool? recargarTodo = await Navigator.push(
                //   context,
                //   MaterialPageRoute<bool>(
                //       builder: (BuildContext context) => InfoPOI(
                //           poi: poi,
                //           locationUser: _locationUser,
                //           iconMarker: icono),
                //       fullscreenDialog: false),
                // );
                bool? recargarTodo = await context.push<bool>(
                    '/map/features/${poi.shortId}',
                    extra: [_locationUser, icono]);
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
                if (Config.development) debugPrint(error.toString());
                bool? recargarTodo = await GoRouter.of(context).push<bool>(
                    '/map/features/${poi.shortId}',
                    extra: [_locationUser, icono]);
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
              bool? recargarTodo = await GoRouter.of(context).push<bool>(
                  '/map/features/${poi.shortId}',
                  extra: [_locationUser, icono]);
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

  Future<void> changePage(index) async {
    setState(() {
      currentPageIndex = index;
    });
    if (index == 0) {
      iconFabCenter();
      checkMarkerType();
    }
    if (index != 0) {
      _lastCenter = mapController.camera.center;
      _lastZoom = mapController.camera.zoom;
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
              Itinerary itinerary = Itinerary(element);
              itineraries.add(itinerary);
            } catch (error) {
              //print(error);
              if (Config.development) debugPrint(error.toString());
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
          moveMap(LatLng(_locationUser!.latitude, _locationUser!.longitude),
              mapController.camera.zoom);
        }
      }
    } else {
      // Tengo que recuperar la ubicación del usuario
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
              moveMap(LatLng(point.latitude, point.longitude),
                  max(16, mapController.camera.zoom));
              setState(() {
                _mapCenterInUser = true;
              });
              //checkMarkerType();
            }
          } else {
            if (_mapCenterInUser) {
              setState(() {
                _mapCenterInUser = mapController.camera.center.latitude ==
                        _locationUser!.latitude &&
                    mapController.camera.center.longitude ==
                        _locationUser!.longitude;
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
        } else {
          ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
          smState.clearSnackBars();
          smState.showSnackBar(SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorRecuperarUbicacion,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
        }
      });
      checkMarkerType();
    }
  }

  // void onLongPressMap(LatLng point) async {
  //   ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
  //   AppLocalizations? appLoca = AppLocalizations.of(context);
  //   switch (Auxiliar.userCHEST.rol) {
  //     case Rol.teacher:
  //     case Rol.admin:
  //       if (Auxiliar.userCHEST.crol == Rol.user) {
  //         smState.clearSnackBars();
  //         smState.showSnackBar(SnackBar(
  //             content: Text(appLoca!.vuelveATuPerfil),
  //             duration: const Duration(seconds: 8),
  //             action: SnackBarAction(
  //                 label: appLoca.activar,
  //                 onPressed: () {
  //                   Auxiliar.userCHEST.crol = Auxiliar.userCHEST.rol;
  //                   iconFabCenter();
  //                 })));
  //       } else {
  //         if (mapController.camera.zoom < 16) {
  //           smState.clearSnackBars();
  //           smState.showSnackBar(SnackBar(
  //             content: Text(
  //               appLoca!.aumentaZum,
  //             ),
  //             action: SnackBarAction(
  //                 label: appLoca.aumentaZumShort,
  //                 onPressed: () =>
  //                     // mapController.move(point, 16)
  //                     moveMap(point, 16)),
  //           ));
  //         } else {
  //           await Navigator.push(
  //             context,
  //             MaterialPageRoute<Feature>(
  //               builder: (BuildContext context) => NewPoi(
  //                   point, mapController.camera.visibleBounds, _currentPOIs),
  //               fullscreenDialog: true,
  //             ),
  //           ).then((Feature? poiNewPoi) async {
  //             if (poiNewPoi != null) {
  //               Feature? resetPois = await Navigator.push(
  //                   context,
  //                   MaterialPageRoute<Feature>(
  //                       builder: (BuildContext context) => FormPOI(poiNewPoi),
  //                       fullscreenDialog: false));
  //               if (resetPois is Feature) {
  //                 //lpoi = [];
  //                 MapData.addFeature2Tile(resetPois);
  //                 checkMarkerType();
  //               }
  //             }
  //           });
  //         }
  //       }
  //       break;
  //     default:
  //       break;
  //   }
  // }

  void moveMap(LatLng center, double zoom, {registra = true}) async {
    mapController.move(center, zoom);
    if (Auxiliar.userCHEST.isNotGuest && registra) {
      context
          .go('/map?center=${center.latitude},${center.longitude}&zoom=$zoom');
      saveLocation(center, zoom);
    } else {
      context
          .go('/map?center=${center.latitude},${center.longitude}&zoom=$zoom');
    }
  }

  void saveLocation(LatLng center, double zoom) async {
    LastPosition lp = LastPosition(
      center.latitude,
      center.longitude,
      zoom,
    );
    Auxiliar.userCHEST.lastMapView = lp;
    http.put(Queries.preferences(),
        headers: {
          'content-type': 'application/json',
          'Authorization': Template('Bearer {{{token}}}').renderString(
              {'token': await FirebaseAuth.instance.currentUser!.getIdToken()})
        },
        body: json.encode({'lastPointView': lp.toJSON()}));
  }

  Widget iconoFotoPerfil(Icon altIcon) {
    return altIcon;
    // return (FirebaseAuth.instance.currentUser != null &&
    //         FirebaseAuth.instance.currentUser!.emailVerified &&
    //         FirebaseAuth.instance.currentUser!.photoURL != null)
    // ? ImageNetwork(
    //     image: FirebaseAuth.instance.currentUser!.photoURL!,
    //     height: 24,
    //     width: 24,
    //     duration: 0,
    //     onTap: null,
    //     borderRadius: BorderRadius.circular(12),
    //     onLoading: Container(),
    //     onError: altIcon,
    //   )
    //     : altIcon;
  }
}
