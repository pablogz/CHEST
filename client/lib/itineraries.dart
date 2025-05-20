import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;

import 'package:chest/util/helpers/pair.dart';
import 'package:chest/util/helpers/providers/dbpedia.dart';
import 'package:chest/util/helpers/providers/jcyl.dart';
import 'package:chest/util/helpers/providers/osm.dart';
import 'package:chest/util/helpers/providers/wikidata.dart';
import 'package:chest/util/map_layer.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:image_network/image_network.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/parser/html_to_delta.dart';

import 'package:chest/l10n/generated/app_localizations.dart';
import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/itineraries.dart';
import 'package:chest/util/helpers/map_data.dart';
import 'package:chest/util/helpers/feature.dart';
import 'package:chest/util/queries.dart';
import 'package:chest/util/helpers/tasks.dart';
import 'package:chest/main.dart';
import 'package:chest/features.dart';
import 'package:chest/tasks.dart';
import 'package:chest/util/config.dart';
import 'package:chest/util/helpers/chest_marker.dart';
import 'package:chest/full_screen.dart';
import 'package:chest/util/exceptions.dart';
import 'package:chest/util/helpers/user_xest.dart';
import 'package:chest/util/helpers/widget_facto.dart';
import 'package:chest/util/helpers/auxiliar_mobile.dart'
    if (dart.library.html) 'package:chest/util/helpers/auxiliar_web.dart';
import 'package:chest/util/helpers/track.dart';

class AddEditItinerary extends StatefulWidget {
  final Itinerary itinerary;
  final LatLngBounds? latLngBounds;

  /// Constructor para iniciar el Widget de creación o edición de un itinerario.
  /// Si [itinerary] está vacio se debe proporcionar [latLngBounds] para
  /// determinar en qué zona geográfica se quiere iniciar la creación del
  /// itinario. Si el itinerario se ha iniciado (vamos a editar) este valor se
  /// recupera de [itinerary]
  AddEditItinerary(this.itinerary, {this.latLngBounds, super.key})
      : assert((itinerary.id != null) || (latLngBounds != null));

  /// Constructor para iniciar el Widget de creación de un itinerario. Se debe
  /// proporcionar [latLngBounds] para determinar la zona geográfica donde
  ///la creación del itinario se quiere iniciar la creación del itinario.
  AddEditItinerary.empty({LatLngBounds? latLngBounds, Key? key})
      : this(Itinerary.empty(), latLngBounds: latLngBounds, key: key);

  @override
  State<StatefulWidget> createState() => _AddEditItinerary();
}

class _AddEditItinerary extends State<AddEditItinerary> {
  late LatLngBounds? _latLngBounds;
  final double _heightAppBar = 56;
  late FocusNode _focusNode;
  late QuillController _quillController;
  late bool _hasFocus, _errorDescription, _trackAgregado;
  late String _title, _description;
  late int _step, _lastMapEventScrollWheelZoom;
  late GlobalKey<FormState> _gkS0;
  final MapController _mapController = MapController();
  late List<LatLng> _pointsTrack;
  late List<Marker> _myMarkers;
  late StreamSubscription<MapEvent> strSubMap;

  @override
  void initState() {
    _step = 0;
    _gkS0 = GlobalKey<FormState>();
    _title = widget.itinerary.labels.isNotEmpty
        ? widget.itinerary.getALabel(lang: MyApp.currentLang)
        : '';
    _description = widget.itinerary.comments.isNotEmpty
        ? widget.itinerary.getAComment(lang: MyApp.currentLang)
        : '';
    _latLngBounds = widget.itinerary.id != null
        ? LatLngBounds(
            LatLng(widget.itinerary.maxLat, widget.itinerary.maxLong),
            LatLng(widget.itinerary.minLat, widget.itinerary.minLong))
        : widget.latLngBounds;
    if (widget.itinerary.type == null) {
      widget.itinerary.type = ItineraryType.bag;
    }
    _focusNode = FocusNode();
    _quillController = QuillController.basic();
    try {
      _quillController.document =
          Document.fromDelta(HtmlToDelta().convert(_description));
    } catch (error) {
      _quillController.document = Document();
    }
    _quillController.document.changes.listen((DocChange onData) {
      setState(() {
        _description =
            Auxiliar.quillDelta2Html(_quillController.document.toDelta());
        _errorDescription = _description.trim().isEmpty;
      });
    });
    _hasFocus = false;
    _errorDescription = false;
    _focusNode.addListener(_onFocus);
    _trackAgregado = false;
    _pointsTrack = [];
    _myMarkers = [];
    _lastMapEventScrollWheelZoom = 0;
    strSubMap = _mapController.mapEventStream
        .where((event) =>
            event is MapEventMoveEnd ||
            event is MapEventDoubleTapZoomEnd ||
            event is MapEventScrollWheelZoom)
        .listen((event) {
      _latLngBounds = _mapController.camera.visibleBounds;
      if (event is MapEventScrollWheelZoom) {
        int current = DateTime.now().millisecondsSinceEpoch;
        if (_lastMapEventScrollWheelZoom + 200 < current) {
          _lastMapEventScrollWheelZoom = current;
          _createMarkers();
        }
      } else {
        _createMarkers();
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _quillController.dispose();
    _focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() => _hasFocus = !_hasFocus);

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    final double lMargin =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(widget.itinerary.id == null
                ? appLoca.agregarIt
                : appLoca.editarIt),
            centerTitle: false,
            floating: true,
            pinned: true,
            toolbarHeight: _heightAppBar,
          ),
          SliverVisibility(
            visible: _step == 0,
            sliver: SliverPadding(
              padding: EdgeInsets.all(lMargin),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    child: pasoCero(),
                  ),
                ),
              ),
            ),
          ),
          SliverVisibility(visible: _step == 1, sliver: pasoUno()),
          SliverVisibility(
            visible: _step == 2,
            sliver: SliverPadding(
              padding: EdgeInsets.all(lMargin),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    child: pasoDos(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget pasoCero() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    return Form(
      key: _gkS0,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            maxLines: 1,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: '${appLoca.tituloIt}*',
              hintText: appLoca.tituloIt,
              hintMaxLines: 1,
              hintStyle: const TextStyle(overflow: TextOverflow.ellipsis),
            ),
            textCapitalization: TextCapitalization.sentences,
            initialValue: _title,
            maxLength: 120,
            onChanged: (String v) => setState(() => _title = v),
            validator: (value) => (value == null ||
                    value.trim().isEmpty ||
                    value.trim().length > 120)
                ? appLoca.tituloItError
                : null,
            autovalidateMode: AutovalidateMode.onUnfocus,
            textInputAction: TextInputAction.next,
          ),
          Container(
            margin: EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              border: Border.fromBorderSide(
                BorderSide(
                    color: _errorDescription
                        ? colorScheme.error
                        : _hasFocus
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                    width: _hasFocus ? 2 : 1),
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
                      color: _errorDescription
                          ? colorScheme.error
                          : _hasFocus
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    constraints: const BoxConstraints(
                        maxWidth: Auxiliar.maxWidth,
                        minWidth: Auxiliar.maxWidth),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                    ),
                    child: Auxiliar.quillToolbar(_quillController),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(
                    maxWidth: Auxiliar.maxWidth,
                    maxHeight: 300,
                    minHeight: 150,
                  ),
                  child: QuillEditor.basic(
                    controller: _quillController,
                    // configurations: const QuillEditorConfigurations(
                    //   padding: EdgeInsets.all(5),
                    // ),
                    config: QuillEditorConfig(
                      padding: EdgeInsets.all(5),
                    ),
                    focusNode: _focusNode,
                  ),
                ),
                Visibility(
                  visible: _errorDescription,
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
          SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              runSpacing: 5,
              children: [
                TextButton.icon(
                  onPressed: () async => Auxiliar.showMBS(
                    context,
                    Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appLoca.typeItineraryList,
                            style: textTheme.titleMedium,
                            textAlign: TextAlign.start,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Text(
                              appLoca.typeItineraryE1,
                              textAlign: TextAlign.start,
                            ),
                          ),
                          SizedBox(height: 5),
                          Divider(),
                          SizedBox(height: 5),
                          Text(
                            appLoca.typeItineraryBag,
                            style: textTheme.titleMedium,
                            textAlign: TextAlign.start,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Text(
                              appLoca.typeItineraryE3,
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ]),
                  ),
                  label: Text(
                    appLoca.typeItinerary,
                    style: textTheme.bodyLarge,
                  ),
                  icon: Icon(Icons.info),
                  iconAlignment: IconAlignment.end,
                ),
                SegmentedButton(
                  multiSelectionEnabled: false,
                  emptySelectionAllowed: false,
                  showSelectedIcon: true,
                  segments: [
                    ButtonSegment<ItineraryType>(
                      value: ItineraryType.bag,
                      label: Text(appLoca.typeItineraryBag),
                    ),
                    ButtonSegment<ItineraryType>(
                      value: ItineraryType.list,
                      label: Text(appLoca.typeItineraryList),
                    ),
                  ],
                  selected: <ItineraryType>{widget.itinerary.type!},
                  onSelectionChanged: (Set<ItineraryType> r) {
                    setState(() {
                      widget.itinerary.type = r.first;
                    });
                  },
                )
              ],
            ),
          ),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () async {
                bool titleChecked = _gkS0.currentState!.validate();
                setState(() => _errorDescription = _description.trim().isEmpty);
                if (titleChecked && !_errorDescription) {
                  widget.itinerary
                      .addLabel(PairLang(MyApp.currentLang, _title));
                  widget.itinerary
                      .addComment(PairLang(MyApp.currentLang, _description));
                  setState(() => _step = 1);
                }
              },
              icon: Icon(Icons.arrow_right_alt),
              label: Text(appLoca.siguiente),
              iconAlignment: IconAlignment.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget pasoUno() {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    MediaQueryData mqd = MediaQuery.of(context);
    Size size = mqd.size;
    final double margenLateral = Auxiliar.getLateralMargin(size.width);
    return SliverToBoxAdapter(
      child: SizedBox(
        height: size.height - _heightAppBar,
        child: Stack(children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              backgroundColor: td.brightness == Brightness.light
                  ? Colors.white54
                  : Colors.black54,
              maxZoom: MapLayer.maxZoom,
              minZoom: MapLayer.minZoom,
              initialCameraFit: CameraFit.bounds(bounds: _latLngBounds!),
              keepAlive: false,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.pinchMove |
                    InteractiveFlag.scrollWheelZoom,
                pinchZoomThreshold: 2.0,
              ),
              onMapReady: () async => _createMarkers(),
            ),
            children: [
              MapLayer.tileLayerWidget(brightness: td.brightness),
              MapLayer.atributionWidget(),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _pointsTrack,
                    pattern: const StrokePattern.dotted(),
                    color: MapLayer.layer != Layers.satellite
                        ? colorScheme.tertiary
                        : Colors.white,
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
                    _mapController.move(
                        p0.bounds.center, min(p0.zoom + 1, MapLayer.maxZoom));
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
                      int index = widget.itinerary.points.indexWhere(
                          (PointItinerary pit) =>
                              pit.feature.point == marker.point);
                      if (index > -1) {
                        ++nPul;
                      }
                    }
                    double sizeMarker;
                    int multi = Queries.layerType == LayerType.forest ? 100 : 1;
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
                        border: Border.all(color: Colors.grey[900]!, width: 2),
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
          SafeArea(
            minimum: EdgeInsets.all(margenLateral),
            child: Align(
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: () => setState(() => _step = 0),
                    label: Text(appLoca.atras),
                    icon: Transform.rotate(
                      angle: math.pi,
                      child: Icon(Icons.arrow_right_alt),
                    ),
                  ),
                  SizedBox(height: 6),
                  FloatingActionButton.small(
                    heroTag: null,
                    tooltip: appLoca.tipoMapa,
                    onPressed: () async => _configurarTipoMapa(),
                    elevation: 1,
                    child: Icon(Icons.settings),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            minimum: EdgeInsets.all(margenLateral),
            child: Align(
              alignment: Alignment.topRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: () => setState(() => _step = 2),
                    icon: Icon(Icons.arrow_right_alt),
                    label: Text(appLoca.siguiente),
                    iconAlignment: IconAlignment.end,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(margenLateral),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                verticalDirection: VerticalDirection.up,
                children: [
                  FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () async => _addSpatialThing(),
                    label: Text(appLoca.site),
                    icon: Icon(Icons.add),
                    elevation: 1,
                  ),
                  SizedBox(height: 6),
                  FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () async => _agregarTareaItinerario(),
                    label: Text(appLoca.tareaItinerario),
                    tooltip: appLoca.addItineraryTaskHelp,
                    icon: Icon(Icons.add),
                    elevation: 1,
                  ),
                  SizedBox(height: 6),
                  FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: _trackAgregado
                        ? () async => _borrarTrack()
                        : () async => _cargarTrack(),
                    label: Text(appLoca.gpxTrack),
                    icon: Icon(_trackAgregado
                        ? Icons.delete_forever
                        : Icons.upload_file),
                    tooltip: _trackAgregado
                        ? appLoca.borrarGPXtext
                        : appLoca.agregarGPXtexto,
                    elevation: 1,
                  ),
                  SizedBox(height: 6),
                  Visibility(
                    visible: kIsWeb,
                    child: FloatingActionButton.small(
                      heroTag: null,
                      onPressed: () {
                        _mapController.move(
                            _mapController.camera.center,
                            max(_mapController.camera.zoom - 1,
                                MapLayer.minZoom));
                      },
                      elevation: 1,
                      child: Icon(Icons.zoom_out),
                    ),
                  ),
                  SizedBox(height: 3),
                  Visibility(
                    visible: kIsWeb,
                    child: FloatingActionButton.small(
                      heroTag: null,
                      onPressed: () {
                        _mapController.move(
                            _mapController.camera.center,
                            min(_mapController.camera.zoom + 1,
                                MapLayer.maxZoom));
                      },
                      elevation: 1,
                      child: Icon(Icons.zoom_in),
                    ),
                  )
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: 42,
              left: margenLateral,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Visibility(
                visible: widget.itinerary.tasks.isNotEmpty ||
                    widget.itinerary.points.isNotEmpty,
                child: FloatingActionButton.extended(
                  heroTag: null,
                  elevation: 1,
                  onPressed: () {},
                  label: Text(appLoca.resumen),
                ),
              ),
            ),
          )
        ]),
      ),
    );
  }

  void _cargarTrack() {
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    AuxiliarFunctions.readExternalFile(validExtensions: ['gpx'])
        .then((String? s) {
      if (s != null) {
        widget.itinerary.track = Track.gpx(s);
        setState(() {
          for (LatLngCHEST p in widget.itinerary.track!.points) {
            _pointsTrack.add(p.toLatLng);
          }
          _trackAgregado = true;
        });
        smState.clearSnackBars();
        smState.showSnackBar(SnackBar(
          content: Text(appLoca.agregadoGPX),
        ));
      }
    }).onError((error, stackTrace) async {
      if (error is FileExtensionException) {
        smState.clearSnackBars();
        smState.showSnackBar(SnackBar(
          backgroundColor: colorScheme.error,
          content: Text(
            error.toString(),
            style: textTheme.bodyMedium!.copyWith(color: colorScheme.onError),
          ),
        ));
      } else {
        if (Config.development) {
          debugPrint(error.toString());
        } else {
          await FirebaseCrashlytics.instance.recordError(error, stackTrace);
        }
        smState.clearSnackBars();
        smState.showSnackBar(SnackBar(
          backgroundColor: colorScheme.error,
          content: Text(
            'Error',
            style: textTheme.bodyMedium!.copyWith(color: colorScheme.onError),
          ),
        ));
      }
    });
  }

  void _borrarTrack() {
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    AppLocalizations appLoca = AppLocalizations.of(context)!;

    widget.itinerary.track = null;
    setState(() {
      _pointsTrack = [];
      _trackAgregado = false;
    });
    smState.clearSnackBars();
    smState.showSnackBar(SnackBar(
      content: Text(appLoca.borradoGPX),
    ));
  }

  void _configurarTipoMapa() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    Auxiliar.showMBS(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Wrap(spacing: 10, runSpacing: 10, children: [
              _botonMapa(
                Layers.carto,
                MediaQuery.of(context).platformBrightness == Brightness.light
                    ? 'images/basemap_gallery/estandar_claro.png'
                    : 'images/basemap_gallery/estandar_oscuro.png',
                appLoca.mapaEstandar,
              ),
              _botonMapa(
                Layers.satellite,
                'images/basemap_gallery/satelite.png',
                appLoca.mapaSatelite,
              ),
            ]),
          ),
        ],
      ),
      title: appLoca.tipoMapa,
    );
  }

  Widget _botonMapa(Layers layer, String image, String textLabel) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: MapLayer.layer == layer
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 5, top: 10, right: 10, left: 10),
      child: InkWell(
        onTap: MapLayer.layer != layer
            ? () {
                setState(() {
                  MapLayer.layer = layer;
                  // Auxiliar.updateMaxZoom();
                  if (_mapController.camera.zoom > MapLayer.maxZoom) {
                    _mapController.move(
                        _mapController.camera.center, MapLayer.maxZoom);
                  }
                });
                Navigator.pop(context);
              }
            : () {},
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

  Future<void> _agregarTareaItinerario() async {
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
      setState(() => widget.itinerary.addTask(nTask));
    }
  }

  Future<void> _addSpatialThing() async {
    LatLng center = _mapController.camera.center;
    Feature? suggestResult = await Navigator.push(
      context,
      MaterialPageRoute<Feature>(
        builder: (BuildContext context) =>
            SuggestFeature(center, _mapController.camera.visibleBounds),
        fullscreenDialog: false,
      ),
    );
    if (suggestResult != null && mounted) {
      Feature? newFeature = await Navigator.push(
          context,
          MaterialPageRoute<Feature>(
              builder: (BuildContext context) => FormPOI(suggestResult),
              fullscreenDialog: false));
      if (newFeature is Feature) {
        MapData.resetLocalCache();
        // TODO checkMarkerType();
      }
    }
  }

  void _createMarkers() async {
    _myMarkers = [];
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    MapData.checkCurrentMapSplit(_latLngBounds!)
        .then((List<Feature> listFeatures) {
      for (int i = 0, tama = listFeatures.length; i < tama; i++) {
        Feature feature = listFeatures.elementAt(i);
        if (!feature
            .getALabel(lang: MyApp.currentLang)
            .contains('www.openstreetmap.org')) {
          bool seleccionado = widget.itinerary.points.indexWhere(
                  (PointItinerary pointItinerary) =>
                      pointItinerary.feature.id == feature.id) >
              -1;
          _myMarkers.add(CHESTMarker(context,
              feature: feature,
              icon: Icon(Icons.castle_outlined,
                  color: seleccionado
                      ? colorScheme.onPrimaryContainer
                      : Colors.black),
              circleWidthBorder: seleccionado ? 2 : 1,
              circleWidthColor:
                  seleccionado ? colorScheme.primary : Colors.grey,
              circleContainerColor: seleccionado
                  ? td.colorScheme.primaryContainer
                  : Colors.grey[400]!,
              textInGray: !seleccionado, onTap: () async {
            int index = widget.itinerary.points.indexWhere(
                (PointItinerary pointItinerary) =>
                    pointItinerary.feature.id == feature.id);
            PointItinerary pointItinerary;
            if (index >= 0) {
              pointItinerary = widget.itinerary.points.elementAt(index);
            } else {
              pointItinerary = PointItinerary({
                'id': feature.id,
              });
              pointItinerary.feature = feature;
            }

            PointItinerary? pIt = await Navigator.push(
              context,
              MaterialPageRoute<PointItinerary>(
                  builder: (BuildContext context) => AddEditPointItineary(
                      pointItinerary, widget.itinerary.type!, index < 0),
                  fullscreenDialog: true),
            );
            if (pIt is PointItinerary) {
              if (pIt.removeFromIt) {
                widget.itinerary.removePoint(pIt);
              } else {
                setState(() {
                  widget.itinerary.addPoints(pIt);
                });
              }
            }
            _createMarkers();
          }));
        }
      }
      setState(() {});
    });
  }

  Widget pasoDos() {
    return SliverToBoxAdapter();
  }
}

class AddEditPointItineary extends StatefulWidget {
  final PointItinerary pointItinerary;
  final ItineraryType itineraryType;
  final bool newPointItinerary;

  const AddEditPointItineary(
      this.pointItinerary, this.itineraryType, this.newPointItinerary,
      {super.key});

  @override
  State<StatefulWidget> createState() => _AddEditPointItinerary();
}

class _AddEditPointItinerary extends State<AddEditPointItineary> {
  late int _step;
  late bool _retrieveFeature;
  late String _comment, _label;
  late FocusNode _focusNode;
  late QuillController _quillController;
  late bool _hasFocus, _errorDescription;
  late GlobalKey<FormState> _globalKey;
  late List<Task> _tasks;

  @override
  void initState() {
    _step = 0;
    _retrieveFeature = widget.newPointItinerary;
    _comment = widget.pointItinerary.hasFeature
        ? widget.pointItinerary.feature.getAComment(lang: MyApp.currentLang)
        : '';
    _label = widget.pointItinerary.hasFeature
        ? widget.pointItinerary.feature.getALabel(lang: MyApp.currentLang)
        : '';
    _globalKey = GlobalKey<FormState>();

    _focusNode = FocusNode();
    _quillController = QuillController.basic();
    try {
      _quillController.document = Document.fromDelta(HtmlToDelta().convert(
          widget.pointItinerary.hasFeature &&
                  widget.pointItinerary.feature.comments.isNotEmpty
              ? widget.pointItinerary.feature
                  .getAComment(lang: MyApp.currentLang)
              : _comment));
    } catch (error) {
      _quillController.document = Document();
    }
    _quillController.document.changes.listen((DocChange onData) {
      setState(() {
        _comment =
            Auxiliar.quillDelta2Html(_quillController.document.toDelta());
      });
    });
    _hasFocus = false;
    _errorDescription = false;
    _focusNode.addListener(_onFocus);

    _tasks = [];

    super.initState();
  }

  void _onFocus() => setState(() => _hasFocus = !_hasFocus);

  @override
  void dispose() {
    _quillController.dispose();
    _focusNode.removeListener(_onFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    final double lMargin =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(appLoca.siteIt),
            centerTitle: false,
          ),
          SliverVisibility(
            visible: _step == 0,
            sliver: SliverPadding(
              padding: EdgeInsets.all(lMargin),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    child: _stepZero(),
                  ),
                ),
              ),
            ),
          ),
          SliverVisibility(
            visible: _step == 1,
            sliver: SliverPadding(
              padding: EdgeInsets.all(lMargin),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    child: _stepOne(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List> _getFeature(idFeature) {
    return http.get(Queries.getFeatureInfo(idFeature)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Future<List> _getTasks(String shortId) {
    return http.get(Queries.getTasks(shortId)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Widget _stepZero() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appLoca.descripcionLugar,
          style: td.textTheme.titleLarge,
        ),
        Text(appLoca.descripcionLugarExplica),
        SizedBox(height: 15),
        _retrieveFeature
            ? FutureBuilder<List>(
                future: _getFeature(widget.pointItinerary.feature.shortId),
                builder: (context, snapshot) {
                  if (!snapshot.hasError && snapshot.hasData) {
                    for (int i = 0, tama = snapshot.data!.length;
                        i < tama;
                        i++) {
                      Map provider = snapshot.data![i];
                      Map<String, dynamic>? data = provider['data'];
                      switch (provider["provider"]) {
                        case 'osm':
                          OSM osm = OSM(data);
                          for (PairLang l in osm.labels) {
                            widget.pointItinerary.feature.addLabelLang(l);
                          }
                          if (osm.image != null) {
                            widget.pointItinerary.feature.setThumbnail(
                                osm.image!.image,
                                osm.image!.hasLicense
                                    ? osm.image!.license
                                    : null);
                          }
                          for (PairLang d in osm.descriptions) {
                            widget.pointItinerary.feature.addCommentLang(d);
                          }
                          widget.pointItinerary.feature
                              .addProvider(provider['provider'], osm);
                          break;
                        case 'wikidata':
                          Wikidata? wikidata = Wikidata(data);
                          for (PairLang label in wikidata.labels) {
                            widget.pointItinerary.feature.addLabelLang(label);
                          }
                          for (PairLang comment in wikidata.descriptions) {
                            widget.pointItinerary.feature
                                .addCommentLang(comment);
                          }
                          for (PairImage image in wikidata.images) {
                            widget.pointItinerary.feature.addImage(image.image,
                                license:
                                    image.hasLicense ? image.license : null);
                          }
                          widget.pointItinerary.feature
                              .addProvider(provider['provider'], wikidata);
                          break;
                        case 'jcyl':
                          JCyL jcyl = JCyL(data);
                          widget.pointItinerary.feature
                              .addCommentLang(jcyl.description);
                          widget.pointItinerary.feature
                              .addProvider(provider['provider'], jcyl);
                          break;
                        case 'esDBpedia':
                        case 'dbpedia':
                          DBpedia dbpedia = DBpedia(data, provider['provider']);
                          for (PairLang comment in dbpedia.descriptions) {
                            widget.pointItinerary.feature
                                .addCommentLang(comment);
                          }
                          for (PairLang label in dbpedia.labels) {
                            widget.pointItinerary.feature.addLabelLang(label);
                          }
                          widget.pointItinerary.feature
                              .addProvider(provider['provider'], dbpedia);
                          break;
                        default:
                      }
                    }
                    List<PairLang> allComments =
                        widget.pointItinerary.feature.comments;
                    List<PairLang> comments = [];
                    // Prioridad a la información en el idioma del usuario
                    for (PairLang comment in allComments) {
                      if (comment.hasLang &&
                          comment.lang == MyApp.currentLang) {
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
                      comments.sort((PairLang a, PairLang b) =>
                          b.value.length.compareTo(a.value.length));
                    }
                    _retrieveFeature = false;
                    _label = widget.pointItinerary.feature
                        .getALabel(lang: MyApp.currentLang);
                    _comment = comments.first.value;
                    _quillController.document
                        .delete(0, _quillController.document.length);
                    _quillController.document.compose(
                        HtmlToDelta().convert(_comment), ChangeSource.silent);
                    return _formularioST();
                  } else {
                    return CircularProgressIndicator.adaptive();
                  }
                })
            : _formularioST(),
      ],
    );
  }

  Widget _formularioST() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    return Form(
      key: _globalKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            maxLines: 1,
            decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: appLoca.tituloSite,
                hintText: appLoca.tituloSite,
                helperText: appLoca.requerido,
                hintMaxLines: 1,
                hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.text,
            initialValue: widget.pointItinerary.feature
                .getALabel(lang: MyApp.currentLang),
            onChanged: (String value) => setState(() => _label = value),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return appLoca.tituloNPIExplica;
              } else {
                return null;
              }
            },
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              border: Border.fromBorderSide(
                BorderSide(
                    color: _errorDescription
                        ? colorScheme.error
                        : _hasFocus
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                    width: _hasFocus ? 2 : 1),
              ),
              color: colorScheme.surface,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${appLoca.descrNPI}*',
                    style: td.textTheme.bodySmall!.copyWith(
                      color: _errorDescription
                          ? colorScheme.error
                          : _hasFocus
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(
                            maxWidth: Auxiliar.maxWidth,
                            minWidth: Auxiliar.maxWidth),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                        ),
                        child: Auxiliar.quillToolbar(_quillController),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(
                        maxWidth: Auxiliar.maxWidth,
                        maxHeight: 300,
                        minHeight: 150,
                      ),
                      child: QuillEditor.basic(
                        controller: _quillController,
                        config: QuillEditorConfig(
                          padding: EdgeInsets.all(5),
                        ),
                        focusNode: _focusNode,
                      ),
                    ),
                    Visibility(
                      visible: _errorDescription,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          appLoca.descrNPIExplica,
                          style: textTheme.bodySmall!.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
                direction: Axis.horizontal,
                spacing: 10,
                runSpacing: 5,
                children: [
                  Visibility(
                    visible: !widget.newPointItinerary,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                      label: Text(
                        appLoca.removeResourcesIt,
                      ),
                      icon: Icon(
                        Icons.dangerous,
                      ),
                      onPressed: () {
                        widget.pointItinerary.removeFromIt = true;
                        context.pop(widget.pointItinerary);
                      },
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      bool sigue = _globalKey.currentState!.validate();
                      setState(() {
                        _errorDescription = _comment.trim() == '';
                      });
                      if (sigue && !_errorDescription) {
                        widget.pointItinerary.feature.resetLabels();
                        widget.pointItinerary.feature.resetComments();
                        widget.pointItinerary.feature
                            .addLabelLang(PairLang(MyApp.currentLang, _label));
                        widget.pointItinerary.feature.addCommentLang(
                            PairLang(MyApp.currentLang, _comment));
                        setState(() => _step = 1);
                      }
                    },
                    child: Text(appLoca.siguiente),
                  ),
                ]),
          )
        ],
      ),
    );
  }

  Widget _stepOne() {
    return _tasks.isEmpty
        ? FutureBuilder<List>(
            future: _getTasks(widget.pointItinerary.feature.shortId),
            builder: (context, snapshot) {
              if (!snapshot.hasError && snapshot.hasData) {
                Object data = snapshot.data!;
                if (data is List) {
                  for (Object task in data) {
                    try {
                      _tasks.add(Task(task,
                          idContainer: widget.pointItinerary.id,
                          containerType: ContainerTask.spatialThing));
                    } catch (e) {
                      debugPrint(e.toString());
                    }
                  }
                }
                return _listasDeTareas();
              } else {
                return CircularProgressIndicator.adaptive();
              }
            })
        : _listasDeTareas();
  }

  Widget _listasDeTareas() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _listaTareasNoSeleccionadas(),
        SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            appLoca.tareasSeleccionadasLugar,
            style: textTheme.titleLarge,
          ),
        ),
        _listaTareasSeleccionadas(),
        SizedBox(height: 20),
        Align(
          alignment: Alignment.bottomRight,
          child: Wrap(
              direction: Axis.horizontal,
              spacing: 10,
              runSpacing: 5,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _step = 0;
                    });
                  },
                  label: Text(appLoca.atras),
                ),
                Visibility(
                  visible: !widget.newPointItinerary,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    label: Text(
                      appLoca.removeResourcesIt,
                    ),
                    icon: Icon(
                      Icons.dangerous,
                    ),
                    onPressed: () {
                      widget.pointItinerary.removeFromIt = true;
                      context.pop(widget.pointItinerary);
                    },
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    widget.pointItinerary.removeFromIt = false;
                    context.pop(widget.pointItinerary);
                  },
                  label: Text(appLoca.addResourcesIt),
                  icon: Icon(
                    Icons.add,
                  ),
                ),
              ]),
        )
      ],
    );
  }

  Widget _listaTareasNoSeleccionadas() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    TextTheme textTheme = td.textTheme;
    List<Widget> children = [
      Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          appLoca.tareasNoSeleccionadasLugar,
          style: textTheme.titleLarge,
        ),
      )
    ];
    if (_tasks.isEmpty) {
      children.add(Text(appLoca.sinTareasAgrega));
    } else {
      for (Task task in _tasks) {
        children.add(Visibility(
          visible: !widget.pointItinerary.tasks.contains(task.id),
          child: _tarjetaTarea(task, colorScheme.onSurface, colorScheme.surface,
              labelAction: appLoca.addTaskToIt,
              funAction: () =>
                  setState(() => widget.pointItinerary.addTask(task))),
        ));
      }

      children.add(Visibility(
          visible: widget.pointItinerary.hasLstTasks &&
              widget.pointItinerary.tasks.length == _tasks.length,
          child: Text(appLoca.todasTareasSeleccionadas)));
    }

    children.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Align(
          alignment: Alignment.bottomRight,
          child: OutlinedButton.icon(
            label: Text(appLoca.taskFor),
            icon: Icon(Icons.add),
            onPressed: () async {
              Task? newTask = await Navigator.push(
                  context,
                  MaterialPageRoute<Task>(
                      builder: (BuildContext context) => FormTask(
                            Task.empty(
                              idContainer: widget.pointItinerary.id,
                              containerType: ContainerTask.spatialThing,
                            ),
                          ),
                      fullscreenDialog: true));
              if (newTask != null) {
                setState(() => _tasks = []);
              }
            },
          ),
        ),
      ),
    );

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _listaTareasSeleccionadas() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    List<Widget> tSeleccionadas = [];
    if (widget.pointItinerary.hasLstTasks &&
        widget.pointItinerary.tasksObj.isNotEmpty) {
      for (Task task in widget.pointItinerary.tasksObj) {
        tSeleccionadas.add(_tarjetaTarea(
            task, colorScheme.onPrimaryContainer, colorScheme.primaryContainer,
            labelAction: appLoca.removeTaskFromIt,
            funAction: () =>
                setState(() => widget.pointItinerary.removeTask(task))));
      }
    }
    return !widget.pointItinerary.hasLstTasks ||
            widget.pointItinerary.tasksObj.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(appLoca.sinTareasSeleccionadas),
          )
        : widget.itineraryType == ItineraryType.list
            ? ReorderableListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  Task task = widget.pointItinerary.tasksObj.elementAt(index);
                  return _tarjetaTarea(task, colorScheme.onPrimaryContainer,
                      colorScheme.primaryContainer,
                      key: Key('$index'),
                      labelAction: appLoca.removeTaskFromIt,
                      funAction: () => setState(
                          () => widget.pointItinerary.removeTask(task)));
                },
                itemCount: widget.pointItinerary.hasLstTasks
                    ? widget.pointItinerary.tasksObj.length
                    : 0,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final Task item =
                        widget.pointItinerary.tasksObj.removeAt(oldIndex);
                    widget.pointItinerary.tasksObj.insert(newIndex, item);
                  });
                },
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: tSeleccionadas,
              );
  }

  Widget _tarjetaTarea(Task task, Color color, Color background,
      {String? labelAction, VoidCallback? funAction, Key? key}) {
    ThemeData td = Theme.of(context);
    TextTheme textTheme = td.textTheme;
    return Card(
      key: key,
      elevation: 0,
      shape: RoundedRectangleBorder(
          side: BorderSide(
            color: color,
          ),
          borderRadius: const BorderRadius.all(Radius.circular(12))),
      color: background,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(
                  top: 8, bottom: 16, right: 16, left: 16),
              width: double.infinity,
              child: Text(
                task.getALabel(lang: MyApp.currentLang),
                style: textTheme.titleMedium!.copyWith(color: color),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
              width: double.infinity,
              child: HtmlWidget(
                task.getAComment(lang: MyApp.currentLang),
                textStyle: textTheme.bodyMedium!
                    .copyWith(overflow: TextOverflow.ellipsis, color: color),
              ),
            ),
            funAction == null || labelAction == null
                ? Container()
                : Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                      onPressed: funAction,
                      child: Text(
                        labelAction,
                        style: textTheme.bodyMedium!.copyWith(
                          color: color,
                        ),
                      ),
                    ),
                  ),
          ]),
    );
  }
}

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
  late bool _ordenPoi, /*_start,*/ _ordenTasks, _enableBt, _trackAgregado;
  late FocusNode _focusNode;
  late QuillController _quillController;
  late bool _hasFocus, _errorDescription;
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
    _focusNode = FocusNode();
    _quillController = QuillController.basic();
    try {
      _quillController.document =
          Document.fromDelta(HtmlToDelta().convert(_descriIt));
    } catch (error) {
      _quillController.document = Document();
    }
    _quillController.document.changes.listen((DocChange onData) {
      setState(() {
        _descriIt =
            Auxiliar.quillDelta2Html(_quillController.document.toDelta());
      });
    });
    _hasFocus = false;
    _errorDescription = false;
    _focusNode.addListener(_onFocus);
    super.initState();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _quillController.dispose();
    _focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() => _hasFocus = !_hasFocus);

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
                    appLoca!.sitesSeleccionados(_numPoiSelect),
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
                        appLoca!.tasksSeleccionadas(_numTaskSelect),
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
                              : const CircularProgressIndicator.adaptive(),
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
                      setState(() => _errorDescription = false);
                      _newIt.comments = {
                        "value": _descriIt,
                        "lang": MyApp.currentLang
                      };
                    } else {
                      setState(() => _errorDescription = true);
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
                        } on Exception catch (e, stack) {
                          if (Config.development) {
                            debugPrint(e.toString());
                          } else {
                            await FirebaseCrashlytics.instance
                                .recordError(e, stack);
                          }
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
                      _pointsItinerary[i].addTaskId(task.id);
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
                                'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
                          },
                          body: json.encode(bodyRequest))
                      .then((response) {
                    switch (response.statusCode) {
                      case 201:
                        //Vuelvo a la pantalla anterior. True para que recargue (adaptar la anterior)
                        String idIt = response.headers['location']!;
                        _newIt.id = idIt;
                        _newIt.author = UserXEST.userXEST.id;
                        if (!Config.development) {
                          FirebaseAnalytics.instance.logEvent(
                              name: 'newItinerary',
                              parameters: {
                                'iri': Auxiliar.id2shortId(idIt)!,
                                'author': _newIt.author!
                              }).then((_) {
                            if (context.mounted) Navigator.pop(context, _newIt);
                            smState.clearSnackBars();
                            smState.showSnackBar(
                              SnackBar(content: Text(appLoca!.infoRegistrada)),
                            );
                          });
                        } else {
                          Navigator.pop(context, _newIt);
                          smState.clearSnackBars();
                          smState.showSnackBar(
                            SnackBar(content: Text(appLoca!.infoRegistrada)),
                          );
                        }
                        break;
                      default:
                        setState(() => _enableBt = true);
                        smState.clearSnackBars();
                        smState.showSnackBar(SnackBar(
                            content: Text(response.statusCode.toString())));
                    }
                  }).onError((error, stackTrace) async {
                    setState(() => _enableBt = true);
                    smState.clearSnackBars();
                    smState
                        .showSnackBar(const SnackBar(content: Text("Error")));
                    if (Config.development) {
                      debugPrint(error.toString());
                    } else {
                      await FirebaseCrashlytics.instance
                          .recordError(error, stackTrace);
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
        if (!p
            .getALabel(lang: MyApp.currentLang)
            .contains('https://www.openstreetmap.org/')) {
          bool pulsado =
              _pointS.indexWhere((Feature poi) => poi.id == p.id) > -1;
          _myMarkers.add(CHESTMarker(context,
              feature: p,
              icon: Icon(Icons.castle_outlined,
                  color:
                      pulsado ? colorScheme.onPrimaryContainer : Colors.black),
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
                    color: _errorDescription
                        ? colorScheme.error
                        : _hasFocus
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                    width: _hasFocus ? 2 : 1),
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
                      color: _errorDescription
                          ? colorScheme.error
                          : _hasFocus
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    constraints: const BoxConstraints(
                        maxWidth: Auxiliar.maxWidth,
                        minWidth: Auxiliar.maxWidth),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                    ),
                    child: Auxiliar.quillToolbar(_quillController),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(
                    maxWidth: Auxiliar.maxWidth,
                    maxHeight: 300,
                    minHeight: 150,
                  ),
                  child: QuillEditor.basic(
                    controller: _quillController,
                    // configurations: const QuillEditorConfigurations(
                    //   padding: EdgeInsets.all(5),
                    // ),
                    config: QuillEditorConfig(
                      padding: EdgeInsets.all(5),
                    ),
                    focusNode: _focusNode,
                  ),
                ),
                Visibility(
                  visible: _errorDescription,
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

  // Widget _showURLDialog(String selectText, int indexS, int lengthS) {
  //   AppLocalizations appLoca = AppLocalizations.of(context)!;
  //   TextTheme textTheme = Theme.of(context).textTheme;
  //   String uri = '';
  //   GlobalKey<FormState> formEnlace = GlobalKey<FormState>();
  //   return Padding(
  //     padding: EdgeInsets.only(
  //       bottom: MediaQuery.of(context).viewInsets.bottom + 20,
  //       left: 10,
  //       right: 10,
  //     ),
  //     child: Form(
  //       key: formEnlace,
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           Text(
  //             appLoca.agregaEnlace,
  //             style: textTheme.titleMedium,
  //           ),
  //           const SizedBox(height: 20),
  //           TextFormField(
  //             maxLines: 1,
  //             decoration: InputDecoration(
  //               border: const OutlineInputBorder(),
  //               labelText: "${appLoca.enlace}*",
  //               hintText: appLoca.hintEnlace,
  //               helperText: appLoca.requerido,
  //               hintMaxLines: 1,
  //             ),
  //             textInputAction: TextInputAction.next,
  //             keyboardType: TextInputType.url,
  //             validator: (value) {
  //               if (value != null && value.isNotEmpty) {
  //                 uri = value.trim();
  //                 return null;
  //               }
  //               return appLoca.errorEnlace;
  //             },
  //           ),
  //           const SizedBox(height: 10),
  //           Wrap(
  //             alignment: WrapAlignment.end,
  //             spacing: 10,
  //             direction: Axis.horizontal,
  //             children: [
  //               TextButton(
  //                 onPressed: () => Navigator.of(context).pop(),
  //                 child: Text(appLoca.cancelar),
  //               ),
  //               FilledButton(
  //                 onPressed: () async {
  //                   if (formEnlace.currentState!.validate()) {
  //                     _quillEditorController
  //                         .setSelectionRange(indexS, lengthS)
  //                         .then(
  //                       (value) {
  //                         _quillEditorController
  //                             .getSelectedText()
  //                             .then((textoSeleccionado) async {
  //                           if (textoSeleccionado != null &&
  //                               textoSeleccionado is String &&
  //                               textoSeleccionado.isNotEmpty) {
  //                             _quillEditorController.setFormat(
  //                                 format: 'link', value: uri);
  //                             if (mounted) Navigator.of(context).pop();
  //                             setState(() {
  //                               _focusQuillEditorController = true;
  //                             });
  //                             _quillEditorController.focus();
  //                           }
  //                         });
  //                       },
  //                     );
  //                   }
  //                 },
  //                 child: Text(appLoca.insertarEnlace),
  //               )
  //             ],
  //           )
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget contentStep1() {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    TextTheme textTheme = td.textTheme;
    Size size = MediaQuery.of(context).size;
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
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
                maxHeight: max(size.height - 300, 200)),
            child: Stack(
              alignment: AlignmentDirectional.bottomEnd,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    backgroundColor: td.brightness == Brightness.light
                        ? Colors.white54
                        : Colors.black54,
                    maxZoom: MapLayer.maxZoom,
                    minZoom: 13,
                    initialCenter: widget.initPoint,
                    initialZoom: widget.initZoom,
                    keepAlive: false,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.pinchZoom |
                          InteractiveFlag.doubleTapZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.pinchMove |
                          InteractiveFlag.scrollWheelZoom,
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
                            builder: (BuildContext context) => SuggestFeature(
                                point, _mapController.camera.visibleBounds),
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
                    MapLayer.tileLayerWidget(brightness: td.brightness),
                    MapLayer.atributionWidget(),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _pointsTrack,
                          pattern: const StrokePattern.dotted(),
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
                              min(p0.zoom + 1, MapLayer.maxZoom));
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
                            setState(() {
                              for (LatLngCHEST p in _newIt.track!.points) {
                                _pointsTrack.add(p.toLatLng);
                              }
                              debugPrint(_pointsTrack.length.toString());
                              _trackAgregado = true;
                            });
                            smState.clearSnackBars();
                            smState.showSnackBar(SnackBar(
                              content: Text(appLoca.agregadoGPX),
                            ));
                          }
                        }).onError((error, stackTrace) async {
                          if (error is FileExtensionException) {
                            smState.clearSnackBars();
                            smState.showSnackBar(SnackBar(
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
                            } else {
                              await FirebaseCrashlytics.instance
                                  .recordError(error, stackTrace);
                            }
                            smState.clearSnackBars();
                            smState.showSnackBar(SnackBar(
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
              // onChanged: (v) {
              //   setState(() {
              //     _ordenPoi = v;
              //   });
              // },
              onChanged: null,
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
          Visibility(
            visible: false,
            child: SwitchListTile.adaptive(
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
  final String shortId;
  const InfoItinerary(this.shortId, {super.key});

  @override
  State<StatefulWidget> createState() => _InfoItinerary();
}

class _InfoItinerary extends State<InfoItinerary> {
  Future<Map<String, dynamic>> _getItinerary(idIt) {
    return http.get(Queries.getItinerary(idIt)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : {});
  }

  Future<Map<String, dynamic>> _getItineraryFeatures(idIt) {
    return http.get(Queries.getItineraryFeatures(idIt)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : {});
  }

  Future<List> _getItineraryTrack(idIt) {
    return http.get(Queries.getItineraryTrack(idIt)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Future<List> _getItineraryTasks(idIt) {
    return http.get(Queries.getItineraryTask(idIt)).then((response) =>
        response.statusCode == 200 ? json.decode(response.body) : []);
  }

  Future<List> _getTasksFeature(idIt, idFeature) {
    return http.get(Queries.getTasksFeatureIt(idIt, idFeature)).then(
        (response) =>
            response.statusCode == 200 ? json.decode(response.body) : []);
  }

  final MapController _mapController = MapController();
  late Itinerary itinerary;
  late GlobalKey globalKey;
  late String? id;

  @override
  void initState() {
    // itinerary = Itinerary.empty();
    globalKey = GlobalKey();
    // itinerary.id = Auxiliar.shortId2Id(widget.shortId);
    id = Auxiliar.shortId2Id(widget.shortId);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widgetBody(),
      floatingActionButton: Visibility(
        key: globalKey,
        visible: !kIsWeb,
        child: FloatingActionButton.small(
            heroTag: Auxiliar.mainFabHero,
            onPressed: () async => Auxiliar.share(globalKey,
                '${Config.addClient}/home/itineraries/${widget.shortId}'),
            child: const Icon(Icons.share)),
      ),
    );
  }

  Widget widgetBody() {
    ThemeData td = Theme.of(context);
    TextTheme textTheme = td.textTheme;
    ColorScheme colorScheme = td.colorScheme;
    double margenLateral =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);

    if (id == null) {
      return CustomScrollView(
        slivers: [
          SliverAppBar(title: Text(AppLocalizations.of(context)!.noEncontrado))
        ],
      );
    }
    return FutureBuilder(
        future: _getItinerary(id),
        builder: (context, snapshot) {
          if (!snapshot.hasError && snapshot.hasData) {
            Object? bodyItinerary = snapshot.data;
            if (bodyItinerary != null &&
                bodyItinerary is Map<String, dynamic>) {
              if (bodyItinerary.isEmpty) {
                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                        title: Text(AppLocalizations.of(context)!.noEncontrado))
                  ],
                );
              }
              bodyItinerary['id'] = id;
              itinerary = Itinerary(bodyItinerary);

              return CustomScrollView(slivers: [
                SliverAppBar(
                  title: Text(itinerary.getALabel(lang: MyApp.currentLang)),
                  floating: true,
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(top: 40),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: Container(
                        constraints:
                            const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(20),
                        margin: EdgeInsets.symmetric(horizontal: margenLateral),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: HtmlWidget(
                                itinerary.getAComment(lang: MyApp.currentLang),
                                textStyle: textTheme.bodyMedium!.copyWith(
                                    color: colorScheme.onSecondaryContainer),
                                factoryBuilder: () => MyWidgetFactory(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: margenLateral,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: Container(
                        constraints:
                            const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                        child: FutureBuilder(
                            future: _getItineraryFeatures(itinerary.id),
                            builder: (context, snapshot) {
                              if (!snapshot.hasError && snapshot.hasData) {
                                Object? bodyFeatures = snapshot.data;
                                if (bodyFeatures != null &&
                                    bodyFeatures is Map &&
                                    (bodyFeatures as Map<String, dynamic>)
                                        .containsKey('feature')) {
                                  if (bodyFeatures['feature'] is Map) {
                                    bodyFeatures['feature'] = [
                                      bodyFeatures['feature']
                                    ];
                                  }
                                  if (bodyItinerary.containsKey('track')) {
                                    return FutureBuilder(
                                        future:
                                            _getItineraryTrack(itinerary.id),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasError &&
                                              snapshot.hasData) {
                                            Object? bodyTrack = snapshot.data;
                                            if (bodyTrack != null &&
                                                bodyTrack is List) {
                                              return _generaMapa(
                                                  bodyItinerary: bodyItinerary,
                                                  bodyFeatures: bodyFeatures,
                                                  track: bodyTrack);
                                            } else {
                                              return Container();
                                            }
                                          } else {
                                            return snapshot.hasError
                                                ? Container()
                                                : const CircularProgressIndicator
                                                    .adaptive();
                                          }
                                        });
                                  } else {
                                    return _generaMapa(
                                        bodyItinerary: bodyItinerary,
                                        bodyFeatures: bodyFeatures);
                                  }
                                } else {
                                  return Container();
                                }
                              } else {
                                return snapshot.hasError
                                    ? Container()
                                    : const CircularProgressIndicator
                                        .adaptive();
                              }
                            }),
                      ),
                    ),
                  ),
                ),
              ]);

              // return FutureBuilder(
              //     future: _getItineraryFeatures(itinerary.id),
              //     builder: (context, snapshot) {
              //       if (!snapshot.hasError && snapshot.hasData) {
              //         Object? bodyFeatures = snapshot.data;
              //         if (bodyFeatures != null &&
              //             bodyFeatures is Map &&
              //             (bodyFeatures as Map<String, dynamic>)
              //                 .containsKey('feature')) {
              //           if (bodyFeatures['feature'] is Map) {
              //             bodyFeatures['feature'] = [bodyFeatures['feature']];
              //           }
              //           if (bodyItinerary.containsKey('track')) {
              //             return FutureBuilder(
              //                 future: _getItineraryTrack(itinerary.id),
              //                 builder: (context, snapshot) {
              //                   if (!snapshot.hasError && snapshot.hasData) {
              //                     Object? bodyTrack = snapshot.data;
              //                     if (bodyTrack != null && bodyTrack is List) {
              //                       return _generaMapa(
              //                           bodyItinerary: bodyItinerary,
              //                           bodyFeatures: bodyFeatures,
              //                           track: bodyTrack);
              //                     } else {
              //                       return Container();
              //                     }
              //                   } else {
              //                     return snapshot.hasError
              //                         ? Container()
              //                         : const CircularProgressIndicator
              //                             .adaptive();
              //                   }
              //                 });
              //           } else {
              //             return _generaMapa(
              //                 bodyItinerary: bodyItinerary,
              //                 bodyFeatures: bodyFeatures);
              //           }
              //         } else {
              //           return Container();
              //         }
              //       } else {
              //         return snapshot.hasError
              //             ? Container()
              //             : const CircularProgressIndicator.adaptive();
              //       }
              //     });
            } else {
              return CustomScrollView(
                  slivers: [SliverToBoxAdapter(child: Container())]);
            }
          } else {
            return snapshot.hasError
                ? CustomScrollView(
                    slivers: [SliverToBoxAdapter(child: Container())])
                : const CustomScrollView(slivers: [
                    SliverToBoxAdapter(
                        child:
                            Center(child: CircularProgressIndicator.adaptive()))
                  ]);
          }
        });
  }

  Widget _generaMapa({
    required Map<String, dynamic> bodyItinerary,
    required Map<String, dynamic> bodyFeatures,
    List? track,
  }) {
    List points = bodyFeatures['feature'];
    List<PointItinerary> featuresIt = [];
    List<CHESTMarker> markers = [];
    List<LatLng> trackPoints = [];
    double sup = -90, inf = 90, izq = 180, der = -180;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    for (Map<String, dynamic> point in points) {
      PointItinerary pointItinerary = PointItinerary({'id': point['id']});
      pointItinerary.feature = Feature(point);
      sup = pointItinerary.feature.lat > sup ? pointItinerary.feature.lat : sup;
      inf = pointItinerary.feature.lat < inf ? pointItinerary.feature.lat : inf;
      izq =
          pointItinerary.feature.long < izq ? pointItinerary.feature.long : izq;
      der =
          pointItinerary.feature.long > der ? pointItinerary.feature.long : der;
      if (point.containsKey('commentAlt')) {
        pointItinerary.altComments = point['commentAlt'];
      }
      featuresIt.add(pointItinerary);
      markers.add(CHESTMarker(
        context,
        feature: pointItinerary.feature,
        icon: Center(
          child: Icon(
            Auxiliar.getIcon(pointItinerary.feature.spatialThingTypes),
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        currentLayer: MapLayer.layer!,
        circleWidthBorder: 1,
        circleWidthColor: colorScheme.primary,
        circleContainerColor: colorScheme.primaryContainer,
      ));
    }
    if (track != null) {
      Track trackIt = Track.server({'track': track});
      trackIt.calculateBounds();
      itinerary.track = trackIt;
      for (var p in track) {
        if (p is Map<String, dynamic> &&
            p.containsKey('lat') &&
            p.containsKey('long')) {
          trackPoints.add(LatLng(p['lat'], p['long']));
        }
      }
      sup = itinerary.track!.northWest.latitude;
      inf = itinerary.track!.southEast.latitude;
      izq = itinerary.track!.northWest.longitude;
      der = itinerary.track!.southEast.longitude;
    }
    List<Widget> columnLstTasks = [];
    for (int i = 0, tama = featuresIt.length; i < tama; i++) {
      PointItinerary pointItinerary = featuresIt.elementAt(i);
      columnLstTasks.add(Container(
        padding: const EdgeInsets.all(20),
        margin: i != 0
            ? const EdgeInsets.symmetric(vertical: 5)
            : const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          // border: Border.all(color: colorScheme.tertiary),
          color: colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: FutureBuilder(
            future:
                _getTasksFeature(itinerary.id, pointItinerary.feature.shortId),
            builder: (context, snapshot) {
              if (!snapshot.hasError && snapshot.hasData) {
                Object? objTasks = snapshot.data;
                if (objTasks != null) {
                  if (objTasks is Map) {
                    objTasks = [objTasks];
                  }
                  if (objTasks is List) {
                    List<Task> lstTask = [];
                    for (Map o in objTasks) {
                      try {
                        Task t = Task(o);
                        lstTask.add(t);
                        featuresIt.elementAt(i).addTask(t);
                      } catch (error, stackTrace) {
                        if (Config.development) {
                          debugPrint(error.toString());
                        } else {
                          FirebaseCrashlytics.instance
                              .recordError(error, stackTrace);
                        }
                      }
                    }
                    itinerary.addPoints(featuresIt.elementAt(i));
                    List<Widget> lstTasks = [];
                    lstTasks.add(SizedBox(
                      width: double.infinity,
                      child: Text(
                        pointItinerary.feature
                            .getALabel(lang: MyApp.currentLang),
                        style: td.textTheme.bodyLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ));
                    if (lstTask.isNotEmpty) {
                      lstTasks.add(Text(
                        '${AppLocalizations.of(context)!.nTaskAso}: ${lstTask.length}',
                        style: td.textTheme.bodyMedium!.copyWith(
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ));
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: lstTasks,
                      );
                    } else {
                      List<Widget> lstTasks = [];
                      lstTasks.add(Text(
                        pointItinerary.feature
                            .getALabel(lang: MyApp.currentLang),
                        style: td.textTheme.bodyLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onTertiaryContainer,
                        ),
                      ));
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: lstTasks,
                      );
                    }
                  }
                }
                return Container();
              } else {
                return snapshot.hasError
                    ? Container()
                    : const CircularProgressIndicator.adaptive();
              }
            }),
      ));
    }
    Size size = MediaQuery.of(context).size;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 20),
          constraints: BoxConstraints(
            maxWidth: Auxiliar.maxWidth,
            maxHeight: 0.5 * size.height,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(alignment: Alignment.bottomRight, children: [
              FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    backgroundColor: td.brightness == Brightness.light
                        ? Colors.white54
                        : Colors.black54,
                    maxZoom: MapLayer.maxZoom,
                    minZoom: MapLayer.minZoom,
                    initialCenter: const LatLng(41.662319, -4.705917),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                      pinchZoomThreshold: 2.0,
                    ),
                    onMapReady: () {
                      _mapController.fitCamera(
                        CameraFit.bounds(
                          bounds: LatLngBounds(
                            LatLng(sup, izq),
                            LatLng(inf, der),
                          ),
                          padding: const EdgeInsets.all(48),
                        ),
                      );
                    },
                  ),
                  children: [
                    MapLayer.tileLayerWidget(brightness: td.brightness),
                    MapLayer.atributionWidget(),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: trackPoints,
                          pattern: const StrokePattern.dotted(),
                          color: MapLayer.layer != Layers.satellite
                              ? colorScheme.tertiary
                              : Colors.white,
                          strokeWidth: 5,
                        )
                      ],
                    ),
                    MarkerLayer(markers: markers),
                  ]),
              Padding(
                padding: const EdgeInsets.only(right: 10, bottom: 10, top: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: null,
                      onPressed: UserXEST.userXEST.isNotGuest &&
                              UserXEST.userXEST.crol == Rol.user
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      CarryOutIt(itinerary),
                                  fullscreenDialog: true,
                                ),
                              );
                            }
                          : UserXEST.userXEST.isGuest
                              ? () {
                                  ScaffoldMessenger.of(context)
                                      .clearSnackBars();
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(AppLocalizations.of(context)!
                                        .iniciaParaRealizar),
                                  ));
                                }
                              : () {
                                  ScaffoldMessenger.of(context)
                                      .clearSnackBars();
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(AppLocalizations.of(context)!
                                        .cambiaEstudiante),
                                  ));
                                },
                      label: Text(AppLocalizations.of(context)!.iniciar),
                      icon: Icon(Icons.play_arrow_rounded,
                          color: colorScheme.onPrimaryContainer),
                    ),
                    bodyItinerary.containsKey('tasksIt')
                        ? widgetTasksIt()
                        : Container(),
                  ],
                ),
              ),
            ]),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: columnLstTasks,
        ),
      ],
    );
  }

  Widget widgetTasksIt() {
    return FutureBuilder(
      future: _getItineraryTasks(itinerary.id),
      builder: ((context, snapshot) {
        if (!snapshot.hasError && snapshot.hasData) {
          Object? bodyTasksIt = snapshot.data;
          if (bodyTasksIt != null) {
            if (bodyTasksIt is Map) {
              bodyTasksIt = [bodyTasksIt];
            }
            if (bodyTasksIt is List) {
              List<Task> tasksIt = [];
              for (Map b in bodyTasksIt) {
                try {
                  Task t = Task(
                    b,
                    containerType: ContainerTask.itinerary,
                    idContainer: itinerary.id,
                  );
                  tasksIt.add(t);
                  itinerary.addTask(t);
                } catch (error, stackTrace) {
                  if (Config.development) {
                    debugPrint(error.toString());
                  } else {
                    FirebaseCrashlytics.instance.recordError(error, stackTrace);
                  }
                }
              }
              ThemeData td = Theme.of(context);
              ColorScheme colorScheme = td.colorScheme;
              TextTheme textTheme = td.textTheme;
              AppLocalizations appLoca = AppLocalizations.of(context)!;
              List<Widget> widgetMBS = [];
              for (Task t in tasksIt) {
                widgetMBS.add(
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.primary,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              t.getALabel(lang: MyApp.currentLang),
                              style: textTheme.bodyMedium!
                                  .copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          HtmlWidget(
                            t.getAComment(lang: MyApp.currentLang),
                            factoryBuilder: () => MyWidgetFactory(),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }
              return FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => Auxiliar.showMBS(
                  context,
                  DraggableScrollableSheet(
                    initialChildSize: 0.7,
                    minChildSize: 0.2,
                    maxChildSize: 1,
                    expand: false,
                    builder: (context, controller) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: controller,
                            itemCount: widgetMBS.length,
                            itemBuilder: ((context, index) =>
                                widgetMBS.elementAt(index)),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                label: Text(appLoca.tareasTodoIt),
              );
            }
          }
        }
        return Container();
      }),
    );
  }
}

class CarryOutIt extends StatefulWidget {
  final Itinerary itinerary;
  const CarryOutIt(this.itinerary, {super.key});
  @override
  State<CarryOutIt> createState() => _CarryOutIt();
}

class _CarryOutIt extends State<CarryOutIt> {
  final MapController _mapController = MapController();
  late List<Marker> _markers;
  late List<CircleMarker> _userCirclePostion;
  late List<LatLng> _pointsTrack;
  late LatLng _locationUser;
  // StreamSubscription<Position>? _strLocationUser;
  late List<double> _distances;
  final double _distanciaTarea = 50;
  late List<Widget> _widgetMBS;

  @override
  void initState() {
    super.initState();
    _locationUser = const LatLng(0, 0);
    _markers = [];
    _userCirclePostion = [];
    _pointsTrack = [];
    _distances = [];

    for (int i = 0, tama = widget.itinerary.points.length; i < tama; i++) {
      _distances.add(double.infinity);
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;

    _widgetMBS = [];
    for (Task t in widget.itinerary.tasks) {
      _widgetMBS.add(
        Padding(
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.primary,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.getALabel(lang: MyApp.currentLang),
                    style: td.textTheme.bodyMedium!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                HtmlWidget(
                  t.getAComment(lang: MyApp.currentLang),
                  factoryBuilder: () => MyWidgetFactory(),
                )
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.itinerary.getALabel(lang: MyApp.currentLang),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Stack(
        alignment: Alignment.bottomRight,
        children: [
          RepaintBoundary(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                maxZoom: MapLayer.maxZoom,
                minZoom: MapLayer.minZoom,
                initialCameraFit: CameraFit.bounds(
                  bounds: widget.itinerary.latLngBounds,
                  padding: const EdgeInsets.all(48),
                ),
                keepAlive: false,
                onMapReady: () {
                  _askLocation();
                  Size size = MediaQuery.of(context).size;
                  double mW = Auxiliar.maxWidth * 0.5;
                  double mH = size.width > size.height
                      ? size.height * 0.5
                      : size.height / 3;
                  for (int i = 0, tama = widget.itinerary.points.length;
                      i < tama;
                      i++) {
                    PointItinerary pi = widget.itinerary.points.elementAt(i);
                    List<Widget> lstCardTareas = [];
                    if (pi.hasLstTasks) {
                      List<String> ids = [];
                      for (Task t in pi.tasksObj) {
                        if (!ids.contains(t.id)) {
                          ids.add(t.id);
                          lstCardTareas.add(
                            Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  side: BorderSide(
                                    color: td.colorScheme.outline,
                                  ),
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(12))),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.only(
                                        top: 24,
                                        bottom: 16,
                                        right: 16,
                                        left: 16),
                                    child: Text(
                                        t.getALabel(lang: MyApp.currentLang)),
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                          top: 16,
                                          bottom: 8,
                                          right: 16,
                                          left: 16),
                                      child: FilledButton(
                                        onPressed: () {
                                          GoRouter.of(context).go(
                                              '/home/features/${pi.feature.shortId}/tasks/${Auxiliar.id2shortId(t.id)}',
                                              extra: [
                                                null,
                                                null,
                                                null,
                                                false,
                                                true
                                              ]);
                                        },
                                        child: Text(
                                            AppLocalizations.of(context)!
                                                .realizaTareaBt),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        }
                      }
                    }
                    _markers.add(CHESTMarker(
                      context,
                      feature: pi.feature,
                      icon: Center(
                        child: Icon(
                          Auxiliar.getIcon(pi.feature.spatialThingTypes),
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      circleWidthBorder: 2,
                      circleWidthColor: colorScheme.primary,
                      circleContainerColor: colorScheme.primaryContainer,
                      currentLayer: MapLayer.layer!,
                      onTap: () {
                        Auxiliar.showMBS(
                          context,
                          DraggableScrollableSheet(
                            initialChildSize: 0.7,
                            minChildSize: 0.2,
                            maxChildSize: 1,
                            expand: false,
                            builder: (context, controller) => Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    controller: controller,
                                    itemCount: 5,
                                    itemBuilder: (context, index) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: [
                                        Text(
                                          pi.feature.getALabel(
                                              lang: MyApp.currentLang),
                                          style: td.textTheme.titleLarge!,
                                          textAlign: TextAlign.center,
                                        ),
                                        pi.feature.hasThumbnail
                                            ? ImageNetwork(
                                                image:
                                                    pi.feature.thumbnail.image,
                                                height: mH,
                                                width: mW,
                                                duration: 0,
                                                onPointer: true,
                                                fitWeb: BoxFitWeb.cover,
                                                fitAndroidIos: BoxFit.cover,
                                                borderRadius:
                                                    BorderRadius.circular(25),
                                                curve: Curves.easeIn,
                                                onTap: () async {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute<void>(
                                                        builder: (BuildContext
                                                                context) =>
                                                            FullScreenImage(
                                                                pi.feature
                                                                    .thumbnail,
                                                                local: false),
                                                        fullscreenDialog:
                                                            false),
                                                  );
                                                },
                                                onError: const Icon(
                                                    Icons.image_not_supported),
                                                onLoading:
                                                    const CircularProgressIndicator
                                                        .adaptive(),
                                              )
                                            : Container(),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            HtmlWidget(
                                              pi.feature.getAComment(
                                                  lang: MyApp.currentLang),
                                              factoryBuilder: () =>
                                                  MyWidgetFactory(),
                                            ),
                                            // TODO TTS
                                            // Padding(
                                            //   padding:
                                            //       const EdgeInsets.only(top: 5),
                                            //   child: Align(
                                            //     alignment:
                                            //         Alignment.centerRight,
                                            //     child: TextButton(
                                            //       child: Text(
                                            //         AppLocalizations.of(
                                            //                 context)!
                                            //             .escuchar,
                                            //         style: td
                                            //             .textTheme.bodyMedium!
                                            //             .copyWith(
                                            //           color:
                                            //               colorScheme.primary,
                                            //         ),
                                            //       ),
                                            //       onPressed: () async {
                                            //         if (_isPlaying) {
                                            //           setState(() =>
                                            //               _isPlaying = false);
                                            //           _stop();
                                            //         } else {
                                            //           setState(() =>
                                            //               _isPlaying = true);
                                            //           List<String> lstTexto =
                                            //               Auxiliar.frasesParaTTS(pi
                                            //                   .feature
                                            //                   .getAComment(
                                            //                       lang: MyApp
                                            //                           .currentLang));
                                            //           for (String leerParte
                                            //               in lstTexto) {
                                            //             await _speak(leerParte);
                                            //           }
                                            //           setState(() =>
                                            //               _isPlaying = false);
                                            //         }
                                            //       },
                                            //     ),
                                            //   ),
                                            // )
                                          ],
                                        ),
                                        Visibility(
                                          visible: Auxiliar.distance(
                                                  pi.feature.point,
                                                  _locationUser) >
                                              _distanciaTarea,
                                          child: Text(
                                            appLoca.distanceItTask(
                                                Auxiliar.distance(
                                                            pi.feature.point,
                                                            _locationUser) >
                                                        1000
                                                    ? ((Auxiliar.distance(
                                                                    pi.feature
                                                                        .point,
                                                                    _locationUser) -
                                                                _distanciaTarea) /
                                                            1000)
                                                        .toStringAsFixed(2)
                                                    : Auxiliar.distance(
                                                            pi.feature.point,
                                                            _locationUser) -
                                                        _distanciaTarea,
                                                Auxiliar.distance(
                                                            pi.feature.point,
                                                            _locationUser) >
                                                        1000
                                                    ? 'km'
                                                    : 'm'),
                                            style: td.textTheme.bodyMedium!
                                                .copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                          ),
                                        ),
                                        Visibility(
                                          visible: Auxiliar.distance(
                                                  pi.feature.point,
                                                  _locationUser) <=
                                              _distanciaTarea,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: lstCardTareas,
                                          ),
                                        ),
                                      ].elementAt(index),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ));
                  }
                  if (widget.itinerary.track != null) {
                    for (LatLngCHEST d in widget.itinerary.track!.points) {
                      _pointsTrack.add(d.toLatLng);
                    }
                  }
                },
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                  pinchZoomThreshold: 2.0,
                ),
              ),
              children: [
                MapLayer.tileLayerWidget(brightness: td.brightness),
                MapLayer.atributionWidget(),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _pointsTrack,
                      pattern: const StrokePattern.dotted(),
                      color: MapLayer.layer != Layers.satellite
                          ? colorScheme.tertiary
                          : Colors.white,
                      strokeWidth: 5,
                    )
                  ],
                ),
                CircleLayer(circles: _userCirclePostion),
                MarkerLayer(
                  markers: _markers,
                  rotate: true,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10, bottom: 10, top: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
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
                                appLoca.mapaEstandar,
                              ),
                              _botonMapa(
                                Layers.satellite,
                                'images/basemap_gallery/satelite.png',
                                appLoca.mapaSatelite,
                              ),
                            ]),
                          ),
                        ],
                      ),
                      title: appLoca.tipoMapa),
                  // child: const Icon(Icons.layers),
                  child: Icon(
                    Icons.settings_applications,
                    semanticLabel: appLoca.ajustes,
                  ),
                ),
                const Visibility(
                  visible: kIsWeb,
                  child: SizedBox(height: 10),
                ),
                Visibility(
                  visible: kIsWeb,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    onPressed: () {
                      _mapController.move(
                          _mapController.camera.center,
                          min(_mapController.camera.zoom + 1,
                              MapLayer.maxZoom));
                    },
                    tooltip: appLoca.aumentaZumShort,
                    child: Icon(
                      Icons.zoom_in,
                      semanticLabel: appLoca.aumentaZumShort,
                    ),
                  ),
                ),
                const Visibility(
                  visible: kIsWeb,
                  child: SizedBox(height: 5),
                ),
                Visibility(
                  visible: kIsWeb,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    onPressed: () {
                      _mapController.move(
                          _mapController.camera.center,
                          max(_mapController.camera.zoom - 1,
                              MapLayer.minZoom));
                    },
                    tooltip: appLoca.disminuyeZum,
                    child: Icon(
                      Icons.zoom_out,
                      semanticLabel: appLoca.disminuyeZum,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: null,
                  onPressed: () {
                    _mapController.move(
                        _locationUser, _mapController.camera.zoom);
                  },
                  child: const Icon(Icons.location_searching),
                ),
                const SizedBox(height: 10),
                _widgetMBS.isNotEmpty
                    ? FloatingActionButton.extended(
                        heroTag: null,
                        onPressed: () => Auxiliar.showMBS(
                          context,
                          DraggableScrollableSheet(
                            initialChildSize: 0.7,
                            minChildSize: 0.2,
                            maxChildSize: 1,
                            expand: false,
                            builder: (context, controller) => Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    controller: controller,
                                    itemCount: _widgetMBS.length,
                                    itemBuilder: ((context, index) =>
                                        _widgetMBS.elementAt(index)),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                        label: Text(AppLocalizations.of(context)!.tareasTodoIt),
                      )
                    : Container()
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _askLocation() async {
    // LocationSettings locationSettings =
    //     await Auxiliar.checkPermissionsLocation(context, defaultTargetPlatform);
    bool hasPermissions = await MyApp.locationUser.checkPermissions(context);
    if (hasPermissions) {
      MyApp.locationUser.positionUser!.listen((Position point) {
        setState(() {
          _locationUser = LatLng(point.latitude, point.longitude);
          _distances = _calculeDistances();
          _userCirclePostion = [];
          _userCirclePostion.add(CircleMarker(
              point: _locationUser,
              radius: _distanciaTarea,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              useRadiusInMeter: true,
              borderColor: Colors.white,
              borderStrokeWidth: 2));
        });
      }, cancelOnError: true);
    }
    // Geolocator.getPositionStream(locationSettings: locationSettings)
    //     .listen((Position? point) async {
    //   setState(() {
    //     _locationUser = LatLng(point!.latitude, point.longitude);
    //     _distances = _calculeDistances();
    //     _userCirclePostion = [];
    //     _userCirclePostion.add(CircleMarker(
    //         point: _locationUser,
    //         radius: _distanciaTarea,
    //         color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
    //         useRadiusInMeter: true,
    //         borderColor: Colors.white,
    //         borderStrokeWidth: 2));
    //   });
    // });
  }

  List<double> _calculeDistances() {
    List<double> out = [];
    for (int i = 0, tama = widget.itinerary.points.length; i < tama; i++) {
      Feature f = widget.itinerary.points.elementAt(i).feature;
      out.add(Auxiliar.distance(f.point, _locationUser));
    }
    return out;
  }

  Widget _botonMapa(Layers layer, String image, String textLabel) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: MapLayer.layer == layer
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 5, top: 10, right: 10, left: 10),
      child: InkWell(
        onTap: MapLayer.layer != layer ? () => _changeLayer(layer) : () {},
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

  void _changeLayer(Layers layer) async {
    setState(() {
      MapLayer.layer = layer;
      // Auxiliar.updateMaxZoom();
      if (_mapController.camera.zoom > MapLayer.maxZoom) {
        _mapController.move(_mapController.camera.center, MapLayer.maxZoom);
      }
    });
    if (UserXEST.userXEST.isNotGuest) {
      http
          .put(Queries.preferences(),
              headers: {
                'content-type': 'application/json',
                'Authorization':
                    'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
              },
              body: json.encode({'defaultMap': layer.name}))
          .then((_) {
        if (mounted) Navigator.pop(context);
      }).onError((error, stackTrace) {
        if (mounted) Navigator.pop(context);
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    MyApp.locationUser.dispose();
    super.dispose();
  }
}
