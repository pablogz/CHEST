import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:mustache_template/mustache.dart';

import 'package:chest/helpers/auxiliar.dart';
import 'package:chest/helpers/itineraries.dart';
import 'package:chest/helpers/map_data.dart';
import 'package:chest/helpers/pois.dart';
import 'package:chest/helpers/queries.dart';
import 'package:chest/helpers/tasks.dart';
import 'package:chest/main.dart';
import 'package:chest/pois.dart';
import 'package:chest/tasks.dart';

class NewItinerary extends StatefulWidget {
  // final List<POI> pois;
  final LatLng initPoint;
  final double initZoom;
  const NewItinerary(/*this.pois, */ this.initPoint, this.initZoom,
      {super.key});
  @override
  State<StatefulWidget> createState() => _NewItinerary();
}

class _NewItinerary extends State<NewItinerary> {
  late int _index;
  late GlobalKey<FormState> _keyStep0, _keyStep2;
  late Itinerary _newIt;
  // late List<bool> _markersPress;
  //late List<String> _markersPress;
  late List<List<bool>> _tasksPress;
  late List<List<Task>> _tasksProcesadas, _tasksSeleccionadas;
  late List<POI> _pointS;
  late bool _ordenPoi, /*_start,*/ _ordenTasks, _enableBt;
  late List<Marker> _myMarkers;
  final MapController _mapController = MapController();
  late List<PointItinerary> _pointsItinerary;
  late int _numPoiSelect, _numTaskSelect, _lastMapEventScrollWheelZoom;
  late StreamSubscription<MapEvent> strSubMap;

  @override
  void initState() {
    // _start = true;
    _index = 0;
    _keyStep0 = GlobalKey<FormState>();
    _keyStep2 = GlobalKey<FormState>();
    _newIt = Itinerary.empty();
    // _markersPress = [];
    // for (int i = 0, tama = widget.pois.length; i < tama; i++) {
    //   _markersPress.add(false);
    // }
    _pointS = [];
    _ordenPoi = false;
    _myMarkers = [];
    _pointsItinerary = [];
    _tasksPress = [];
    _tasksProcesadas = [];
    _tasksSeleccionadas = [];
    _ordenTasks = false;
    _numPoiSelect = 0;
    _numTaskSelect = 0;
    _enableBt = true;
    //_markersPress = [];
    _lastMapEventScrollWheelZoom = 0;
    strSubMap = _mapController.mapEventStream
        .where((event) =>
            event is MapEventMoveEnd ||
            event is MapEventDoubleTapZoomEnd ||
            event is MapEventScrollWheelZoom)
        .listen((event) {
      if (event is MapEventScrollWheelZoom) {
        int current = DateTime.now().millisecondsSinceEpoch;
        if (_lastMapEventScrollWheelZoom + 200 < current) {
          _lastMapEventScrollWheelZoom = current;
          createMarkers();
        }
      } else {
        createMarkers();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    StepperType stepperType =
        MediaQuery.of(context).orientation == Orientation.landscape &&
                MediaQuery.of(context).size.aspectRatio > 0.9
            ? StepperType.horizontal
            : StepperType.vertical;
    return Scaffold(
      appBar: AppBar(
        title: _index == 1
            ? _numPoiSelect == 0
                ? Text(AppLocalizations.of(context)!.agregarIt)
                : Text(
                    Template('{{{numTaskSelect}}} {{{text}}}').renderString({
                      "numTaskSelect": _numPoiSelect,
                      "text": _numPoiSelect == 1
                          ? AppLocalizations.of(context)!.seleccionado
                          : AppLocalizations.of(context)!.seleccionados
                    }),
                    textAlign: TextAlign.end,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge!
                        .copyWith(color: Colors.white),
                  )
            : _index == 3
                ? _numTaskSelect == 0
                    ? Text(AppLocalizations.of(context)!.agregarIt)
                    : Text(
                        Template('{{{numTaskSelect}}} {{{text}}}')
                            .renderString({
                          "numTaskSelect": _numTaskSelect,
                          "text": _numTaskSelect == 1
                              ? AppLocalizations.of(context)!.seleccionada
                              : AppLocalizations.of(context)!.seleccionadas
                        }),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge!
                            .copyWith(color: Colors.white),
                      )
                : Text(AppLocalizations.of(context)!.agregarIt),
        backgroundColor: _index == 1 && _numPoiSelect > 0
            ? Theme.of(context).brightness == Brightness.light
                ? Colors.black87
                : Theme.of(context).indicatorColor.withOpacity(0.8)
            : _index == 3 && _numTaskSelect > 0
                ? Theme.of(context).brightness == Brightness.light
                    ? Colors.black87
                    : Theme.of(context).indicatorColor.withOpacity(0.8)
                : Theme.of(context).appBarTheme.backgroundColor,
        leading: _index == 1
            ? _numPoiSelect == 0
                // ? const BackButton(color: Colors.white)
                ? null
                : InkWell(
                    child: const Icon(Icons.close, color: Colors.white),
                    onTap: () {
                      setState(() {
                        // for (int i = 0, tama = _markersPress.length;
                        //     i < tama;
                        //     i++) {
                        //   _markersPress[i] = false;
                        // }
                        _numPoiSelect = 0;
                        _pointS = [];
                      });
                      createMarkers();
                    },
                  )
            : _index == 3
                ? _numTaskSelect == 0
                    // ? const BackButton(color: Colors.white)
                    ? null
                    : InkWell(
                        child: const Icon(Icons.close, color: Colors.white),
                        onTap: () {
                          setState(() {
                            for (int i = 0, tama = _tasksPress.length;
                                i < tama;
                                i++) {
                              List<bool> tp = _tasksPress[i];
                              for (int j = 0, tama2 = tp.length;
                                  j < tama2;
                                  j++) {
                                _tasksPress[i][j] = false;
                              }
                              _tasksSeleccionadas[i] = [];
                            }
                            _numTaskSelect = 0;
                          });
                        },
                      )
                // : const BackButton(color: Colors.white),
                : null,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          child: Stepper(
            type: stepperType,
            currentStep: _index,
            controlsBuilder: (BuildContext context, ControlsDetails details) {
              switch (details.currentStep) {
                case 0:
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton(
                          onPressed: details.onStepContinue,
                          child: Text(AppLocalizations.of(context)!.siguiente),
                        ),
                      ],
                    ),
                  );
                case 4:
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: Text(AppLocalizations.of(context)!.atras),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _enableBt ? details.onStepContinue : null,
                          child: _enableBt
                              ? Text(AppLocalizations.of(context)!.finalizar)
                              : const CircularProgressIndicator(),
                        ),
                      ],
                    ),
                  );
                default:
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: Text(AppLocalizations.of(context)!.atras),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: details.onStepContinue,
                          child: Text(AppLocalizations.of(context)!.siguiente),
                        ),
                      ],
                    ),
                  );
              }
            },
            onStepCancel: () {
              if (_index > 0) {
                setState(() {
                  --_index;
                });
              }
            },
            onStepContinue: () async {
              if (_index < 4) {
                late bool sigue;
                switch (_index) {
                  case 0:
                    sigue = _keyStep0.currentState!.validate();
                    break;
                  case 1:
                    sigue = _pointS.isNotEmpty;
                    if (!sigue) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.red,
                          content: Text(
                            AppLocalizations.of(context)!.errorSeleccionaUnPoi,
                          ),
                        ),
                      );
                    }
                    break;
                  case 2:
                    _keyStep2.currentState!.validate();
                    List<Future> queries = [];
                    for (POI poi in _pointS) {
                      queries.add(_getTasks(poi.id));
                    }
                    List<dynamic> data = await Future.wait(queries);
                    _tasksPress = [];
                    _tasksProcesadas = [];
                    _numTaskSelect = 0;
                    _tasksSeleccionadas = [];
                    for (int i = 0, tama = _pointS.length; i < tama; i++) {
                      POI poi = _pointS[i];
                      List<dynamic> tareasSinProcesar = data[i];
                      List<Task> tareasProcesadas = [];
                      List<bool> tPress = [];
                      for (var t in tareasSinProcesar) {
                        Task task = Task(t['task'], t['comment'], t['author'],
                            t['space'], t['at'], poi.id);
                        if (t['label'] != null) {
                          task.setLabels(t['label']);
                        }
                        tareasProcesadas.add(task);
                        tPress.add(false);
                      }
                      _tasksPress.add(tPress);
                      _tasksProcesadas.add(tareasProcesadas);
                      _tasksSeleccionadas.add([]);
                    }
                    sigue = true;
                    break;
                  case 3:
                    sigue = true;
                    // Pueden existir itinerarios sin tareas seleccionadas (los de visita)
                    // for (List<Task> lt in _tasksSeleccionadas) {
                    //   if (lt.isEmpty) {
                    //     sigue = false;
                    //     ScaffoldMessenger.of(context).clearSnackBars();
                    //     ScaffoldMessenger.of(context).showSnackBar(
                    //       SnackBar(
                    //         backgroundColor: Colors.red,
                    //         content: Text(
                    //           AppLocalizations.of(context)!
                    //               .errorSeleccionaUnaTarea,
                    //         ),
                    //       ),
                    //     );
                    //     break;
                    //   }
                    // }
                    break;
                  default:
                    throw Exception();
                }
                if (sigue) {
                  setState(() {
                    ++_index;
                  });
                }
              } else {
                if (_index == 4) {
                  //Bloqueo el botón antes de continuar ya que me voy a comunicar con el servidor
                  setState(() => _enableBt = false);
                  //Agrego los PointIteneray al itinerario
                  for (int i = 0, tama = _pointS.length; i < tama; i++) {
                    List<Task> tasks = _tasksSeleccionadas[i];
                    for (Task task in tasks) {
                      _pointsItinerary[i].addTask(task.id);
                    }
                  }
                  _newIt.points = _pointsItinerary;
                  if (_ordenPoi) {
                    _newIt.type = "order";
                  } else {
                    if (_ordenTasks) {
                      _newIt.type = "orderPoi";
                    } else {
                      _newIt.type = "noOrder";
                    }
                  }
                  //Envío la información al servidor
                  Map<String, dynamic> bodyRequest = {
                    "type": _newIt.type!.name,
                    "label": _newIt.labels2List(),
                    "comment": _newIt.comments2List(),
                    "points": _newIt.points2List()
                  };
                  http
                      .post(Queries().newItinerary(),
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization':
                                Template('Bearer {{{token}}}').renderString({
                              'token': await FirebaseAuth.instance.currentUser!
                                  .getIdToken(),
                            })
                          },
                          body: json.encode(bodyRequest))
                      .then((response) {
                    switch (response.statusCode) {
                      case 201:
                        //Vuelvo a la pantalla anterior. True para que recargue (adaptar la anterior)
                        String idIt = response.headers['location']!;
                        _newIt.id = idIt;
                        _newIt.author = Auxiliar.userCHEST.id;
                        Navigator.pop(context, _newIt);
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(AppLocalizations.of(context)!
                                  .infoRegistrada)),
                        );
                        break;
                      default:
                        setState(() => _enableBt = true);

                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(response.statusCode.toString())));
                    }
                  }).onError((error, stackTrace) {
                    setState(() => _enableBt = true);
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text("Error")));
                    //print(error.toString());
                  });
                }
              }
            },
            onStepTapped: (index) {
              if (index < _index) {
                setState(() {
                  _index = index;
                });
              }
            },
            steps: [
              Step(
                title: Text(AppLocalizations.of(context)!.infoGeneral),
                state: _index == 0 ? StepState.editing : StepState.complete,
                isActive: _index == 0,
                content: contentStep0(),
              ),
              Step(
                title: Text(AppLocalizations.of(context)!.puntosIt),
                state: _index < 1
                    ? StepState.disabled
                    : _index == 1
                        ? StepState.editing
                        : StepState.complete,
                isActive: _index == 1,
                content: contentStep1(),
              ),
              Step(
                title: Text(AppLocalizations.of(context)!.ordenPuntosIt),
                state: _index < 2
                    ? StepState.disabled
                    : _index == 2
                        ? StepState.editing
                        : StepState.complete,
                isActive: _index == 2,
                content: contentStep2(),
              ),
              Step(
                title: Text(AppLocalizations.of(context)!.tareasIt),
                state: _index < 3
                    ? StepState.disabled
                    : _index == 3
                        ? StepState.editing
                        : StepState.complete,
                isActive: _index == 3,
                content: contentStep3(),
              ),
              Step(
                title: Text(AppLocalizations.of(context)!.ordenTareas),
                state: _index < 4
                    ? StepState.disabled
                    : _index == 4
                        ? StepState.editing
                        : StepState.complete,
                isActive: _index == 4,
                content: contentStep4(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void createMarkers() async {
    _myMarkers = [];
    ThemeData td = Theme.of(context);
    if (_mapController.bounds != null) {
      List<POI> listPoi =
          await MapData.checkCurrentMapSplit(_mapController.bounds!);
      for (int i = 0, tama = listPoi.length; i < tama; i++) {
        POI p = listPoi.elementAt(i);
        Container icono;

        final String intermedio =
            p.labels.first.value.replaceAllMapped(RegExp(r'[^A-Z]'), (m) => "");
        final String iniciales =
            intermedio.substring(0, min(3, intermedio.length));
        bool pulsado = _pointS.indexWhere((POI poi) => poi.id == p.id) > -1;

        if (p.hasThumbnail == true &&
            p.thumbnail.image
                .contains('commons.wikimedia.org/wiki/Special:FilePath/')) {
          String imagen = p.thumbnail.image;
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
                color: pulsado ? td.primaryColorDark : Colors.grey,
                width: pulsado ? 3 : 2,
              ),
              color: pulsado ? td.primaryColor : null,
              image: pulsado
                  ? null
                  : DecorationImage(
                      image: Image.network(
                        imagen,
                        errorBuilder: (context, error, stack) => Container(
                          color: Colors.grey[300]!,
                          child: Center(
                              child:
                                  Text(iniciales, textAlign: TextAlign.center)),
                        ),
                      ).image,
                      fit: BoxFit.cover),
            ),
            child: pulsado
                ? Center(
                    child: Text(
                      iniciales,
                      textAlign: TextAlign.center,
                      style: pulsado
                          ? td.textTheme.bodyLarge!
                              .copyWith(color: Colors.white)
                          : td.textTheme.bodyLarge,
                    ),
                  )
                : null,
          );
        } else {
          icono = Container(
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: pulsado ? td.primaryColorDark : Colors.grey,
                    width: pulsado ? 3 : 2),
                color: pulsado ? td.primaryColor : Colors.grey[300]!),
            width: 52,
            height: 52,
            child: Center(
              child: Text(
                iniciales,
                textAlign: TextAlign.center,
                style: pulsado
                    ? td.textTheme.bodyLarge!.copyWith(color: Colors.white)
                    : td.textTheme.bodyLarge,
              ),
            ),
          );
        }

        _myMarkers.add(
          Marker(
            width: 52,
            height: 52,
            point: LatLng(p.lat, p.long),
            builder: (context) => Tooltip(
              message: p.labelLang(MyApp.currentLang) ?? p.labelLang("es"),
              child: InkWell(
                onTap: () {
                  int press = _pointS.indexWhere((POI poi) => poi.id == p.id);
                  if (press > -1) {
                    _pointS.removeAt(press);
                    setState(() => --_numPoiSelect);
                  } else {
                    _pointS.add(p);
                    setState(() => ++_numPoiSelect);
                  }
                  createMarkers();
                },
                child: icono,
              ),
            ),
          ),
        );
      }
      setState(() {});
    }
  }

  Future<List> _getTasks(String idPoi) {
    return http.get(Queries().getTasks(idPoi)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Widget contentStep0() {
    //Info Itinerary
    return Form(
      key: _keyStep0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 5),
          TextFormField(
            maxLines: 1,
            decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: AppLocalizations.of(context)!.tituloIt,
                hintText: AppLocalizations.of(context)!.tituloIt,
                hintMaxLines: 1,
                hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            validator: (v) {
              if (v != null && v.trim().isNotEmpty) {
                _newIt.labels = {"value": v.trim(), "lang": MyApp.currentLang};
                return null;
              } else {
                return AppLocalizations.of(context)!.tituloItError;
              }
            },
          ),
          const SizedBox(height: 10),
          TextFormField(
            maxLines: 7,
            minLines: 3,
            decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: AppLocalizations.of(context)!.descriIt,
                hintText: AppLocalizations.of(context)!.descriIt,
                hintMaxLines: 1,
                hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            validator: (v) {
              if (v != null && v.trim().isNotEmpty) {
                _newIt.comments = {
                  "value": v.trim(),
                  "lang": MyApp.currentLang
                };
                return null;
              } else {
                return AppLocalizations.of(context)!.descriItError;
              }
            },
          ),
        ],
      ),
    );
  }

  Widget contentStep1() {
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.infoAccionSeleccionMarkers),
          const SizedBox(height: 10),
          Container(
            constraints: BoxConstraints(
                maxWidth: Auxiliar.maxWidth,
                maxHeight: max(MediaQuery.of(context).size.height - 300, 200)),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                maxZoom: Auxiliar.maxZoom,
                minZoom: 13,
                center: widget.initPoint,
                zoom: widget.initZoom,
                keepAlive: false,
                interactiveFlags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.pinchMove,
                enableScrollWheel: true,
                // onPositionChanged: ((position, hasGesture) {
                //   //if (!hasGesture && _start) {
                //   //_start = false;
                //   createMarkers2();
                //   //}
                // }),
                onMapReady: () => createMarkers(),
                /*onMapCreated: (mC) {
                  _mapController = mC;
                  _mapController.onReady.then((value) => null);
                },*/
                onLongPress: (tapPosition, point) async {
                  List<POI> pois = await MapData.checkCurrentMapSplit(
                      _mapController.bounds!);
                  POI? createPoi = await Navigator.push(
                    context,
                    MaterialPageRoute<POI>(
                      builder: (BuildContext context) =>
                          NewPoi(point, _mapController.bounds!, pois),
                      fullscreenDialog: true,
                    ),
                  );
                  if (createPoi is POI) {
                    POI? newPOI = await Navigator.push(
                        context,
                        MaterialPageRoute<POI>(
                            builder: (BuildContext context) =>
                                FormPOI(createPoi),
                            fullscreenDialog: false));
                    if (newPOI is POI) {
                      //widget.pois.add(newPOI);
                      // _markersPress.add(false);
                      //createMarkers();
                      MapData.addPoi2Tile(newPOI);
                      createMarkers();
                    }
                  }
                },
                pinchMoveThreshold: 2.0,
                // plugins: [MarkerClusterPlugin()],
              ),
              children: [
                Auxiliar.tileLayerWidget(
                    brightness: Theme.of(context).brightness),
                Auxiliar.atributionWidget(),
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
                      int nPul = 0;
                      for (Marker marker in markers) {
                        int index = _pointS
                            .indexWhere((POI poi) => poi.point == marker.point);
                        if (index > -1) {
                          // if (_markersPress.contains(widget.pois[index].id)) {
                          //   ++nPul;
                          // }
                          ++nPul;
                        }
                      }

                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(52),
                          border:
                              Border.all(color: Colors.grey[900]!, width: 2),
                          color: nPul == tama
                              ? Theme.of(context).primaryColor
                              : nPul == 0
                                  ? Colors.grey[700]!
                                  : Colors.pink[100]!,
                        ),
                        child: Center(
                          child: Text(
                            markers.length.toString(),
                            style: TextStyle(
                                color: nPul == tama || nPul == 0
                                    ? Colors.white
                                    : Colors.black),
                          ),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget contentStep2() {
    return Container(
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            header: SwitchListTile(
              value: _ordenPoi,
              onChanged: (v) {
                setState(() {
                  _ordenPoi = v;
                });
              },
              title: Text(
                AppLocalizations.of(context)!.establecerOrdenPoi,
              ),
            ),
            itemCount: _pointS.length,
            itemBuilder: (context, index) {
              return Card(
                key: Key('$index'),
                child: ListTile(
                  leading: _ordenPoi ? Text((index + 1).toString()) : null,
                  minLeadingWidth: 0,
                  title: Text(
                    _pointS[index].labelLang(MyApp.currentLang) ??
                        _pointS[index].labelLang("es") ??
                        _pointS[index].labels.first.value,
                  ),
                ),
              );
            },
            onReorder: (oldIndex, newIndex) {
              if (_ordenPoi) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final POI item = _pointS.removeAt(oldIndex);
                  _pointS.insert(newIndex, item);
                });
              }
            },
            buildDefaultDragHandles: _ordenPoi,
          ),
          const SizedBox(height: 10),
          Text(AppLocalizations.of(context)!.infoPersonalizarDescrip),
          const SizedBox(height: 10),
          Form(
            key: _keyStep2,
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _pointS.length,
              itemBuilder: (context, index) {
                POI poi = _pointS[index];
                return ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: [
                    Text(
                      poi.labelLang(MyApp.currentLang) ??
                          poi.labelLang("es") ??
                          poi.labels.first.value,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      maxLines: 7,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: poi.commentLang(MyApp.currentLang) ??
                              poi.commentLang("es") ??
                              poi.comments.first.value,
                          hintMaxLines: 7,
                          hintStyle:
                              const TextStyle(overflow: TextOverflow.ellipsis)),
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      validator: (v) {
                        _pointsItinerary
                            .removeWhere((pit) => pit.idPoi == poi.id);
                        if (v != null && v.trim().isNotEmpty) {
                          _pointsItinerary.add(PointItinerary.poiAltComment(
                              poi.id,
                              {"value": v.trim(), "lang": MyApp.currentLang}));
                        } else {
                          _pointsItinerary.add(PointItinerary.onlyPoi(poi.id));
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget contentStep3() {
    return Container(
        alignment: Alignment.centerLeft,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          children: [
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _pointS.length,
              itemBuilder: (context, index) {
                POI poi = _pointS[index];
                if (_tasksProcesadas.length == _pointS.length) {
                  List<Task> tasks = _tasksProcesadas[index];
                  return ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            flex: 2,
                            child: Text(
                              poi.labelLang(MyApp.currentLang) ??
                                  poi.labelLang("es") ??
                                  poi.labels.first.value,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Flexible(
                            flex: 1,
                            child: OutlinedButton(
                              child: Text(
                                AppLocalizations.of(context)!.agregarTarea,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () async {
                                Task? newTask = await Navigator.push(
                                    context,
                                    MaterialPageRoute<Task>(
                                        builder: (BuildContext context) =>
                                            FormTask(Task.empty(poi.id)),
                                        fullscreenDialog: true));
                                if (newTask != null) {
                                  //Agrego la tarea a las existentes del poi y actualizo la vista
                                  setState(() {
                                    _tasksPress[index].add(false);
                                    _tasksProcesadas[index].add(newTask);
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 5,
                      ),
                      ListView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: tasks.length,
                        itemBuilder: (context, indexT) {
                          Task task = tasks[indexT];
                          return Card(
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  color: _tasksPress[index][indexT]
                                      ? Theme.of(context).primaryColor
                                      : Theme.of(context).cardColor,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              color: _tasksPress[index][indexT]
                                  ? Theme.of(context).primaryColorLight
                                  : Theme.of(context).cardColor,
                              child: ListTile(
                                title: Text(
                                    (task.commentLang(MyApp.currentLang) ??
                                            task.commentLang("es") ??
                                            task.comments.first.value)
                                        .replaceAll(
                                            RegExp('<[^>]*>?',
                                                multiLine: true, dotAll: true),
                                            '')),
                                onTap: () {
                                  if (_tasksPress[index][indexT]) {
                                    _tasksSeleccionadas[index].removeWhere(
                                        (Task t) => t.id == task.id);
                                    setState(() => --_numTaskSelect);
                                  } else {
                                    _tasksSeleccionadas[index].add(task);
                                    setState(() => ++_numTaskSelect);
                                  }
                                  setState(() {
                                    _tasksPress[index][indexT] =
                                        !_tasksPress[index][indexT];
                                  });
                                },
                              ));
                        },
                      ),
                      const SizedBox(
                        height: 15,
                      ),
                    ],
                  );
                } else {
                  return Container();
                }
              },
            ),
            /*const SizedBox(height: 20),
            Text(
              Template('{{{textNumTasks}}}: {{{numTaskSelect}}}').renderString({
                "textNumTasks":
                    AppLocalizations.of(context)!.textNumeroTareasIt,
                "numTaskSelect": _numTaskSelect
              }),
              textAlign: TextAlign.end,
            ),*/
            const SizedBox(height: 10),
          ],
        ));
  }

  Widget contentStep4() {
    return Container(
      alignment: Alignment.centerLeft,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          SwitchListTile(
            value: _ordenPoi || _ordenTasks,
            onChanged: _ordenPoi
                ? null
                : (v) {
                    setState(() => _ordenTasks = v);
                  },
            title: Text(
              AppLocalizations.of(context)!.establecerOrdenPoi,
            ),
          ),
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _pointS.length,
            itemBuilder: (context, index) {
              POI poi = _pointS[index];
              if (_tasksSeleccionadas.length == _pointS.length) {
                List<Task> sT = _tasksSeleccionadas[index];
                return ReorderableListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  header: Text(
                    poi.labelLang(MyApp.currentLang) ??
                        poi.labelLang("es") ??
                        poi.labels.first.value,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  itemCount: sT.length,
                  itemBuilder: (context, indexT) => Card(
                    key: Key('$indexT'),
                    child: ListTile(
                      leading: _ordenPoi || _ordenTasks
                          ? Text((indexT + 1).toString())
                          : null,
                      minLeadingWidth: 0,
                      title: Text(
                        (sT[indexT].commentLang(MyApp.currentLang) ??
                                sT[indexT].commentLang("es") ??
                                sT[indexT].comments.first.value)
                            .replaceAll(
                                RegExp('<[^>]*>?',
                                    multiLine: true, dotAll: true),
                                ''),
                      ),
                    ),
                  ),
                  onReorder: (oldIndex, newIndex) {
                    if (_ordenPoi || _ordenTasks) {
                      setState(() {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final Task item =
                            _tasksSeleccionadas[index].removeAt(oldIndex);
                        _tasksSeleccionadas[index].insert(newIndex, item);
                      });
                    }
                  },
                  footer: SizedBox(
                      height: 20,
                      child:
                          index < _pointS.length - 1 ? const Divider() : null),
                  buildDefaultDragHandles: _ordenPoi || _ordenTasks,
                );
              } else {
                return Container();
              }
            },
          ),
        ],
      ),
    );
  }
}

class InfoItinerary extends StatefulWidget {
  final Itinerary itinerary;
  const InfoItinerary(this.itinerary, {super.key});

  @override
  State<StatefulWidget> createState() => _InfoItinerary();
}

class _InfoItinerary extends State<InfoItinerary> {
  Future<Map> _getItinerary(idIt) {
    return http.get(Queries().getItinerary(idIt)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : {});
  }

  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // leading: const BackButton(color: Colors.white),
        title: Text(widget.itinerary.labelLang(MyApp.currentLang) ??
            widget.itinerary.labelLang("es") ??
            AppLocalizations.of(context)!.descrIt),
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(10),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
            child: CustomScrollView(
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      switch (index) {
                        case 0: //DESCRIPCIÓN
                          return Text(
                              widget.itinerary.commentLang(MyApp.currentLang) ??
                                  widget.itinerary.commentLang("es") ??
                                  widget.itinerary.comments.first.value);
                        case 2: //MAPA con DISTANCIA ESTIMADA
                          return FutureBuilder(
                            future: _getItinerary(widget.itinerary.id),
                            builder: ((context, snapshot) {
                              if (!snapshot.hasError && snapshot.hasData) {
                                Object? body = snapshot.data;
                                if (body != null &&
                                    body is Map &&
                                    body.keys.contains("points")) {
                                  List points = body["points"];
                                  List<PointItinerary> pointsIt = [];
                                  List<Marker> markers = [];
                                  double maxLat = -90,
                                      minLat = 90,
                                      maxLong = -180,
                                      minLong = 180;

                                  for (Map<String, dynamic> point in points) {
                                    PointItinerary pIt =
                                        PointItinerary.onlyPoi(point["poi"]);
                                    pIt.poiObj = POI(
                                        point["poi"],
                                        point["label"],
                                        point["comment"],
                                        point["lat"],
                                        point["long"],
                                        point["author"]);
                                    if (point.keys.contains("altComment")) {
                                      pIt.altComments = point["altComment"];
                                    }
                                    pointsIt.add(pIt);
                                  }
                                  widget.itinerary.points = pointsIt;
                                  switch (widget.itinerary.type) {
                                    case ItineraryType.order:
                                      PointItinerary point =
                                          widget.itinerary.points.first;
                                      maxLat = point.poiObj.lat;
                                      minLat = maxLat;
                                      minLong = point.poiObj.long;
                                      maxLong = minLong;
                                      markers.add(
                                        Marker(
                                          width: 52,
                                          height: 52,
                                          point: LatLng(
                                            point.poiObj.lat,
                                            point.poiObj.long,
                                          ),
                                          builder: (context) {
                                            return Tooltip(
                                              message: point.poiObj.labelLang(
                                                      MyApp.currentLang) ??
                                                  point.poiObj
                                                      .labelLang("es") ??
                                                  point.poiObj.labels.first
                                                      .value,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Theme.of(context)
                                                        .primaryColor),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.start,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                      break;
                                    default:
                                      for (PointItinerary point
                                          in widget.itinerary.points) {
                                        if (point.poiObj.lat > maxLat) {
                                          maxLat = point.poiObj.lat;
                                        }
                                        if (point.poiObj.lat < minLat) {
                                          minLat = point.poiObj.lat;
                                        }
                                        if (point.poiObj.long > maxLong) {
                                          maxLong = point.poiObj.long;
                                        }
                                        if (point.poiObj.long < minLong) {
                                          minLong = point.poiObj.long;
                                        }
                                        markers.add(
                                          Marker(
                                            width: 26,
                                            height: 26,
                                            point: LatLng(
                                              point.poiObj.lat,
                                              point.poiObj.long,
                                            ),
                                            builder: (context) {
                                              return Tooltip(
                                                message: point.poiObj.labelLang(
                                                        MyApp.currentLang) ??
                                                    point.poiObj
                                                        .labelLang("es") ??
                                                    point.poiObj.labels.first
                                                        .value,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Theme.of(context)
                                                          .primaryColor),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      }
                                  }
                                  double distancia = 0;
                                  List<Card> pois = [];
                                  List<PointItinerary> pIt =
                                      widget.itinerary.points;
                                  List<Polyline> polylines = [];
                                  switch (widget.itinerary.type) {
                                    case ItineraryType.order:
                                      for (int i = 1, tama = pIt.length;
                                          i < tama;
                                          i++) {
                                        distancia += Auxiliar.distance(
                                            pIt[i].poiObj.point,
                                            pIt[i - 1].poiObj.point);
                                      }
                                      pois.add(
                                        Card(
                                          child: ListTile(
                                            title: Text(widget.itinerary.points
                                                    .first.poiObj
                                                    .labelLang(
                                                        MyApp.currentLang) ??
                                                widget.itinerary.points.first
                                                    .poiObj
                                                    .labelLang("es") ??
                                                widget.itinerary.points.first
                                                    .poiObj.labels.first.value),
                                          ),
                                        ),
                                      );
                                      break;
                                    default:
                                      List<List<double>> matrixPIt = [];
                                      List<double> d = [];
                                      //Calculo "todas" las distancias entre los puntos del itinerario
                                      //teniendo en cuenta que habrá valores que se repitan
                                      double vMin = 999999999999;
                                      for (int i = 0, tama = pIt.length;
                                          i < tama;
                                          i++) {
                                        d = [];
                                        bool primera = true;
                                        for (int j = 0; j < tama; j++) {
                                          if (i == j) {
                                            primera = false;
                                          }
                                          if (primera) {
                                            for (int z = 0; z < i; z++) {
                                              d.add(matrixPIt[z][i]);
                                              ++j;
                                            }
                                            --j;
                                            primera = false;
                                          } else {
                                            if (i == j) {
                                              d.add(0);
                                            } else {
                                              double v = Auxiliar.distance(
                                                  pIt[i].poiObj.point,
                                                  pIt[j].poiObj.point);
                                              d.add(v);
                                              if (v < vMin) {
                                                vMin = v;
                                              }
                                            }
                                          }
                                        }
                                        matrixPIt.add(d);
                                      }
                                      // Calculo que puntos son los extremos del mapa
                                      double dMax = -1;
                                      late int iMax, jMax;
                                      for (int i = 0,
                                              tama = widget
                                                  .itinerary.points.length;
                                          i < tama;
                                          i++) {
                                        for (int j = 0; j < tama; j++) {
                                          if (matrixPIt[i][j] > dMax) {
                                            dMax = matrixPIt[i][j];
                                            iMax = i;
                                            jMax = j;
                                          }
                                        }
                                      }
                                      Map<String, dynamic> r1, r2;
                                      r1 = calculeRoute(
                                          pIt, matrixPIt, iMax, dMax);
                                      r2 = calculeRoute(
                                          pIt, matrixPIt, jMax, dMax);
                                      if (r1["distancia"] < r2["distancia"]) {
                                        distancia = r1["distancia"];
                                        polylines.addAll(r1["polylines"]);
                                      } else {
                                        distancia = r2["distancia"];
                                        polylines.addAll(r2["polylines"]);
                                      }
                                      for (PointItinerary p
                                          in widget.itinerary.points) {
                                        pois.add(
                                          Card(
                                            child: ListTile(
                                              title: Text((p.poiObj.labelLang(
                                                          MyApp.currentLang) ??
                                                      p.poiObj
                                                          .labelLang("es")) ??
                                                  p.poiObj.labels.first.value),
                                            ),
                                          ),
                                        );
                                      }
                                  }
                                  Column cPois = Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: pois,
                                  );
                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Text(
                                            Template("{{{m}}}: {{{v}}}{{{u}}}")
                                                .renderString(
                                              {
                                                "m": AppLocalizations.of(
                                                        context)!
                                                    .distanciaAproxIt,
                                                "v": (distancia > 1000)
                                                    ? (distancia / 1000)
                                                        .toStringAsFixed(2)
                                                    : distancia.toInt(),
                                                "u": (distancia > 1000)
                                                    ? "km"
                                                    : "m"
                                              },
                                            ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                            textAlign: TextAlign.end,
                                          ),
                                          Tooltip(
                                            message:
                                                Template("{{{ms}}}{{{mo}}}")
                                                    .renderString({
                                              "ms":
                                                  AppLocalizations.of(context)!
                                                      .explicaDistancia,
                                              "mo": widget.itinerary.type ==
                                                      ItineraryType.order
                                                  ? ''
                                                  : Template(" {{{m}}}")
                                                      .renderString({
                                                      "m": AppLocalizations.of(
                                                              context)!
                                                          .explicaRutaSugerida
                                                    })
                                            }),
                                            showDuration: Duration(
                                                seconds:
                                                    widget.itinerary.type ==
                                                            ItineraryType.order
                                                        ? 2
                                                        : 4),
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 5),
                                              child: Icon(
                                                Icons.info,
                                                color: Theme.of(context)
                                                    .primaryColorLight,
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        constraints: BoxConstraints(
                                          maxWidth: Auxiliar.maxWidth,
                                          maxHeight: min(
                                              max(
                                                  MediaQuery.of(context)
                                                          .size
                                                          .height -
                                                      300,
                                                  150),
                                              300),
                                        ),
                                        child: FlutterMap(
                                          mapController: _mapController,
                                          options: MapOptions(
                                            maxZoom: Auxiliar.maxZoom,
                                            onMapReady: () {
                                              _mapController.fitBounds(
                                                LatLngBounds(
                                                    LatLng(maxLat, maxLong),
                                                    LatLng(minLat, minLong)),
                                                options: const FitBoundsOptions(
                                                  padding: EdgeInsets.all(24),
                                                ),
                                              );
                                            },
                                            interactiveFlags: InteractiveFlag
                                                    .pinchZoom |
                                                InteractiveFlag.doubleTapZoom,
                                            enableScrollWheel: true,
                                          ),
                                          children: [
                                            Auxiliar.tileLayerWidget(
                                                brightness: Theme.of(context)
                                                    .brightness),
                                            Auxiliar.atributionWidget(),
                                            PolylineLayer(polylines: polylines),
                                            MarkerLayer(markers: markers),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        widget.itinerary.type ==
                                                ItineraryType.order
                                            ? AppLocalizations.of(context)!
                                                .puntoInicioIt
                                            : AppLocalizations.of(context)!
                                                .puntosDelIt,
                                      ),
                                      cPois,
                                    ],
                                  );
                                } else {
                                  return Container();
                                }
                              } else {
                                if (snapshot.connectionState ==
                                        ConnectionState.done &&
                                    snapshot.hasError) {
                                  return Container();
                                } else {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                              }
                            }),
                          );
                        default:
                          return const Divider(
                            indent: 10,
                            endIndent: 10,
                          );
                      }
                    },
                    childCount: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> calculeRoute(pIt, matrixPIt, rowVMin, vMin) {
    List<Polyline> polylines = [];
    double distancia = 0;
    // Con rowVMin sé por que punto empezar
    List<int> rows = [];
    for (int i = 0, tama = pIt.length; i < tama; i++) {
      List<double> d = matrixPIt[rowVMin];
      LatLng pointStart = pIt[rowVMin].poiObj.point;
      if (i != 0) {
        vMin = 999999999999;
        for (int j = 0; j < tama; j++) {
          if (!rows.contains(j) && d[j] != 0) {
            if (d[j] < vMin) {
              vMin = d[j];
              rowVMin = j;
            }
          }
        }
      } else {
        rows.add(rowVMin);
        for (double element in d) {
          if (element < vMin) {
            vMin = element;
          }
        }
      }
      int index = d.indexOf(vMin);
      rowVMin = index;
      rows.add(rowVMin);
      LatLng pointEnd = pIt[rowVMin].poiObj.point;
      polylines.add(Polyline(
          isDotted: true,
          color: Theme.of(context).primaryColor,
          strokeWidth: 3,
          points: [pointStart, pointEnd]));
      distancia += d[index];
    }
    return {"polylines": polylines, "distancia": distancia};
  }
}
