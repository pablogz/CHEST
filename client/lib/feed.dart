import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/parser/html_to_delta.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:chest/util/queries.dart';
import 'package:chest/itineraries.dart';
import 'package:chest/util/helpers/chest_marker.dart';
import 'package:chest/util/map_layer.dart';
import 'package:chest/full_screen.dart';
import 'package:chest/util/config.dart';
import 'package:chest/l10n/generated/app_localizations.dart';
import 'package:chest/main.dart';
import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/feed.dart';
import 'package:chest/util/helpers/pair.dart';
import 'package:chest/util/helpers/widget_facto.dart';
import 'package:chest/util/helpers/user_xest.dart';
import 'package:chest/util/helpers/cache.dart';
import 'package:chest/util/helpers/feature.dart';

class FormFeeder extends StatefulWidget {
  final Feed feed;
  const FormFeeder(this.feed, {super.key});

  @override
  State<StatefulWidget> createState() => _FormFeeder();
}

class _FormFeeder extends State<FormFeeder> {
  late GlobalKey<FormState> _formFeedTeacherKey;
  late Feed _feed;
  late String _description, _label, _pass;
  late FocusNode _focusNode;
  late QuillController _quillController;
  late bool _hasFocus, _errorDescription, _enviarPulsado;
  late final bool _isNewFeed;

  @override
  void initState() {
    _feed = widget.feed;
    _isNewFeed = _feed.id.isEmpty;
    _formFeedTeacherKey = GlobalKey<FormState>();
    _enviarPulsado = false;
    _focusNode = FocusNode();
    _label = _feed.getALabel(lang: MyApp.currentLang);
    _description = _feed.getAComment(lang: MyApp.currentLang);
    _pass = _feed.pass;
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
        if (_errorDescription) {
          _errorDescription = _description.trim().isEmpty;
        }
      });
    });
    _hasFocus = false;
    _errorDescription = false;
    _focusNode.addListener(_onFocus);
    super.initState();
  }

  @override
  void dispose() {
    _quillController.dispose();
    _focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() => _hasFocus = !_hasFocus);

  @override
  Widget build(BuildContext context) {
    double mLateral =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);

    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    ThemeData td = Theme.of(context);
    TextTheme textTheme = td.textTheme;
    return Form(
      key: _formFeedTeacherKey,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              centerTitle: false,
              title: Text(_isNewFeed ? appLoca.newFeed : appLoca.editFeed),
            ),
            SliverSafeArea(
              top: false,
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints:
                        const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    margin: EdgeInsets.only(
                        top: mLateral, left: mLateral, right: mLateral),
                    child: TextFormField(
                      maxLines: 1,
                      enabled: !_enviarPulsado,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: appLoca.tituloFeed,
                          hintText: appLoca.tituloFeed,
                          helperText: appLoca.requerido,
                          hintMaxLines: 1,
                          hintStyle:
                              const TextStyle(overflow: TextOverflow.ellipsis)),
                      maxLength: 40,
                      keyboardType: TextInputType.text,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value is String && value.trim().isNotEmpty) {
                          _label = value.trim();
                          return null;
                        }
                        return appLoca.tituloFeedError;
                      },
                      initialValue: _label,
                    ),
                  ),
                ),
              ),
            ),
            SliverSafeArea(
              top: false,
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints:
                        const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    margin: EdgeInsets.only(
                        top: mLateral, left: mLateral, right: mLateral),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                      border: Border.fromBorderSide(
                        BorderSide(
                            color: _errorDescription
                                ? colorScheme.error
                                : _enviarPulsado
                                    ? td.disabledColor
                                    : _hasFocus
                                        ? colorScheme.primary
                                        : colorScheme.onSurface,
                            width: _enviarPulsado
                                ? 1
                                : _hasFocus
                                    ? 2
                                    : 1),
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
                            '${appLoca.descripcionFeed}*',
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
                                  minWidth: Auxiliar.maxWidth,
                                ),
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
                                  appLoca.descripcionFeedError,
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
                ),
              ),
            ),
            SliverSafeArea(
              top: false,
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints:
                        const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    margin: EdgeInsets.only(
                        top: mLateral, left: mLateral, right: mLateral),
                    child: TextFormField(
                      maxLines: 1,
                      enabled: !_enviarPulsado,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: appLoca.passFeed,
                          hintText: appLoca.passFeed,
                          helper: Text.rich(
                            TextSpan(children: [
                              WidgetSpan(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: Icon(
                                    Icons.info_outline,
                                    color: colorScheme.onSurface,
                                    size: 20,
                                  ),
                                ),
                              ),
                              TextSpan(
                                text: appLoca.passFeedHelper,
                                style: td.textTheme.labelMedium,
                              ),
                            ]),
                          ),
                          hintMaxLines: 1,
                          hintStyle:
                              const TextStyle(overflow: TextOverflow.ellipsis)),
                      keyboardType: TextInputType.visiblePassword,
                      style: GoogleFonts.robotoMono()
                          .copyWith(fontSize: td.textTheme.bodyLarge!.fontSize),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value is String && value.length < 120) {
                          _pass = value;
                        }
                        return null;
                      },
                      maxLength: 120,
                      initialValue: _pass,
                    ),
                  ),
                ),
              ),
            ),
            SliverSafeArea(
              top: false,
              bottom: false,
              sliver: SliverPadding(
                padding: EdgeInsets.all(mLateral),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.center,
                    child: FilledButton(
                      onPressed: _enviarPulsado
                          ? null
                          : () async {
                              _quillController.readOnly = true;
                              setState(() => _enviarPulsado = true);
                              bool noErrorLabel =
                                  _formFeedTeacherKey.currentState!.validate();
                              if (noErrorLabel) {
                                _feed.labels = [
                                  PairLang(MyApp.currentLang, _label)
                                ];
                              }
                              if (_description.trim().isNotEmpty) {
                                setState(() => _errorDescription = false);
                                _feed.comments = [
                                  PairLang(MyApp.currentLang, _description)
                                ];
                              } else {
                                setState(() {
                                  _errorDescription = true;
                                });
                              }

                              _feed.pass = _pass;
                              if (noErrorLabel && !_errorDescription) {
                                // TODO Aquí hay que hacer la comunicación con el servidor
                                Map<String, dynamic> out = _feed.toJson();
                                ScaffoldMessengerState smState =
                                    ScaffoldMessenger.of(context);
                                if (_feed.id.isEmpty) {
                                  // Es una creación
                                  http
                                      .post(Queries.feeds(),
                                          headers: {
                                            'content-type': 'application/json',
                                            'Authorization':
                                                'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
                                          },
                                          body: json.encode(out))
                                      .then((response) {
                                    switch (response.statusCode) {
                                      case 201:
                                        _feed.id =
                                            response.headers['location']!;
                                        FeedCache.updateFeed(_feed);
                                        _quillController.readOnly = false;

                                        if (!Config.development) {
                                          FirebaseAnalytics.instance.logEvent(
                                              name: 'newFeed',
                                              parameters: {
                                                'iri': _feed.shortId,
                                                'author': _feed.feeders.first.id
                                              }).then((_) {
                                            if (mounted) {
                                              Navigator.pop(context, _feed);
                                              smState.clearSnackBars();
                                              smState.showSnackBar(
                                                SnackBar(
                                                    content: Text(appLoca
                                                        .infoRegistrada)),
                                              );
                                            }
                                          });
                                        } else {
                                          Navigator.pop(context, _feed);
                                          smState.clearSnackBars();
                                          smState.showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    appLoca.infoRegistrada)),
                                          );
                                        }
                                        break;
                                      default:
                                        setState(() => _enviarPulsado = false);
                                        _quillController.readOnly = false;
                                        smState.clearSnackBars();
                                        smState.showSnackBar(SnackBar(
                                            content: Text(response.statusCode
                                                .toString())));
                                    }
                                  }).onError((error, stackTrace) async {
                                    setState(() => _enviarPulsado = false);
                                    _quillController.readOnly = false;
                                    smState.clearSnackBars();
                                    smState.showSnackBar(
                                        const SnackBar(content: Text('Error')));
                                    if (Config.development) {
                                      debugPrint(error.toString());
                                    } else {
                                      await FirebaseCrashlytics.instance
                                          .recordError(error, stackTrace);
                                    }
                                  });
                                } else {
                                  // Es una actualización
                                  http
                                      .put(Queries.feed(_feed.shortId),
                                          headers: {
                                            'content-type': 'application/json',
                                            'Authorization':
                                                'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
                                          },
                                          body: json.encode(out))
                                      .then((response) {
                                    switch (response.statusCode) {
                                      case 200:
                                        FeedCache.updateFeed(_feed);
                                        _quillController.readOnly = false;

                                        if (!Config.development) {
                                          FirebaseAnalytics.instance.logEvent(
                                              name: 'updatedFeed',
                                              parameters: {
                                                'iri': _feed.shortId,
                                                'author':
                                                    _feed.feeders.first.id,
                                              }).then((_) {
                                            if (mounted) {
                                              Navigator.pop(context, _feed);
                                              smState.clearSnackBars();
                                              smState.showSnackBar(
                                                SnackBar(
                                                    content: Text(appLoca
                                                        .infoRegistrada)),
                                              );
                                            }
                                          });
                                        } else {
                                          Navigator.pop(context, _feed);
                                          smState.clearSnackBars();
                                          smState.showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    appLoca.infoRegistrada)),
                                          );
                                        }
                                        break;
                                      default:
                                        setState(() => _enviarPulsado = false);
                                        _quillController.readOnly = false;
                                        smState.clearSnackBars();
                                        smState.showSnackBar(SnackBar(
                                            content: Text(response.statusCode
                                                .toString())));
                                    }
                                  }).onError((error, stackTrace) async {
                                    setState(() => _enviarPulsado = false);
                                    _quillController.readOnly = false;
                                    smState.clearSnackBars();
                                    smState.showSnackBar(
                                        const SnackBar(content: Text('Error')));
                                    if (Config.development) {
                                      debugPrint(error.toString());
                                    } else {
                                      await FirebaseCrashlytics.instance
                                          .recordError(error, stackTrace);
                                    }
                                  });
                                }

                                // await Future.delayed(
                                //     const Duration(milliseconds: 300));
                                // // Nos devolverá un identificador único para el canal
                                // // Ahora lo simulo con un uuid generado en el cliente
                                // _feed.id =
                                //     '${Config.moultData}${const Uuid().v4()}';
                                // FeedCache.updateFeed(_feed);
                                // // Finalmente…
                                // setState(() => _enviarPulsado = false);
                                // _quillController.readOnly = false;
                                // if (mounted) {
                                //   Navigator.pop(context, _feed);
                                // }
                              } else {
                                setState(() => _enviarPulsado = false);
                                _quillController.readOnly = false;
                              }
                            },
                      child:
                          Text(_isNewFeed ? appLoca.addFeed : appLoca.editFeed),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class FormFeedSubscriber extends StatefulWidget {
  const FormFeedSubscriber({super.key});

  @override
  State<StatefulWidget> createState() => _FormFeedSubscriber();
}

class _FormFeedSubscriber extends State<FormFeedSubscriber> {
  late GlobalKey<FormState> _formFeedStudentKey;
  late Feed _feed;
  late String _id;
  late bool _enviarPulsado;

  @override
  void initState() {
    _formFeedStudentKey = GlobalKey<FormState>();
    _enviarPulsado = false;

    // TODO recuperar del servidor el Feed
    // _feed = Feed.(dataServer);

    _id = '';
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double w = MediaQuery.of(context).size.width;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return Form(
      key: _formFeedStudentKey,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(centerTitle: false, title: Text(appLoca.newFeed)),
            SliverSafeArea(
              top: false,
              bottom: false,
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints:
                        const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    margin: EdgeInsets.all(Auxiliar.getLateralMargin(w)),
                    child: TextFormField(
                      maxLines: 1,
                      enabled: !_enviarPulsado,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: appLoca.idFeed,
                          hintText: appLoca.idFeedError,
                          helperText: appLoca.requerido,
                          hintMaxLines: 1,
                          hintStyle:
                              const TextStyle(overflow: TextOverflow.ellipsis)),
                      maxLength: 40,
                      keyboardType: TextInputType.text,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: (value) {
                        if (value is String && value.trim().isNotEmpty) {
                          _id = value.trim();
                          return null;
                        }
                        return appLoca.idFeedError;
                      },
                      initialValue: _id,
                    ),
                  ),
                ),
              ),
            ),
            SliverSafeArea(
              top: false,
              bottom: false,
              sliver: SliverPadding(
                padding: EdgeInsets.all(Auxiliar.getLateralMargin(w)),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.center,
                    child: FilledButton(
                      onPressed: null,
                      child: Text(appLoca.apuntarmeFeed),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class InfoFeed extends StatefulWidget {
  final String idFeed;
  const InfoFeed(this.idFeed, {super.key});

  @override
  State<StatefulWidget> createState() => _InfoFeed();
}

class _InfoFeed extends State<InfoFeed> with SingleTickerProviderStateMixin {
  late Feed? _feed;
  late List<String> _idTabs;
  late TabController _tabController;
  late bool _passVisible, _noFeedFound;

  @override
  void initState() {
    _feed = FeedCache.getFeed(widget.idFeed);
    _noFeedFound = _feed == null;
    _idTabs = ['info', 'answers'];
    // _idTabs = ['info', 'resources', 'answers'];
    _tabController = TabController(length: _idTabs.length, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _passVisible = false;
    super.initState();
  }

  @override
  void dispose() {
    _tabController.removeListener(() {
      setState(() {});
    });
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double margenLateral =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return _noFeedFound
        ? Scaffold(
            appBar: AppBar(
              title: Text(appLoca.feeds),
              centerTitle: true,
            ),
            body: SafeArea(
              minimum: const EdgeInsets.all(Auxiliar.mediumMargin),
              child: Text(
                'Feed no found',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          )
        : DefaultTabController(
            length: _idTabs.length,
            child: Scaffold(
              floatingActionButton: _fav(),
              body: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
                  SliverOverlapAbsorber(
                    handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                        context),
                    sliver: SliverAppBar(
                      title: Text(
                        _feed!.getALabel(lang: MyApp.currentLang),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        textScaler: const TextScaler.linear(0.9),
                      ),
                      titleTextStyle: Theme.of(context).textTheme.titleLarge,
                      pinned: true,
                      centerTitle: false,
                      forceElevated: innerBoxIsScrolled,
                      bottom: TabBar(
                        controller: _tabController,
                        tabs: [
                          Tab(text: appLoca.infor),
                          // Tab(text: appLoca.resources),
                          Tab(text: appLoca.respuestas)
                        ],
                      ),
                    ),
                  )
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: _idTabs
                      .map((String name) => Builder(
                            builder: (BuildContext context) => CustomScrollView(
                              scrollBehavior: ScrollConfiguration.of(context)
                                  .copyWith(scrollbars: false),
                              key: PageStorageKey<String>(name),
                              slivers: [
                                SliverOverlapInjector(
                                  handle: NestedScrollView
                                      .sliverOverlapAbsorberHandleFor(context),
                                ),
                                SliverPadding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: margenLateral),
                                  sliver: SliverToBoxAdapter(
                                    child: Center(
                                      child: Container(
                                          constraints: BoxConstraints(
                                              maxWidth: Auxiliar.maxWidth),
                                          child: name == _idTabs.elementAt(0)
                                              ? _widgetInformation()
                                              : _widgetAnswers()),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          );
  }

  Widget _widgetInformation() {
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    Size size = MediaQuery.of(context).size;
    double sizeQr = min(Auxiliar.maxWidth, size.shortestSide) * 0.25;
    double margenLateral = Auxiliar.getLateralMargin(size.width);
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(
              maxWidth: Auxiliar.maxWidth,
              minWidth: Auxiliar.maxWidth,
            ),
            margin: EdgeInsets.only(top: margenLateral),
            decoration: BoxDecoration(
              color: td.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.all(Auxiliar.getLateralMargin(size.width)),
            alignment: Alignment.centerLeft,
            child: HtmlWidget(
              _feed!.getAComment(lang: MyApp.currentLang),
              textStyle: td.textTheme.bodyMedium!
                  .copyWith(color: colorScheme.onSecondaryContainer),
              factoryBuilder: () => MyWidgetFactory(),
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
            padding: EdgeInsets.all(Auxiliar.getLateralMargin(size.width)),
            margin: EdgeInsets.only(top: margenLateral),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                kIsWeb
                    ? Container()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SelectableText.rich(
                          TextSpan(text: _feed!.iri),
                          style: td.textTheme.bodyLarge!.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                SizedBox(
                  width: sizeQr,
                  height: sizeQr,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<String?>(
                            builder: (BuildContext context) =>
                                FullScreenQR(_feed!.iri),
                            fullscreenDialog: true),
                      );
                    },
                    child: QrImageView(
                      data: _feed!.iri,
                      version: QrVersions.auto,
                      gapless: false,
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: colorScheme.onTertiaryContainer,
                      ),
                      eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: colorScheme.onTertiaryContainer),
                    ),
                  ),
                ),
                _feed!.pass.isNotEmpty &&
                        _feed!.feeders.indexWhere(
                                (Feeder f) => f.id == UserXEST.userXEST.id) >
                            -1
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 5),
                        child: SwitchListTile.adaptive(
                            value: _passVisible,
                            title: Text(appLoca.showPassword),
                            activeColor: colorScheme.primary,
                            onChanged: (bool v) =>
                                setState(() => _passVisible = v)))
                    : Container(),
                _feed!.pass.isEmpty
                    ? Container()
                    : _passVisible
                        ? SelectableText(
                            _feed!.pass,
                            style: GoogleFonts.robotoMono().copyWith(
                                fontSize:
                                    td.textTheme.headlineMedium!.fontSize),
                          )
                        : Text('* * * * *', style: GoogleFonts.robotoMono()),
              ],
            ),
          ),
          SizedBox(height: 80),
        ]);
  }

  // Widget _widgetResources() {
  //   List<Widget> children = [_featuresAndTasksFeed(), _itinerariesFeed()];
  //   for (int i = 0, tama = children.length; i < tama; i++) {
  //     children[i] = Center(
  //       child: Container(
  //         constraints: BoxConstraints(
  //             minWidth: Auxiliar.maxWidth, maxWidth: Auxiliar.maxWidth),
  //         child: children.elementAt(i),
  //       ),
  //     );
  //   }
  //   return Column(
  //     mainAxisSize: MainAxisSize.min,
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: children,
  //   );
  // }

  // Widget _featuresAndTasksFeed() {
  //   AppLocalizations appLoca = AppLocalizations.of(context)!;
  //   TextStyle textStyle = Theme.of(context).textTheme.titleMedium!;
  //   List<Widget> out = [
  //     Wrap(
  //       alignment: WrapAlignment.spaceBetween,
  //       crossAxisAlignment: WrapCrossAlignment.center,
  //       spacing: 5,
  //       runSpacing: 5,
  //       children: [
  //         Text(appLoca.sTyLT, style: textStyle),
  //         _feed!.feeder.id == UserXEST.userXEST.id &&
  //                 UserXEST.userXEST.canEditNow
  //             ? TextButton.icon(
  //                 icon: Icon(Icons.edit),
  //                 label: Text(appLoca.editar),
  //                 onPressed: () async {
  //                   List<PointItinerary>? pit = await Navigator.push(
  //                       context,
  //                       MaterialPageRoute<List<PointItinerary>>(
  //                           builder: (BuildContext context) =>
  //                               MapForST(_feed!.lstStLt),
  //                           fullscreenDialog: true));
  //                   if (pit != null) {
  //                     setState(() => _feed!.lstStLt = pit);
  //                   }
  //                 },
  //               )
  //             : Container()
  //       ],
  //     )
  //   ];

  //   if (_feed!.lstStLt.isNotEmpty) {
  //     for (int i = 0, tama = _feed!.lstStLt.length; i < tama; i++) {
  //       // List<Task> tasksInFeature;
  //       // if (pit.hasLstTasks) {
  //       //   tasksInFeature = pit.tasksObj
  //       //       .where((Task task) => task.idContainer == pit.feature.id)
  //       //       .toList();
  //       // } else {
  //       //   tasksInFeature = [];
  //       // }
  //       // out.add(_resourceList(pit.feature, tasks: tasksInFeature));
  //       PointItinerary pIt = _feed!.lstStLt.elementAt(i);
  //       out.add(_cardPointItinerary(pIt));
  //     }
  //   } else {
  //     out.add(
  //       Padding(
  //         padding: const EdgeInsets.only(left: 10),
  //         child: Text(appLoca.sinSTniTaskAgregadoCanal),
  //       ),
  //     );
  //   }
  //   out.add(SizedBox(height: 20));
  //   for (int i = 0, tama = out.length; i < tama; i++) {
  //     out[i] = Padding(
  //       padding: const EdgeInsets.only(top: 10),
  //       child: out.elementAt(i),
  //     );
  //   }
  //   return Column(
  //       mainAxisSize: MainAxisSize.min,
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: out);
  // }

  // Widget _itinerariesFeed() {
  //   AppLocalizations appLoca = AppLocalizations.of(context)!;

  //   TextStyle textStyle = Theme.of(context).textTheme.titleMedium!;
  //   List<Widget> out = [
  //     Wrap(
  //       alignment: WrapAlignment.spaceBetween,
  //       crossAxisAlignment: WrapCrossAlignment.center,
  //       spacing: 5,
  //       runSpacing: 5,
  //       children: [
  //         Text(
  //           appLoca.itinerarios,
  //           style: textStyle,
  //         ),
  //         _feed!.feeder.id == UserXEST.userXEST.id &&
  //                 UserXEST.userXEST.canEditNow
  //             ? TextButton.icon(
  //                 icon: Icon(Icons.edit),
  //                 label: Text(appLoca.editar),
  //                 onPressed: () async {
  //                   // Tengo que recuperar la lista de itinearios
  //                   List itServer = await _getItineraries();
  //                   List<Itinerary> itinerariesServer = [];
  //                   for (dynamic objServer in itServer) {
  //                     try {
  //                       Itinerary it = Itinerary(objServer);
  //                       if (!_feed!.listItineraries.contains(it.id!)) {
  //                         itinerariesServer.add(it);
  //                       }
  //                     } catch (error) {
  //                       if (Config.development) {
  //                         debugPrint(error.toString());
  //                       }
  //                     }
  //                   }
  //                   // Ahora paso a la pantalla de la gestión de los itinerarios. Le paso los que están activos en el momento. Espero que me devuelva una lista con los itinerarios agregados. Si es null no modifico la lista de itinearios del canal
  //                   if (mounted) {
  //                     List<Itinerary>? newListFeed = await Navigator.push(
  //                         context,
  //                         MaterialPageRoute<List<Itinerary>>(
  //                           builder: (BuildContext context) =>
  //                               ManageItinerariesFeed(
  //                             _feed!.itineraries,
  //                             itinerariesServer,
  //                           ),
  //                           fullscreenDialog: true,
  //                         ));
  //                     if (newListFeed != null) {
  //                       setState(() => _feed!.itineraries = newListFeed);
  //                       //TODO falta enviar este cambio al servidor
  //                     }
  //                   }
  //                 },
  //               )
  //             : Container()
  //       ],
  //     )
  //   ];

  //   if (_feed!.itineraries.isNotEmpty) {
  //     for (Itinerary itinerary in _feed!.itineraries) {
  //       out.add(_resourceList(itinerary));
  //     }
  //   } else {
  //     out.add(
  //       Padding(
  //         padding: const EdgeInsets.only(left: 10),
  //         child: Text(appLoca.sinItAgregadoCanal),
  //       ),
  //     );
  //   }
  //   out.add(SizedBox(height: 70));
  //   for (int i = 0, tama = out.length; i < tama; i++) {
  //     out[i] = Padding(
  //       padding: const EdgeInsets.only(top: 10),
  //       child: out.elementAt(i),
  //     );
  //   }
  //   return Column(
  //       mainAxisSize: MainAxisSize.min,
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: out);
  // }

  // Future<List> _getItineraries() {
  //   return http.get(Queries.getItineraries()).then((response) =>
  //       response.statusCode == 200 ? json.decode(response.body) : []);
  // }

  // Widget _resourceList(Object mainResource, {List<Task>? tasks}) {
  //   Widget out;
  //   ThemeData td = Theme.of(context);
  //   ColorScheme colorScheme = td.colorScheme;
  //   TextTheme textTheme = td.textTheme;
  //   if (mainResource is Itinerary) {
  //     out = Center(
  //       child: Container(
  //         constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
  //         child: Card(
  //           elevation: 0,
  //           shape: RoundedRectangleBorder(
  //               side: BorderSide(
  //                 color: colorScheme.outline,
  //               ),
  //               borderRadius: const BorderRadius.all(Radius.circular(12))),
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Container(
  //                 padding: const EdgeInsets.only(
  //                     top: 8, bottom: 16, right: 16, left: 16),
  //                 width: double.infinity,
  //                 child: Text(
  //                   mainResource.getALabel(lang: MyApp.currentLang),
  //                   style: textTheme.titleMedium!,
  //                   maxLines: 3,
  //                   overflow: TextOverflow.ellipsis,
  //                 ),
  //               ),
  //               Container(
  //                 padding:
  //                     const EdgeInsets.only(bottom: 16, right: 16, left: 16),
  //                 width: double.infinity,
  //                 child: HtmlWidget(
  //                   mainResource.getAComment(lang: MyApp.currentLang),
  //                   textStyle: textTheme.bodyMedium!.copyWith(
  //                     overflow: TextOverflow.ellipsis,
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     );
  //   } else {
  //     mainResource as Feature;
  //     List<Widget> children = [];
  //     children.add(Text(mainResource.getALabel(lang: MyApp.currentLang)));
  //     if (tasks != null) {
  //       for (Task t in tasks) {
  //         children.add(
  //           Padding(
  //             padding: const EdgeInsets.only(top: 4, left: 10),
  //             child: Text.rich(
  //               TextSpan(children: [
  //                 TextSpan(text: t.getALabel(lang: MyApp.currentLang)),
  //                 TextSpan(text: ': ${t.getAComment(lang: MyApp.currentLang)}')
  //               ]),
  //             ),
  //           ),
  //         );
  //       }
  //     }
  //     out = Column(mainAxisSize: MainAxisSize.min, children: children);
  //   }
  //   return out;
  // }

  // Widget _cardPointItinerary(PointItinerary pIt) {
  //   ThemeData td = Theme.of(context);
  //   ColorScheme colorScheme = td.colorScheme;
  //   TextTheme textTheme = td.textTheme;
  //   List<Widget> labelsTasks = [];
  //   if (pIt.hasLstTasks) {
  //     for (int i = 0, tama = pIt.tasksObj.length; i < tama; i++) {
  //       Task task = pIt.tasksObj.elementAt(i);
  //       labelsTasks.add(Padding(
  //         padding: const EdgeInsets.only(left: 26, bottom: 8),
  //         child: RichText(
  //           text: TextSpan(
  //               text: '${task.getALabel(lang: MyApp.currentLang)} ',
  //               style:
  //                   textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
  //               children: [
  //                 TextSpan(
  //                     text: task.getAComment(lang: MyApp.currentLang),
  //                     style: textTheme.bodyMedium)
  //               ]),
  //           maxLines: 5,
  //           overflow: TextOverflow.ellipsis,
  //         ),
  //       ));
  //     }
  //   }

  //   return Card(
  //     elevation: 0,
  //     shape: RoundedRectangleBorder(
  //         side: BorderSide(
  //           color: colorScheme.outline,
  //         ),
  //         borderRadius: const BorderRadius.all(Radius.circular(12))),
  //     child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Container(
  //             padding:
  //                 const EdgeInsets.only(top: 8, bottom: 8, right: 16, left: 16),
  //             width: double.infinity,
  //             child: Text(
  //               pIt.feature.getALabel(lang: MyApp.currentLang),
  //               style: textTheme.titleMedium!,
  //               maxLines: 3,
  //               overflow: TextOverflow.ellipsis,
  //             ),
  //           ),
  //           Column(
  //               mainAxisSize: MainAxisSize.min,
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: labelsTasks),
  //         ]),
  //   );
  // }

  Widget _widgetAnswers() {
    return Container();
  }

  Widget _fav() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    int indexFeeder =
        _feed!.feeders.indexWhere((Feeder f) => UserXEST.userXEST.id == f.id);
    switch (_tabController.index) {
      case 0:
        return indexFeeder > -1 && UserXEST.userXEST.canEditNow
            ? FloatingActionButton.extended(
                heroTag: Auxiliar.mainFabHero,
                onPressed: () async {
                  Feed? f = await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (BuildContext context) => FormFeeder(
                              _feed!,
                            ),
                        fullscreenDialog: true),
                  );
                  if (f is Feed) {
                    setState(() {
                      _feed = f;
                    });
                  }
                },
                icon: Icon(Icons.edit),
                label: Text(appLoca.editar),
              )
            : Container();
      // case 2:
      case 1:
        return indexFeeder > -1 && UserXEST.userXEST.canEditNow
            ? FloatingActionButton.extended(
                heroTag: Auxiliar.mainFabHero,
                onPressed: null,
                icon: Icon(Icons.manage_accounts),
                label: Text(appLoca.editarUsuarios),
              )
            : Container();
      default:
        return Container();
    }
  }
}

// class ManageItinerariesFeed extends StatefulWidget {
//   final List<Itinerary> currentIt, allIt;
//   const ManageItinerariesFeed(this.currentIt, this.allIt, {super.key});

//   @override
//   State<ManageItinerariesFeed> createState() => _ManageItinerariesFeed();
// }

// class _ManageItinerariesFeed extends State<ManageItinerariesFeed> {
//   late List<Itinerary> _currentIt, _allIt;

//   @override
//   void initState() {
//     _currentIt = widget.currentIt;
//     _allIt = widget.allIt;
//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Los represento en dos listas, no seleccionados y seleccionados
//     // Van pasando de una lista a otra
//     // Idealmente dos opciones seleccionar/deseleccionar y vista previa
//     // Por lo tanto:
//     // Tarjeta con el título, la descripción (recortada) y dos botones
//     AppLocalizations appLoca = AppLocalizations.of(context)!;
//     TextStyle casiTitle = Theme.of(context).textTheme.headlineSmall!;
//     List<Widget> cardsAllIts = [
//       Padding(
//         padding: const EdgeInsets.symmetric(vertical: 10),
//         child: Text(
//           appLoca.itSinSeleccionar,
//           style: casiTitle,
//         ),
//       )
//     ];
//     for (Itinerary it in _allIt) {
//       cardsAllIts.add(_cardIt(itinerary: it, sinAgregar: true));
//     }
//     if (_allIt.isEmpty) {
//       cardsAllIts.add(Text(appLoca.agregarNuevosItinerarios));
//     }
//     List<Widget> cardsItsEnabled = [
//       Padding(
//         padding: const EdgeInsets.symmetric(vertical: 10),
//         child: Text(
//           appLoca.itSeleccionados,
//           style: casiTitle,
//         ),
//       )
//     ];
//     for (Itinerary it in _currentIt) {
//       cardsItsEnabled.add(_cardIt(itinerary: it, sinAgregar: false));
//     }
//     if (_currentIt.isEmpty) {
//       cardsItsEnabled.add(Text(appLoca.sinItAgregadoCanal));
//     }
//     double mLateral =
//         Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
//     return Scaffold(
//       body: CustomScrollView(
//         slivers: [
//           SliverAppBar(
//             centerTitle: false,
//             pinned: true,
//             title: Text(appLoca.editItFeed),
//           ),
//           SliverSafeArea(
//             minimum: EdgeInsets.all(mLateral),
//             sliver: SliverToBoxAdapter(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: cardsAllIts,
//               ),
//             ),
//           ),
//           SliverSafeArea(
//             minimum: EdgeInsets.all(mLateral),
//             sliver: SliverToBoxAdapter(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: cardsItsEnabled,
//               ),
//             ),
//           ),
//           SliverSafeArea(
//             minimum: EdgeInsets.all(mLateral),
//             sliver: SliverToBoxAdapter(
//               child: Align(
//                 alignment: Alignment.bottomRight,
//                 child: Wrap(
//                     spacing: 5,
//                     runSpacing: 5,
//                     alignment: WrapAlignment.end,
//                     children: [
//                       TextButton(
//                         child: Text(appLoca.atras),
//                         onPressed: () => Navigator.pop(context),
//                       ),
//                       FilledButton(
//                         onPressed: () => Navigator.pop(context, _currentIt),
//                         child: Text(appLoca.guardar),
//                       ),
//                     ]),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _cardIt({required Itinerary itinerary, required bool sinAgregar}) {
//     ThemeData td = Theme.of(context);
//     ColorScheme colorScheme = td.colorScheme;
//     TextTheme textTheme = td.textTheme;
//     AppLocalizations appLoca = AppLocalizations.of(context)!;
//     return Center(
//       child: Container(
//         constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
//         child: Card(
//           elevation: 0,
//           shape: RoundedRectangleBorder(
//               side: BorderSide(
//                 color: sinAgregar ? colorScheme.outline : colorScheme.primary,
//               ),
//               borderRadius: const BorderRadius.all(Radius.circular(12))),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Container(
//                 padding: const EdgeInsets.only(
//                     top: 8, bottom: 16, right: 16, left: 16),
//                 width: double.infinity,
//                 child: Text(
//                   itinerary.getALabel(lang: MyApp.currentLang),
//                   style: textTheme.titleMedium!,
//                   maxLines: 3,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.only(bottom: 16, right: 16, left: 16),
//                 width: double.infinity,
//                 child: HtmlWidget(
//                   itinerary.getAComment(lang: MyApp.currentLang),
//                   textStyle: textTheme.bodyMedium!.copyWith(
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ),
//               ),
//               Align(
//                 alignment: Alignment.topRight,
//                 child: Padding(
//                   padding: const EdgeInsets.only(
//                       top: 16, bottom: 8, right: 16, left: 16),
//                   child: Wrap(
//                     spacing: 5,
//                     runSpacing: 5,
//                     alignment: WrapAlignment.end,
//                     children: [
//                       OutlinedButton.icon(
//                         onPressed: sinAgregar
//                             ? () {
//                                 setState(() {
//                                   _allIt.removeWhere((Itinerary it) =>
//                                       it.id! == itinerary.id!);
//                                   _currentIt.add(itinerary);
//                                 });
//                               }
//                             : () {
//                                 setState(() {
//                                   _currentIt.removeWhere((Itinerary it) =>
//                                       it.id! == itinerary.id!);
//                                   _allIt.add(itinerary);
//                                 });
//                               },
//                         label: Text(
//                           sinAgregar ? appLoca.agregarIt : appLoca.quitarIt,
//                         ),
//                       )
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class MapForST extends StatefulWidget {
//   final List<PointItinerary> pointItineraries;
//   const MapForST(this.pointItineraries, {super.key});

//   @override
//   State<StatefulWidget> createState() => _MapForST();
// }

// class _MapForST extends State<MapForST> {
//   late LatLngBounds _latLngBounds;
//   late LastPosition _startPoint;
//   late List<PointItinerary> _pointItineraries;
//   final MapController _mapController = MapController();
//   late List<CHESTMarker> _myMarkers;
//   late StreamSubscription<MapEvent> _strSubMap;
//   late int _lastMapEventScrollWheelZoom;
//   final SearchController _searchController = SearchController();

//   @override
//   void initState() {
//     _latLngBounds = LatLngBounds(
//         LatLng(41.652319, -4.715917), LatLng(41.662319, -4.705917));
//     _startPoint = UserXEST.userXEST.lastMapView;
//     _pointItineraries = widget.pointItineraries;
//     _myMarkers = [];
//     _lastMapEventScrollWheelZoom = 0;
//     _strSubMap = _mapController.mapEventStream
//         .where((event) =>
//             event is MapEventMoveEnd ||
//             event is MapEventDoubleTapZoomEnd ||
//             event is MapEventScrollWheelZoom)
//         .listen((event) {
//       _latLngBounds = _mapController.camera.visibleBounds;
//       if (event is MapEventScrollWheelZoom) {
//         int current = DateTime.now().millisecondsSinceEpoch;
//         if (_lastMapEventScrollWheelZoom + 200 < current) {
//           _lastMapEventScrollWheelZoom = current;
//           _createMarkers();
//         }
//       } else {
//         _createMarkers();
//       }
//     });

//     super.initState();
//   }

//   @override
//   void dispose() {
//     _mapController.dispose();
//     _strSubMap.cancel();
//     super.dispose();
//   }

//   void _createMarkers() async {
//     _myMarkers = [];
//     ThemeData td = Theme.of(context);
//     ColorScheme colorScheme = td.colorScheme;
//     MapData.checkCurrentMapSplit(_latLngBounds)
//         .then((List<Feature> listFeatures) {
//       for (int i = 0, tama = listFeatures.length; i < tama; i++) {
//         Feature feature = listFeatures.elementAt(i);
//         if (!feature
//             .getALabel(lang: MyApp.currentLang)
//             .contains('www.openstreetmap.org')) {
//           bool seleccionado = _pointItineraries.indexWhere(
//                   (PointItinerary pointItinerary) =>
//                       pointItinerary.feature.id == feature.id) >
//               -1;
//           if (mounted) {
//             _myMarkers.add(CHESTMarker(context,
//                 feature: feature,
//                 icon: Icon(Icons.castle_outlined,
//                     color: seleccionado
//                         ? colorScheme.onPrimaryContainer
//                         : Colors.black),
//                 currentLayer: MapLayer.layer!,
//                 circleWidthBorder: seleccionado ? 2 : 1,
//                 circleWidthColor:
//                     seleccionado ? colorScheme.primary : Colors.grey,
//                 circleContainerColor: seleccionado
//                     ? td.colorScheme.primaryContainer
//                     : Colors.grey[400]!,
//                 textInGray: !seleccionado, onTap: () async {
//               int index = _pointItineraries.indexWhere(
//                   (PointItinerary pointItinerary) =>
//                       pointItinerary.feature.id == feature.id);
//               PointItinerary pointItinerary;
//               if (index >= 0) {
//                 pointItinerary = _pointItineraries.elementAt(index);
//               } else {
//                 pointItinerary = PointItinerary({
//                   'id': feature.id,
//                 });
//                 pointItinerary.feature = feature;
//               }

//               PointItinerary? pIt = await Navigator.push(
//                 context,
//                 MaterialPageRoute<PointItinerary>(
//                     builder: (BuildContext context) => AddEditPointItineary(
//                           pointItinerary,
//                           ItineraryType.bag,
//                           index < 0,
//                           enableEdit: false,
//                         ),
//                     fullscreenDialog: true),
//               );
//               if (pIt is PointItinerary) {
//                 if (pIt.removeFromIt) {
//                   _pointItineraries.removeWhere(
//                       (PointItinerary pointIt) => pointIt.id == pIt.id);
//                 } else {
//                   int index = _pointItineraries
//                       .indexWhere((PointItinerary pit) => pit.id == pIt.id);
//                   if (index > -1) {
//                     _pointItineraries.removeAt(index);
//                   }
//                   _pointItineraries.add(pIt);
//                 }
//               }
//               _createMarkers();
//             }));
//           }
//         }
//       }
//       setState(() {});
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     AppLocalizations appLoca = AppLocalizations.of(context)!;
//     ThemeData td = Theme.of(context);
//     ColorScheme colorScheme = td.colorScheme;
//     return Scaffold(
//       appBar: AppBar(
//         centerTitle: false,
//         title: Text(appLoca.sTyLT),
//       ),
//       body: Stack(
//         alignment: Alignment.bottomRight,
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               backgroundColor: td.brightness == Brightness.light
//                   ? Colors.white54
//                   : Colors.black54,
//               maxZoom: MapLayer.maxZoom,
//               minZoom: MapLayer.minZoom,
//               // initialCenter: const LatLng(41.662319, -4.705917),
//               // initialZoom: 14,
//               initialCenter: _startPoint.point!,
//               initialZoom: _startPoint.zoom!,
//               interactionOptions: const InteractionOptions(
//                 flags: InteractiveFlag.all,
//                 pinchZoomThreshold: 2.0,
//               ),
//               onMapReady: () {
//                 _createMarkers();
//               },
//             ),
//             children: [
//               MapLayer.tileLayerWidget(brightness: td.brightness),
//               MapLayer.atributionWidget(),
//               MarkerClusterLayerWidget(
//                 options: MarkerClusterLayerOptions(
//                   maxClusterRadius: 120,
//                   centerMarkerOnClick: false,
//                   zoomToBoundsOnClick: false,
//                   showPolygon: false,
//                   onClusterTap: (p0) {
//                     _mapController.move(
//                         p0.bounds.center, min(p0.zoom + 1, MapLayer.maxZoom));
//                   },
//                   disableClusteringAtZoom: 18,
//                   size: const Size(76, 76),
//                   markers: _myMarkers,
//                   circleSpiralSwitchover: 6,
//                   spiderfySpiralDistanceMultiplier: 1,
//                   polygonOptions: PolygonOptions(
//                       borderColor: colorScheme.primary,
//                       color: colorScheme.primaryContainer,
//                       borderStrokeWidth: 1),
//                   builder: (context, markers) {
//                     int tama = markers.length;
//                     int nPul = 0;
//                     for (Marker marker in markers) {
//                       int index = _pointItineraries.indexWhere(
//                           (PointItinerary pit) =>
//                               pit.feature.point == marker.point);
//                       if (index > -1) {
//                         ++nPul;
//                       }
//                     }
//                     double sizeMarker;
//                     int multi = Queries.layerType == LayerType.forest ? 100 : 1;
//                     if (tama <= (5 * multi)) {
//                       sizeMarker = 56;
//                     } else {
//                       if (tama <= (8 * multi)) {
//                         sizeMarker = 66;
//                       } else {
//                         sizeMarker = 76;
//                       }
//                     }
//                     return Container(
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(sizeMarker),
//                         border: Border.all(color: Colors.grey[900]!, width: 2),
//                         color: nPul == tama
//                             ? colorScheme.primary
//                             : nPul == 0
//                                 ? Colors.grey[700]!
//                                 : Colors.pink[100]!,
//                       ),
//                       child: Center(
//                         child: Text(
//                           markers.length.toString(),
//                           style: TextStyle(
//                               color: nPul == tama
//                                   ? colorScheme.onPrimary
//                                   : nPul == 0
//                                       ? Colors.white
//                                       : Colors.black),
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//           SafeArea(
//             minimum: const EdgeInsets.only(top: 15, left: 15),
//             bottom: false,
//             right: false,
//             child: Align(
//               alignment: Alignment.topLeft,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 14),
//                     clipBehavior: Clip.none,
//                     child: SearchAnchor(
//                       builder: (context, controller) =>
//                           FloatingActionButton.small(
//                         heroTag: Auxiliar.searchHero,
//                         tooltip: appLoca.searchCity,
//                         onPressed: () => _searchController.openView(),
//                         child: Icon(
//                           Icons.search,
//                           semanticLabel: appLoca.realizaBusqueda,
//                         ),
//                       ),
//                       searchController: _searchController,
//                       suggestionsBuilder: (context, controller) =>
//                           Auxiliar.recuperaSugerencias(
//                         context,
//                         controller,
//                         mapController: _mapController,
//                         moveWithUrl: false,
//                       ),
//                     ),
//                   ),
//                   Padding(
//                     padding:
//                         const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
//                     child: FloatingActionButton.small(
//                       heroTag: null,
//                       tooltip: appLoca.tipoMapa,
//                       onPressed: () => Auxiliar.showMBS(
//                           context,
//                           Column(
//                             mainAxisSize: MainAxisSize.min,
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Center(
//                                 child: Wrap(
//                                   spacing: 10,
//                                   runSpacing: 10,
//                                   children: [
//                                     _botonMapa(
//                                       Layers.carto,
//                                       MediaQuery.of(context)
//                                                   .platformBrightness ==
//                                               Brightness.light
//                                           ? 'images/basemap_gallery/estandar_claro.png'
//                                           : 'images/basemap_gallery/estandar_oscuro.png',
//                                       appLoca.mapaEstandar,
//                                     ),
//                                     _botonMapa(
//                                       Layers.satellite,
//                                       'images/basemap_gallery/satelite.png',
//                                       appLoca.mapaSatelite,
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                             ],
//                           ),
//                           title: appLoca.tipoMapa),
//                       child: Icon(
//                         Icons.settings_applications,
//                         semanticLabel: appLoca.ajustes,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           SafeArea(
//             minimum: const EdgeInsets.only(bottom: 15, right: 15),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               crossAxisAlignment: CrossAxisAlignment.end,
//               children: [
//                 Visibility(
//                   visible: kIsWeb,
//                   child: Padding(
//                     padding: const EdgeInsets.only(bottom: 6),
//                     child: Wrap(
//                       direction: Axis.vertical,
//                       spacing: 3,
//                       children: [
//                         FloatingActionButton.small(
//                           heroTag: null,
//                           onPressed: () {
//                             _mapController.move(
//                                 _mapController.camera.center,
//                                 min(_mapController.camera.zoom + 1,
//                                     MapLayer.maxZoom));
//                             _createMarkers();
//                           },
//                           tooltip: appLoca.aumentaZumShort,
//                           child: Icon(
//                             Icons.zoom_in,
//                             semanticLabel: appLoca.aumentaZumShort,
//                           ),
//                         ),
//                         FloatingActionButton.small(
//                           heroTag: null,
//                           onPressed: () {
//                             _mapController.move(
//                                 _mapController.camera.center,
//                                 max(_mapController.camera.zoom - 1,
//                                     MapLayer.minZoom));
//                             _createMarkers();
//                           },
//                           tooltip: appLoca.disminuyeZum,
//                           child: Icon(
//                             Icons.zoom_out,
//                             semanticLabel: appLoca.disminuyeZum,
//                           ),
//                         )
//                       ],
//                     ),
//                   ),
//                 ),
//                 FilledButton.icon(
//                   onPressed: () {
//                     Navigator.pop(context, _pointItineraries);
//                   },
//                   label: Text(appLoca.guardar),
//                   icon: Icon(Icons.save),
//                 ),
//               ],
//             ),
//           )
//         ],
//       ),
//     );
//   }

//   Widget _botonMapa(Layers layer, String image, String textLabel) {
//     return Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(
//           color: MapLayer.layer == layer
//               ? Theme.of(context).colorScheme.primary
//               : Colors.transparent,
//           width: 2,
//         ),
//       ),
//       margin: const EdgeInsets.only(bottom: 5, top: 10, right: 10, left: 10),
//       child: InkWell(
//         onTap: MapLayer.layer != layer ? () => _changeLayer(layer) : () {},
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             Container(
//               margin: const EdgeInsets.all(10),
//               width: 100,
//               height: 100,
//               child: ClipRRect(
//                 borderRadius: BorderRadius.circular(10),
//                 child: Image.asset(
//                   image,
//                   fit: BoxFit.fill,
//                 ),
//               ),
//             ),
//             Container(
//               margin: const EdgeInsets.only(bottom: 10, right: 10, left: 10),
//               child: Text(textLabel),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _changeLayer(Layers layer) async {
//     setState(() {
//       MapLayer.layer = layer;
//       // Auxiliar.updateMaxZoom();
//       if (_mapController.camera.zoom > MapLayer.maxZoom) {
//         _mapController.move(_mapController.camera.center, MapLayer.maxZoom);
//       }
//     });
//     if (UserXEST.userXEST.isNotGuest) {
//       http
//           .put(Queries.preferences(),
//               headers: {
//                 'content-type': 'application/json',
//                 'Authorization':
//                     'Bearer ${await FirebaseAuth.instance.currentUser!.getIdToken()}'
//               },
//               body: json.encode({'defaultMap': layer.name}))
//           .then((_) {
//         if (mounted) Navigator.pop(context);
//         _createMarkers();
//       }).onError((error, stackTrace) {
//         if (mounted) Navigator.pop(context);
//         _createMarkers();
//       });
//     } else {
//       Navigator.pop(context);
//       _createMarkers();
//     }
//   }
// }
