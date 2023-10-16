import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:chest/util/config.dart';
import 'package:chest/util/helpers/chest_marker.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
// import 'package:flutter_map_dragmarker/flutter_map_dragmarker.dart';
// import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/util/helpers/map_data.dart';
// import 'package:chest/users.dart';
import 'package:chest/full_screen.dart';
import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/pois.dart';
import 'package:chest/util/helpers/queries.dart';
import 'package:chest/util/helpers/tasks.dart';
import 'package:chest/util/helpers/user.dart';
import 'package:chest/util/helpers/widget_facto.dart';
import 'package:chest/main.dart';
import 'package:chest/tasks.dart';
import 'package:chest/util/helpers/pair.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoPOI extends StatefulWidget {
  // final POI? poi;
  final Position? locationUser;
  final Widget? iconMarker;
  final String? shortId;

  const InfoPOI({
    required this.shortId,
    this.locationUser,
    this.iconMarker,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _InfoPOI();
}

class _InfoPOI extends State<InfoPOI> {
  late POI feature;
  late bool todoTexto, mostrarFab, _requestTask;
  late LatLng? pointUser;
  late StreamSubscription<Position> _strLocationUser;
  late double distance;
  late String distanceString;
  final MapController mapController = MapController();
  List<Task> tasks = [];
  late Map<String, dynamic> osm, wikidata, esDBpedia, dbpedia, jcyl;
  late bool yaTengoLosDatos;

  @override
  void initState() {
    POI? p = MapData.getFeatureCache(widget.shortId!);
    feature = p ?? POI.empty(widget.shortId!);
    todoTexto = false;
    _requestTask = true;
    pointUser = (widget.locationUser != null && widget.locationUser is Position)
        ? LatLng(widget.locationUser!.latitude, widget.locationUser!.longitude)
        : null;
    mostrarFab = Auxiliar.userCHEST.crol == Rol.teacher ||
        Auxiliar.userCHEST.crol == Rol.admin;
    osm = {};
    wikidata = {};
    esDBpedia = {};
    dbpedia = {};
    jcyl = {};
    yaTengoLosDatos = false;
    super.initState();
    if (p == null) {
      getFeature();
    }
  }

  Future<void> getFeature() async {
    await http
        .get(Queries().getFeatureInfo(widget.shortId!))
        .then((response) =>
            response.statusCode == 200 ? json.decode(response.body) : null)
        .then((providers) {
      if (providers != null) {
        for (Map provider in providers) {
          if (provider['provider'] == 'osm') {
            Map data = provider['data'];
            feature = POI(
              data['id'],
              data['shortId'],
              data['labels'],
              data['labels'],
              data['lat'],
              data['long'],
              data['author'],
            );
          }
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
  void dispose() async {
    if (pointUser != null) {
      _strLocationUser.cancel();
    }
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      floatingActionButton: widgetFab(),
      body: CustomScrollView(
        slivers: [
          widgetAppbar(size),
          // widgetImage(size),
          // widgetInfoPoi(size),
          widgetBody(size),
          widgetGridTasks(size),

          const SliverPadding(padding: EdgeInsets.only(bottom: 500))
        ],
      ),
    );
  }

  Widget? widgetFab() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return mostrarFab
        ? Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Visibility(
                visible: feature.author == Auxiliar.userCHEST.id ||
                    Auxiliar.userCHEST.crol == Rol.admin,
                child: FloatingActionButton.small(
                    heroTag: null,
                    tooltip: appLoca!.borrarPOI,
                    onPressed: () async => borraPoi(appLoca),
                    child: const Icon(Icons.delete)),
              ),
              Visibility(
                visible: feature.author == Auxiliar.userCHEST.id ||
                    Auxiliar.userCHEST.crol == Rol.admin,
                child: const SizedBox(
                  height: 24,
                ),
              ),
              FloatingActionButton.extended(
                  heroTag: Auxiliar.mainFabHero,
                  tooltip: appLoca.nTask,
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
                  icon: const Icon(Icons.add)),
            ],
          )
        : null;
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
            MapData.removePoiFromTile(feature);
            if (!Config.debug) {
              await FirebaseAnalytics.instance.logEvent(
                name: "deletedPoi",
                parameters: {"iri": feature.id.split('/').last},
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

  Widget widgetAppbar(Size size) {
    return SliverAppBar(
      title: Text(
        feature.labelLang(MyApp.currentLang) ??
            feature.labelLang('es') ??
            feature.labels.first.value,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
        textScaleFactor: 0.9,
      ),
      titleTextStyle: Theme.of(context).textTheme.titleLarge,
      pinned: true,
    );
  }

  Widget widgetImageRedu(Size size) {
    return Visibility(
      visible: feature.hasThumbnail,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: Auxiliar.maxWidth / 2,
              maxHeight: size.width > size.height
                  ? size.height * 0.5
                  : size.height / 3,
            ),
            child: feature.hasThumbnail
                ? Image.network(
                    feature.thumbnail.image.contains('commons.wikimedia.org')
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
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        width: 10,
                        height: 5,
                      );
                    },
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
                                          FullScreenImage(feature.thumbnail,
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
                            tooltip:
                                AppLocalizations.of(context)!.pantallaCompleta,
                          ),
                          // color: Colors.white,
                        ),
                      ],
                    ),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
        ),
      ),
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

  Widget widgetInfoPoi(Size size) {
    if (widget.locationUser != null && widget.locationUser is Position) {
      checkUserLocation();
      calculateDistance();
    }

    String commentPoi = feature.commentLang(MyApp.currentLang) ??
        feature.commentLang('es') ??
        feature.comments.first.value;

    List<Widget> lista = [
      widgetMapa(),
      Container(
        padding: const EdgeInsets.only(top: 15),
        child: Visibility(
          visible: !todoTexto,
          child: InkWell(
            onTap: () => setState(() {
              todoTexto = true;
            }),
            child: Text(
              commentPoi,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
      Visibility(
        visible: todoTexto,
        child: HtmlWidget(
          commentPoi,
          factoryBuilder: () => MyWidgetFactory(),
        ),
      ),
    ];

    double horizontalSpace = MediaQuery.of(context).size.width >= 600
        ? Auxiliar.mediumMargin
        : Auxiliar.compactMargin;
    return SliverPadding(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: horizontalSpace),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: lista.elementAt(index),
            ),
          ),
          childCount: lista.length,
        ),
      ),
    );
  }

  Widget widgetMapa() {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    MapOptions mapOptions = (pointUser != null)
        ? MapOptions(
            maxZoom: Auxiliar.maxZoom,
            bounds: LatLngBounds(pointUser!, feature.point),
            boundsOptions: const FitBoundsOptions(padding: EdgeInsets.all(30)),
            // interactiveFlags:
            //     InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
            interactiveFlags: InteractiveFlag.none,
            enableScrollWheel: false,
          )
        : MapOptions(
            zoom: 17,
            maxZoom: Auxiliar.maxZoom,
            // interactiveFlags:
            //     InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
            interactiveFlags: InteractiveFlag.none,
            enableScrollWheel: false,
            center: feature.point,
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
      builder: (context) => widget.iconMarker != null
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
              builder: (context) => Container(
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
              builder: (context) => Container(
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
        borderRadius: BorderRadius.circular(5),
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

  Widget widgetGridTasks(Size size) {
    double aspectRatio = 2 * (size.longestSide / size.shortestSide);
    int nColumn = MediaQuery.of(context).orientation == Orientation.landscape
        ? 2
        : size.shortestSide > 599
            ? 2
            : 1;
    late double pLateral;
    if (size.width > Auxiliar.maxWidth) {
      pLateral = (size.width - Auxiliar.maxWidth) / 2;
    } else {
      pLateral = 10;
    }
    if (_requestTask) {
      return SliverPadding(
        padding: EdgeInsets.only(left: pLateral, right: pLateral, bottom: 80),
        sliver: tasks.isEmpty
            ? FutureBuilder<List>(
                future: _getTasks(feature.id),
                builder: (context, snapshot) {
                  if (snapshot.hasData && !snapshot.hasError) {
                    List<dynamic> data = snapshot.data!;
                    for (var t in data) {
                      try {
                        Task task = Task(t['task'], t['comment'], t['author'],
                            t['space'], t['at'], feature.id);
                        if (t['label'] != null) {
                          task.setLabels(t['label']);
                        }
                        switch (task.aT) {
                          case AnswerType.mcq:
                            if (t['correct'] != null &&
                                t['distractor'] != null) {
                              task.setCorrectMCQ(t['correct']);
                              task.setDistractorMCQ(t['distractor']);
                              t['singleSelection'] != null
                                  ? task.singleSelection = t['singleSelection']
                                  : true;
                            } else {
                              throw Exception('Without correct or distractor');
                            }
                            break;
                          case AnswerType.tf:
                            if (t['correct'] != null) {
                              task.correctTF = t['correct'];
                            }
                            break;
                          default:
                        }
                        bool noRealizada = true;
                        for (var answer in Auxiliar.userCHEST.answers) {
                          if (answer.hasPoi &&
                              answer.idPoi == task.poi &&
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
                    return cardTasks(nColumn, aspectRatio);
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
                },
              )
            : cardTasks(nColumn, aspectRatio),
      );
    } else {
      _requestTask = true;
      return SliverList(delegate: SliverChildListDelegate([]));
    }
  }

  SliverGrid cardTasks(int nColumn, double aspectRatio) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: nColumn,
        childAspectRatio: aspectRatio,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          Task task = tasks[index];
          late String title;
          if (task.hasLabel) {
            title = task.labelLang(MyApp.currentLang) ??
                task.labelLang('es') ??
                task.labels.first.value;
          } else {
            title = Auxiliar.getLabelAnswerType(
                AppLocalizations.of(context), task.aT);
          }
          String comment = task.commentLang(MyApp.currentLang) ??
              task.commentLang('es') ??
              task.comments.first.value;
          comment = comment.replaceAll(
              RegExp('<[^>]*>?', multiLine: true, dotAll: true), '');
          return Card(
            child: ListTile(
              isThreeLine: true,
              leading: task.spaces.length > 1
                  ? const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Icon(Icons.looks_two))
                  : task.spaces.first == Space.physical
                      ? const Icon(Icons.phone_android)
                      : const Icon(Icons.computer),
              minLeadingWidth: 0,
              horizontalTitleGap: 10,
              visualDensity: VisualDensity.adaptivePlatformDensity,
              title: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                comment,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () async {
                ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);
                ThemeData td = Theme.of(context);
                AppLocalizations? appLoca = AppLocalizations.of(context);
                // if (FirebaseAuth.instance.currentUser == null ||
                //     Auxiliar.userCHEST.crol == Rol.guest) {
                //   //No identificado
                //   sMState.clearSnackBars();
                //   sMState.showSnackBar(SnackBar(
                //     content: Text(
                //       appLoca!.iniciaParaRealizar,
                //     ),
                //     action: SnackBarAction(
                //       label: appLoca.iniciarSes,
                //       onPressed: () => Navigator.push(
                //         context,
                //         MaterialPageRoute<void>(
                //             builder: (BuildContext context) =>
                //                 const LoginUsers(),
                //             fullscreenDialog: true),
                //       ),
                //     ),
                //   ));
                // } else {
                if (Auxiliar.userCHEST.crol == Rol.user ||
                    Auxiliar.userCHEST.crol == Rol.guest) {
                  //Solo usuarios con el rol de estudiante
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
                            backgroundColor: td.colorScheme.errorContainer,
                            content: Text(
                              appLoca!.acercate,
                              style: td.textTheme.bodyMedium!.copyWith(
                                color: td.colorScheme.onErrorContainer,
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
                          content: Text(appLoca!.activaLocalizacion),
                          duration: const Duration(seconds: 8),
                          action: SnackBarAction(
                            label: appLoca.activar,
                            onPressed: () => checkUserLocation(),
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
                    if (!Config.debug) {
                      await FirebaseAnalytics.instance.logEvent(
                        name: "seenTask",
                        parameters: {"iri": task.id.split('/').last},
                      ).then(
                        (value) {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (BuildContext context) => COTask(
                                      feature,
                                      task,
                                      answer: null,
                                    ),
                                fullscreenDialog: true),
                          ).onError((error, stackTrace) {
                            // print(error);
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) => COTask(
                                  feature,
                                  task,
                                  answer: null,
                                ),
                                fullscreenDialog: true,
                              ),
                            );
                          });
                        },
                      );
                    } else {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) => COTask(
                            feature,
                            task,
                            answer: null,
                          ),
                          fullscreenDialog: true,
                        ),
                      );
                    }
                  }
                } else {
                  if (Auxiliar.userCHEST.crol == Rol.teacher ||
                      Auxiliar.userCHEST.crol == Rol.admin) {
                    sMState.clearSnackBars();
                    sMState.showSnackBar(
                      SnackBar(
                          content: Text(appLoca!.cambiaEstudiante),
                          duration: const Duration(seconds: 8),
                          action: SnackBarAction(
                              label: appLoca.activar,
                              onPressed: () {
                                Auxiliar.userCHEST.crol = Rol.user;
                                setState(() {
                                  mostrarFab =
                                      Auxiliar.userCHEST.crol == Rol.teacher ||
                                          Auxiliar.userCHEST.crol == Rol.admin;
                                });
                              })),
                    );
                  } else {
                    sMState.clearSnackBars();
                    sMState.showSnackBar(
                      SnackBar(content: Text(appLoca!.cambiaEstudiante)),
                    );
                  }
                }
                // }
              },
              onLongPress: () async {
                if (FirebaseAuth.instance.currentUser != null) {
                  if ((Auxiliar.userCHEST.crol == Rol.teacher &&
                          task.author == Auxiliar.userCHEST.id) ||
                      Auxiliar.userCHEST.crol == Rol.admin) {
                    //Puede editar/borrar la tarea
                    AppLocalizations? appLoca = AppLocalizations.of(context);
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
                            label: Text(appLoca!.editar),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              Navigator.pop(context);
                              bool? borrarLista = await Auxiliar.deleteDialog(
                                  context,
                                  appLoca.borrar,
                                  appLoca.preguntaBorrarTarea);
                              if (borrarLista != null && borrarLista) {
                                dynamic tareaBorrada =
                                    await _deleteTask(task.id);
                                if (tareaBorrada is bool) {
                                  if (tareaBorrada) {
                                    showSnackTaskDelete(false);
                                    setState(() {
                                      tasks.removeWhere((t) => t.id == task.id);
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
                            icon: const Icon(Icons.delete),
                            label: Text(appLoca.borrar),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
            ),
          );
        },
        childCount: tasks.length,
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
    return http.delete(Queries().deleteTask(feature.id, id), headers: {
      'Content-Type': 'application/json',
      'Authorization': Template('Bearer {{{token}}}').renderString({
        'token': await FirebaseAuth.instance.currentUser!.getIdToken(),
      })
    }).then((response) async {
      if (response.statusCode == 200) {
        if (!Config.debug) {
          await FirebaseAnalytics.instance.logEvent(
            name: "deletedTask",
            parameters: {"iri": id.split('/').last},
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
          mapController.fitBounds(LatLngBounds(pointUser!, feature.point),
              options: const FitBoundsOptions(padding: EdgeInsets.all(30)));
          calculateDistance();
        }
      }
    }, cancelOnError: true);
  }

  void calculateDistance() {
    if (mounted) {
      setState(() {
        distance = Auxiliar.distance(feature.point, pointUser!);
        distanceString = distance < Auxiliar.maxWidth
            ? Template('{{{metros}}}m')
                .renderString({"metros": distance.toInt().toString()})
            : Template('{{{km}}}km').renderString(
                {"km": (distance / Auxiliar.maxWidth).toStringAsFixed(2)});
      });
    }
  }

  Widget widgetBody(Size size) {
    late double pLateral;
    if (size.width > Auxiliar.maxWidth) {
      pLateral = (size.width - Auxiliar.maxWidth) / 2;
    } else {
      pLateral = Auxiliar.compactMargin;
    }
    if (widget.locationUser != null && widget.locationUser is Position) {
      checkUserLocation();
      calculateDistance();
    }
    return SliverPadding(
      padding:
          EdgeInsets.only(top: 20, left: pLateral, right: pLateral, bottom: 80),
      sliver: yaTengoLosDatos
          ? SliverList(
              delegate: SliverChildListDelegate([
                widgetImageRedu(size),
                widgetBICCyL(),
                widgetMapa(),
                Container(
                  padding: const EdgeInsets.only(top: 15),
                  child: todoTexto
                      ? HtmlWidget(
                          feature.commentLang(MyApp.currentLang) ??
                              feature.commentLang('es') ??
                              feature.comments.first.value,
                          factoryBuilder: () => MyWidgetFactory(),
                        )
                      : InkWell(
                          onTap: () => setState(() => todoTexto = true),
                          child: Text(
                            feature.commentLang(MyApp.currentLang) ??
                                feature.commentLang('es') ??
                                feature.comments.first.value,
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
                fuentesInfo(),
              ]),
            )
          : FutureBuilder<List>(
              future: _getInfoPoi(feature.shortId),
              builder: (context, snapshot) {
                if (snapshot.hasData && !snapshot.hasError) {
                  for (int i = 0, tama = snapshot.data!.length; i < tama; i++) {
                    Map provider = snapshot.data![i];
                    Map data = provider['data'];
                    switch (provider["provider"]) {
                      case 'osm':
                        osm['id'] = data['id'];
                        osm['lat'] = data['lat'];
                        osm['long'] = data['long'];
                        osm['author'] = data['author'];
                        osm['license'] = data['license'];
                        if (data.containsKey('name')) {
                          osm['name'] = data['name'];
                          feature
                              .addLabelLang(PairLang.withoutLang(data['name']));
                        }
                        if (data.containsKey('wikipedia')) {
                          osm['wikipedia'] = data['wikipedia'];
                        }
                        if (data.containsKey('tags')) {
                          osm['tags'] = data['tags'];
                        }
                        if (osm['tags'].containsKey('image')) {
                          String urlImage = osm['tags']['image']
                              .replaceAll('http://', 'https://');
                          String? licenseImage;
                          if (urlImage
                              .contains('commons.wikimedia.org/wiki/File:')) {
                            licenseImage = urlImage;
                            urlImage = urlImage.replaceAll(
                                'File:', 'Special:FilePath/');
                          }
                          if (licenseImage != null &&
                              urlImage.toString().isNotEmpty) {
                            feature.setThumbnail(urlImage, licenseImage);
                          } else {
                            feature.setThumbnail(urlImage, null);
                          }
                          // widget.poi.setThumbnail(osm['tags']['image'], null);
                        }
                        if (data.containsKey('geometry')) {
                          osm['geometry'] = data['geometry'];
                        }
                        if (data.containsKey('members')) {
                          osm['members'] = data['members'];
                        }
                        break;
                      case 'wikidata':
                        wikidata['id'] = data['id'];
                        if (data.containsKey('label')) {
                          wikidata['label'] = data['label'] is Map
                              ? [data['label']]
                              : data['label'];
                          for (Map l in wikidata['label']) {
                            feature
                                .addLabelLang(PairLang(l['lang'], l['value']));
                          }
                        }
                        if (data.containsKey('description')) {
                          wikidata['description'] = data['description'] is Map
                              ? [data['description']]
                              : data['description'];
                          for (Map d in wikidata['description']) {
                            feature.addCommentLang(
                                PairLang(d['lang'], d['value']));
                          }
                        }
                        if (data.containsKey('image')) {
                          //TODO
                          if (data['image'] is Map) {
                            data['image'] = [data['image']];
                          }
                          if (data['image'] != null &&
                              data['image'].isNotEmpty) {
                            wikidata['image'] = data['image'];
                          }
                          for (Map d in data['image']) {
                            feature.addImage(d['f'], license: d['l']);
                          }
                        }
                        wikidata['type'] = data['type'];
                        if (data.containsKey('bicJCyL')) {
                          wikidata['bicJCyL'] = data['bicJCyL'];
                        }
                        if (data.containsKey('arcStyle')) {
                          wikidata['arcStyle'] = data['arcStyle'];
                        }
                        if (data.containsKey('inception')) {
                          wikidata['inception'] =
                              DateTime.fromMicrosecondsSinceEpoch(
                                  data['inception']);
                        }
                        if (data.containsKey('lat')) {
                          wikidata['lat'] = data['lat'];
                        }
                        if (data.containsKey('long')) {
                          wikidata['long'] = data['long'];
                        }
                        break;
                      case 'jcyl':
                        jcyl['id'] = data['id'];
                        jcyl['url'] = data['url'];
                        jcyl['label'] = data['label'] is Map
                            ? [data['label']]
                            : data['label'];
                        jcyl['category'] = data['category'];
                        jcyl['categoryLabel'] = data['categoryLabel'];
                        jcyl['license'] = data['license'];
                        if (data.containsKey('altLabel')) {
                          jcyl['altLabel'] = data['altLabel'] is Map
                              ? [data['altLabel']]
                              : data['altLabel'];
                        }
                        if (data.containsKey('comment')) {
                          jcyl['comment'] = data['comment'] is Map
                              ? [data['comment']]
                              : data['comment'];
                        }
                        if (data.containsKey('lat')) {
                          jcyl['lat'] = data['lat'];
                        }
                        if (data.containsKey('long')) {
                          jcyl['long'] = data['long'];
                        }
                        break;
                      case 'esDBpedia':
                        esDBpedia['id'] = data['id'];
                        if (data.containsKey('comment')) {
                          esDBpedia['comment'] = data['comment'] is Map
                              ? [data['comment']]
                              : data['comment'];
                          for (Map d in esDBpedia['comment']) {
                            feature.addCommentLang(
                                PairLang(d['lang'], d['value']));
                          }
                        }
                        if (data.containsKey('type')) {
                          esDBpedia['type'] = data['type'];
                        }
                        if (data.containsKey('label')) {
                          esDBpedia['label'] = data['label'] is Map
                              ? [data['label']]
                              : data['label'];
                          for (Map d in esDBpedia['label']) {
                            feature
                                .addLabelLang(PairLang(d['lang'], d['value']));
                          }
                        }
                        break;
                      case 'dbpedia':
                        dbpedia['id'] = data['id'];
                        if (data.containsKey('comment')) {
                          dbpedia['comment'] = data['comment'] is Map
                              ? [data['comment']]
                              : data['comment'];
                          for (Map d in dbpedia['comment']) {
                            feature.addCommentLang(
                                PairLang(d['lang'], d['value']));
                          }
                        }
                        if (data.containsKey('type')) {
                          dbpedia['type'] = data['type'];
                        }
                        if (data.containsKey('label')) {
                          dbpedia['label'] = data['label'] is Map
                              ? [data['label']]
                              : data['label'];
                          for (Map d in dbpedia['label']) {
                            feature
                                .addLabelLang(PairLang(d['lang'], d['value']));
                          }
                        }
                        break;
                      default:
                    }
                  }
                  String commentPoi = feature.commentLang(MyApp.currentLang) ??
                      feature.commentLang('es') ??
                      feature.comments.first.value;
                  yaTengoLosDatos = true;
                  return SliverList(
                    delegate: SliverChildListDelegate([
                      widgetImageRedu(size),
                      widgetBICCyL(),
                      widgetMapa(),
                      Container(
                        padding: const EdgeInsets.only(top: 15),
                        child: todoTexto
                            ? HtmlWidget(
                                commentPoi,
                                factoryBuilder: () => MyWidgetFactory(),
                              )
                            : InkWell(
                                onTap: () => setState(() => todoTexto = true),
                                child: Text(
                                  commentPoi,
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                      ),
                      fuentesInfo(),
                    ]),
                  );
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
    return jcyl.isNotEmpty && jcyl.containsKey('url')
        ? Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Center(
              child: FilledButton.icon(
                onPressed: () async {
                  if (!await launchUrl(Uri.parse(jcyl['url']))) {
                    debugPrint('Url jcyl problem!');
                  }
                },
                label: Text(AppLocalizations.of(context)!.bicCyL),
                icon: const Icon(Icons.favorite),
              ),
            ),
          )
        : Container();
  }

  OutlinedButton _fuentesInfoBt(
    String nameSource,
    Map<String, dynamic> infoMap,
  ) {
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
    List<Widget> lstSources = [];
    if (osm.isNotEmpty) {
      lstSources.add(_fuentesInfoBt('OpenStreetMap', osm));
    }
    if (wikidata.isNotEmpty) {
      lstSources.add(_fuentesInfoBt('Wikidata', wikidata));
    }
    if (jcyl.isNotEmpty) {
      lstSources.add(_fuentesInfoBt('JCyL', jcyl));
    }
    if (esDBpedia.isNotEmpty) {
      lstSources.add(_fuentesInfoBt('es.DBpedia', esDBpedia));
    }
    if (dbpedia.isNotEmpty) {
      lstSources.add(_fuentesInfoBt('DBpedia', dbpedia));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text(
              AppLocalizations.of(context)!.fuentesInfo,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Wrap(
            runAlignment: WrapAlignment.start,
            runSpacing: 4,
            spacing: 8,
            children: lstSources,
          ),
        ],
      ),
    );
  }
}

class NewPoi extends StatefulWidget {
  final LatLng point;
  final LatLngBounds bounds;
  final List<POI> cPois;
  const NewPoi(this.point, this.bounds, this.cPois, {Key? key})
      : super(key: key);

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
    for (POI poi in widget.cPois) {
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
                POI poi = pois[index]["poi"];
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
                                if (!Config.debug) {
                                  await FirebaseAnalytics.instance.logEvent(
                                    name: "seenPoi",
                                    parameters: {"iri": poi.id.split('/').last},
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
                  List<POI> pois = [];
                  List<dynamic> data = snapshot.data!;
                  for (var d in data) {
                    try {
                      // TODO Cambiar el segundo elemento por el shortId
                      POI p = POI(d['id'], d['id'], d['label'], d['comment'],
                          d['lat'], d['lng'], Auxiliar.userCHEST.id);
                      if (d['thumbnailImg'] != null &&
                          d['thumbnailImg'].toString().isNotEmpty) {
                        if (d['thumbnailLic'] != null &&
                            d['thumbnailLic'].toString().isNotEmpty) {
                          p.setThumbnail(d['thumbnailImg'], d['thumbnailLic']);
                        } else {
                          p.setThumbnail(d['thumbnailImg'], null);
                        }
                      }
                      p.source = d['id'];
                      if (d['categories'] != null) {
                        p.categories = d['categories'];
                      }
                      pois.add(p);
                    } catch (e) {
                      debugPrint(e.toString());
                    }
                  }
                  if (pois.isNotEmpty) {
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                          childCount: pois.length, (context, index) {
                        POI p = pois[index];
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
                      POI.point(widget.point.latitude, widget.point.longitude),
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
  final POI _poi;

  const FormPOI(this._poi, {Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _FormPOI();
}

class _FormPOI extends State<FormPOI> {
  String? image, licenseImage;
  late String commentFeature;
  late GlobalKey<FormState> thisKey;
  late MapController mapController;
  late bool errorCommentFeature, focusHtmlEditor;
  late HtmlEditorController htmlEditorController;
  late List<Marker> _markers;

  @override
  void initState() {
    thisKey = GlobalKey<FormState>();
    mapController = MapController();
    focusHtmlEditor = false;
    errorCommentFeature = false;
    htmlEditorController = HtmlEditorController();
    commentFeature = '';
    _markers = [];
    super.initState();
  }

  @override
  void dispose() {
    mapController.dispose();
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
                                  : focusHtmlEditor
                                      ? cS.primary
                                      : td.disabledColor,
                              width: focusHtmlEditor ? 2 : 1),
                        ),
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
                                    : focusHtmlEditor
                                        ? cS.primary
                                        : td.disabledColor,
                              ),
                            ),
                          ),
                          HtmlEditor(
                            controller: htmlEditorController,
                            otherOptions: OtherOptions(
                              height: size.height * 0.4,
                            ),
                            htmlToolbarOptions: HtmlToolbarOptions(
                                toolbarType: ToolbarType.nativeGrid,
                                toolbarPosition: ToolbarPosition.belowEditor,
                                defaultToolbarButtons: [
                                  const FontButtons(
                                    clearAll: false,
                                    superscript: false,
                                    subscript: false,
                                    strikethrough: false,
                                  ),
                                  const ListButtons(
                                    listStyles: false,
                                  ),
                                  const InsertButtons(
                                    picture: false,
                                    audio: false,
                                    video: false,
                                    table: false,
                                    hr: false,
                                  ),
                                ],
                                onButtonPressed: (ButtonType bType,
                                    bool? status,
                                    Function? updateStatus) async {
                                  if (bType == ButtonType.link) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => PointerInterceptor(
                                        child: _showURLDialog(),
                                      ),
                                    );
                                    return false;
                                  }
                                  return true;
                                }),
                            htmlEditorOptions: HtmlEditorOptions(
                              adjustHeightForKeyboard: false,
                              hint: appLoca.descrNPI,
                              initialText: widget._poi.comments.isEmpty
                                  ? ''
                                  : widget._poi
                                          .commentLang(MyApp.currentLang) ??
                                      widget._poi.commentLang('es') ??
                                      widget._poi.comments.first.value,
                              inputType: HtmlInputType.text,
                              spellCheck: true,
                            ),
                            callbacks: Callbacks(
                              onChangeContent: (p0) =>
                                  commentFeature = p0.toString(),
                              onFocus: () =>
                                  setState(() => focusHtmlEditor = true),
                              onBlur: () =>
                                  setState(() => focusHtmlEditor = false),
                            ),
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
                                maxZoom: Auxiliar.maxZoom,
                                minZoom: Auxiliar.maxZoom - 2,
                                center: widget._poi.point,
                                zoom: Auxiliar.maxZoom - 1,
                                interactiveFlags: InteractiveFlag.drag |
                                    InteractiveFlag.pinchZoom |
                                    InteractiveFlag.doubleTapZoom,
                                enableScrollWheel: true,
                                onMapReady: () {
                                  setState(() {
                                    _markers = [
                                      CHESTMarker(
                                        poi: widget._poi,
                                        icon: const Icon(Icons.adjust),
                                      )
                                    ];
                                  });
                                },
                                onMapEvent: (event) {
                                  if (event is MapEventMove ||
                                      event is MapEventDoubleTapZoomEnd ||
                                      event is MapEventScrollWheelZoom) {
                                    setState(() {
                                      LatLng p1 = mapController.center;
                                      widget._poi.lat = p1.latitude;
                                      widget._poi.long = p1.longitude;
                                      _markers = [
                                        CHESTMarker(
                                          poi: widget._poi,
                                          icon: const Icon(Icons.adjust),
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

  AlertDialog _showURLDialog() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    String uri = '';
    String? text;
    GlobalKey<FormState> formEnlace = GlobalKey<FormState>();
    return AlertDialog(
      scrollable: true,
      title: Text(appLoca!.agregaEnlace),
      content: Form(
          key: formEnlace,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 20),
              TextFormField(
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: appLoca.textoEnlace,
                  hintText: appLoca.hintTextoEnlace,
                  hintMaxLines: 1,
                ),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    text = value.trim();
                  }
                  return null;
                },
              ),
            ],
          )),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(appLoca.cancelar),
        ),
        TextButton(
          onPressed: () {
            if (formEnlace.currentState!.validate()) {
              htmlEditorController.insertLink(
                  text == null ? uri : text!, uri, true);
              Navigator.of(context).pop();
            }
          },
          child: Text(appLoca.insertarEnlace),
        )
      ],
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
                            if (!Config.debug) {
                              await FirebaseAnalytics.instance.logEvent(
                                name: "newPoi",
                                parameters: {
                                  "iri": widget._poi.id.split('/').last
                                },
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
                        //print(error.toString());
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
