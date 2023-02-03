import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/helpers/answers.dart';
import 'package:chest/helpers/auxiliar.dart';
import 'package:chest/helpers/itineraries.dart';
import 'package:chest/helpers/map_data.dart';
import 'package:chest/helpers/pois.dart';
import 'package:chest/helpers/queries.dart';
import 'package:chest/helpers/user.dart';
import 'package:chest/helpers/tasks.dart';
import 'package:chest/itineraries.dart';
import 'package:chest/main.dart';
import 'package:chest/pois.dart';
import 'package:chest/users.dart';

class MyMap extends StatefulWidget {
  const MyMap({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _MyMap();
}

class _MyMap extends State<MyMap> {
  int currentPageIndex = 0;
  bool _userIded = false,
      _locationON = false,
      _mapCenterInUser = false,
      _cargaInicial = true;
  late bool _banner, _perfilProfe, _esProfe, _extendedBar;
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
  late FirebaseAnalytics firebaseAnalytics;

  @override
  void initState() {
    _lastMapEventScrollWheelZoom = 0;
    barraAlLado = false;
    _lastBack = 0;
    _banner = false;
    _lastCenter = LatLng(41.6529, -4.72839);
    _lastZoom = 15.0;
    itineraries = [];
    _extendedBar = false;
    checkUserLogin();
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      strSubMap = mapController.mapEventStream
          .where((event) =>
              event is MapEventMoveEnd ||
              event is MapEventDoubleTapZoomEnd ||
              event is MapEventScrollWheelZoom)
          .listen((event) async {
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
    pages = [
      widgetMap(),
      widgetItineraries(),
      widgetAnswers(),
      widgetProfile(),
    ];
    // bool barraAlLado =
    //     MediaQuery.of(context).orientation == Orientation.landscape &&
    //         MediaQuery.of(context).size.aspectRatio > 0.9;
    barraAlLado = MediaQuery.of(context).orientation == Orientation.landscape &&
        MediaQuery.of(context).size.shortestSide > 599;
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
              content: Text(AppLocalizations.of(context)!.atrasSalir),
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
                      label: AppLocalizations.of(context)!.mapa,
                      tooltip: AppLocalizations.of(context)!.mapa,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.route_outlined),
                      selectedIcon: const Icon(Icons.route),
                      label: AppLocalizations.of(context)!.itinerarios,
                      tooltip: AppLocalizations.of(context)!.misItinerarios,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.my_library_books_outlined),
                      selectedIcon: const Icon(Icons.my_library_books),
                      label: AppLocalizations.of(context)!.respuestas,
                      tooltip: AppLocalizations.of(context)!.misRespuestas,
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
                    backgroundColor: Theme.of(context)
                        .bottomNavigationBarTheme
                        .backgroundColor,
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
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    AppLocalizations.of(context)!.chest,
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
                                ),
                                const SizedBox(height: 1),
                                Text(AppLocalizations.of(context)!.chest),
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
                        label: Text(AppLocalizations.of(context)!.mapa),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.route_outlined),
                        selectedIcon: const Icon(Icons.route),
                        label: Text(_extendedBar
                            ? AppLocalizations.of(context)!.misItinerarios
                            : AppLocalizations.of(context)!.misItinerarios),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.my_library_books_outlined),
                        selectedIcon: const Icon(Icons.my_library_books),
                        label: Text(_extendedBar
                            ? AppLocalizations.of(context)!.misRespuestas
                            : AppLocalizations.of(context)!.misRespuestas),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.person_pin_outlined),
                        selectedIcon: const Icon(Icons.person_pin),
                        label: Text(AppLocalizations.of(context)!.perfil),
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

  Widget widgetMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            maxZoom: Auxiliar.maxZoom,
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
            onMapReady: () {
              //mapController = mC;
              //mapController.onReady.then((value) => {});
              // strSubMap = mapController.mapEventStream
              //     .where((event) =>
              //         event is MapEventMoveEnd ||
              //         event is MapEventDoubleTapZoomEnd ||
              //         event is MapEventScrollWheelZoom)
              //     .listen((event) {
              //   if (event is MapEventScrollWheelZoom) {
              //     int current = DateTime.now().millisecondsSinceEpoch;
              //     if (_lastMapEventScrollWheelZoom + 200 < current) {
              //       _lastMapEventScrollWheelZoom = current;
              //       checkMarkerType();
              //     }
              //   } else {
              //     checkMarkerType();
              //   }
              // });
            },
            pinchZoomThreshold: 2.0,
            /*plugins: [
                MarkerClusterPlugin(),
              ]*/
          ),
          children: [
            Auxiliar.tileLayerWidget(brightness: Theme.of(context).brightness),
            Auxiliar.atributionWidget(),
            CircleLayer(circles: _userCirclePosition),
            MarkerLayer(markers: _myMarkersNPi),
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
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          child: TextField(
            decoration: InputDecoration(
              constraints: const BoxConstraints(maxWidth: 600),
              border: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey)),
              focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey)),
              hintText: AppLocalizations.of(context)!.realizaBusqueda,
              prefixIcon: barraAlLado
                  ? null
                  : SvgPicture.asset(
                      'images/logo.svg',
                      height: 60,
                    ),
              prefixIconConstraints:
                  barraAlLado ? null : const BoxConstraints(maxHeight: 36),
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.light
                  ? Colors.white70
                  : Theme.of(context).colorScheme.background,
            ),
            readOnly: true,
            autofocus: false,
            onTap: () {
              // Llamo a la interfaz de búsqeuda de municipios
              debugPrint("Pulso");
            },
          ),
        )
      ],
    );
  }

  Widget widgetItineraries() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          centerTitle: true,
          floating: true,
          title: Text(AppLocalizations.of(context)!.misItinerarios),
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
                            showModalBottomSheet(
                              context: context,
                              constraints: const BoxConstraints(maxWidth: 640),
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(10))),
                              builder: (context) => Padding(
                                padding: const EdgeInsets.only(
                                  top: 22,
                                  right: 10,
                                  left: 10,
                                  bottom: 5,
                                ),
                                child: Column(
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
                                    const Divider(),
                                    TextButton.icon(
                                      onPressed: null,
                                      icon: const Icon(Icons.edit),
                                      label: Text(
                                          AppLocalizations.of(context)!.editar),
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete),
                                      label: Text(
                                          AppLocalizations.of(context)!.borrar),
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        bool? delete =
                                            await Auxiliar.deleteDialog(
                                                context,
                                                AppLocalizations.of(context)!
                                                    .borrarIt,
                                                AppLocalizations.of(context)!
                                                    .preguntaBorrarIt);
                                        if (delete != null && delete) {
                                          http.delete(
                                              Queries().deleteIt(it.id!),
                                              headers: {
                                                'Content-Type':
                                                    'application/json',
                                                'Authorization': Template(
                                                        'Bearer {{{token}}}')
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
      lista.add(
        Card(
          child: ListTile(
            title: titulo,
            subtitle: subtitulo,
          ),
        ),
      );
    }

    // return SafeArea(
    //   minimum: const EdgeInsets.all(10),
    //   child: Center(
    //     child: Container(
    //       constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
    //       child: _userIded && Auxiliar.userCHEST.answers.isNotEmpty
    //           ? ListView(
    //               children: lista,
    //             )
    //           : Text(AppLocalizations.of(context)!.sinRespuestas),
    //     ),
    //   ),
    // );
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          centerTitle: true,
          floating: true,
          title: Text(AppLocalizations.of(context)!.misRespuestas),
        ),
        SliverPadding(
            padding: const EdgeInsets.all(10),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                  _userIded && Auxiliar.userCHEST.answers.isNotEmpty
                      ? lista
                      : [Text(AppLocalizations.of(context)!.sinRespuestas)]),
            ))
      ],
    );
  }

  Widget widgetProfile() {
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          centerTitle: true,
          surfaceTintColor: Theme.of(context).primaryColor,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.all(10),
            centerTitle: true,
            title: Text(
              AppLocalizations.of(context)!.chestLargo,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        widgetCurrentUser(),
        SliverPadding(
          padding: const EdgeInsets.all(10),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              [
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {},
                    label: Text(AppLocalizations.of(context)!.politica),
                    icon: const Icon(Icons.policy),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {},
                    label: Text(AppLocalizations.of(context)!.comparteApp),
                    icon: const Icon(Icons.share),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () {
                      // Navigator.push(
                      //     context,
                      //     MaterialPageRoute<void>(
                      //         builder: (BuildContext context) =>
                      //             const MoreInfo(),
                      //         fullscreenDialog: false));
                      Navigator.pushNamed(context, '/about');
                    },
                    label: Text(AppLocalizations.of(context)!.masInfo),
                    icon: const Icon(Icons.info),
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget widgetCurrentUser() {
    List<Container> widgets = [];
    if (!_userIded) {
      widgets.add(Container(
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        child: FilledButton(
          child: Text(AppLocalizations.of(context)!.iniciarSesionRegistro),
          onPressed: () async {
            _banner = false;
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            await Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (BuildContext context) => const LoginUsers(),
                    fullscreenDialog: false));
            //setState(() {});
          },
        ),
      ));
    }
    widgets.add(Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _userIded
            ? () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (BuildContext context) => const InfoUser(),
                        fullscreenDialog: false));
              }
            : null,
        label: Text(AppLocalizations.of(context)!.infoGestion),
        icon: const Icon(Icons.person),
      ),
    ));
    widgets.add(Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _userIded
            ? () {
                FirebaseAuth.instance.signOut();
                Auxiliar.userCHEST = UserCHEST.guest();
              }
            : null,
        label: Text(AppLocalizations.of(context)!.cerrarSes),
        icon: const Icon(Icons.output),
      ),
    ));
    widgets.add(Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _userIded ? () {} : null,
        label: Text(AppLocalizations.of(context)!.ajustesCHEST),
        icon: const Icon(Icons.settings),
      ),
    ));
    widgets.add(Container(
      constraints: const BoxConstraints(minHeight: 48),
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _userIded ? () {} : null,
        label: Text(AppLocalizations.of(context)!.ayudaOpinando),
        icon: const Icon(Icons.feedback),
      ),
    ));

    return SliverPadding(
      padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
      sliver: SliverList(
        delegate: SliverChildListDelegate(widgets),
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
    switch (currentPageIndex) {
      case 0:
        iconFabCenter();
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Visibility(
                visible: _esProfe,
                child: const SizedBox(
                  height: 24,
                )),
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
              ),
            ),
            Visibility(
                visible: _esProfe,
                child: const SizedBox(
                  height: 24,
                )),
            FloatingActionButton(
              heroTag: Auxiliar.mainFabHero,
              onPressed: () => getLocationUser(true),
              child: Icon(iconLocation),
            ),
            //   const SizedBox(
            //     height: 12,
            //   ),
            //   Container(
            //     // alignment: Alignment.center,
            //     constraints: const BoxConstraints(maxWidth: 640),
            //     child: FractionallySizedBox(
            //       widthFactor: 0.9,
            //       alignment: Alignment.center,
            //       child: Card(
            //         // child: ListTile(
            //         //   leading: const Icon(Icons.directions),
            //         //   title: Text("Tienes que ir a la Plaza mayor de Valladolid"),
            //         //   onTap: () {},
            //         // ),
            //         // child: ListTile(
            //         //   leading: const Icon(Icons.edit),
            //         //   isThreeLine: true,
            //         //   title: Text(
            //         //     "Plaza mayor de Valladolid",
            //         //     maxLines: 1,
            //         //     overflow: TextOverflow.ellipsis,
            //         //   ),
            //         //   subtitle: Text(
            //         //     "Busca en esta plaza elementos de la arquitectura popular castellana. Si los hay fotografíalos y si no los hay reflexiona los motivos.",
            //         //     maxLines: 2,
            //         //     overflow: TextOverflow.ellipsis,
            //         //   ),
            //         //   onTap: () {},
            //         // ),
            //         child: ListTile(
            //           leading: const Icon(Icons.list_alt),
            //           title: Text("Lista de POI y tareas del itinerario activo"),
            //           onTap: () {},
            //           onLongPress: () {
            //             showModalBottomSheet(
            //               context: context,
            //               constraints: const BoxConstraints(
            //                 maxWidth: 640,
            //                 minHeight: 100,
            //               ),
            //               isScrollControlled: true,
            //               shape: const RoundedRectangleBorder(
            //                   borderRadius: BorderRadius.vertical(
            //                       top: Radius.circular(10))),
            //               builder: ((context) {
            //                 return Padding(
            //                   padding: const EdgeInsets.only(
            //                     top: 22,
            //                     right: 10,
            //                     left: 10,
            //                     bottom: 5,
            //                   ),
            //                   child: FractionallySizedBox(
            //                     widthFactor: 0.9,
            //                     child: Column(
            //                       mainAxisSize: MainAxisSize.min,
            //                       children: [
            //                         Text("Manage itinerary status"),
            //                         const SizedBox(height: 10),
            //                         Row(
            //                           mainAxisAlignment:
            //                               MainAxisAlignment.spaceEvenly,
            //                           crossAxisAlignment:
            //                               CrossAxisAlignment.start,
            //                           children: [
            //                             TextButton(
            //                               onPressed: () {
            //                                 Navigator.pop(context);
            //                               },
            //                               child: Column(
            //                                 mainAxisSize: MainAxisSize.min,
            //                                 crossAxisAlignment:
            //                                     CrossAxisAlignment.center,
            //                                 children: [
            //                                   const Icon(Icons.stop),
            //                                   Text(
            //                                     "Stop",
            //                                     style: Theme.of(context)
            //                                         .textTheme
            //                                         .bodySmall,
            //                                   )
            //                                 ],
            //                               ),
            //                             ),
            //                             TextButton(
            //                               onPressed: () {
            //                                 Navigator.pop(context);
            //                               },
            //                               child: Column(
            //                                 mainAxisSize: MainAxisSize.min,
            //                                 crossAxisAlignment:
            //                                     CrossAxisAlignment.center,
            //                                 children: [
            //                                   const Icon(Icons.restart_alt),
            //                                   Text(
            //                                     "Restart",
            //                                     style: Theme.of(context)
            //                                         .textTheme
            //                                         .bodySmall,
            //                                   )
            //                                 ],
            //                               ),
            //                             ),
            //                             TextButton(
            //                               onPressed: () {
            //                                 Navigator.pop(context);
            //                               },
            //                               child: Column(
            //                                 mainAxisSize: MainAxisSize.min,
            //                                 crossAxisAlignment:
            //                                     CrossAxisAlignment.center,
            //                                 children: [
            //                                   const Icon(Icons.report_problem),
            //                                   Text(
            //                                     "Any problem?",
            //                                     style: Theme.of(context)
            //                                         .textTheme
            //                                         .bodySmall,
            //                                   )
            //                                 ],
            //                               ),
            //                             )
            //                           ],
            //                         ),
            //                         //const Divider(),
            //                       ],
            //                     ),
            //                   ),
            //                 );
            //               }),
            //             );
            //           },
            //         ),
            //       ),
            //     ),
            //   )
          ],
        );
      case 1:
        return _perfilProfe
            ? FloatingActionButton.extended(
                heroTag: Auxiliar.mainFabHero,
                onPressed: () async {
                  /*List<POI> pois = [];
                  for (TeselaPoi tp in lpoi) {
                    // pois.addAll(tp.getPois());
                    List<POI> tpPois = tp.getPois();
                    for (POI poi in tpPois) {
                      if (pois.indexWhere((POI p) => poi.id == p.id) == -1) {
                        pois.add(poi);
                      }
                    }
                  }*/
                  // pois.sort((POI a, POI b) {
                  //   String ta = a.labelLang(MyApp.currentLang) ??
                  //       a.labelLang("es") ??
                  //       '';
                  //   String tb = b.labelLang(MyApp.currentLang) ??
                  //       b.labelLang("es") ??
                  //       '';
                  //   return ta.compareTo(tb);
                  // });
                  // List<POI> pois =
                  //     await MapData.checkCurrentMapSplit(mapController.bounds!);
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
                label: Text(AppLocalizations.of(context)!.agregarIt),
                icon: const Icon(Icons.add),
                tooltip: AppLocalizations.of(context)!.agregarIt,
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
      addMarkers2Map(await MapData.checkCurrentMapSplit(mapBounds!), mapBounds);
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
                onTap: () async {
                  mapController.move(
                      LatLng(npoi.lat, npoi.long), mapController.zoom + 1);
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
      for (POI poi in visiblePois) {
        final String intermedio = poi.labels.first.value
            .replaceAllMapped(RegExp(r'[^A-Z]'), (m) => "");
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
                      child: Text(iniciales,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .copyWith(color: Colors.white)),
                    ),
                  ).image,
                  fit: BoxFit.cover),
            ),
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
              child: Text(iniciales,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .copyWith(color: Colors.white)),
            ),
          );
        }
        _currentPOIs.add(poi);
        _myMarkers.add(
          Marker(
            width: 52,
            height: 52,
            point: LatLng(poi.lat, poi.long),
            builder: (context) => Tooltip(
              message: poi.labelLang(MyApp.currentLang) ??
                  poi.labelLang("es") ??
                  poi.labels.first.value,
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
                  FirebaseAnalytics.instance.logEvent(
                    name: "seenPoi",
                    parameters: {"iri": poi.id.split('/').last},
                  );
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
                },
                child: icono,
              ),
            ),
          ),
        );
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
    if (!_userIded && index != 3) {
      if (!_userIded && !_banner) {
        _banner = true;
        ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
        AppLocalizations? appLoca = AppLocalizations.of(context);
        smState.showMaterialBanner(
          MaterialBanner(
            content: Text(appLoca!.iniciaParaRealizar),
            actions: [
              TextButton(
                onPressed: () async {
                  _banner = false;
                  smState.hideCurrentMaterialBanner();
                  _lastCenter = mapController.center;
                  _lastZoom = mapController.zoom;
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (BuildContext context) => const LoginUsers(),
                        fullscreenDialog: true),
                  );
                },
                child: Text(appLoca.iniciarSesionRegistro),
              ),
              TextButton(
                onPressed: () {
                  _banner = false;
                  smState.hideCurrentMaterialBanner();
                },
                child: Text(appLoca.masTarde),
              )
            ],
          ),
        );
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
              .listen((Position? point) async {
        if (point != null) {
          _locationUser = point;
          if (!_locationON) {
            setState(() {
              _locationON = true;
            });
            if (centerPosition) {
              mapController.move(LatLng(point.latitude, point.longitude),
                  max(mapController.zoom, 16));
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
                //lpoi = [];
                MapData.addPoi2Tile(resetPois);
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
