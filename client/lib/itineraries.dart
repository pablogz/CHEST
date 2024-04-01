import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:chest/util/exceptions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:mustache_template/mustache.dart';

import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/itineraries.dart';
import 'package:chest/util/helpers/map_data.dart';
import 'package:chest/util/helpers/feature.dart';
import 'package:chest/util/helpers/queries.dart';
import 'package:chest/util/helpers/tasks.dart';
import 'package:chest/main.dart';
import 'package:chest/features.dart';
import 'package:chest/tasks.dart';
import 'package:chest/util/config.dart';
import 'package:chest/util/helpers/chest_marker.dart';
import 'package:quill_html_editor/quill_html_editor.dart';
import 'package:chest/util/helpers/auxiliar_mobile.dart'
    if (dart.library.html) 'package:chest/util/helpers/auxiliar_web.dart';
import 'package:chest/util/helpers/track.dart';

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
  late List<Feature> _pointS;
  late bool _ordenPoi,
      /*_start,*/ _ordenTasks,
      _enableBt,
      _focusQuillEditorController,
      _errorDescriIt,
      _trackAgregado;
  late QuillEditorController _quillEditorController;
  late List<ToolBarStyle> _toolBarElentes;
  late List<Marker> _myMarkers;
  final MapController _mapController = MapController();
  late List<PointItinerary> _pointsItinerary;
  late int _numPoiSelect, _numTaskSelect, _lastMapEventScrollWheelZoom;
  late StreamSubscription<MapEvent> strSubMap;
  late String _descriIt;
  late List<LatLng> _pointsTrack;

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
    _trackAgregado = false;
    _pointsTrack = [];
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
    _errorDescriIt = false;
    _quillEditorController = QuillEditorController();
    _toolBarElentes = Auxiliar.getToolbarElements();
    _focusQuillEditorController = false;
    _descriIt = '';
    _quillEditorController.onEditorLoaded(() {
      _quillEditorController.unFocus();
    });
    super.initState();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _quillEditorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.of(context);
    StepperType stepperType = mediaQuery.orientation == Orientation.landscape &&
            mediaQuery.size.width > 890
        ? StepperType.horizontal
        : StepperType.vertical;
    ThemeData td = Theme.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    return Scaffold(
      appBar: AppBar(
        title: _index == 1
            ? _numPoiSelect == 0
                ? Text(appLoca!.agregarIt)
                : Text(
                    Template('{{{numTaskSelect}}} {{{text}}}').renderString({
                      "numTaskSelect": _numPoiSelect,
                      "text": _numPoiSelect == 1
                          ? appLoca!.seleccionado
                          : appLoca!.seleccionados
                    }),
                    textAlign: TextAlign.end,
                    style: td.textTheme.titleLarge!.copyWith(
                        color: td.brightness == Brightness.light
                            ? Colors.white
                            : Colors.black),
                  )
            : _index == 3
                ? _numTaskSelect == 0
                    ? Text(appLoca!.agregarIt)
                    : Text(
                        Template('{{{numTaskSelect}}} {{{text}}}')
                            .renderString({
                          "numTaskSelect": _numTaskSelect,
                          "text": _numTaskSelect == 1
                              ? appLoca!.seleccionada
                              : appLoca!.seleccionadas
                        }),
                        style: td.textTheme.titleLarge!.copyWith(
                            color: td.brightness == Brightness.light
                                ? Colors.white
                                : Colors.black),
                      )
                : Text(AppLocalizations.of(context)!.agregarIt),
        backgroundColor: _index == 1 && _numPoiSelect > 0
            ? td.brightness == Brightness.light
                ? Colors.black87
                : td.indicatorColor
            : _index == 3 && _numTaskSelect > 0
                ? td.brightness == Brightness.light
                    ? Colors.black87
                    : td.indicatorColor
                : td.appBarTheme.backgroundColor,
        leading: _index == 1
            ? _numPoiSelect == 0
                // ? const BackButton(color: Colors.white)
                ? null
                : InkWell(
                    child: Icon(Icons.close,
                        color: td.brightness == Brightness.light
                            ? Colors.white
                            : Colors.black),
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
                        child: Icon(Icons.close,
                            color: td.brightness == Brightness.light
                                ? Colors.white
                                : Colors.black),
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
            elevation: 0,
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
                          child: Text(appLoca!.siguiente),
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
                          child: Text(appLoca!.atras),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _enableBt ? details.onStepContinue : null,
                          child: _enableBt
                              ? Text(appLoca.finalizar)
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
                          child: Text(appLoca!.atras),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: details.onStepContinue,
                          child: Text(appLoca.siguiente),
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
                    if (_descriIt.isNotEmpty) {
                      setState(() => _errorDescriIt = false);
                      _newIt.comments = {
                        "value": _descriIt,
                        "lang": MyApp.currentLang
                      };
                    } else {
                      setState(() => _errorDescriIt = true);
                      sigue = false;
                    }
                    break;
                  case 1:
                    sigue = _pointS.isNotEmpty;
                    if (!sigue) {
                      smState.clearSnackBars();
                      smState.showSnackBar(
                        SnackBar(
                          backgroundColor: td.colorScheme.error,
                          content: Text(
                            appLoca!.errorSeleccionaUnPoi,
                            style: td.textTheme.bodyMedium!
                                .copyWith(color: td.colorScheme.onError),
                          ),
                        ),
                      );
                    }
                    break;
                  case 2:
                    _keyStep2.currentState!.validate();
                    List<Future> queries = [];
                    for (Feature poi in _pointS) {
                      queries.add(_getTasks(poi.shortId));
                    }
                    List<dynamic> data = await Future.wait(queries);
                    _tasksPress = [];
                    _tasksProcesadas = [];
                    _numTaskSelect = 0;
                    _tasksSeleccionadas = [];
                    for (int i = 0, tama = _pointS.length; i < tama; i++) {
                      Feature poi = _pointS[i];
                      List<dynamic> tareasSinProcesar = data[i];
                      List<Task> tareasProcesadas = [];
                      List<bool> tPress = [];
                      for (var t in tareasSinProcesar) {
                        try {
                          Task task = Task(t,
                              idContainer: poi.id,
                              containerType: ContainerTask.spatialThing);
                          tareasProcesadas.add(task);
                          tPress.add(false);
                        } on Exception catch (e) {
                          if (Config.development) debugPrint(e.toString());
                        }
                      }
                      _tasksPress.add(tPress);
                      _tasksProcesadas.add(tareasProcesadas);
                      _tasksSeleccionadas.add([]);
                    }
                    sigue = true;
                    break;
                  case 3:
                    sigue = true;
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
                    _newIt.type = ItineraryType.list;
                  } else {
                    if (_ordenTasks) {
                      _newIt.type = ItineraryType.bagSTsListTasks;
                    } else {
                      _newIt.type = ItineraryType.bag;
                    }
                  }
                  //Envío la información al servidor
                  // Map<String, dynamic> bodyRequest = {
                  //   "type": _newIt.type!.name,
                  //   "label": _newIt.labels2List(),
                  //   "comment": _newIt.comments2List(),
                  //   "points": _newIt.points2List()
                  // };

                  Map<String, dynamic> bodyRequest = _newIt.toMap();
                  http
                      .post(Queries.newItinerary(),
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
                        // _newIt.author = Auxiliar.userCHEST.id;
                        _newIt.author = '123';
                        Navigator.pop(context, _newIt);
                        smState.clearSnackBars();
                        smState.showSnackBar(
                          SnackBar(content: Text(appLoca!.infoRegistrada)),
                        );
                        break;
                      default:
                        setState(() => _enableBt = true);

                        smState.clearSnackBars();
                        smState.showSnackBar(SnackBar(
                            content: Text(response.statusCode.toString())));
                    }
                  }).onError((error, stackTrace) {
                    setState(() => _enableBt = true);
                    smState.clearSnackBars();
                    smState
                        .showSnackBar(const SnackBar(content: Text("Error")));
                    if (Config.development) {
                      debugPrint(error.toString());
                    }
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
                title: Text(
                  appLoca!.infoGeneral,
                  overflow: TextOverflow.ellipsis,
                ),
                state: _index == 0 ? StepState.editing : StepState.complete,
                isActive: _index == 0,
                content: contentStep0(),
              ),
              Step(
                title: Text(appLoca.puntosIt),
                state: _index < 1
                    ? StepState.disabled
                    : _index == 1
                        ? StepState.editing
                        : StepState.complete,
                isActive: _index == 1,
                content: contentStep1(),
              ),
              Step(
                title: Text(
                  appLoca.ordenPuntosIt,
                  overflow: TextOverflow.ellipsis,
                ),
                state: _index < 2
                    ? StepState.disabled
                    : _index == 2
                        ? StepState.editing
                        : StepState.complete,
                isActive: _index == 2,
                content: contentStep2(),
              ),
              Step(
                title: Text(
                  appLoca.tareasIt,
                  overflow: TextOverflow.ellipsis,
                ),
                state: _index < 3
                    ? StepState.disabled
                    : _index == 3
                        ? StepState.editing
                        : StepState.complete,
                isActive: _index == 3,
                content: contentStep3(),
              ),
              Step(
                title: Text(
                  appLoca.ordenTareas,
                  overflow: TextOverflow.ellipsis,
                ),
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
    ColorScheme colorScheme = td.colorScheme;
    MapData.checkCurrentMapSplit(_mapController.camera.visibleBounds)
        .then((List<Feature> listPoi) {
      for (int i = 0, tama = listPoi.length; i < tama; i++) {
        Feature p = listPoi.elementAt(i);
        bool pulsado = _pointS.indexWhere((Feature poi) => poi.id == p.id) > -1;
        _myMarkers.add(CHESTMarker(context,
            feature: p,
            icon: Icon(Icons.castle_outlined,
                color: pulsado ? colorScheme.onPrimaryContainer : Colors.black),
            circleWidthBorder: pulsado ? 2 : 1,
            circleWidthColor: pulsado ? colorScheme.primary : Colors.grey,
            circleContainerColor:
                pulsado ? td.colorScheme.primaryContainer : Colors.grey[400]!,
            textInGray: !pulsado, onTap: () {
          int press = _pointS.indexWhere((Feature poi) => poi.id == p.id);
          if (press > -1) {
            _pointS.removeAt(press);
            setState(() => --_numPoiSelect);
          } else {
            _pointS.add(p);
            setState(() => ++_numPoiSelect);
          }
          createMarkers();
        }));
      }
      setState(() {});
    });
  }

  Future<List> _getTasks(String shortId) {
    return http.get(Queries.getTasks(shortId)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Widget contentStep0() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    Size size = MediaQuery.of(context).size;

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
                labelText: '${appLoca.tituloIt}*',
                hintText: appLoca.tituloIt,
                hintMaxLines: 1,
                hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            validator: (v) {
              if (v != null && v.trim().isNotEmpty) {
                _newIt.labels = {"value": v.trim(), "lang": MyApp.currentLang};
                return null;
              } else {
                return appLoca.tituloItError;
              }
            },
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              border: Border.fromBorderSide(
                BorderSide(
                    color: _errorDescriIt
                        ? colorScheme.error
                        : _focusQuillEditorController
                            ? colorScheme.primary
                            : td.disabledColor,
                    width: _focusQuillEditorController ? 2 : 1),
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
                    '${appLoca.descriIt}*',
                    style: td.textTheme.bodySmall!.copyWith(
                      color: _errorDescriIt
                          ? colorScheme.error
                          : _focusQuillEditorController
                              ? colorScheme.primary
                              : td.disabledColor,
                    ),
                  ),
                ),
                QuillHtmlEditor(
                    controller: _quillEditorController,
                    hintText: '',
                    minHeight: size.height * 0.2,
                    ensureVisible: false,
                    autoFocus: false,
                    backgroundColor: colorScheme.surface,
                    textStyle: textTheme.bodyLarge!
                        .copyWith(color: colorScheme.onSurface),
                    padding: const EdgeInsets.all(5),
                    onFocusChanged: (focus) =>
                        setState(() => _focusQuillEditorController = focus),
                    onTextChanged: (text) {
                      _descriIt = text.trim();
                    }),
                ToolBar(
                  controller: _quillEditorController,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  alignment: WrapAlignment.spaceEvenly,
                  direction: Axis.horizontal,
                  toolBarColor: colorScheme.primaryContainer,
                  iconColor: colorScheme.onPrimaryContainer,
                  activeIconColor: colorScheme.tertiary,
                  toolBarConfig: _toolBarElentes,
                  customButtons: [
                    InkWell(
                      focusColor: colorScheme.tertiary,
                      onTap: () async {
                        _quillEditorController
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
                              constraints: const BoxConstraints(maxWidth: 640),
                              showDragHandle: true,
                              builder: (context) => _showURLDialog(),
                            );
                          } else {
                            ScaffoldMessengerState smState =
                                ScaffoldMessenger.of(context);
                            smState.clearSnackBars();
                            smState.showSnackBar(SnackBar(
                              content: Text(
                                appLoca.seleccionaTexto,
                                style: textTheme.bodyMedium!
                                    .copyWith(color: colorScheme.onError),
                              ),
                              backgroundColor: colorScheme.error,
                            ));
                          }
                        });
                      },
                      child: Icon(
                        Icons.link,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                Visibility(
                  visible: _errorDescriIt,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      appLoca.descriItError,
                      style: textTheme.bodySmall!.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, right: 10, left: 10),
              child: Text(
                appLoca.requerido,
                style: textTheme.bodySmall,
                textAlign: TextAlign.start,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _showURLDialog() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    TextTheme textTheme = Theme.of(context).textTheme;
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
              appLoca.agregaEnlace,
              style: textTheme.titleMedium,
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
                      _quillEditorController
                          .getSelectedText()
                          .then((textoSeleccionado) async {
                        if (textoSeleccionado != null &&
                            textoSeleccionado is String &&
                            textoSeleccionado.isNotEmpty) {
                          _quillEditorController.setFormat(
                              format: 'link', value: uri);
                          Navigator.of(context).pop();
                          setState(() {
                            _focusQuillEditorController = true;
                          });
                          _quillEditorController.focus();
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

  Widget contentStep1() {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    TextTheme textTheme = td.textTheme;
    return Container(
      padding: const EdgeInsets.only(bottom: 10),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appLoca.infoAccionSeleccionMarkers,
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Container(
            constraints: BoxConstraints(
                maxWidth: Auxiliar.maxWidth,
                maxHeight: max(MediaQuery.of(context).size.height - 300, 200)),
            child: Stack(
              alignment: AlignmentDirectional.bottomEnd,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    backgroundColor: td.brightness == Brightness.light
                        ? Colors.white54
                        : Colors.black54,
                    maxZoom: Auxiliar.maxZoom,
                    minZoom: 13,
                    initialCenter: widget.initPoint,
                    initialZoom: widget.initZoom,
                    keepAlive: false,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.pinchMove,
                      enableScrollWheel: true,
                      pinchZoomThreshold: 2.0,
                    ),
                    onMapReady: () => createMarkers(),
                    onLongPress: (tapPosition, point) async {
                      await MapData.checkCurrentMapSplit(
                              _mapController.camera.visibleBounds)
                          .then((List<Feature> pois) async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<Feature>(
                            builder: (BuildContext context) => NewPoi(
                              point,
                              _mapController.camera.visibleBounds,
                              pois,
                            ),
                            fullscreenDialog: true,
                          ),
                        ).then((Feature? createPoi) async {
                          if (createPoi is Feature) {
                            Feature? newPOI = await Navigator.push(
                                context,
                                MaterialPageRoute<Feature>(
                                    builder: (BuildContext context) =>
                                        FormPOI(createPoi),
                                    fullscreenDialog: false));
                            if (newPOI is Feature) {
                              MapData.addFeature2Tile(newPOI);
                              createMarkers();
                            }
                          }
                        });
                      });
                    },
                  ),
                  children: [
                    Auxiliar.tileLayerWidget(brightness: td.brightness),
                    Auxiliar.atributionWidget(),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _pointsTrack,
                          isDotted: true,
                          color: colorScheme.tertiary,
                          strokeWidth: 5,
                        )
                      ],
                    ),
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 120,
                        centerMarkerOnClick: false,
                        zoomToBoundsOnClick: false,
                        showPolygon: false,
                        onClusterTap: (p0) {
                          _mapController.move(p0.bounds.center,
                              min(p0.zoom + 1, Auxiliar.maxZoom));
                        },
                        disableClusteringAtZoom: 18,
                        size: const Size(76, 76),
                        markers: _myMarkers,
                        circleSpiralSwitchover: 6,
                        spiderfySpiralDistanceMultiplier: 1,
                        polygonOptions: PolygonOptions(
                            borderColor: colorScheme.primary,
                            color: colorScheme.primaryContainer,
                            borderStrokeWidth: 1),
                        builder: (context, markers) {
                          int tama = markers.length;
                          int nPul = 0;
                          for (Marker marker in markers) {
                            int index = _pointS.indexWhere(
                                (Feature poi) => poi.point == marker.point);
                            if (index > -1) {
                              ++nPul;
                            }
                          }
                          double sizeMarker;
                          int multi =
                              Queries.layerType == LayerType.forest ? 100 : 1;
                          if (tama <= (5 * multi)) {
                            sizeMarker = 56;
                          } else {
                            if (tama <= (8 * multi)) {
                              sizeMarker = 66;
                            } else {
                              sizeMarker = 76;
                            }
                          }
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(sizeMarker),
                              border: Border.all(
                                  color: Colors.grey[900]!, width: 2),
                              color: nPul == tama
                                  ? colorScheme.primary
                                  : nPul == 0
                                      ? Colors.grey[700]!
                                      : Colors.pink[100]!,
                            ),
                            child: Center(
                              child: Text(
                                markers.length.toString(),
                                style: TextStyle(
                                    color: nPul == tama
                                        ? colorScheme.onPrimary
                                        : nPul == 0
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
                Visibility(
                  visible: _numPoiSelect > 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FloatingActionButton.extended(
                      heroTag: null,
                      onPressed: () {
                        List<Widget> lst = [];
                        for (Feature f in _pointS) {
                          lst.add(tarjetaLugarSeleccionado(f));
                        }
                        Auxiliar.showMBS(
                            context,
                            DraggableScrollableSheet(
                              initialChildSize: 0.4,
                              minChildSize: 0.2,
                              maxChildSize: 1,
                              expand: false,
                              builder: (context, controller) => Column(
                                children: [
                                  Expanded(
                                    child: ListView.builder(
                                      controller: controller,
                                      itemCount: lst.length,
                                      itemBuilder: (context, index) {
                                        return lst.elementAt(index);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ));
                      },
                      label:
                          Text(AppLocalizations.of(context)!.verSeleccionados),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runAlignment: WrapAlignment.spaceBetween,
            spacing: 20,
            runSpacing: 10,
            children: [
              Text(
                appLoca.agregarGPXtexto,
                style: textTheme.titleSmall,
              ),
              FilledButton(
                onPressed: _trackAgregado
                    ? null
                    : () async {
                        AuxiliarFunctions.readExternalFile(
                            validExtensions: ['gpx']).then((String? s) {
                          if (s != null) {
                            _newIt.track = Track.gpx(s);
                            debugPrint(_newIt.track!.points.length.toString());
                            setState(() {
                              for (LatLngCHEST p in _newIt.track!.points) {
                                _pointsTrack.add(p.toLatLng);
                              }
                              debugPrint(_pointsTrack.length.toString());
                              _trackAgregado = true;
                            });
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(appLoca.agregadoGPX),
                            ));
                          }
                        }).onError((error, stackTrace) {
                          if (error is FileExtensionException) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              backgroundColor: colorScheme.error,
                              content: Text(
                                error.toString(),
                                style: textTheme.bodyMedium!
                                    .copyWith(color: colorScheme.onError),
                              ),
                            ));
                          } else {
                            if (Config.development) {
                              debugPrint(error.toString());
                            }
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              backgroundColor: colorScheme.error,
                              content: Text(
                                'Error',
                                style: textTheme.bodyMedium!
                                    .copyWith(color: colorScheme.onError),
                              ),
                            ));
                          }
                        });
                      },
                child: Text(appLoca.agregarGPX),
              ),
              Visibility(
                  visible: _trackAgregado,
                  child: IconButton(
                    onPressed: () {
                      _newIt.track = null;
                      setState(() {
                        _pointsTrack = [];
                        _trackAgregado = false;
                      });
                    },
                    icon: const Icon(Icons.delete),
                  ))
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget tarjetaLugarSeleccionado(Feature lugar) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          lugar.getALabel(lang: MyApp.currentLang),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .bodyMedium!
              .copyWith(color: colorScheme.onPrimaryContainer),
        ),
      ),
    );
  }

  Widget contentStep2() {
    ThemeData td = Theme.of(context);
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    TextTheme textTheme = td.textTheme;

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
                appLoca.establecerOrdenPoi,
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
                    _pointS[index].getALabel(lang: MyApp.currentLang),
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
                  final Feature item = _pointS.removeAt(oldIndex);
                  _pointS.insert(newIndex, item);
                });
              }
            },
            buildDefaultDragHandles: _ordenPoi,
          ),
          const SizedBox(height: 10),
          Text(appLoca.infoPersonalizarDescrip),
          const SizedBox(height: 10),
          Form(
            key: _keyStep2,
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: _pointS.length,
              itemBuilder: (context, index) {
                Feature poi = _pointS[index];
                return ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: [
                    Text(
                      poi.getALabel(lang: MyApp.currentLang),
                      style: textTheme.bodyMedium!
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    TextFormField(
                      maxLines: 7,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: (poi.getAComment(lang: MyApp.currentLang))
                              .replaceAll(
                                  RegExp('<[^>]*>?',
                                      multiLine: true, dotAll: true),
                                  ''),
                          hintMaxLines: 7,
                          hintStyle:
                              const TextStyle(overflow: TextOverflow.ellipsis)),
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      validator: (v) {
                        _pointsItinerary.removeWhere((pit) => pit.id == poi.id);
                        if (v != null && v.trim().isNotEmpty) {
                          _pointsItinerary.add(PointItinerary({
                            'id': poi.id,
                            'altComment': {
                              "value": v.trim(),
                              "lang": MyApp.currentLang,
                            }
                          }));
                        } else {
                          _pointsItinerary.add(PointItinerary({'id': poi.id}));
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
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
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
              Feature poi = _pointS[index];
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
                            poi.getALabel(lang: MyApp.currentLang),
                            style: textTheme.bodyMedium!
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: OutlinedButton(
                            child: Text(
                              appLoca.agregarTarea,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () async {
                              Task? newTask = await Navigator.push(
                                  context,
                                  MaterialPageRoute<Task>(
                                      builder: (BuildContext context) =>
                                          FormTask(
                                            Task.empty(
                                              idContainer: poi.id,
                                              containerType:
                                                  ContainerTask.spatialThing,
                                            ),
                                          ),
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
                                  ? colorScheme.primary
                                  : td.cardColor,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          color: _tasksPress[index][indexT]
                              ? colorScheme.primaryContainer
                              : td.cardColor,
                          child: ListTile(
                            title: Text(
                              (task.getAComment(lang: MyApp.currentLang))
                                  .replaceAll(
                                      RegExp('<[^>]*>?',
                                          multiLine: true, dotAll: true),
                                      ''),
                              style: textTheme.bodyMedium!.copyWith(
                                color: _tasksPress[index][indexT]
                                    ? colorScheme.onPrimaryContainer
                                    : null,
                              ),
                            ),
                            onTap: () {
                              if (_tasksPress[index][indexT]) {
                                _tasksSeleccionadas[index]
                                    .removeWhere((Task t) => t.id == task.id);
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
                          ),
                        );
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
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Container(
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.secondaryContainer,
                  ),
                  borderRadius: BorderRadius.circular(8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton(
                            onPressed: () async {
                              Task? nTask = await Navigator.push(
                                  context,
                                  MaterialPageRoute<Task>(
                                    builder: (BuildContext context) => FormTask(
                                      Task.empty(
                                        containerType: ContainerTask.itinerary,
                                      ),
                                    ),
                                    fullscreenDialog: true,
                                  ));
                              if (nTask is Task) {
                                setState(() => _newIt.addTask(nTask));
                              }
                            },
                            child: Text(appLoca.addItineraryTask),
                          ),
                          Tooltip(
                            message: appLoca.addItineraryTaskHelp,
                            child: Icon(
                              Icons.info,
                              color: colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _newIt.tasks.length,
                    itemBuilder: ((context, index) {
                      return Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer,
                          border: Border.all(
                            color: colorScheme.tertiary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _newIt.tasks
                              .elementAt(index)
                              .getALabel(lang: MyApp.currentLang),
                          style: textTheme.bodyMedium!.copyWith(
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      );
                    }),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget contentStep4() {
    ThemeData td = Theme.of(context);
    TextTheme textTheme = td.textTheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return Container(
      alignment: Alignment.centerLeft,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          SwitchListTile.adaptive(
            value: _ordenPoi || _ordenTasks,
            onChanged: _ordenPoi
                ? null
                : (v) {
                    setState(() => _ordenTasks = v);
                  },
            title: Text(
              appLoca.establecerOrdenPoi,
            ),
          ),
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: _pointS.length,
            itemBuilder: (context, index) {
              Feature poi = _pointS[index];
              if (_tasksSeleccionadas.length == _pointS.length) {
                List<Task> sT = _tasksSeleccionadas[index];
                return ReorderableListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  header: Text(
                    poi.getALabel(lang: MyApp.currentLang),
                    style: textTheme.bodyMedium!
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
                        (sT[indexT].getAComment(lang: MyApp.currentLang))
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
    return http.get(Queries.getItinerary(idIt)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : {});
  }

  Future<List> _getTasksFeature(idIt, idFeature) {
    return http.get(Queries.getTasksFeatureIt(idIt, idFeature)).then(
        (response) =>
            response.statusCode == 200 ? json.decode(response.body) : {});
  }

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> lst = [
      Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(widget.itinerary.getAComment(lang: MyApp.currentLang)),
        ),
      ),
      // const Padding(
      //   padding: EdgeInsets.symmetric(vertical: 10),
      //   child: Divider(
      //     indent: 10,
      //     endIndent: 10,
      //   ),
      // ),
      Padding(
        padding: const EdgeInsets.only(bottom: 40),
        child: widgetMapPoints(),
      ),
    ];
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(widget.itinerary.getALabel(lang: MyApp.currentLang)),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Center(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: lst[index],
                  ),
                ),
              ),
              childCount: lst.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget widgetMapPoints() {
    return FutureBuilder(
        future: _getItinerary(widget.itinerary.id),
        builder: ((context, snapshot) {
          ThemeData td = Theme.of(context);
          AppLocalizations? appLoca = AppLocalizations.of(context);
          if (!snapshot.hasError && snapshot.hasData) {
            Object? body = snapshot.data;
            if (body != null && body is Map && body.keys.contains('points')) {
              List points = body['points'];
              List<PointItinerary> pointsIt = [];
              List<Marker> markers = [];
              double maxLat = -90, minLat = 90, maxLong = -180, minLong = 180;
              for (Map<String, dynamic> point in points) {
                PointItinerary pIt = PointItinerary({'id': point["poi"]});
                // TODO Cambiar el segundo elemento por el shortId
                // pIt.poiObj = POI(
                //     point["poi"],
                //     point["poi"],
                //     point["label"],
                //     point["comment"],
                //     point["lat"],
                //     point["long"],
                //     point["author"]);
                // TODO Cambiar el segundo elemento por el shortId
                Map data = {
                  'id': point['poi'],
                  'shortId': Auxiliar.id2shortId(point['poi']),
                  'labels': point['label'],
                  'descriptions': point['comment'],
                  'lat': point['lat'],
                  'long': point['long'],
                  'author': point['author']
                };
                pIt.feature = Feature(data);
                if (point.keys.contains("altComment")) {
                  pIt.altComments = point["altComment"];
                }
                pointsIt.add(pIt);
              }
              widget.itinerary.points = pointsIt;
              switch (widget.itinerary.type) {
                case ItineraryType.list:
                  PointItinerary point = widget.itinerary.points.first;
                  maxLat = point.feature.lat;
                  minLat = maxLat;
                  minLong = point.feature.long;
                  maxLong = minLong;
                  markers.add(
                    Marker(
                      width: 52,
                      height: 52,
                      point: LatLng(
                        point.feature.lat,
                        point.feature.long,
                      ),
                      child: Tooltip(
                        message:
                            point.feature.getALabel(lang: MyApp.currentLang),
                        child: Container(
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: td.colorScheme.primary),
                          child: const Center(
                            child: Icon(
                              Icons.start,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  break;
                default:
                  for (PointItinerary point in widget.itinerary.points) {
                    if (point.feature.lat > maxLat) {
                      maxLat = point.feature.lat;
                    }
                    if (point.feature.lat < minLat) {
                      minLat = point.feature.lat;
                    }
                    if (point.feature.long > maxLong) {
                      maxLong = point.feature.long;
                    }
                    if (point.feature.long < minLong) {
                      minLong = point.feature.long;
                    }
                    markers.add(
                      Marker(
                        width: 26,
                        height: 26,
                        point: LatLng(
                          point.feature.lat,
                          point.feature.long,
                        ),
                        child: Tooltip(
                          message:
                              point.feature.getALabel(lang: MyApp.currentLang),
                          child: Container(
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: td.colorScheme.primary),
                          ),
                        ),
                      ),
                    );
                  }
                  break;
              }
              double distancia = 0;
              List<PointItinerary> pIt = widget.itinerary.points;
              List<Polyline> polylines = [];
              switch (widget.itinerary.type) {
                case ItineraryType.list:
                  for (int i = 1, tama = pIt.length; i < tama; i++) {
                    distancia += Auxiliar.distance(
                        pIt[i].feature.point, pIt[i - 1].feature.point);
                  }
                  break;
                default:
                  List<List<double>> matrixPIt = [];
                  List<double> d = [];
                  //Calculo "todas" las distancias entre los puntos del itinerario
                  //teniendo en cuenta que habrá valores que se repitan
                  double vMin = 999999999999;
                  for (int i = 0, tama = pIt.length; i < tama; i++) {
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
                              pIt[i].feature.point, pIt[j].feature.point);
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
                  for (int i = 0, tama = widget.itinerary.points.length;
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
                  r1 = calculeRoute(pIt, matrixPIt, iMax, dMax);
                  r2 = calculeRoute(pIt, matrixPIt, jMax, dMax);
                  if (r1["distancia"] < r2["distancia"]) {
                    distancia = r1["distancia"];
                    polylines.addAll(r1["polylines"]);
                  } else {
                    distancia = r2["distancia"];
                    polylines.addAll(r2["polylines"]);
                  }
              }

              List<Widget> pointsWithTasks = [];
              for (PointItinerary p in widget.itinerary.points) {
                Column c = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          p.feature.getALabel(lang: MyApp.currentLang),
                          style: td.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    FutureBuilder(
                      future:
                          _getTasksFeature(widget.itinerary.id, p.feature.id),
                      builder: (context, snapshot) {
                        if (!snapshot.hasError && snapshot.hasData) {
                          Object? body = snapshot.data;
                          if (body != null && body is List) {
                            List<Widget> enunTareas = [];
                            RegExp regExp = RegExp(r"<[^>]*>",
                                multiLine: true, caseSensitive: true);
                            for (Map t in body) {
                              if (t.containsKey("label")) {
                                String txt = t["label"]["value"] +
                                    ". " +
                                    t["comment"]["value"];
                                txt = txt.replaceAll(regExp, "");
                                enunTareas.add(Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 20,
                                      bottom: 5,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(right: 5),
                                          child:
                                              Icon(Icons.chevron_right_rounded),
                                        ),
                                        Flexible(
                                          child: Text(
                                            txt,
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ));
                              } else {
                                enunTareas.add(
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 20,
                                        bottom: 5,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(right: 5),
                                            child: Icon(
                                                Icons.chevron_right_rounded),
                                          ),
                                          Flexible(
                                            child: Text(
                                              t["comment"]["value"]
                                                  .replaceAll(regExp, ""),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: enunTareas,
                            );
                          } else {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: CircularProgressIndicator(
                                  value: 1, color: td.colorScheme.error),
                            );
                          }
                        } else {
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: CircularProgressIndicator(
                                  value: 1, color: td.colorScheme.error),
                            );
                          } else {
                            return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: CircularProgressIndicator());
                          }
                        }
                      },
                    )
                  ],
                );
                pointsWithTasks.add(c);
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          Template("{{{m}}}: {{{v}}}{{{u}}}").renderString(
                            {
                              "m": appLoca!.distanciaAproxIt,
                              "v": (distancia > 1000)
                                  ? (distancia / 1000).toStringAsFixed(2)
                                  : distancia.toInt(),
                              "u": (distancia > 1000) ? "km" : "m"
                            },
                          ),
                          style: td.textTheme.bodySmall,
                          textAlign: TextAlign.end,
                        ),
                        Tooltip(
                          message: Template("{{{ms}}}{{{mo}}}").renderString({
                            "ms": appLoca.explicaDistancia,
                            "mo": widget.itinerary.type == ItineraryType.list
                                ? ''
                                : Template(" {{{m}}}").renderString(
                                    {"m": appLoca.explicaRutaSugerida})
                          }),
                          showDuration: Duration(
                              seconds:
                                  widget.itinerary.type == ItineraryType.list
                                      ? 2
                                      : 4),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: Icon(Icons.info,
                                color: td.colorScheme.secondary),
                          ),
                        )
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: Auxiliar.maxWidth,
                        maxHeight: min(
                            max(MediaQuery.of(context).size.height - 300, 150),
                            300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                              backgroundColor: td.brightness == Brightness.light
                                  ? Colors.white54
                                  : Colors.black54,
                              maxZoom: Auxiliar.maxZoom,
                              minZoom: 8,
                              onMapReady: () {
                                _mapController.fitCamera(
                                  CameraFit.bounds(
                                    bounds: LatLngBounds(
                                        LatLng(maxLat, maxLong),
                                        LatLng(minLat, minLong)),
                                    padding: const EdgeInsets.all(24),
                                  ),
                                );
                              },
                              interactionOptions: const InteractionOptions(
                                enableScrollWheel: true,
                              )),
                          children: [
                            Auxiliar.tileLayerWidget(brightness: td.brightness),
                            PolylineLayer(polylines: polylines),
                            Auxiliar.atributionWidget(),
                            MarkerLayer(markers: markers),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // const Padding(
                  //   padding: EdgeInsets.symmetric(vertical: 10),
                  //   child: Divider(
                  //     indent: 10,
                  //     endIndent: 10,
                  //   ),
                  // ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: pointsWithTasks,
                  )
                ],
              );
            } else {
              return Container();
            }
          } else {
            if (snapshot.hasError) {
              return Container();
            } else {
              return const CircularProgressIndicator();
            }
          }
        }));
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
          color: Theme.of(context).colorScheme.tertiary,
          strokeWidth: 2,
          points: [pointStart, pointEnd]));
      distancia += d[index];
    }
    return {"polylines": polylines, "distancia": distancia};
  }
}
