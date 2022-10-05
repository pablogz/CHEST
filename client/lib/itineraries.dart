import 'dart:convert';
import 'dart:math';

import 'package:chest/helpers/tasks.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:mustache_template/mustache.dart';

import 'helpers/auxiliar.dart';
import 'helpers/itineraries.dart';
import 'helpers/pois.dart';
import 'helpers/queries.dart';
import 'main.dart';

class NewItinerary extends StatefulWidget {
  final List<POI> pois;
  final LatLng initPoint;
  final double initZoom;
  const NewItinerary(this.pois, this.initPoint, this.initZoom, {super.key});
  @override
  State<StatefulWidget> createState() => _NewItinerary();
}

class _NewItinerary extends State<NewItinerary> {
  late int _index;
  late GlobalKey<FormState> _keyStep0, _keyStep2;
  late Itinerary _newIt;
  late List<bool> _vPoi, _markersPress;
  late List<List<bool>> _tasksPress;
  late List<List<Task>> _tasksProcesadas, _tasksSeleccionadas;
  late List<POI> _pointS;
  late bool _ordenPoi, _start, _ordenTasks;
  late List<Marker> _myMarkers;
  late MapController _mapController;
  late List<PointItinerary> _pointsItinerary;
  @override
  void initState() {
    _start = true;
    _index = 0;
    _keyStep0 = GlobalKey<FormState>();
    _keyStep2 = GlobalKey<FormState>();
    _newIt = Itinerary.empty();
    _vPoi = [];
    for (int i = 0, tama = widget.pois.length; i < tama; i++) {
      _vPoi.add(false);
    }
    _pointS = [];
    _ordenPoi = false;
    _myMarkers = [];
    _markersPress = [];
    _pointsItinerary = [];
    _tasksPress = [];
    _tasksProcesadas = [];
    _tasksSeleccionadas = [];
    _ordenTasks = false;
    for (int i = 0, tama = widget.pois.length; i < tama; i++) {
      _markersPress.add(false);
    }
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
        title: Text(AppLocalizations.of(context)!.agregarIt),
        backgroundColor: Theme.of(context).primaryColorDark,
        leading: const BackButton(color: Colors.white),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
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
                        ElevatedButton(
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
                        ElevatedButton(
                          onPressed: details.onStepContinue,
                          child: Text(AppLocalizations.of(context)!.finalizar),
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
                        const SizedBox(
                          width: 10,
                        ),
                        ElevatedButton(
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
                  _index -= 1;
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
                    for (List<Task> lt in _tasksSeleccionadas) {
                      if (lt.isEmpty) {
                        sigue = false;
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: Colors.red,
                            content: Text(
                              AppLocalizations.of(context)!
                                  .errorSeleccionaUnaTarea,
                            ),
                          ),
                        );
                        break;
                      }
                    }
                    break;
                  default:
                    sigue = false;
                    throw Exception();
                }
                if (sigue) {
                  setState(() {
                    //TODO comprobar los campos
                    _index += 1;
                  });
                }
              } else {
                if (_index == 4) {
                  //El usuario ha pulsado finalizar
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

  void createMarkers() {
    _myMarkers = [];
    for (int i = 0, tama = widget.pois.length; i < tama; i++) {
      POI p = widget.pois[i];
      Container icono;
      final String intermedio =
          p.labels[0].value.replaceAllMapped(RegExp(r'[^A-Z]'), (m) => "");
      final String iniciales =
          intermedio.substring(0, min(3, intermedio.length));
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
                  color: _markersPress[i]
                      ? Theme.of(context).primaryColorDark
                      : Colors.grey,
                  width: 2),
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
                  color: _markersPress[i]
                      ? Theme.of(context).primaryColorDark
                      : Colors.grey,
                  width: 2),
              color: _markersPress[i]
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300]!),
          width: 52,
          height: 52,
          child: Center(
              child: Text(
            iniciales,
            textAlign: TextAlign.center,
          )),
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
                _markersPress[i] ? _pointS.remove(p) : _pointS.add(p);
                setState(() {
                  _markersPress[i] = !_markersPress[i];
                  createMarkers();
                });
                //setState(() {});
              },
              child: icono,
            ),
          ),
        ),
      );
    }
    Future.delayed(Duration.zero, () {
      setState(() {});
    });
  }

  Future<List> _getTasks(String idPoi) {
    return http.get(Queries().getTasks(idPoi)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Widget contentStep0() {
    return Form(
      key: _keyStep0,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
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
      child: /* ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: widget.pois.length,
                    itemBuilder: (context, index) {
                      String l =
                          widget.pois[index].labelLang(MyApp.currentLang) ??
                              widget.pois[index].labelLang("es") ??
                              '';
                      if (l.isNotEmpty) {
                        return CheckboxListTile(
                            title: Text(l),
                            value: _vPoi[index],
                            onChanged: (v) {
                              if (v is bool) {
                                setState(() => _vPoi[index] = v);
                                if (v) {
                                  _pointS.add(widget.pois[index]);
                                } else {
                                  _pointS.remove(widget.pois[index]);
                                }
                              }
                            });
                      } else {
                        return const SizedBox(
                          height: 0,
                          width: 0,
                        );
                      }
                    },
                  ),*/
          Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.infoAccionSeleccionMarkers),
          const SizedBox(height: 10),
          Container(
            constraints: BoxConstraints(
                maxWidth: Auxiliar.MAX_WIDTH,
                maxHeight: max(MediaQuery.of(context).size.height - 300, 200)),
            child: FlutterMap(
              options: MapOptions(
                maxZoom: 18,
                // maxZoom: 20, //Con mapbox
                minZoom: 8,
                center: widget.initPoint,
                zoom: widget.initZoom,
                keepAlive: false,
                interactiveFlags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.pinchMove,
                enableScrollWheel: true,
                onPositionChanged: ((position, hasGesture) {
                  if (!hasGesture && _start) {
                    _start = false;
                    createMarkers();
                  }
                }),
                onMapCreated: (mC) {
                  _mapController = mC;
                  _mapController.onReady.then((value) => null);
                },
                pinchMoveThreshold: 2.0,
                plugins: [MarkerClusterPlugin()],
              ),
              children: [
                Auxiliar.tileLayerWidget(),
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
                      Color intensidad;
                      if (tama <= 5) {
                        intensidad = Colors.grey[300]!;
                      } else {
                        if (tama <= 15) {
                          intensidad = Colors.grey;
                        } else {
                          intensidad = Colors.grey[700]!;
                        }
                      }
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(52),
                          color: intensidad,
                          border:
                              Border.all(color: Colors.grey[900]!, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            markers.length.toString(),
                            style: TextStyle(
                                color:
                                    (tama <= 15) ? Colors.black : Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget contentStep2() {
    return Container(
      alignment: Alignment.centerLeft,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
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
                        '',
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
                            '',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    TextFormField(
                      maxLines: 7,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: poi.commentLang(MyApp.currentLang) ??
                              poi.commentLang("es") ??
                              '',
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
      child: ListView.builder(
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
                Text(
                    poi.labelLang(MyApp.currentLang) ??
                        poi.labelLang("es") ??
                        '',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .copyWith(fontWeight: FontWeight.bold)),
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
                                : Colors.grey,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ListTile(
                          title: Text(task.commentLang(MyApp.currentLang) ??
                              task.commentLang("es") ??
                              ''),
                          onTap: () {
                            /*_tasksPress[index][indexT]
                                ? _pointsItinerary[index].removeTask(task.id)
                                : _pointsItinerary[index].addTask(task.id);*/
                            _tasksPress[index][indexT]
                                ? _tasksSeleccionadas[index]
                                    .removeWhere((Task t) => t.id == task.id)
                                : _tasksSeleccionadas[index].add(task);
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
    );
  }

  Widget contentStep4() {
    return Container(
      alignment: Alignment.centerLeft,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          SwitchListTile(
            value: _ordenPoi | _ordenTasks,
            onChanged: (v) {
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
              List<Task> sT = _tasksSeleccionadas[index];
              return ReorderableListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                header: Text(poi.labelLang(MyApp.currentLang) ??
                    poi.labelLang("es") ??
                    ''),
                itemCount: sT.length,
                itemBuilder: (context, indexT) => Card(
                  key: Key('$indexT'),
                  child: ListTile(
                    leading: _ordenPoi | _ordenTasks
                        ? Text((indexT + 1).toString())
                        : null,
                    minLeadingWidth: 0,
                    title: Text(
                      sT[indexT].commentLang(MyApp.currentLang) ??
                          sT[indexT].commentLang("es") ??
                          '',
                    ),
                  ),
                ),
                onReorder: (oldIndex, newIndex) {
                  if (_ordenPoi | _ordenTasks) {
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
                footer: const SizedBox(height: 20),
                buildDefaultDragHandles: _ordenPoi | _ordenTasks,
              );
            },
          )
        ],
      ),
    );
  }
}
