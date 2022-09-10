import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:chest/config.dart';
import 'package:chest/more_info.dart';
import 'package:chest/users.dart';
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

import 'helpers/auxiliar.dart';
import 'helpers/pois.dart';
import 'helpers/queries.dart';
import 'helpers/tasks.dart';
import 'helpers/user.dart';
import 'helpers/widget_facto.dart';
import 'main.dart';
import 'tasks.dart';

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
  late bool todoTexto, mostrarFab;
  late LatLng? pointUser;
  late StreamSubscription<Position> _strLocationUser;
  late double distance;
  late String distanceString;
  late MapController mapController;

  @override
  void initState() {
    todoTexto = false;
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
    if (widget.locationUser != null && widget.locationUser is Position) {
      checkUserLocation();
      calculateDistance();
    }
    MapOptions mapOptions = (pointUser != null)
        ? MapOptions(
            bounds: LatLngBounds(pointUser, widget.poi.point),
            boundsOptions: const FitBoundsOptions(padding: EdgeInsets.all(30)),
            interactiveFlags: InteractiveFlag.pinchZoom,
            enableScrollWheel: true,
            onMapCreated: (mC) {
              mapController = mC;
            },
          )
        : MapOptions(
            zoom: 17,
            interactiveFlags: InteractiveFlag.pinchZoom,
            enableScrollWheel: false,
            center: widget.poi.point,
            onMapCreated: (mC) {
              mapController = mC;
            },
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
    Size size = MediaQuery.of(context).size;
    double aspectRatio = 2 * (size.longestSide / size.shortestSide);
    int nColumn = MediaQuery.of(context).orientation == Orientation.landscape
        ? 2
        : size.width > 767
            ? 2
            : 1;
    String commentPoi = widget.poi.commentLang(MyApp.currentLang) ??
        widget.poi.commentLang('es') ??
        widget.poi.commentLang('')!;
    return Scaffold(
      floatingActionButton: mostrarFab
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Visibility(
                  visible: widget.poi.author == Auxiliar.userCHEST.id ||
                      Auxiliar.userCHEST.crol == Rol.admin,
                  child: FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () {},
                    label: Text(AppLocalizations.of(context)!.borrarPOI),
                  ),
                ),
                Visibility(
                    visible: widget.poi.author == Auxiliar.userCHEST.id ||
                        Auxiliar.userCHEST.crol == Rol.admin,
                    child: const SizedBox(
                      height: 10,
                    )),
                FloatingActionButton.extended(
                  heroTag: Auxiliar.mainFabHero,
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                FormTask(Task.empty(widget.poi.id)),
                            fullscreenDialog: true));
                  },
                  label: Text(AppLocalizations.of(context)!.nTask),
                )
              ],
            )
          : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            pinned: true,
            snap: false,
            floating: false,
            backgroundColor: Theme.of(context).primaryColorDark,
            leading: const BackButton(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: SizedBox(
                  width: 50000,
                  child: Text(
                    widget.poi.labelLang(MyApp.currentLang) ??
                        widget.poi.labelLang('es') ??
                        widget.poi.labelLang('')!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )),
              background: widget.poi.hasThumbnail
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
                      color: Colors.black38,
                      colorBlendMode: BlendMode.darken,
                      errorBuilder: (ctx, obj, stack) => Container(),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 10),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  SafeArea(
                    left: true,
                    right: true,
                    minimum: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Container(
                          constraints: const BoxConstraints(
                              maxHeight: 150, maxWidth: Auxiliar.MAX_WIDTH),
                          child: FlutterMap(
                            options: mapOptions,
                            children: [
                              Auxiliar.tileLayerWidget(),
                              Auxiliar.atributionWidget(),
                              PolylineLayerWidget(
                                options:
                                    PolylineLayerOptions(polylines: polylines),
                              ),
                              MarkerLayerWidget(
                                options: MarkerLayerOptions(markers: markers),
                              )
                            ],
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(
                              maxWidth: Auxiliar.MAX_WIDTH),
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
                        Container(
                          constraints: const BoxConstraints(
                              maxWidth: Auxiliar.MAX_WIDTH),
                          //padding: const EdgeInsets.only(top: 15),
                          child: Visibility(
                            visible: todoTexto,
                            child: HtmlWidget(
                              commentPoi,
                              factoryBuilder: () => MyWidgetFactory(),
                            ),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(
                              maxWidth: Auxiliar.MAX_WIDTH),
                          padding: const EdgeInsets.only(top: 15),
                          child: FutureBuilder<List>(
                            future: _getTasks(widget.poi.id),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && !snapshot.hasError) {
                                List<Task> tasks = [];
                                List<dynamic> data = snapshot.data!;
                                for (var t in data) {
                                  try {
                                    Task task = Task(
                                        t['task'],
                                        t['comment'],
                                        t['author'],
                                        t['space'],
                                        t['at'],
                                        widget.poi.id);
                                    if (t['label'] != null) {
                                      task.setLabels(t['label']);
                                    }
                                    tasks.add(task);
                                  } catch (error) {
                                    //print(error);
                                  }
                                }
                                return GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: nColumn,
                                    childAspectRatio: aspectRatio,
                                  ),
                                  itemCount: tasks.length,
                                  itemBuilder: (context, index) {
                                    Task task = tasks[index];
                                    late String title;
                                    if (task.hasLabel) {
                                      title =
                                          task.labelLang(MyApp.currentLang) ??
                                              task.labelLang('es') ??
                                              task.labelLang('')!;
                                    } else {
                                      switch (task.aT) {
                                        case AnswerType.mcq:
                                          title = AppLocalizations.of(context)!
                                              .mcqTitle;
                                          break;
                                        case AnswerType.multiplePhotos:
                                          title = AppLocalizations.of(context)!
                                              .multiplePhotosTitle;
                                          break;
                                        case AnswerType.multiplePhotosText:
                                          title = AppLocalizations.of(context)!
                                              .multiplePhotosTextTitle;
                                          break;
                                        case AnswerType.noAnswer:
                                          title = AppLocalizations.of(context)!
                                              .noAnswerTitle;
                                          break;
                                        case AnswerType.photo:
                                          title = AppLocalizations.of(context)!
                                              .photoTitle;
                                          break;
                                        case AnswerType.photoText:
                                          title = AppLocalizations.of(context)!
                                              .photoTextTitle;
                                          break;
                                        case AnswerType.text:
                                          title = AppLocalizations.of(context)!
                                              .textTitle;
                                          break;
                                        case AnswerType.tf:
                                          title = AppLocalizations.of(context)!
                                              .tfTitle;
                                          break;
                                        case AnswerType.video:
                                          title = AppLocalizations.of(context)!
                                              .videoTitle;
                                          break;
                                        case AnswerType.videoText:
                                          title = AppLocalizations.of(context)!
                                              .videoTextTitle;
                                          break;
                                        default:
                                          title = "¿?¿?¿?";
                                      }
                                    }
                                    String comment =
                                        task.commentLang(MyApp.currentLang) ??
                                            task.commentLang('es') ??
                                            task.commentLang('')!;
                                    comment = comment.replaceAll(
                                        RegExp('<[^>]*>?',
                                            multiLine: true, dotAll: true),
                                        '');
                                    return Card(
                                      child: ListTile(
                                        isThreeLine: true,
                                        leading: task.spaces.length > 1
                                            ? const Padding(
                                                padding:
                                                    EdgeInsets.only(top: 10),
                                                child: Icon(Icons.looks_two))
                                            : task.spaces[0] == Space.physical
                                                ? const Icon(
                                                    Icons.phone_android)
                                                : const Icon(Icons.computer),
                                        minLeadingWidth: 0,
                                        horizontalTitleGap: 10,
                                        visualDensity: VisualDensity
                                            .adaptivePlatformDensity,
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
                                        onTap: () {
                                          if (FirebaseAuth
                                                      .instance.currentUser ==
                                                  null ||
                                              Auxiliar.userCHEST.crol ==
                                                  Rol.guest) {
                                            //No identificado
                                            ScaffoldMessenger.of(context)
                                                .clearSnackBars();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: Text(
                                                AppLocalizations.of(context)!
                                                    .iniciaParaRealizar,
                                              ),
                                              action: SnackBarAction(
                                                label: AppLocalizations.of(
                                                        context)!
                                                    .iniciarSes,
                                                onPressed: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute<void>(
                                                      builder: (BuildContext
                                                              context) =>
                                                          const LoginUsers(),
                                                      fullscreenDialog: true),
                                                ),
                                              ),
                                            ));
                                          } else {
                                            if (Auxiliar.userCHEST.crol ==
                                                Rol.user) {
                                              //Solo usuarios con el rol de estudiante
                                              bool startTask = true;
                                              if (task.spaces.length == 1 &&
                                                  task.spaces[0] ==
                                                      Space.physical) {
                                                if (pointUser != null) {
                                                  if (distance > 100) {
                                                    startTask = false;
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .clearSnackBars();
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        backgroundColor:
                                                            Colors.red,
                                                        content: Text(
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .acercate),
                                                      ),
                                                    );
                                                  }
                                                } else {
                                                  startTask = false;
                                                  ScaffoldMessenger.of(context)
                                                      .clearSnackBars();
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                          AppLocalizations.of(
                                                                  context)!
                                                              .activaLocalizacion),
                                                      duration: const Duration(
                                                          seconds: 8),
                                                      action: SnackBarAction(
                                                        label:
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .activar,
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
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute<void>(
                                                      builder: (BuildContext
                                                              context) =>
                                                          const MoreInfo(),
                                                      fullscreenDialog: true),
                                                );
                                              }
                                            } else {
                                              if (Auxiliar.userCHEST.crol ==
                                                      Rol.teacher ||
                                                  Auxiliar.userCHEST.crol ==
                                                      Rol.admin) {
                                                ScaffoldMessenger.of(context)
                                                    .clearSnackBars();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        AppLocalizations.of(
                                                                context)!
                                                            .cambiaEstudiante),
                                                    duration: const Duration(
                                                        seconds: 8),
                                                    action: SnackBarAction(
                                                        label:
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .activar,
                                                        onPressed: () {
                                                          Auxiliar.userCHEST
                                                              .crol = Rol.user;
                                                          setState(() {
                                                            mostrarFab = Auxiliar
                                                                        .userCHEST
                                                                        .crol ==
                                                                    Rol
                                                                        .teacher ||
                                                                Auxiliar.userCHEST
                                                                        .crol ==
                                                                    Rol.admin;
                                                          });
                                                        }),
                                                  ),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context)
                                                    .clearSnackBars();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        AppLocalizations.of(
                                                                context)!
                                                            .cambiaEstudiante),
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                                    );
                                  },
                                );
                              } else {
                                if (snapshot.hasError) {
                                  //print(snapshot.error);
                                }
                                return Container();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
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
    setState(() {
      distance = Auxiliar.distance(widget.poi.point, pointUser!);
      distanceString = distance < Auxiliar.MAX_WIDTH
          ? Template('{{{metros}}}m')
              .renderString({"metros": distance.toInt().toString()})
          : Template('{{{km}}}km').renderString(
              {"km": (distance / Auxiliar.MAX_WIDTH).toStringAsFixed(2)});
    });
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
    return DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.addPOI),
          backgroundColor: Theme.of(context).primaryColorDark,
          leading: const BackButton(color: Colors.white),
          bottom: const TabBar(indicatorColor: Colors.white, tabs: [
            Tab(icon: Icon(Icons.near_me)),
            Tab(icon: Icon(Icons.public)),
            Tab(icon: Icon(Icons.draw))
          ]),
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

    return SafeArea(
        minimum: const EdgeInsets.all(10),
        child: SingleChildScrollView(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
                child: Text(
                  AppLocalizations.of(context)!.puntosYaExistentesEx,
                )),
            const SizedBox(height: 10),
            Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
                child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: pois.length,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: ((context, index) {
                      POI poi = pois[index]["poi"];
                      String distanceSrting = pois[index]["distanceString"];
                      return Card(
                        child: Container(
                            height: 150,
                            constraints: const BoxConstraints(
                                maxWidth: Auxiliar.MAX_WIDTH),
                            child: Stack(
                              children: [
                                poi.hasThumbnail
                                    ? SizedBox.expand(
                                        child: Image.network(
                                          poi.thumbnail.image.contains(
                                                  'commons.wikimedia.org')
                                              ? Template(
                                                      '{{{wiki}}}?width={{{width}}}&height={{{height}}}')
                                                  .renderString({
                                                  "wiki": poi.thumbnail.image,
                                                  "width": size.width >
                                                          Auxiliar.MAX_WIDTH
                                                      ? 800
                                                      : max(150,
                                                          size.width - 100),
                                                  "height": size.height >
                                                          Auxiliar.MAX_WIDTH
                                                      ? 800
                                                      : max(150,
                                                          size.height - 100)
                                                })
                                              : poi.thumbnail.image,
                                          color: Colors.black38,
                                          colorBlendMode: BlendMode.darken,
                                          loadingBuilder: (context, child,
                                                  loadingProgress) =>
                                              Container(
                                                  color: Theme.of(context)
                                                      .primaryColorDark,
                                                  child: child),
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, obj, stack) =>
                                              Container(
                                            color: Theme.of(context)
                                                .primaryColorDark,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        color:
                                            Theme.of(context).primaryColorDark),
                                SizedBox(
                                    width: Auxiliar.MAX_WIDTH,
                                    height: 150,
                                    child: ListTile(
                                      textColor: Colors.white,
                                      title: Text(
                                        poi.labelLang(MyApp.currentLang) ??
                                            poi.labelLang('es') ??
                                            poi.labelLang('')!,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Text(distanceSrting),
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                                builder:
                                                    (BuildContext context) =>
                                                        InfoPOI(poi),
                                                fullscreenDialog: false));
                                      },
                                    ))
                              ],
                            )),
                      );
                    })))
          ],
        )));
  }

  Widget widgetLODPois() {
    Size size = MediaQuery.of(context).size;
    return SafeArea(
        minimum: const EdgeInsets.all(10),
        child: SingleChildScrollView(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.lodPoiEx),
            const SizedBox(
              height: 10,
            ),
            Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
              child: FutureBuilder<List>(
                future: _getPoisLod(widget.point, widget.bounds),
                builder: (context, snapshot) {
                  if (snapshot.hasData && !snapshot.hasError) {
                    List<POI> pois = [];
                    List<dynamic> data = snapshot.data!;
                    for (var d in data) {
                      try {
                        POI p = POI(d['poi'], d['label'], d['comment'],
                            d['lat'], d['lng'], Auxiliar.userCHEST.id);
                        if (d['thumbnailImg'] != null &&
                            d['thumbnailImg'].toString().isNotEmpty) {
                          if (d['thumbnailLic'] != null &&
                              d['thumbnailImg'].toString().isNotEmpty) {
                            p.setThumbnail(
                                d['thumbnailImg'], d['thumbnailImg']);
                          } else {
                            p.setThumbnail(d['thumbnailImg'], null);
                          }
                        }
                        p.source = d['poi'];
                        pois.add(p);
                      } catch (e) {
                        print(e);
                      }
                    }
                    if (pois.isNotEmpty) {
                      return ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: pois.length,
                          itemBuilder: ((context, index) {
                            POI p = pois[index];
                            return Card(
                              child: Container(
                                  height: 150,
                                  constraints: const BoxConstraints(
                                      maxWidth: Auxiliar.MAX_WIDTH),
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
                                                        "wiki":
                                                            p.thumbnail.image,
                                                        "width": size.width >
                                                                Auxiliar
                                                                    .MAX_WIDTH
                                                            ? 800
                                                            : max(
                                                                150,
                                                                size.width -
                                                                    100),
                                                        "height": size.height >
                                                                Auxiliar
                                                                    .MAX_WIDTH
                                                            ? 800
                                                            : max(
                                                                150,
                                                                size.height -
                                                                    100)
                                                      })
                                                    : p.thumbnail.image,
                                                color: Colors.black38,
                                                colorBlendMode:
                                                    BlendMode.darken,
                                                loadingBuilder: (context, child,
                                                        loadingProgress) =>
                                                    Container(
                                                        color: Theme.of(context)
                                                            .primaryColorDark,
                                                        child: child),
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (ctx, obj, stack) =>
                                                        Container(
                                                  color: Theme.of(context)
                                                      .primaryColorDark,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              color: Theme.of(context)
                                                  .primaryColorDark),
                                      SizedBox(
                                          width: Auxiliar.MAX_WIDTH,
                                          height: 150,
                                          child: ListTile(
                                            textColor: Colors.white,
                                            title: Text(
                                              p.labelLang(MyApp.currentLang) ??
                                                  p.labelLang('es') ??
                                                  p.labelLang('')!,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            onTap: () {
                                              Navigator.pop(context, p);
                                            },
                                          ))
                                    ],
                                  )),
                            );
                          }));
                    } else {
                      return Container();
                    }
                  } else {
                    return Container();
                  }
                },
              ),
            )
          ],
        )));
  }

  Widget widgetPoiNew() {
    return SafeArea(
        minimum: const EdgeInsets.all(10),
        child: SingleChildScrollView(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.start, children: [
          Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
              child: Text(AppLocalizations.of(context)!.nPoiEx)),
          const SizedBox(
            height: 10,
          ),
          Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context,
                      POI.point(widget.point.latitude, widget.point.longitude));
                },
                child: Text(
                  AppLocalizations.of(context)!.addPOI,
                ),
              ))
        ])));
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
    final _thisKey = GlobalKey<FormState>();
    String? image, licenseImage;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: Auxiliar.mainFabHero,
        icon: const Icon(Icons.publish),
        label: Text(AppLocalizations.of(context)!.enviarNPI),
        onPressed: () async {
          if (_thisKey.currentState!.validate()) {
            if (image != null) {
              widget._poi.setThumbnail(image!, licenseImage);
            }
            //TODO enviar la info al servidor
            Map<String, dynamic> bodyRequest = {
              "lat": widget._poi.lat,
              "long": widget._poi.long,
              "comment": widget._poi.comments2List(),
              "label": widget._poi.labels2List()
            };
            if (image != null) {
              widget._poi.setThumbnail(image!, licenseImage);
              bodyRequest["thumbnail"] = widget._poi.thumbnail2Map();
            }
            http
                .post(
              Uri.parse(Template('{{{addr}}}/pois')
                  .renderString({'addr': Config.addServer})),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': Template('Bearer {{{token}}}').renderString({
                  'token':
                      await FirebaseAuth.instance.currentUser!.getIdToken(),
                }),
              },
              body: json.encode(bodyRequest),
            )
                .then((response) {
              switch (response.statusCode) {
                case 201:
                  String idPOI = response.headers['location']!;
                  //TODO Crear un nuevo POI para pasarselo a la pantalla del mapa a través del POI
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(AppLocalizations.of(context)!.infoRegistrada)));
                  break;
                default:
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(response.statusCode.toString())));
              }
            }).onError((error, stackTrace) {
              print(error.toString());
            });
          }
        },
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColorDark,
        leading: const BackButton(color: Colors.white),
        title: Text(AppLocalizations.of(context)!.tNPoi),
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(10),
        child: Form(
          key: _thisKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                Container(
                  //label
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
                  child: TextFormField(
                    maxLines: 1,
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: AppLocalizations.of(context)!.tituloNPI,
                        hintText: AppLocalizations.of(context)!.tituloNPI,
                        hintMaxLines: 1,
                        hintStyle:
                            const TextStyle(overflow: TextOverflow.ellipsis)),
                    textCapitalization: TextCapitalization.words,
                    keyboardType: TextInputType.text,
                    initialValue: widget._poi.labels.isEmpty
                        ? ''
                        : widget._poi.labelLang(MyApp.currentLang) ??
                            (widget._poi.labelLang('es') ??
                                (widget._poi.labelLang('') ?? '')),
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
                ),
                const SizedBox(height: 10),
                Container(
                  //comment
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
                  child: TextFormField(
                    minLines: 1,
                    maxLines: 5,
                    decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: AppLocalizations.of(context)!.descrNPI,
                        hintText: AppLocalizations.of(context)!.descrNPI,
                        hintMaxLines: 1,
                        hintStyle:
                            const TextStyle(overflow: TextOverflow.ellipsis)),
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    initialValue: widget._poi.comments.isEmpty
                        ? ''
                        : widget._poi.commentLang(MyApp.currentLang) ??
                            (widget._poi.commentLang('es') ??
                                (widget._poi.commentLang('') ?? '')),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return AppLocalizations.of(context)!.descrNPIExplica;
                      } else {
                        widget._poi
                            .addCommentLang(PairLang(MyApp.currentLang, value));
                        return null;
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  //Latitud
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
                  child: TextFormField(
                      minLines: 1,
                      readOnly: true,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!.latitudNPI,
                          hintText: AppLocalizations.of(context)!.latitudNPI,
                          hintMaxLines: 1,
                          hintStyle:
                              const TextStyle(overflow: TextOverflow.ellipsis)),
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
                ),
                const SizedBox(height: 10),
                Container(
                  //Longitud
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
                  child: TextFormField(
                      minLines: 1,
                      readOnly: true,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: AppLocalizations.of(context)!.longitudNPI,
                          hintText: AppLocalizations.of(context)!.longitudNPI,
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
                      })),
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
                  initialValue: widget._poi.hasSource ? widget._poi.source : '',
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      if (v.trim().isEmpty) {
                        return AppLocalizations.of(context)!.fuentesNPIExplica;
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
                    hintStyle: const TextStyle(overflow: TextOverflow.ellipsis),
                  ),
                  initialValue: widget._poi.hasThumbnail
                      ? widget._poi.thumbnail.image
                      : "",
                  keyboardType: TextInputType.url,
                  textCapitalization: TextCapitalization.none,
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      if (Uri.tryParse(v.trim()) == null) {
                        return AppLocalizations.of(context)!.imagenNPIExplica;
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
                    hintStyle: const TextStyle(overflow: TextOverflow.ellipsis),
                  ),
                  initialValue: widget._poi.hasThumbnail
                      ? widget._poi.thumbnail.image
                      : "",
                  keyboardType: TextInputType.url,
                  textCapitalization: TextCapitalization.none,
                  validator: (v) {
                    if (v != null && v.isNotEmpty) {
                      if (Uri.tryParse(v.trim()) == null) {
                        return AppLocalizations.of(context)!.licenciaNPIExplica;
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
    );
  }
}
