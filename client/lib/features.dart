import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_network/image_network.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';
import 'package:quill_html_editor/quill_html_editor.dart';
// import 'package:html_editor_enhanced/html_editor.dart';
// import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/util/helpers/map_data.dart';
import 'package:chest/full_screen.dart';
import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/feature.dart';
import 'package:chest/util/helpers/queries.dart';
import 'package:chest/util/helpers/tasks.dart';
import 'package:chest/util/helpers/user.dart';
import 'package:chest/util/helpers/widget_facto.dart';
import 'package:chest/main.dart';
import 'package:chest/tasks.dart';
import 'package:chest/util/helpers/pair.dart';
import 'package:chest/util/config.dart';
import 'package:chest/util/helpers/chest_marker.dart';
import 'package:chest/util/helpers/providers/dbpedia.dart';
import 'package:chest/util/helpers/providers/jcyl.dart';
import 'package:chest/util/helpers/providers/osm.dart';
import 'package:chest/util/helpers/providers/wikidata.dart';

class InfoFeature extends StatefulWidget {
  final Position? locationUser;
  final Widget? iconMarker;
  final String? shortId;

  const InfoFeature({
    required this.shortId,
    this.locationUser,
    this.iconMarker,
    super.key,
  });

  @override
  State<StatefulWidget> createState() => _InfoFeature();
}

class _InfoFeature extends State<InfoFeature>
    with SingleTickerProviderStateMixin {
  late Feature feature;
  late bool todoTexto, mostrarFabProfe, _requestTask;
  late LatLng? pointUser;
  late StreamSubscription<Position> _strLocationUser;
  late double distance;
  late String distanceString;
  final MapController mapController = MapController();
  List<Task> tasks = [];
  late List<String> tabs;
  late TabController _tabController;
  late Widget? _fab;

  @override
  void initState() {
    tabs = <String>['info', 'tasks', 'sources'];
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController.addListener(() {
      _updateFab(_tabController.index);
    });
    _fab = null;
    Feature? p = MapData.getFeatureCache(widget.shortId!);
    feature = p ?? Feature.empty(widget.shortId!);
    todoTexto = false;
    _requestTask = true;
    pointUser = (widget.locationUser != null && widget.locationUser is Position)
        ? LatLng(widget.locationUser!.latitude, widget.locationUser!.longitude)
        : null;
    mostrarFabProfe = Auxiliar.userCHEST.crol == Rol.teacher ||
        Auxiliar.userCHEST.crol == Rol.admin;
    distanceString = '';
    super.initState();
    if (p == null) {
      getFeature();
    }
  }

  @override
  void dispose() async {
    if (pointUser != null) {
      _strLocationUser.cancel();
    }
    _tabController.removeListener(() {
      _updateFab(_tabController.index);
    });
    _tabController.dispose();
    mapController.dispose();
    super.dispose();
  }

  Future<void> getFeature() async {
    await http
        .get(Queries().getFeatureInfo(widget.shortId!))
        .then((response) =>
            response.statusCode == 200 ? json.decode(response.body) : null)
        .then((providers) {
      if (providers != null) {
        for (Map provider in providers) {
          Map data = provider['data'];
          feature = Feature(data);
          feature.addProvider(provider['provider'], data);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error'),
          duration: Duration(milliseconds: 1500),
        ));
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/map');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _fab = widgetFab(index: _tabController.index);
    Size size = MediaQuery.of(context).size;
    double pLateral = size.width > Auxiliar.maxWidth
        ? (size.width - Auxiliar.maxWidth) / 2
        : 0;
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        floatingActionButton: _fab,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverOverlapAbsorber(
                handle:
                    NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: widgetAppbar(size, innerBoxIsScrolled),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: tabs.map(
              (String name) {
                return SafeArea(
                  top: false,
                  bottom: false,
                  minimum: EdgeInsets.symmetric(
                      horizontal: size.width < 600
                          ? Auxiliar.compactMargin
                          : Auxiliar.mediumMargin),
                  child: Builder(builder: (BuildContext context) {
                    return CustomScrollView(
                        key: PageStorageKey<String>(name),
                        slivers: [
                          SliverOverlapInjector(
                            handle:
                                NestedScrollView.sliverOverlapAbsorberHandleFor(
                                    context),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.only(
                                right: pLateral, left: pLateral),
                            sliver: name == tabs.elementAt(0)
                                ? widgetBody(size)
                                : name == tabs.elementAt(1)
                                    // ? widgetGridTasks(size)
                                    ? widgetListTasks(size)
                                    : fuentesInfo(),
                          ),
                        ]);
                  }),
                );
              },
            ).toList(),
          ),
        ),
      ),
    );
  }

  void _updateFab(int index) {
    setState(() {
      // _fab = widgetFab(index: index);
    });
  }

  Widget? widgetFab({int index = 0}) {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    switch (index) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Visibility(
              visible: !kIsWeb,
              child: FloatingActionButton.small(
                  heroTag: mostrarFabProfe ? null : Auxiliar.mainFabHero,
                  onPressed: () async => Auxiliar.share(
                      '${Config.addClient}/map/features/${feature.shortId}',
                      context),
                  child: const Icon(Icons.share)),
            ),
            Visibility(
              visible:
                  mostrarFabProfe && feature.author == Auxiliar.userCHEST.id,
              child: const SizedBox(
                height: 12,
              ),
            ),
            Visibility(
              visible:
                  mostrarFabProfe && feature.author == Auxiliar.userCHEST.id,
              child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: appLoca!.borrarPOI,
                  onPressed: () async => borraPoi(appLoca),
                  child: const Icon(Icons.delete)),
            ),
            Visibility(
              visible: mostrarFabProfe,
              child: const SizedBox(
                height: 24,
              ),
            ),
            Visibility(
              visible: mostrarFabProfe,
              child: FloatingActionButton.extended(
                heroTag: mostrarFabProfe ? null : null,
                tooltip: appLoca.editarPOI,
                onPressed: null,
                icon: const Icon(Icons.edit),
                label: Text(appLoca.editarPOI),
              ),
            ),
          ],
        );
      case 1:
        return mostrarFabProfe
            ? FloatingActionButton.extended(
                heroTag: Auxiliar.mainFabHero,
                tooltip: appLoca!.nTask,
                onPressed: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                      context,
                      MaterialPageRoute<Task>(
                          builder: (BuildContext context) =>
                              FormTask(Task.empty(feature.id)),
                          fullscreenDialog: true));
                },
                label: Text(appLoca.nTask),
                icon: const Icon(Icons.add))
            : null;
      default:
        return null;
    }
  }

  void borraPoi(AppLocalizations? appLoca) async {
    bool? borrarPoi = await Auxiliar.deleteDialog(
        context, appLoca!.borrarPOI, appLoca.preguntaBorrarPOI);
    if (borrarPoi != null && borrarPoi) {
      http.delete(Queries().deletePOI(feature.id), headers: {
        'Content-Type': 'application/json',
        'Authorization': Template('Bearer {{{token}}}').renderString({
          'token': await FirebaseAuth.instance.currentUser!.getIdToken(),
        })
      }).then((response) async {
        ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);
        switch (response.statusCode) {
          case 200:
            MapData.removeFeatureFromTile(feature);
            if (!Config.development) {
              await FirebaseAnalytics.instance.logEvent(
                name: "deletedFeature",
                parameters: {"iri": feature.shortId},
              ).then(
                (value) {
                  sMState.clearSnackBars();
                  sMState.showSnackBar(
                    SnackBar(
                        content: Text(
                      appLoca.poiBorrado,
                    )),
                  );
                  // Navigator.pop(context, true);
                  context.pop(true);
                },
              ).onError((error, stackTrace) {
                // print(error);
                sMState.clearSnackBars();
                sMState.showSnackBar(SnackBar(
                    content: Text(
                  appLoca.poiBorrado,
                )));
                Navigator.pop(context, true);
              });
            } else {
              sMState.clearSnackBars();
              sMState.showSnackBar(SnackBar(
                  content: Text(
                appLoca.poiBorrado,
              )));
              // Navigator.pop(context, true);
              context.pop(true);
            }
            break;
          default:
            sMState.clearSnackBars();
            sMState.showSnackBar(SnackBar(
                content: Text(
              appLoca.errorBorrarPoi,
            )));
        }
      });
    }
  }

  Widget widgetAppbar(Size size, bool fE) {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return SliverAppBar(
      title: Text(
        feature.labelLang(MyApp.currentLang) ??
            feature.labelLang('es') ??
            feature.labels.first.value,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        // textScaleFactor: 0.9,
        textScaler: const TextScaler.linear(0.9),
      ),
      titleTextStyle: Theme.of(context).textTheme.titleLarge,
      pinned: true,
      forceElevated: fE,
      bottom: TabBar(
        controller: _tabController,
        tabs: [
          Tab(text: appLoca!.infor),
          Tab(text: appLoca.tasks),
          Tab(text: appLoca.fuentes)
        ],
      ),
    );
  }

  Widget widgetImageRedu(Size size) {
    double mW = Auxiliar.maxWidth * 0.5;
    double mH = size.width > size.height ? size.height * 0.5 : size.height / 3;
    return Stack(
      alignment: AlignmentDirectional.bottomCenter,
      children: [
        Visibility(
          visible: feature.hasThumbnail,
          child: Center(
            child: feature.hasThumbnail
                ? ImageNetwork(
                    image: feature.thumbnail.image
                            .contains('commons.wikimedia.org')
                        ? Template(
                                '{{{wiki}}}?width={{{width}}}&height={{{height}}}')
                            .renderString({
                            "wiki": feature.thumbnail.image,
                            "width": size.width,
                            "height": size.height
                          })
                        : feature.thumbnail.image,
                    height: mH,
                    width: mW,
                    duration: 0,
                    fullScreen: false,
                    onPointer: true,
                    fitWeb: BoxFitWeb.cover,
                    fitAndroidIos: BoxFit.cover,
                    borderRadius: BorderRadius.circular(25),
                    curve: Curves.easeIn,
                    onTap: () async {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (BuildContext context) => FullScreenImage(
                                feature.thumbnail,
                                local: false),
                            fullscreenDialog: false),
                      );
                    },
                    onError: const Icon(Icons.image_not_supported),
                  )
                // ? Image.network(
                //     feature.thumbnail.image.contains('commons.wikimedia.org')
                //         ? Template(
                //                 '{{{wiki}}}?width={{{width}}}&height={{{height}}}')
                //             .renderString({
                //             "wiki": feature.thumbnail.image,
                //             "width": size.width,
                //             "height": size.height
                //           })
                //         : feature.thumbnail.image,
                //     loadingBuilder: (context, child, loadingProgress) =>
                //         loadingProgress != null
                //             ? const CircularProgressIndicator()
                //             : child,
                //     errorBuilder: (context, error, stackTrace) {
                //       return const SizedBox(height: 0);
                //     },
                //     frameBuilder:
                //         (context, child, frame, wasSynchronouslyLoaded) =>
                //             Stack(
                //       alignment: Alignment.topRight,
                //       children: [
                //         Padding(
                //           padding: const EdgeInsets.only(bottom: 10),
                //           child: ClipRRect(
                //             borderRadius: BorderRadius.circular(25),
                //             child: InkWell(
                // onTap: () async {
                //   Navigator.push(
                //     context,
                //     MaterialPageRoute<void>(
                //         builder: (BuildContext context) =>
                //             FullScreenImage(feature.thumbnail,
                //                 local: false),
                //         fullscreenDialog: false),
                //   );
                // },
                //                 child: child),
                //           ),
                //         ),
                //         Padding(
                //           padding: const EdgeInsets.all(5),
                //           child: IconButton(
                // onPressed: () async {
                //   Navigator.push(
                //     context,
                //     MaterialPageRoute<void>(
                //         builder: (BuildContext context) =>
                //             FullScreenImage(feature.thumbnail,
                //                 local: false),
                //         fullscreenDialog: false),
                //   );
                // },
                //             icon: const Icon(Icons.fullscreen),
                //             tooltip: AppLocalizations.of(context)!
                //                 .pantallaCompleta,
                //           ),
                //           // color: Colors.white,
                //         ),
                //       ],
                //     ),
                //     fit: BoxFit.cover,
                //   )
                : null,
          ),
        ),
        widgetBICCyL()
      ],
    );
  }

  Widget widgetImage(Size size) {
    return SliverVisibility(
      visible: feature.hasThumbnail,
      sliver: SliverPadding(
        padding: const EdgeInsets.all(10),
        sliver: SliverList(
          delegate: SliverChildListDelegate(
            [
              Center(
                child: Container(
                  constraints: BoxConstraints(
                      maxWidth: Auxiliar.maxWidth / 2,
                      maxHeight: size.height / 3),
                  child: feature.hasThumbnail
                      ? Image.network(
                          feature.thumbnail.image
                                  .contains('commons.wikimedia.org')
                              ? Template(
                                      '{{{wiki}}}?width={{{width}}}&height={{{height}}}')
                                  .renderString({
                                  "wiki": feature.thumbnail.image,
                                  "width": size.width,
                                  "height": size.height
                                })
                              : feature.thumbnail.image,
                          loadingBuilder: (context, child, loadingProgress) =>
                              loadingProgress != null
                                  ? const CircularProgressIndicator()
                                  : child,
                          frameBuilder:
                              (context, child, frame, wasSynchronouslyLoaded) =>
                                  Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: InkWell(
                                    onTap: () async {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                            builder: (BuildContext context) =>
                                                FullScreenImage(
                                                    feature.thumbnail,
                                                    local: false),
                                            fullscreenDialog: false),
                                      );
                                    },
                                    child: child),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(5),
                                child: IconButton(
                                  onPressed: () async {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (BuildContext context) =>
                                              FullScreenImage(feature.thumbnail,
                                                  local: false),
                                          fullscreenDialog: false),
                                    );
                                  },
                                  icon: const Icon(Icons.fullscreen),
                                  tooltip: AppLocalizations.of(context)!
                                      .pantallaCompleta,
                                ),
                                // color: Colors.white,
                              ),
                            ],
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget widgetMapa() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    MapOptions mapOptions = (pointUser != null)
        ? MapOptions(
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? Colors.white54
                : Colors.black54,
            maxZoom: Auxiliar.maxZoom,
            initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds(pointUser!, feature.point),
                padding: const EdgeInsets.all(30)),
            // boundsOptions: const FitBoundsOptions(padding: EdgeInsets.all(30)),
            // interactiveFlags:
            //     InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
            // interactiveFlags: InteractiveFlag.none,
            // enableScrollWheel: false,
            interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none, enableScrollWheel: false),
          )
        : MapOptions(
            initialZoom: 17,
            maxZoom: Auxiliar.maxZoom,
            // interactiveFlags:
            //     InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
            interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none, enableScrollWheel: false),
            // interactiveFlags: InteractiveFlag.none,
            // enableScrollWheel: false,
            initialCenter: feature.point,
          );
    List<Polyline> polylines = (pointUser != null)
        ? [
            Polyline(
              isDotted: true,
              points: [pointUser!, feature.point],
              gradientColors: [
                colorScheme.tertiary,
                colorScheme.tertiaryContainer,
              ],
              strokeWidth: 5,
            )
          ]
        : [Polyline(points: [])];
    Marker markerPoi = Marker(
      width: 48,
      height: 48,
      point: feature.point,
      child: widget.iconMarker != null
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                border: Border.all(
                  color: colorScheme.primary,
                  width: 2,
                ),
                color: colorScheme.primaryContainer,
              ),
              child: widget.iconMarker!)
          : Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: colorScheme.primary),
            ),
    );
    List<Marker> markers = pointUser != null
        ? [
            markerPoi,
            Marker(
              //user
              width: 24,
              height: 24,
              point: pointUser!,
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: colorScheme.tertiary),
              ),
            ),
            Marker(
              //Distancia
              width: 60,
              height: 20,
              point: LatLng(
                ((max(feature.lat, pointUser!.latitude) -
                            min(feature.lat, pointUser!.latitude)) /
                        2) +
                    min(feature.lat, pointUser!.latitude),
                ((max(feature.long, pointUser!.longitude) -
                            min(feature.long, pointUser!.longitude)) /
                        2) +
                    min(feature.long, pointUser!.longitude),
              ),
              child: Container(
                decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    // border: Border.all(
                    //     color: colorScheme.onPrimaryContainer, width: 1),
                    borderRadius: BorderRadius.circular(2)),
                child: Center(
                  child: Text(
                    distanceString,
                    // style: const TextStyle(color: Colors.black, fontSize: 12),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(color: colorScheme.onPrimaryContainer),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
              ),
            )
          ]
        : [markerPoi];
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: FlutterMap(
          mapController: mapController,
          options: mapOptions,
          children: [
            Auxiliar.tileLayerWidget(brightness: Theme.of(context).brightness),
            PolylineLayer(polylines: polylines),
            Auxiliar.atributionWidget(),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }

  Widget widgetListTasks(Size size) {
    // double pLateral = size.width > Auxiliar.maxWidth
    //     ? (size.width - Auxiliar.maxWidth) / 2
    //     : 0;
    if (_requestTask) {
      return SliverPadding(
          padding: const EdgeInsets.only(bottom: 80),
          sliver: tasks.isEmpty
              ? FutureBuilder<List>(
                  future: _getTasks(feature.shortId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && !snapshot.hasError) {
                      // tasks.add(Task({
                      //   'task': 'task0',
                      //   'comment': {
                      //     'value': 'Descripción de la tarea',
                      //     'lang': 'es'
                      //   },
                      //   'author': 'yo',
                      //   'at': 'http://chest.gsic.uva.es/ontology/photo',
                      //   'space':
                      //       'http://chest.gsic.uva.es/ontology/PhysicalSpace',
                      // }, feature.id));
                      // tasks.add(Task({
                      //   'task': 'task1',
                      //   'comment': {
                      //     'value': 'Descripción de la tarea 2',
                      //     'lang': 'es'
                      //   },
                      //   'author': 'yo',
                      //   'at': 'http://chest.gsic.uva.es/ontology/tf',
                      //   'space':
                      //       'http://chest.gsic.uva.es/ontology/VirtualSpace',
                      //   'correct': true
                      // }, feature.id));
                      // tasks.add(Task({
                      //   'task': 'task2',
                      //   'comment': {
                      //     'value': 'Descripción de la tarea 3',
                      //     'lang': 'es'
                      //   },
                      //   'author': 'yo',
                      //   'at': 'http://chest.gsic.uva.es/ontology/mcq',
                      //   'space':
                      //       'http://chest.gsic.uva.es/ontology/PhysicalSpace',
                      //   'singleSelection': true,
                      //   'correct': {
                      //     'value': 'Esta es la correcta',
                      //     'lang': 'es'
                      //   },
                      //   'distractor': [
                      //     {'value': 'Esta es la incorrecta0', 'lang': 'es'},
                      //     {'value': 'Esta es la incorrecta2', 'lang': 'es'}
                      //   ],
                      // }, feature.id));
                      // return _listTasks(size);
                      List<dynamic>? data = snapshot.data;
                      if (data != null && data.isNotEmpty) {
                        for (var t in data) {
                          try {
                            Task task = Task(t, feature.id);

                            bool noRealizada = true;
                            for (var answer in Auxiliar.userCHEST.answers) {
                              if (answer.hasPoi &&
                                  answer.idPoi == task.idFeature &&
                                  answer.hasTask &&
                                  answer.idTask == task.id) {
                                noRealizada = false;
                                break;
                              }
                            }
                            if (noRealizada) {
                              tasks.add(task);
                            }
                          } catch (error) {
                            debugPrint(error.toString());
                          }
                        }
                        return _listTasks(size);
                      } else {
                        return SliverList(
                          delegate: SliverChildListDelegate([
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child:
                                  Text(AppLocalizations.of(context)!.sinTareas),
                            ),
                          ]),
                        );
                      }
                    } else {
                      if (snapshot.hasError) {
                        return SliverList(
                          delegate: SliverChildListDelegate([
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child:
                                  Text(AppLocalizations.of(context)!.sinTareas),
                            ),
                          ]),
                        );
                      } else {
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                              (context, index) => const Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  ),
                              childCount: 1),
                        );
                      }
                    }
                  },
                )
              : _listTasks(size));
    } else {
      _requestTask = true;
      return SliverList(delegate: SliverChildListDelegate([]));
    }
  }

  Widget _listTasks(Size size) {
    return SliverPadding(
      padding: const EdgeInsets.all(8.0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          ThemeData td = Theme.of(context);
          ColorScheme colorSheme = td.colorScheme;
          TextTheme textTheme = td.textTheme;
          AppLocalizations? appLoca = AppLocalizations.of(context);
          ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);

          Task task = tasks.elementAt(index);
          String title = task.hasLabel
              ? task.labelLang(MyApp.currentLang) ??
                  task.labelLang('es') ??
                  task.labels.first.value
              : Auxiliar.getLabelAnswerType(
                  AppLocalizations.of(context), task.aT);
          String comment = (task.commentLang(MyApp.currentLang) ??
                  task.commentLang('es') ??
                  task.comments.first.value)
              .replaceAll(
                  RegExp('<[^>]*>?', multiLine: true, dotAll: true), '');

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: colorSheme.outline,
                ),
                borderRadius: const BorderRadius.all(Radius.circular(12))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                      padding: const EdgeInsets.only(
                          top: 24, bottom: 16, right: 16, left: 16),
                      child: Wrap(
                          spacing: 4,
                          children: task.spaces.map((Space space) {
                            switch (space) {
                              case Space.physical:
                                return const Icon(Icons.mobile_friendly,
                                    size: 18);
                              case Space.virtual:
                                return const Icon(Icons.map, size: 18);
                              case Space.web:
                                return const Icon(Icons.web, size: 18);
                              default:
                                return Container();
                            }
                          }).toList())),
                ),
                Container(
                  padding:
                      const EdgeInsets.only(bottom: 16, right: 16, left: 16),
                  width: double.infinity,
                  child: Text(
                    title,
                    style: textTheme.titleLarge!
                        .copyWith(color: colorSheme.onSecondaryContainer),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(comment.replaceAll(RegExp('<[^>]*>'), '')),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                        top: 16, bottom: 8, right: 16, left: 16),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      children: mostrarFabProfe
                          ? Auxiliar.userCHEST.id == task.author
                              ? [
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      bool? borrarLista =
                                          await Auxiliar.deleteDialog(
                                              context,
                                              appLoca!.borrar,
                                              appLoca.preguntaBorrarTarea);
                                      if (borrarLista != null && borrarLista) {
                                        dynamic tareaBorrada =
                                            await _deleteTask(task.id);
                                        if (tareaBorrada is bool) {
                                          if (tareaBorrada) {
                                            showSnackTaskDelete(false);
                                            setState(() {
                                              tasks.removeWhere(
                                                  (t) => t.id == task.id);
                                              if (tasks.isEmpty) {
                                                _requestTask = false;
                                              }
                                            });
                                          } else {
                                            showSnackTaskDelete(true);
                                          }
                                        } else {
                                          showSnackTaskDelete(true);
                                        }
                                      }
                                    },
                                    child: Text(appLoca!.borrar),
                                  ),
                                  TextButton(
                                    // TODO
                                    onPressed: null,
                                    child: Text(appLoca.editar),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      // Navigator.push(
                                      //   context,
                                      //   MaterialPageRoute<void>(
                                      //     builder: (BuildContext context) =>
                                      //         COTask(
                                      //       shortIdFeature: feature.shortId,
                                      //       shortIdTask:
                                      //           Auxiliar.id2shortId(task.id)!,
                                      //       answer: null,
                                      //       preview: true,
                                      //     ),
                                      //     fullscreenDialog: true,
                                      //   ),
                                      // );
                                      context.go(
                                          '/map/features/${feature.shortId}/tasks/${Auxiliar.id2shortId(task.id)}',
                                          extra: [
                                            null,
                                            null,
                                            null,
                                            true,
                                            false
                                          ]);
                                    },
                                    child: Text(appLoca.vistaPrevia),
                                  )
                                ]
                              : [
                                  FilledButton(
                                    onPressed: () {
                                      // Navigator.push(
                                      //   context,
                                      //   MaterialPageRoute<void>(
                                      //     builder: (BuildContext context) =>
                                      //         COTask(
                                      //       shortIdFeature: feature.shortId,
                                      //       shortIdTask:
                                      //           Auxiliar.id2shortId(task.id)!,
                                      //       answer: null,
                                      //       preview: true,
                                      //     ),
                                      //     fullscreenDialog: true,
                                      //   ),
                                      // );
                                      context.go(
                                          '/map/features/${feature.shortId}/tasks/${Auxiliar.id2shortId(task.id)}',
                                          extra: [
                                            null,
                                            null,
                                            null,
                                            true,
                                            false
                                          ]);
                                    },
                                    child: Text(appLoca!.vistaPrevia),
                                  )
                                ]
                          : [
                              FilledButton(
                                onPressed: () async {
                                  bool startTask = true;

                                  if (task.spaces.length == 1 &&
                                      task.spaces.first == Space.physical) {
                                    if (pointUser != null) {
                                      //TODO 200
                                      if (distance > 200) {
                                        startTask = false;
                                        sMState.clearSnackBars();
                                        sMState.showSnackBar(
                                          SnackBar(
                                            backgroundColor:
                                                colorSheme.errorContainer,
                                            content: Text(
                                              appLoca!.acercate,
                                              style: textTheme.bodyMedium!
                                                  .copyWith(
                                                color:
                                                    colorSheme.onErrorContainer,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      startTask = false;
                                      sMState.clearSnackBars();
                                      sMState.showSnackBar(
                                        SnackBar(
                                          content:
                                              Text(appLoca!.activaLocalizacion),
                                          duration: const Duration(seconds: 8),
                                          action: SnackBarAction(
                                            label: appLoca.activar,
                                            onPressed: () =>
                                                checkUserLocation(),
                                          ),
                                        ),
                                      );
                                    }
                                  }

                                  if (startTask) {
                                    if (pointUser != null) {
                                      _strLocationUser.cancel();
                                      pointUser = null;
                                    }
                                    if (!Config.development) {
                                      FirebaseAnalytics.instance.logEvent(
                                        name: "seenTask",
                                        parameters: {
                                          "iri": Auxiliar.id2shortId(task.id)!,
                                        },
                                      );
                                    }
                                    // Navigator.pop(context);
                                    // Navigator.push(
                                    //   context,
                                    //   MaterialPageRoute<void>(
                                    //     builder: (BuildContext context) =>
                                    //         COTask(
                                    //       shortIdFeature: feature.shortId,
                                    //       shortIdTask:
                                    //           Auxiliar.id2shortId(task.id)!,
                                    //       answer: null,
                                    //     ),
                                    //     fullscreenDialog: true,
                                    //   ),
                                    // );
                                    // TODO recuperar si se ha realizado la tarea, y si es así, pintar la nueva lista
                                    context.go(
                                        '/map/features/${feature.shortId}/tasks/${Auxiliar.id2shortId(task.id)}',
                                        extra: [
                                          null,
                                          null,
                                          null,
                                          false,
                                          startTask
                                        ]);
                                  }
                                },
                                child: Text(appLoca!.realizaTareaBt),
                              )
                            ],
                    ),
                  ),
                )
              ],
            ),
          );
        }, childCount: tasks.length),
      ),
    );
  }

  void showSnackTaskDelete(bool error) {
    ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);
    ThemeData td = Theme.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    sMState.clearSnackBars();
    sMState.showSnackBar(
      SnackBar(
        backgroundColor: error ? td.colorScheme.errorContainer : null,
        content: Text(
          error ? appLoca!.errorBorrarTask : appLoca!.tareaBorrada,
          style: td.textTheme.bodyMedium!.copyWith(
            color: error ? td.colorScheme.onErrorContainer : null,
          ),
        ),
      ),
    );
  }

  Future<dynamic> _deleteTask(String id) async {
    String shortIdTask = Auxiliar.id2shortId(id)!;
    return http
        .delete(Queries().deleteTask(feature.shortId, shortIdTask), headers: {
      'Content-Type': 'application/json',
      'Authorization': Template('Bearer {{{token}}}').renderString({
        'token': await FirebaseAuth.instance.currentUser!.getIdToken(),
      })
    }).then((response) async {
      if (response.statusCode == 200) {
        if (!Config.development) {
          await FirebaseAnalytics.instance.logEvent(
            name: "deletedTask",
            parameters: {"iri": shortIdTask},
          );
        }
        return true;
      } else {
        return response.body;
      }
    }).onError((error, stackTrace) => false);
  }

  Future<List> _getTasks(id) {
    return http.get(Queries().getTasks(id)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  void checkUserLocation() async {
    _strLocationUser = Geolocator.getPositionStream(
            locationSettings: await Auxiliar.checkPermissionsLocation(
                context, defaultTargetPlatform))
        .listen((Position? position) {
      if (position != null) {
        if (mounted) {
          setState(() {
            pointUser = LatLng(position.latitude, position.longitude);
          });
          mapController.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds(pointUser!, feature.point),
            padding: const EdgeInsets.all(30),
          ));
          calculateDistance();
        }
      }
    }, cancelOnError: true);
  }

  void calculateDistance() {
    if (mounted) {
      // setState(() {
      distance = Auxiliar.distance(feature.point, pointUser!);
      distanceString = distance < Auxiliar.maxWidth
          ? Template('{{{metros}}}m')
              .renderString({"metros": distance.toInt().toString()})
          : Template('{{{km}}}km').renderString(
              {"km": (distance / Auxiliar.maxWidth).toStringAsFixed(2)});
      // });
    }
  }

  Widget _cuerpo(Size size) {
    List<PairLang> allComments = feature.comments;
    List<PairLang> comments = [];
    // Prioridad a la información en el idioma del usuario
    for (PairLang comment in allComments) {
      if (comment.hasLang && comment.lang == MyApp.currentLang) {
        comments.add(comment);
      }
    }
    // Si no hay información en su idioma se le ofrece en inglés
    if (comments.isEmpty) {
      for (PairLang comment in allComments) {
        if (comment.hasLang && comment.lang == 'en') {
          comments.add(comment);
        }
      }
    }
    // Si tampoco se tiene en inglés se le pasa el primer comentario disponible
    if (comments.isEmpty) {
      comments.add(allComments.first);
    }
    if (comments.length > 1) {
      comments.sort(
          (PairLang a, PairLang b) => b.value.length.compareTo(a.value.length));
    }
    PairLang comment = comments.first;
    return SliverList(
      delegate: SliverChildListDelegate(
        [
          widgetImageRedu(size),
          Container(
            padding: const EdgeInsets.only(top: 10, bottom: 15),
            child: todoTexto
                ? HtmlWidget(
                    comment.value,
                    factoryBuilder: () => MyWidgetFactory(),
                  )
                : InkWell(
                    onTap: () => setState(() => todoTexto = true),
                    child: Text(
                      comment.value.replaceAll(RegExp('<[^>]*>'), ''),
                      maxLines: 7,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
          ),
          widgetMapa(),
        ],
      ),
    );
  }

  Widget widgetBody(Size size) {
    if (widget.locationUser != null && widget.locationUser is Position) {
      checkUserLocation();
      calculateDistance();
    }
    return SliverPadding(
      padding: const EdgeInsets.only(
        top: 20,
        bottom: 80,
      ),
      sliver: feature.ask4Resource
          ? _cuerpo(size)
          : FutureBuilder<List>(
              future: _getInfoPoi(feature.shortId),
              builder: (context, snapshot) {
                if (snapshot.hasData && !snapshot.hasError) {
                  for (int i = 0, tama = snapshot.data!.length; i < tama; i++) {
                    Map provider = snapshot.data![i];
                    Map<String, dynamic>? data = provider['data'];
                    switch (provider["provider"]) {
                      case 'osm':
                        OSM osm = OSM(data);
                        for (PairLang l in osm.labels) {
                          feature.addLabelLang(l);
                        }
                        if (osm.image != null) {
                          feature.setThumbnail(
                              osm.image!.image,
                              osm.image!.hasLicense
                                  ? osm.image!.license
                                  : null);
                        }
                        for (PairLang d in osm.descriptions) {
                          feature.addCommentLang(d);
                        }
                        feature.addProvider(provider['provider'], osm);
                        break;
                      case 'wikidata':
                        Wikidata? wikidata = Wikidata(data);
                        for (PairLang label in wikidata.labels) {
                          feature.addLabelLang(label);
                        }
                        for (PairLang comment in wikidata.descriptions) {
                          feature.addCommentLang(comment);
                        }
                        for (PairImage image in wikidata.images) {
                          feature.addImage(image.image,
                              license: image.hasLicense ? image.license : null);
                        }
                        feature.addProvider(provider['provider'], wikidata);
                        break;
                      case 'jcyl':
                        JCyL jcyl = JCyL(data);
                        feature.addCommentLang(jcyl.description);
                        feature.addProvider(provider['provider'], jcyl);
                        break;
                      case 'esDBpedia':
                      case 'dbpedia':
                        DBpedia dbpedia = DBpedia(data, provider['provider']);
                        for (PairLang comment in dbpedia.descriptions) {
                          feature.addCommentLang(comment);
                        }
                        for (PairLang label in dbpedia.labels) {
                          feature.addLabelLang(label);
                        }
                        feature.addProvider(provider['provider'], dbpedia);
                        break;
                      default:
                    }
                  }
                  feature.ask4Resource = true;
                  feature.ask4Resource = MapData.updateFeatureCache(feature);
                  return _cuerpo(size);
                } else {
                  if (snapshot.hasError) {
                    return SliverList(delegate: SliverChildListDelegate([]));
                  } else {
                    return SliverList(
                      delegate: SliverChildListDelegate(
                          [const Center(child: CircularProgressIndicator())]),
                    );
                  }
                }
              }),
    );
  }

  Future<List> _getInfoPoi(idFeature) {
    return http.get(Queries().getFeatureInfo(idFeature)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Widget widgetBICCyL() {
    Object? obj = feature.getProvider('jcyl');
    if (obj != null) {
      Provider jcyl = obj as Provider;
      return Center(
        child: FilledButton.icon(
          onPressed: () async {
            if (!await launchUrl(Uri.parse(jcyl.data.url))) {
              debugPrint('Url jcyl problem!');
            }
          },
          label: Text(AppLocalizations.of(context)!.bicCyL),
          icon: const Icon(Icons.favorite),
        ),
      );
    }
    return Container();
  }

  Widget widgetGoTo() {
    // AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Map<String, dynamic>> goto = [
      // {
      //   'key': datakeyFuentes,
      //   'textBt': appLoca!.fuentesInfo,
      // }
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.spaceAround,
        runAlignment: WrapAlignment.center,
        children: List<OutlinedButton>.generate(goto.length, (int index) {
          Map<String, dynamic> gt = goto.elementAt(index);
          return OutlinedButton(
            child: Text(gt['textBt']),
            onPressed: () async => Scrollable.ensureVisible(
              gt['key'].currentContext!,
              duration: const Duration(milliseconds: 200),
            ),
          );
        }),
      ),
    );
  }

  OutlinedButton _fuentesInfoBt(
    String nameSource,
    Map<String, dynamic> infoMap,
  ) {
    switch (nameSource) {
      case 'osm':
        nameSource = 'OpenStreetMap';
        break;
      case 'wikidata':
        nameSource = 'Wikidata';
        break;
      case 'jcyl':
        nameSource = 'JCyL';
        break;
      case 'dbpedia':
        nameSource = 'DBpedia';
        break;
      case 'esDBpedia':
        nameSource = 'es.DBpedia';
        break;
      default:
    }
    return OutlinedButton(
      onPressed: () => showDialog(
          context: context,
          builder: (context) {
            ThemeData td = Theme.of(context);
            TextStyle? bodyMedium = td.textTheme.bodyMedium;
            ColorScheme colorScheme = td.colorScheme;
            List<Widget> lst = [];
            for (String k in infoMap.keys) {
              lst.add(ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: SelectableText(
                      '$k: ${infoMap[k]}',
                      style: bodyMedium!
                          .copyWith(color: colorScheme.onPrimaryContainer),
                    ),
                  ),
                ),
              ));
            }
            return AlertDialog(
              scrollable: true,
              actions: [
                TextButton(
                  child: const Text('Ok'),
                  onPressed: () => Navigator.pop(context),
                )
              ],
              title: Text(nameSource),
              content: Wrap(
                alignment: WrapAlignment.start,
                spacing: 8,
                runSpacing: 4,
                children: lst,
              ),
            );
          }),
      child: Text(nameSource),
    );
  }

  Widget fuentesInfo() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> lstSources = [];
    for (Provider ele in feature.providers) {
      lstSources.add(_fuentesInfoBt(ele.id, ele.data.toSourceInfo()));
    }
    String cLabel = feature.labelLang(MyApp.currentLang) ??
        feature.labelLang('es') ??
        feature.labels.first.value;
    List<PairLang> allComments = feature.comments;
    List<PairLang> comments = [];
    // Prioridad a la información en el idioma del usuario
    for (PairLang comment in allComments) {
      if (comment.hasLang && comment.lang == MyApp.currentLang) {
        comments.add(comment);
      }
    }
    // Si no hay información en su idioma se le ofrece en inglés
    if (comments.isEmpty) {
      for (PairLang comment in allComments) {
        if (comment.hasLang && comment.lang == 'en') {
          comments.add(comment);
        }
      }
    }
    // Si tampoco se tiene en inglés se le pasa el primer comentario disponible
    if (comments.isEmpty) {
      comments.add(allComments.first);
    }
    if (comments.length > 1) {
      comments.sort(
          (PairLang a, PairLang b) => b.value.length.compareTo(a.value.length));
    }
    String cComment = comments.first.value;

    bool mainProvOSM = true;
    bool imgWikidata = false;
    bool isBic = false;
    String? labelSource, commentSource;
    for (Provider provider in feature.providers) {
      switch (provider.id) {
        case 'osm':
          OSM data = provider.data;
          for (PairLang pl in data.labels) {
            if (pl.value == cLabel) {
              labelSource = 'OpenStreetMap';
            }
          }
          for (PairLang pl in data.labels) {
            if (pl.value == cComment) {
              commentSource = 'OpenStreetMap';
            }
          }
          break;
        case 'wikidata':
          Wikidata data = provider.data;
          imgWikidata = feature.hasThumbnail && data.images.isNotEmpty;
          for (PairLang pl in data.labels) {
            if (pl.value == cLabel) {
              labelSource = 'Wikidata';
            }
          }
          for (PairLang pl in data.descriptions) {
            if (pl.value == cComment) {
              commentSource = 'Wikidata';
            }
          }
          isBic = data.idBIC != null;
          break;
        case 'esDBpedia':
          DBpedia data = provider.data;
          for (PairLang pl in data.labels) {
            if (pl.value == cLabel) {
              labelSource = 'es.DBpedia';
            }
          }
          for (PairLang pl in data.descriptions) {
            if (pl.value == cComment) {
              commentSource = 'es.DBpedia';
            }
          }

          break;
        case 'dbpedia':
          DBpedia data = provider.data;
          for (PairLang pl in data.labels) {
            if (pl.value == cLabel) {
              labelSource = 'DBpedia';
            }
          }
          for (PairLang pl in data.descriptions) {
            if (pl.value == cComment) {
              commentSource = 'DBpedia';
            }
          }
          break;
        case 'jcyl':
          JCyL data = provider.data;
          if (data.label.value == cLabel) {
            labelSource = appLoca!.gobcyl;
          }
          if (data.description.value == cComment) {
            commentSource = appLoca!.gobcyl;
          }
          break;
        case 'chest':
          mainProvOSM = false;
          break;
        default:
      }
      if (feature.hasThumbnail) {
        if (provider.id == 'wikidata' &&
            (provider.data as Wikidata).images.isNotEmpty) {
          imgWikidata = true;
        }
      }
    }
    List<Widget> lstTextoFuentes = [
      Text('${appLoca!.obtLbl} $labelSource.'),
      feature.hasThumbnail
          ? Text(
              '${appLoca.obtImg} ${imgWikidata ? 'Wikidata' : 'OpenStreetMap'}.')
          : Container(),
      isBic ? Text('${appLoca.obtBic}.') : Container(),
      isBic ? Text('${appLoca.obtEnlBic} ${appLoca.gobcyl}.') : Container(),
      Text('${appLoca.obtCom} $commentSource.'),
      Text('${appLoca.obtCoor} ${mainProvOSM ? 'OpenStreetMap' : 'CHEST'}.'),
    ];
    if (feature.hasThumbnail) {
      // Wikidata or OSM?
    }
    List<Widget> lst = [
      // Título:
      Text(
        AppLocalizations.of(context)!.fuentesInfo,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      // Frases:
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Auxiliar.mediumMargin,
          vertical: Auxiliar.compactMargin,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lstTextoFuentes,
        ),
      ),
      // Fuentes:
      Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          child: Wrap(
            runAlignment: WrapAlignment.spaceEvenly,
            alignment: WrapAlignment.center,
            runSpacing: Auxiliar.compactMargin / 2,
            spacing: Auxiliar.compactMargin,
            children: lstSources,
          ),
        ),
      ),
    ];

    return SliverPadding(
      padding: const EdgeInsets.only(
        top: 10,
        bottom: 80,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) => lst[index],
            childCount: lst.length),
      ),
    );
  }
}

class NewPoi extends StatefulWidget {
  final LatLng point;
  final LatLngBounds bounds;
  final List<Feature> cPois;
  const NewPoi(this.point, this.bounds, this.cPois, {super.key});

  @override
  State<StatefulWidget> createState() => _NewPoi();
}

class _NewPoi extends State<NewPoi> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(appLoca!.addPOI),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: const Icon(Icons.near_me), text: appLoca.poiCercanos),
              Tab(icon: const Icon(Icons.public), text: appLoca.basadosLOD),
              Tab(icon: const Icon(Icons.draw), text: appLoca.sinAyuda),
            ],
          ),
        ),
        body: TabBarView(
            children: [widgetNearPois(), widgetLODPois(), widgetPoiNew()]),
      ),
    );
  }

  Widget widgetNearPois() {
    Size size = MediaQuery.of(context).size;
    //Solo voy a mostrar los 20 primeros POI ordenados por distancia
    List<Map<String, dynamic>> pois = [];
    for (Feature poi in widget.cPois) {
      Map<String, dynamic> a = {
        "distance": Auxiliar.distance(widget.point, poi.point),
        "poi": poi
      };
      a["distanceString"] = a["distance"] < 1000
          ? Template('{{{metros}}} m')
              .renderString({"metros": a["distance"].toInt().toString()})
          : Template('{{{km}}} km')
              .renderString({"km": (a["distance"] / 1000).toStringAsFixed(2)});

      pois.add(a);
    }
    pois.sort((Map<String, dynamic> a, Map<String, dynamic> b) =>
        a["distance"].compareTo(b["distance"]));
    pois = pois.getRange(0, min(pois.length, 20)).toList();

    AppLocalizations? appLoca = AppLocalizations.of(context);
    return SafeArea(
      minimum: const EdgeInsets.all(10),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 10),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  Center(
                    child: Container(
                      constraints:
                          const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                      child: Text(appLoca!.puntosYaExistentesEx),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              childCount: pois.length,
              (context, index) {
                Feature poi = pois[index]["poi"];
                String distanceSrting = pois[index]["distanceString"];
                ColorScheme colorScheme = Theme.of(context).colorScheme;
                return Center(
                  child: Container(
                    height: 150,
                    constraints:
                        const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    child: Card(
                      child: Stack(
                        children: [
                          poi.hasThumbnail
                              ? SizedBox.expand(
                                  child: Image.network(
                                    poi.thumbnail.image
                                            .contains('commons.wikimedia.org')
                                        ? Template(
                                                '{{{wiki}}}?width={{{width}}}&height={{{height}}}')
                                            .renderString(
                                            {
                                              "wiki": poi.thumbnail.image,
                                              "width": size.width >
                                                      Auxiliar.maxWidth
                                                  ? 800
                                                  : max(150, size.width - 100),
                                              "height": size.height >
                                                      Auxiliar.maxWidth
                                                  ? 800
                                                  : max(150, size.height - 100)
                                            },
                                          )
                                        : poi.thumbnail.image,
                                    color: Colors.black38,
                                    colorBlendMode: BlendMode.darken,
                                    loadingBuilder:
                                        (context, child, loadingProgress) =>
                                            ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                          height: 150,
                                          color: colorScheme.primaryContainer,
                                          child: child),
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, obj, stack) =>
                                        ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        height: 150,
                                        color: colorScheme.primaryContainer,
                                      ),
                                    ),
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 150,
                                    color: colorScheme.primaryContainer,
                                  ),
                                ),
                          SizedBox(
                            width: Auxiliar.maxWidth,
                            height: 150,
                            child: ListTile(
                              textColor: poi.hasThumbnail
                                  ? Colors.white
                                  : colorScheme.onPrimaryContainer,
                              title: Text(
                                poi.labelLang(MyApp.currentLang) ??
                                    poi.labelLang('es') ??
                                    poi.labels.first.value,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(distanceSrting),
                              onTap: () async {
                                if (!Config.development) {
                                  await FirebaseAnalytics.instance.logEvent(
                                    name: "seenFeature",
                                    parameters: {"iri": poi.shortId},
                                  ).then(
                                    (value) {
                                      // Navigator.pop(context);
                                      // Navigator.push(
                                      //   context,
                                      //   MaterialPageRoute<void>(
                                      //       builder: (BuildContext context) =>
                                      //           InfoPOI(poi),
                                      //       fullscreenDialog: false),
                                      // );
                                      context.pop();
                                      context.push<bool>(
                                          '/features/${poi.shortId}');
                                    },
                                  ).onError((error, stackTrace) {
                                    // print(error);
                                    // Navigator.pop(context);
                                    // Navigator.push(
                                    //   context,
                                    //   MaterialPageRoute<void>(
                                    //       builder: (BuildContext context) =>
                                    //           InfoPOI(poi),
                                    //       fullscreenDialog: false),
                                    // );
                                    context.pop();
                                    context
                                        .push<bool>('/features/${poi.shortId}');
                                  });
                                } else {
                                  // Navigator.pop(context);
                                  // Navigator.push(
                                  //   context,
                                  //   MaterialPageRoute<void>(
                                  //       builder: (BuildContext context) =>
                                  //           InfoPOI(poi),
                                  //       fullscreenDialog: false),
                                  // );
                                  context.pop();
                                  context
                                      .push<bool>('/features/${poi.shortId}');
                                }
                              },
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget widgetLODPois() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    Size size = MediaQuery.of(context).size;
    return SafeArea(
      minimum: const EdgeInsets.all(10),
      child: CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              Center(
                child: Container(
                    constraints:
                        const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    child: Text(appLoca!.lodPoiEx)),
              ),
              const SizedBox(height: 10),
            ]),
          ),
          FutureBuilder<List>(
              future: _getPoisLod(widget.point, widget.bounds),
              builder: ((context, snapshot) {
                if (snapshot.hasData) {
                  List<Feature> pois = [];
                  List<dynamic> data = snapshot.data!;
                  for (var d in data) {
                    try {
                      d['author'] = Auxiliar.userCHEST.id;
                      // TODO Cambiar el segundo elemento por el shortId
                      d['shortId'] = Auxiliar.id2shortId(d['id']);
                      d['labels'] = d['label'];
                      d['long'] = d['lng'];
                      // TODO Cambiar por la fuente
                      d['source'] = d['id'];
                      Feature p = Feature(d);
                      // if (d['thumbnailImg'] != null &&
                      //     d['thumbnailImg'].toString().isNotEmpty) {
                      //   if (d['thumbnailLic'] != null &&
                      //       d['thumbnailLic'].toString().isNotEmpty) {
                      //     p.setThumbnail(d['thumbnailImg'], d['thumbnailLic']);
                      //   } else {
                      //     p.setThumbnail(d['thumbnailImg'], null);
                      //   }
                      // }
                      // p.source = d['id'];
                      // if (d['categories'] != null) {
                      //   p.categories = d['categories'];
                      // }
                      pois.add(p);
                    } catch (e) {
                      debugPrint(e.toString());
                    }
                  }
                  if (pois.isNotEmpty) {
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                          childCount: pois.length, (context, index) {
                        Feature p = pois[index];
                        ColorScheme colorScheme = Theme.of(context).colorScheme;
                        return Center(
                          child: Container(
                            height: 150,
                            constraints: const BoxConstraints(
                                maxWidth: Auxiliar.maxWidth),
                            child: Card(
                              child: Stack(
                                children: [
                                  p.hasThumbnail
                                      ? SizedBox.expand(
                                          child: Image.network(
                                            p.thumbnail.image.contains(
                                                    'commons.wikimedia.org')
                                                ? Template(
                                                        '{{{wiki}}}?width={{{width}}}&height={{{height}}}')
                                                    .renderString({
                                                    "wiki": p.thumbnail.image,
                                                    "width": size.width >
                                                            Auxiliar.maxWidth
                                                        ? 800
                                                        : max(150,
                                                            size.width - 100),
                                                    "height": size.height >
                                                            Auxiliar.maxWidth
                                                        ? 800
                                                        : max(150,
                                                            size.height - 100)
                                                  })
                                                : p.thumbnail.image,
                                            color: Colors.black38,
                                            colorBlendMode: BlendMode.darken,
                                            loadingBuilder: (context, child,
                                                    loadingProgress) =>
                                                ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                  color: colorScheme
                                                      .primaryContainer,
                                                  child: child),
                                            ),
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, obj, stack) =>
                                                ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                color: colorScheme
                                                    .primaryContainer,
                                              ),
                                            ),
                                          ),
                                        )
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                              color:
                                                  colorScheme.primaryContainer),
                                        ),
                                  SizedBox(
                                    width: Auxiliar.maxWidth,
                                    height: 150,
                                    child: ListTile(
                                      textColor: p.hasThumbnail
                                          ? Colors.white
                                          : colorScheme.onPrimaryContainer,
                                      title: Text(
                                        p.labelLang(MyApp.currentLang) ??
                                            p.labelLang('es') ??
                                            p.labels.first.value,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      onTap: () {
                                        Navigator.pop(context, p);
                                      },
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  } else {
                    return SliverList(delegate: SliverChildListDelegate([]));
                  }
                } else {
                  if (snapshot.hasError) {
                    return SliverList(delegate: SliverChildListDelegate([]));
                  } else {
                    return SliverList(
                      delegate: SliverChildListDelegate(
                          [const Center(child: CircularProgressIndicator())]),
                    );
                  }
                }
              })),
        ],
      ),
    );
  }

  Widget widgetPoiNew() {
    return SafeArea(
      minimum: const EdgeInsets.all(10),
      child: CustomScrollView(slivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            [
              Center(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: Text(AppLocalizations.of(context)!.nPoiEx),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      Feature.point(
                          widget.point.latitude, widget.point.longitude),
                    );
                  },
                  child: Text(AppLocalizations.of(context)!.addPOI),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Future<List> _getPoisLod(LatLng point, LatLngBounds bounds) {
    return http.get(Queries().getPoisLod(point, bounds)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }
}

class FormPOI extends StatefulWidget {
  final Feature _poi;

  const FormPOI(this._poi, {super.key});

  @override
  State<StatefulWidget> createState() => _FormPOI();
}

class _FormPOI extends State<FormPOI> {
  String? image, licenseImage;
  late String commentFeature;
  late GlobalKey<FormState> thisKey;
  late MapController mapController;
  late bool errorCommentFeature, focusQuillEditorController;
  // late HtmlEditorController htmlEditorController;
  late QuillEditorController quillEditorController;
  late List<ToolBarStyle> toolbarElements;
  late List<Marker> _markers;

  @override
  void initState() {
    thisKey = GlobalKey<FormState>();
    mapController = MapController();
    errorCommentFeature = false;
    // htmlEditorController = HtmlEditorController();
    commentFeature = '';
    _markers = [];
    quillEditorController = QuillEditorController();
    toolbarElements = Auxiliar.getToolbarElements();
    focusQuillEditorController = false;
    quillEditorController.onEditorLoaded(() {
      quillEditorController.unFocus();
      quillEditorController.setText('');
    });
    super.initState();
  }

  @override
  void dispose() {
    mapController.dispose();
    quillEditorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          title: Text(AppLocalizations.of(context)!.tNPoi),
          pinned: true,
        ),
        SliverPadding(padding: const EdgeInsets.all(10), sliver: formNP()),
        SliverVisibility(
          visible: widget._poi.categories.isNotEmpty,
          sliver: SliverPadding(
            padding: const EdgeInsets.all(10),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed(
                [
                  Center(
                    child: Container(
                      constraints:
                          const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppLocalizations.of(context)!.categories,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverVisibility(
          visible: widget._poi.categories.isNotEmpty,
          sliver: SliverPadding(
              padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
              sliver: categoriesNP()),
        ),
        SliverPadding(padding: const EdgeInsets.all(10), sliver: buttonNP())
      ]),
    );
  }

  Widget formNP() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ThemeData td = Theme.of(context);
    ColorScheme cS = td.colorScheme;
    Size size = MediaQuery.of(context).size;
    return SliverList(
      delegate: SliverChildListDelegate(
        [
          Form(
            key: thisKey,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      maxLines: 1,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: appLoca!.tituloNPI,
                          hintText: appLoca.tituloNPI,
                          helperText: appLoca.requerido,
                          hintMaxLines: 1,
                          hintStyle:
                              const TextStyle(overflow: TextOverflow.ellipsis)),
                      textCapitalization: TextCapitalization.words,
                      keyboardType: TextInputType.text,
                      initialValue: widget._poi.labels.isEmpty
                          ? ''
                          : widget._poi.labelLang(MyApp.currentLang) ??
                              widget._poi.labelLang('es') ??
                              widget._poi.labels.first.value,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return appLoca.tituloNPIExplica;
                        } else {
                          widget._poi
                              .addLabelLang(PairLang(MyApp.currentLang, value));
                          return null;
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(4)),
                        border: Border.fromBorderSide(
                          BorderSide(
                              color: errorCommentFeature
                                  ? cS.error
                                  : focusQuillEditorController
                                      ? cS.primary
                                      : td.disabledColor,
                              width: focusQuillEditorController ? 2 : 1),
                        ),
                        color: cS.surface,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              appLoca.descrNPI,
                              style: td.textTheme.bodySmall!.copyWith(
                                color: errorCommentFeature
                                    ? cS.error
                                    : focusQuillEditorController
                                        ? cS.primary
                                        : td.disabledColor,
                              ),
                            ),
                          ),
                          QuillHtmlEditor(
                            controller: quillEditorController,
                            hintText: '',
                            minHeight: size.height * 0.2,
                            isEnabled: true,
                            ensureVisible: false,
                            autoFocus: false,
                            backgroundColor: cS.surface,
                            textStyle: Theme.of(context)
                                .textTheme
                                .bodyLarge!
                                .copyWith(color: cS.onSurface),
                            padding: const EdgeInsets.all(5),
                            onFocusChanged: (focus) => setState(
                                () => focusQuillEditorController = focus),
                            onTextChanged: (text) async {
                              commentFeature = text;
                            },
                          ),
                          ToolBar(
                            controller: quillEditorController,
                            crossAxisAlignment: WrapCrossAlignment.start,
                            alignment: WrapAlignment.spaceEvenly,
                            direction: Axis.horizontal,
                            toolBarColor: cS.primaryContainer,
                            iconColor: cS.onPrimaryContainer,
                            activeIconColor: cS.tertiary,
                            toolBarConfig: toolbarElements,
                            customButtons: [
                              InkWell(
                                focusColor: cS.tertiary,
                                onTap: () async {
                                  quillEditorController
                                      .getSelectedText()
                                      .then((selectText) async {
                                    if (selectText != null &&
                                        selectText is String &&
                                        selectText.trim().isNotEmpty) {
                                      showModalBottomSheet(
                                        context: context,
                                        isDismissible: true,
                                        useSafeArea: true,
                                        isScrollControlled: true,
                                        constraints:
                                            const BoxConstraints(maxWidth: 640),
                                        showDragHandle: true,
                                        builder: (context) => _showURLDialog(),
                                      );
                                    } else {
                                      ScaffoldMessengerState smState =
                                          ScaffoldMessenger.of(context);
                                      smState.clearSnackBars();
                                      smState.showSnackBar(SnackBar(
                                        content: Text(
                                          AppLocalizations.of(context)!
                                              .seleccionaTexto,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium!
                                              .copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onError),
                                        ),
                                        backgroundColor:
                                            Theme.of(context).colorScheme.error,
                                      ));
                                    }
                                  });
                                },
                                child: Icon(
                                  Icons.link,
                                  color: cS.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                          Visibility(
                            visible: errorCommentFeature,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                appLoca.descrNPIExplica,
                                style: td.textTheme.bodySmall!.copyWith(
                                  color: cS.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 3, horizontal: 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Template("{{{texto}}}: ({{{lat}}}, {{{long}}})")
                              .renderString({
                            'texto': appLoca.currentPosition,
                            'lat': widget._poi.lat.toStringAsFixed(4),
                            'long': widget._poi.long.toStringAsFixed(4),
                          }),
                        ),
                      ),
                    ),
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: Auxiliar.maxWidth,
                        maxHeight:
                            min(400, MediaQuery.of(context).size.height / 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Tooltip(
                          message: appLoca.arrastrarMarcadorCambiarPosicion,
                          child: FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                                backgroundColor:
                                    td.brightness == Brightness.light
                                        ? Colors.white54
                                        : Colors.black54,
                                maxZoom: Auxiliar.maxZoom,
                                minZoom: Auxiliar.maxZoom - 2,
                                initialCenter: widget._poi.point,
                                initialZoom: Auxiliar.maxZoom - 1,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.drag |
                                      InteractiveFlag.pinchZoom |
                                      InteractiveFlag.doubleTapZoom,
                                  enableScrollWheel: true,
                                ),
                                onMapReady: () {
                                  setState(() {
                                    _markers = [
                                      CHESTMarker(
                                        context,
                                        feature: widget._poi,
                                        icon: const Icon(Icons.adjust),
                                        visibleLabel: false,
                                        currentLayer: Auxiliar.layer!,
                                      )
                                    ];
                                  });
                                },
                                onMapEvent: (event) {
                                  if (event is MapEventMove ||
                                      event is MapEventDoubleTapZoomEnd ||
                                      event is MapEventScrollWheelZoom) {
                                    setState(() {
                                      LatLng p1 = mapController.camera.center;
                                      widget._poi.lat = p1.latitude;
                                      widget._poi.long = p1.longitude;
                                      _markers = [
                                        CHESTMarker(
                                          context,
                                          feature: widget._poi,
                                          icon: const Icon(Icons.adjust),
                                          visibleLabel: false,
                                          currentLayer: Auxiliar.layer!,
                                        )
                                      ];
                                    });
                                  }
                                }),
                            children: [
                              Auxiliar.tileLayerWidget(
                                  brightness: Theme.of(context).brightness),
                              Auxiliar.atributionWidget(),
                              MarkerLayer(
                                markers: _markers,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      //Fuente de información
                      //Tengo que soportar que se puedan agregar más de una fuente de información
                      maxLines: 1,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: appLoca.fuentesNPI,
                          hintText: appLoca.fuentesNPI,
                          hintMaxLines: 1,
                          hintStyle:
                              const TextStyle(overflow: TextOverflow.ellipsis)),
                      keyboardType: TextInputType.url,
                      textCapitalization: TextCapitalization.none,
                      readOnly: widget._poi.hasSource,
                      initialValue:
                          widget._poi.hasSource ? widget._poi.source : '',
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          if (v.trim().isEmpty) {
                            return appLoca.fuentesNPIExplica;
                          } else {
                            if (!widget._poi.hasSource) {
                              widget._poi.source = v.trim();
                            }
                            return null;
                          }
                        } else {
                          return null;
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      maxLines: 1,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: appLoca.imagenNPILabel,
                        hintText: appLoca.imagenNPILabel,
                        hintMaxLines: 1,
                        hintStyle:
                            const TextStyle(overflow: TextOverflow.ellipsis),
                      ),
                      initialValue: widget._poi.hasThumbnail
                          ? widget._poi.thumbnail.image
                          : "",
                      keyboardType: TextInputType.url,
                      textCapitalization: TextCapitalization.none,
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          if (Uri.tryParse(v.trim()) == null) {
                            return appLoca.imagenNPIExplica;
                          } else {
                            image = v.trim();
                            return null;
                          }
                        } else {
                          return null;
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      maxLines: 1,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: appLoca.licenciaNPI,
                        hintText: appLoca.licenciaNPI,
                        hintMaxLines: 1,
                        hintStyle:
                            const TextStyle(overflow: TextOverflow.ellipsis),
                      ),
                      initialValue: widget._poi.hasThumbnail
                          ? widget._poi.thumbnail.hasLicense
                              ? widget._poi.thumbnail.license
                              : ''
                          : "",
                      keyboardType: TextInputType.url,
                      textCapitalization: TextCapitalization.none,
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          if (Uri.tryParse(v.trim()) == null) {
                            return AppLocalizations.of(context)!
                                .licenciaNPIExplica;
                          } else {
                            licenseImage = v.trim();
                            return null;
                          }
                        } else {
                          return null;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _showURLDialog() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    String uri = '';
    GlobalKey<FormState> formEnlace = GlobalKey<FormState>();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 10,
        right: 10,
      ),
      child: Form(
        key: formEnlace,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appLoca!.agregaEnlace,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              maxLines: 1,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: "${appLoca.enlace}*",
                hintText: appLoca.hintEnlace,
                helperText: appLoca.requerido,
                hintMaxLines: 1,
              ),
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  uri = value.trim();
                  return null;
                }
                return appLoca.errorEnlace;
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              direction: Axis.horizontal,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(appLoca.cancelar),
                ),
                FilledButton(
                  onPressed: () async {
                    if (formEnlace.currentState!.validate()) {
                      quillEditorController
                          .getSelectedText()
                          .then((textoSeleccionado) async {
                        if (textoSeleccionado != null &&
                            textoSeleccionado is String &&
                            textoSeleccionado.isNotEmpty) {
                          quillEditorController.setFormat(
                              format: 'link', value: uri);
                          Navigator.of(context).pop();
                          setState(() {
                            focusQuillEditorController = true;
                          });
                          quillEditorController.focus();
                        }
                      });
                    }
                  },
                  child: Text(appLoca.insertarEnlace),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget categoriesNP() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final int nBroader = widget._poi.categories[index].broader.length;
          final String vCategory =
              widget._poi.categories[index].label.first.value;
          return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              // child: Card(
              child: ListTile(
                title:
                    Text(nBroader > 0 ? '$vCategory ($nBroader)' : vCategory),
              ),
            ),
          );
        },
        // ),
        childCount: widget._poi.categories.length,
      ),
    );
  }

  Widget buttonNP() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return SliverList(
      delegate: SliverChildListDelegate(
        [
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.publish),
                  label: Text(appLoca!.enviarNPI),
                  onPressed: () async {
                    bool noError = thisKey.currentState!.validate();
                    setState(() =>
                        errorCommentFeature = commentFeature.trim().isEmpty);
                    if (noError && !errorCommentFeature) {
                      commentFeature = Auxiliar.quill2Html(commentFeature);
                      widget._poi.addCommentLang(
                          PairLang(MyApp.currentLang, commentFeature.trim()));
                      if (image != null) {
                        widget._poi.setThumbnail(
                            image!.replaceAll('?width=300', ''), licenseImage);
                      }
                      Map<String, dynamic> bodyRequest = {
                        "lat": widget._poi.lat,
                        "long": widget._poi.long,
                        "comment": widget._poi.comments2List(),
                        "label": widget._poi.labels2List()
                      };
                      if (image != null) {
                        widget._poi.setThumbnail(image!, licenseImage);
                        bodyRequest["image"] = widget._poi.thumbnail2Map();
                      }
                      if (widget._poi.categories.isNotEmpty) {
                        bodyRequest['categories'] =
                            widget._poi.categoriesToList();
                      }
                      http
                          .post(
                        Queries().newPoi(),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization':
                              Template('Bearer {{{token}}}').renderString({
                            'token': await FirebaseAuth.instance.currentUser!
                                .getIdToken(),
                          }),
                        },
                        body: json.encode(bodyRequest),
                      )
                          .then((response) async {
                        ScaffoldMessengerState sMState =
                            ScaffoldMessenger.of(context);
                        switch (response.statusCode) {
                          case 201:
                            String idPOI = response.headers['location']!;
                            widget._poi.id = Uri.decodeFull(idPOI);
                            widget._poi.shortId =
                                Auxiliar.id2shortId(widget._poi.id)!;
                            if (!Config.development) {
                              await FirebaseAnalytics.instance.logEvent(
                                name: "newFeature",
                                parameters: {"iri": widget._poi.shortId},
                              ).then(
                                (value) {
                                  widget._poi.author = Auxiliar.userCHEST.id;
                                  sMState.clearSnackBars();
                                  sMState.showSnackBar(SnackBar(
                                      content: Text(appLoca.infoRegistrada)));
                                  Navigator.pop(context, widget._poi);
                                },
                              ).onError((error, stackTrace) {
                                // print(error);
                                widget._poi.author = Auxiliar.userCHEST.id;
                                sMState.clearSnackBars();
                                sMState.showSnackBar(SnackBar(
                                    content: Text(appLoca.infoRegistrada)));
                                Navigator.pop(context, widget._poi);
                              });
                            } else {
                              widget._poi.author = Auxiliar.userCHEST.id;
                              sMState.clearSnackBars();
                              sMState.showSnackBar(SnackBar(
                                  content: Text(appLoca.infoRegistrada)));
                              Navigator.pop(context, widget._poi);
                            }

                            break;
                          default:
                            sMState.clearSnackBars();
                            sMState.showSnackBar(SnackBar(
                                content: Text(response.statusCode.toString())));
                        }
                      }).onError((error, stackTrace) {
                        debugPrint(error.toString());
                      });
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
