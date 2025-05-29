import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/parser/html_to_delta.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

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

  @override
  void initState() {
    _feed = widget.feed;
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
              title:
                  Text(_feed.id.isEmpty ? appLoca.newFeed : appLoca.editFeed),
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
                              if (_pass.isNotEmpty) {
                                _feed.pass = _pass;
                              }
                              if (noErrorLabel && !_errorDescription) {
                                // TODO Aquí hay que hacer la comunicación con el servidor
                                await Future.delayed(
                                    const Duration(milliseconds: 300));
                                // Nos devolverá un identificador único para el canal
                                // Ahora lo simulo con un uuid generado en el cliente
                                _feed.id =
                                    '${Config.moultData}${const Uuid().v4()}';
                                FeedCache.updateFeed(_feed);
                                // Finalmente…
                                setState(() => _enviarPulsado = false);
                                _quillController.readOnly = false;
                                if (mounted) {
                                  Navigator.pop(context, _feed);
                                }
                              } else {
                                setState(() => _enviarPulsado = false);
                                _quillController.readOnly = false;
                              }
                            },
                      child: Text(_feed.id.isEmpty
                          ? appLoca.addFeed
                          : appLoca.editFeed),
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
    _idTabs = ['info', 'resources', 'answers'];
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
                          Tab(text: appLoca.resources),
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
                                              : name == _idTabs.elementAt(1)
                                                  ? _widgetResources()
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
                      // padding: EdgeInsets.only(
                      //     top: Auxiliar.getLateralMargin(size.width)),
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
                        UserXEST.userXEST.id == _feed!.feeder.id
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 5),
                        child: SwitchListTile.adaptive(
                            value: _passVisible,
                            title: Text(appLoca.showPassword),
                            activeColor: colorScheme.primary,
                            onChanged: (bool v) =>
                                setState(() => _passVisible = v)))
                    : Container(),
                _passVisible
                    ? SelectableText(
                        _feed!.pass,
                        style: GoogleFonts.robotoMono().copyWith(
                            fontSize: td.textTheme.headlineMedium!.fontSize),
                      )
                    : Text(
                        '* * * * *',
                        style: GoogleFonts.robotoMono(),
                      ),
              ],
            ),
          ),
          SizedBox(height: 80),
        ]);
  }

  Widget _widgetResources() {
    return Container(
      color: Colors.pink,
      height: 200000,
      width: 20,
    );
  }

  Widget _widgetAnswers() {
    return Container(
      color: Colors.teal,
      height: 20000,
      width: 20,
    );
  }

  Widget _fav() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    switch (_tabController.index) {
      case 0:
        return _feed!.feeder.id == UserXEST.userXEST.id &&
                UserXEST.userXEST.canEditNow
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
                label: Text(appLoca.editFeed),
              )
            : Container();
      case 1:
        return _feed!.feeder.id == UserXEST.userXEST.id &&
                UserXEST.userXEST.canEditNow
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
                icon: Icon(Icons.edit_document),
                label: Text(appLoca.editarRecursos),
              )
            : Container();
      default:
        return _feed!.feeder.id == UserXEST.userXEST.id &&
                UserXEST.userXEST.canEditNow
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
                icon: Icon(Icons.manage_accounts),
                label: Text(appLoca.editarUsuarios),
              )
            : Container();
    }
  }
}
