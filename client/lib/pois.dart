import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:chest/config.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/helpers/map_data.dart';
import 'package:chest/users.dart';
import 'package:chest/full_screen.dart';
import 'package:chest/helpers/auxiliar.dart';
import 'package:chest/helpers/pois.dart';
import 'package:chest/helpers/queries.dart';
import 'package:chest/helpers/tasks.dart';
import 'package:chest/helpers/user.dart';
import 'package:chest/helpers/widget_facto.dart';
import 'package:chest/main.dart';
import 'package:chest/tasks.dart';
import 'package:chest/helpers/pair.dart';

class InfoPOI extends StatefulWidget {
  final POI poi;
  final Position? locationUser;
  final Container? iconMarker;

  const InfoPOI(this.poi, {this.locationUser, this.iconMarker, Key? key})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _InfoPOI();
}

class _InfoPOI extends State<InfoPOI> {
  late bool todoTexto, mostrarFab, _requestTask;
  late LatLng? pointUser;
  late StreamSubscription<Position> _strLocationUser;
  late double distance;
  late String distanceString;
  final MapController mapController = MapController();
  List<Task> tasks = [];

  @override
  void initState() {
    todoTexto = false;
    _requestTask = true;
    pointUser = (widget.locationUser != null && widget.locationUser is Position)
        ? LatLng(widget.locationUser!.latitude, widget.locationUser!.longitude)
        : null;
    mostrarFab = Auxiliar.userCHEST.crol == Rol.teacher ||
        Auxiliar.userCHEST.crol == Rol.admin;
    super.initState();
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
          widgetImage(size),
          widgetInfoPoi(size),
          widgetGridTasks(size)
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
                visible: widget.poi.author == Auxiliar.userCHEST.id ||
                    Auxiliar.userCHEST.crol == Rol.admin,
                child: Tooltip(
                  message: appLoca!.borrarPOI,
                  child: FloatingActionButton.small(
                      heroTag: null,
                      onPressed: () async {
                        bool? borrarPoi = await Auxiliar.deleteDialog(context,
                            appLoca.borrarPOI, appLoca.preguntaBorrarPOI);
                        if (borrarPoi != null && borrarPoi) {
                          http.delete(Queries().deletePOI(widget.poi.id),
                              headers: {
                                'Content-Type': 'application/json',
                                'Authorization': Template('Bearer {{{token}}}')
                                    .renderString({
                                  'token': await FirebaseAuth
                                      .instance.currentUser!
                                      .getIdToken(),
                                })
                              }).then((response) async {
                            ScaffoldMessengerState sMState =
                                ScaffoldMessenger.of(context);

                            switch (response.statusCode) {
                              case 200:
                                MapData.removePoiFromTile(widget.poi);
                                if (!Config.debug) {
                                  await FirebaseAnalytics.instance.logEvent(
                                    name: "deletedPoi",
                                    parameters: {
                                      "iri": widget.poi.id.split('/').last
                                    },
                                  ).then(
                                    (value) {
                                      sMState.clearSnackBars();
                                      sMState.showSnackBar(SnackBar(
                                          content: Text(
                                        appLoca.poiBorrado,
                                      )));
                                      Navigator.pop(context, true);
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
                                  Navigator.pop(context, true);
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
                      },
                      child: const Icon(Icons.delete)),
                ),
              ),
              Visibility(
                visible: widget.poi.author == Auxiliar.userCHEST.id ||
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
                                FormTask(Task.empty(widget.poi.id)),
                            fullscreenDialog: true));
                  },
                  label: Text(appLoca.nTask),
                  icon: const Icon(Icons.add)),
            ],
          )
        : null;
  }

  Widget widgetAppbar(Size size) {
    return SliverAppBar.large(
      title: Text(
        widget.poi.labelLang(MyApp.currentLang) ??
            widget.poi.labelLang('es') ??
            widget.poi.labels.first.value,
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }

  Widget widgetImage(Size size) {
    return SliverVisibility(
      visible: widget.poi.hasThumbnail,
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
                  child: widget.poi.hasThumbnail
                      ? Image.network(
                          widget.poi.thumbnail.image
                                  .contains('commons.wikimedia.org')
                              ? Template(
                                      '{{{wiki}}}?width={{{width}}}&height={{{height}}}')
                                  .renderString({
                                  "wiki": widget.poi.thumbnail.image,
                                  "width": size.width,
                                  "height": size.height
                                })
                              : widget.poi.thumbnail.image,
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
                                                    widget.poi.thumbnail,
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
                                              FullScreenImage(
                                                  widget.poi.thumbnail,
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

    String commentPoi = widget.poi.commentLang(MyApp.currentLang) ??
        widget.poi.commentLang('es') ??
        widget.poi.comments.first.value;

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

    return SliverPadding(
      padding: const EdgeInsets.all(10),
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
    MapOptions mapOptions = (pointUser != null)
        ? MapOptions(
            maxZoom: Auxiliar.maxZoom,
            bounds: LatLngBounds(pointUser, widget.poi.point),
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
            center: widget.poi.point,
          );
    List<Polyline> polylines = (pointUser != null)
        ? [
            Polyline(
              isDotted: true,
              points: [pointUser!, widget.poi.point],
              gradientColors: [
                Theme.of(context).primaryColorLight,
                Theme.of(context).primaryColorDark,
              ],
              strokeWidth: 5,
            )
          ]
        : [Polyline(points: [])];
    Marker markerPoi = Marker(
      width: 48,
      height: 48,
      point: widget.poi.point,
      builder: (context) => widget.iconMarker != null
          ? widget.iconMarker!
          : Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Theme.of(context).primaryColorDark),
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
                    color: Theme.of(context).primaryColorLight),
              ),
            ),
            Marker(
              //Distancia
              width: 60,
              height: 20,
              point: LatLng(
                ((max(widget.poi.lat, pointUser!.latitude) -
                            min(widget.poi.lat, pointUser!.latitude)) /
                        2) +
                    min(widget.poi.lat, pointUser!.latitude),
                ((max(widget.poi.long, pointUser!.longitude) -
                            min(widget.poi.long, pointUser!.longitude)) /
                        2) +
                    min(widget.poi.long, pointUser!.longitude),
              ),
              builder: (context) => Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                        color: Theme.of(context).primaryColorDark, width: 2),
                    borderRadius: BorderRadius.circular(2)),
                child: Center(
                  child: Text(
                    distanceString,
                    style: const TextStyle(color: Colors.black, fontSize: 12),
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
            Auxiliar.atributionWidget(),
            PolylineLayer(polylines: polylines),
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
                future: _getTasks(widget.poi.id),
                builder: (context, snapshot) {
                  if (snapshot.hasData && !snapshot.hasError) {
                    List<dynamic> data = snapshot.data!;
                    for (var t in data) {
                      try {
                        Task task = Task(t['task'], t['comment'], t['author'],
                            t['space'], t['at'], widget.poi.id);
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
            title = Auxiliar.getLabelAnswerType(context, task.aT);
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
                if (FirebaseAuth.instance.currentUser == null ||
                    Auxiliar.userCHEST.crol == Rol.guest) {
                  //No identificado
                  sMState.clearSnackBars();
                  sMState.showSnackBar(SnackBar(
                    content: Text(
                      appLoca!.iniciaParaRealizar,
                    ),
                    action: SnackBarAction(
                      label: appLoca.iniciarSes,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const LoginUsers(),
                            fullscreenDialog: true),
                      ),
                    ),
                  ));
                } else {
                  if (Auxiliar.userCHEST.crol == Rol.user) {
                    //Solo usuarios con el rol de estudiante
                    bool startTask = true;
                    if (task.spaces.length == 1 &&
                        task.spaces.first == Space.physical) {
                      if (pointUser != null) {
                        //TODO 100
                        if (distance > 100) {
                          startTask = false;
                          sMState.clearSnackBars();
                          sMState.showSnackBar(
                            SnackBar(
                              backgroundColor: td.colorScheme.error,
                              content: Text(appLoca!.acercate),
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
                    //TODO REMOVE
                    switch (task.aT) {
                      case AnswerType.multiplePhotos:
                      case AnswerType.multiplePhotosText:
                      case AnswerType.photo:
                      case AnswerType.photoText:
                      case AnswerType.video:
                      case AnswerType.videoText:
                        startTask = false;
                        sMState.clearSnackBars();
                        sMState.showSnackBar(
                          SnackBar(
                            backgroundColor: td.colorScheme.error,
                            content: Text(appLoca!.enDesarrollo),
                          ),
                        );
                        break;
                      default:
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
                                        widget.poi,
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
                                          widget.poi,
                                          task,
                                          answer: null,
                                        ),
                                    fullscreenDialog: true),
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
                                    widget.poi,
                                    task,
                                    answer: null,
                                  ),
                              fullscreenDialog: true),
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
                                    mostrarFab = Auxiliar.userCHEST.crol ==
                                            Rol.teacher ||
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
                }
              },
              onLongPress: () async {
                if (FirebaseAuth.instance.currentUser != null) {
                  if ((Auxiliar.userCHEST.crol == Rol.teacher &&
                          task.author == Auxiliar.userCHEST.id) ||
                      Auxiliar.userCHEST.crol == Rol.admin) {
                    //Puede editar/borrar la tarea
                    showModalBottomSheet(
                      context: context,
                      constraints: const BoxConstraints(maxWidth: 640),
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(10)),
                      ),
                      builder: (context) {
                        AppLocalizations? appLoca =
                            AppLocalizations.of(context);
                        return Padding(
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
                                label: Text(appLoca!.editar),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  bool? borrarLista =
                                      await Auxiliar.deleteDialog(
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
                                icon: const Icon(Icons.delete),
                                label: Text(appLoca.borrar),
                              )
                            ],
                          ),
                        );
                      },
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
        backgroundColor: error ? td.colorScheme.error : null,
        content: Text(
          error ? appLoca!.errorBorrarTask : appLoca!.tareaBorrada,
        ),
      ),
    );
  }

  Future<dynamic> _deleteTask(String id) async {
    return http.delete(Queries().deleteTask(id), headers: {
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
          mapController.fitBounds(LatLngBounds(pointUser, widget.poi.point),
              options: const FitBoundsOptions(padding: EdgeInsets.all(30)));
          calculateDistance();
        }
      }
    }, cancelOnError: true);
  }

  void calculateDistance() {
    if (mounted) {
      setState(() {
        distance = Auxiliar.distance(widget.poi.point, pointUser!);
        distanceString = distance < Auxiliar.maxWidth
            ? Template('{{{metros}}}m')
                .renderString({"metros": distance.toInt().toString()})
            : Template('{{{km}}}km').renderString(
                {"km": (distance / Auxiliar.maxWidth).toStringAsFixed(2)});
      });
    }
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
    ThemeData td = Theme.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(appLoca!.addPOI),
          bottom: TabBar(
            labelColor:
                td.brightness == Brightness.light ? td.primaryColor : null,
            unselectedLabelColor: td.brightness == Brightness.light
                ? td.unselectedWidgetColor
                : null,
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

    ThemeData td = Theme.of(context);
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
                                          color: td.primaryColorDark,
                                          child: child),
                                    ),
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, obj, stack) =>
                                        ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        height: 150,
                                        color: td.primaryColorDark,
                                      ),
                                    ),
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 150,
                                    color: td.primaryColorDark,
                                  ),
                                ),
                          SizedBox(
                            width: Auxiliar.maxWidth,
                            height: 150,
                            child: ListTile(
                              textColor: Colors.white,
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
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute<void>(
                                            builder: (BuildContext context) =>
                                                InfoPOI(poi),
                                            fullscreenDialog: false),
                                      );
                                    },
                                  ).onError((error, stackTrace) {
                                    // print(error);
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                          builder: (BuildContext context) =>
                                              InfoPOI(poi),
                                          fullscreenDialog: false),
                                    );
                                  });
                                } else {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (BuildContext context) =>
                                            InfoPOI(poi),
                                        fullscreenDialog: false),
                                  );
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
                      POI p = POI(d['poi'], d['label'], d['comment'], d['lat'],
                          d['lng'], Auxiliar.userCHEST.id);
                      if (d['thumbnailImg'] != null &&
                          d['thumbnailImg'].toString().isNotEmpty) {
                        if (d['thumbnailLic'] != null &&
                            d['thumbnailLic'].toString().isNotEmpty) {
                          p.setThumbnail(d['thumbnailImg'], d['thumbnailLic']);
                        } else {
                          p.setThumbnail(d['thumbnailImg'], null);
                        }
                      }
                      p.source = d['poi'];
                      if (d['categories'] != null) {
                        p.categories = d['categories'];
                      }
                      pois.add(p);
                    } catch (e) {
                      // print(e);
                    }
                  }
                  if (pois.isNotEmpty) {
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                          childCount: pois.length, (context, index) {
                        POI p = pois[index];
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
                                                  color: Theme.of(context)
                                                      .primaryColorDark,
                                                  child: child),
                                            ),
                                            fit: BoxFit.cover,
                                            errorBuilder: (ctx, obj, stack) =>
                                                ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                color: Theme.of(context)
                                                    .primaryColorDark,
                                              ),
                                            ),
                                          ),
                                        )
                                      : ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Container(
                                              color: Theme.of(context)
                                                  .primaryColorDark),
                                        ),
                                  SizedBox(
                                    width: Auxiliar.maxWidth,
                                    height: 150,
                                    child: ListTile(
                                      textColor: Colors.white,
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
  late GlobalKey<FormState> thisKey;

  @override
  void initState() {
    thisKey = GlobalKey<FormState>();
    super.initState();
  }

  @override
  void dispose() {
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
                          labelText: AppLocalizations.of(context)!.tituloNPI,
                          hintText: AppLocalizations.of(context)!.tituloNPI,
                          helperText: AppLocalizations.of(context)!.requerido,
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
                          return AppLocalizations.of(context)!.tituloNPIExplica;
                        } else {
                          widget._poi
                              .addLabelLang(PairLang(MyApp.currentLang, value));
                          return null;
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    //comment
                    TextFormField(
                      minLines: 1,
                      maxLines: 5,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!.descrNPI,
                          hintText: AppLocalizations.of(context)!.descrNPI,
                          helperText: AppLocalizations.of(context)!.requerido,
                          hintMaxLines: 1,
                          hintStyle:
                              const TextStyle(overflow: TextOverflow.ellipsis)),
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      initialValue: widget._poi.comments.isEmpty
                          ? ''
                          : widget._poi.commentLang(MyApp.currentLang) ??
                              widget._poi.commentLang('es') ??
                              widget._poi.comments.first.value,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return AppLocalizations.of(context)!.descrNPIExplica;
                        } else {
                          widget._poi.addCommentLang(
                              PairLang(MyApp.currentLang, value));
                          return null;
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    //Latitud
                    TextFormField(
                        minLines: 1,
                        readOnly: true,
                        decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: AppLocalizations.of(context)!.latitudNPI,
                            hintText: AppLocalizations.of(context)!.latitudNPI,
                            helperText: AppLocalizations.of(context)!.requerido,
                            hintMaxLines: 1,
                            hintStyle: const TextStyle(
                                overflow: TextOverflow.ellipsis)),
                        keyboardType: const TextInputType.numberWithOptions(
                            signed: true, decimal: true),
                        initialValue: widget._poi.lat.toString(),
                        validator: ((value) {
                          if (value == null ||
                              value.trim().isEmpty ||
                              double.tryParse(value.trim()) == null) {
                            return AppLocalizations.of(context)!
                                .latitudNPIExplica;
                          } else {
                            return null;
                          }
                        })),
                    const SizedBox(height: 10),
                    TextFormField(
                      minLines: 1,
                      readOnly: true,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!.longitudNPI,
                          hintText: AppLocalizations.of(context)!.longitudNPI,
                          helperText: AppLocalizations.of(context)!.requerido,
                          hintMaxLines: 1,
                          hintStyle:
                              const TextStyle(overflow: TextOverflow.ellipsis)),
                      keyboardType: const TextInputType.numberWithOptions(
                          signed: true, decimal: true),
                      initialValue: widget._poi.long.toString(),
                      validator: ((value) {
                        if (value == null ||
                            value.trim().isEmpty ||
                            double.tryParse(value.trim()) == null) {
                          return AppLocalizations.of(context)!
                              .longitudNPIExplica;
                        } else {
                          return null;
                        }
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      //Fuente de información
                      //Tengo que soportar que se puedan agregar más de una fuente de información
                      maxLines: 1,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!.fuentesNPI,
                          hintText: AppLocalizations.of(context)!.fuentesNPI,
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
                            return AppLocalizations.of(context)!
                                .fuentesNPIExplica;
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
                        labelText: AppLocalizations.of(context)!.imagenNPILabel,
                        hintText: AppLocalizations.of(context)!.imagenNPILabel,
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
                            return AppLocalizations.of(context)!
                                .imagenNPIExplica;
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
                        labelText: AppLocalizations.of(context)!.licenciaNPI,
                        hintText: AppLocalizations.of(context)!.licenciaNPI,
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
                  label: Text(AppLocalizations.of(context)!.enviarNPI),
                  onPressed: () async {
                    if (thisKey.currentState!.validate()) {
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
                                      content: Text(
                                          AppLocalizations.of(context)!
                                              .infoRegistrada)));
                                  Navigator.pop(context, widget._poi);
                                },
                              ).onError((error, stackTrace) {
                                // print(error);
                                widget._poi.author = Auxiliar.userCHEST.id;
                                sMState.clearSnackBars();
                                sMState.showSnackBar(SnackBar(
                                    content: Text(AppLocalizations.of(context)!
                                        .infoRegistrada)));
                                Navigator.pop(context, widget._poi);
                              });
                            } else {
                              widget._poi.author = Auxiliar.userCHEST.id;
                              sMState.clearSnackBars();
                              sMState.showSnackBar(SnackBar(
                                  content: Text(AppLocalizations.of(context)!
                                      .infoRegistrada)));
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
