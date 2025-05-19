import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_delta_from_html/parser/html_to_delta.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:chest/full_screen.dart';
import 'package:chest/util/config.dart';
import 'package:chest/l10n/generated/app_localizations.dart';
import 'package:chest/main.dart';
import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/channel.dart';
import 'package:chest/util/helpers/pair.dart';
import 'package:chest/util/helpers/widget_facto.dart';
import 'package:chest/util/helpers/user_xest.dart';

class FormChannelTeacher extends StatefulWidget {
  const FormChannelTeacher({super.key});

  @override
  State<StatefulWidget> createState() => _FormChannelTeacher();
}

class _FormChannelTeacher extends State<FormChannelTeacher> {
  late GlobalKey<FormState> _formChannelTeacherKey;
  late Channel _channel;
  late String _description, _label;
  late FocusNode _focusNode;
  late QuillController _quillController;
  late bool _hasFocus, _errorDescription, _enviarPulsado;

  @override
  void initState() {
    _formChannelTeacherKey = GlobalKey<FormState>();
    _enviarPulsado = false;
    _focusNode = FocusNode();
    Participant author = Participant.empty();
    author.id = UserXEST.userXEST.id;
    author.alias = UserXEST.userXEST.alias!;
    if (UserXEST.userXEST.comment != null) {
      author.comments = UserXEST.userXEST.comment!;
    }
    _channel = Channel.author(author);
    _label = '';
    _description = '';
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
    double w = MediaQuery.of(context).size.width;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    ThemeData td = Theme.of(context);
    TextTheme textTheme = td.textTheme;
    return Form(
      key: _formChannelTeacherKey,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(centerTitle: false, title: Text(appLoca.newChannel)),
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
                          labelText: appLoca.tituloCanal,
                          hintText: appLoca.tituloCanal,
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
                        return appLoca.tituloCanalError;
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
                    margin: EdgeInsets.all(Auxiliar.getLateralMargin(w)),
                    // padding: EdgeInsets.all(Auxiliar.getLateralMargin(w)),
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
                            '${appLoca.descripcionCanal}*',
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
                                  appLoca.descripcionCanalError,
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
              sliver: SliverPadding(
                padding: EdgeInsets.all(Auxiliar.getLateralMargin(w)),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.center,
                    child: FilledButton(
                      onPressed: _enviarPulsado
                          ? null
                          : () async {
                              _quillController.readOnly = true;
                              setState(() => _enviarPulsado = true);
                              bool noErrorLabel = _formChannelTeacherKey
                                  .currentState!
                                  .validate();
                              if (noErrorLabel) {
                                _channel.labels = [
                                  PairLang(MyApp.currentLang, _label)
                                ];
                              }
                              if (_description.trim().isNotEmpty) {
                                setState(() {
                                  _errorDescription = false;
                                });
                                _channel.comments = [
                                  PairLang(MyApp.currentLang, _description)
                                ];
                              } else {
                                setState(() {
                                  _errorDescription = true;
                                });
                              }
                              if (noErrorLabel && !_errorDescription) {
                                // Aquí hay que hacer la comunicación con el servidor
                                await Future.delayed(
                                    const Duration(milliseconds: 600));
                                // Nos devolverá un identificador único para el canal
                                // Ahora lo simulo con un uuid generado en el cliente
                                _channel.id =
                                    '${Config.addClient}/channels/${const Uuid().v4()}';
                                // Finalmente…
                                setState(() => _enviarPulsado = false);
                                _quillController.readOnly = false;
                                if (mounted) {
                                  Navigator.pop(context, _channel);
                                }
                              } else {
                                setState(() => _enviarPulsado = false);
                                _quillController.readOnly = false;
                              }
                            },
                      child: Text(appLoca.addChannel),
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

class FormChannelStudent extends StatefulWidget {
  const FormChannelStudent({super.key});

  @override
  State<StatefulWidget> createState() => _FormChannelStudent();
}

class _FormChannelStudent extends State<FormChannelStudent> {
  late GlobalKey<FormState> _formChannelStudentKey;
  late Channel _channel;
  late String _id;
  late bool _enviarPulsado;

  @override
  void initState() {
    _formChannelStudentKey = GlobalKey<FormState>();
    _enviarPulsado = false;

    _channel = Channel.empty();

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
      key: _formChannelStudentKey,
      child: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(centerTitle: false, title: Text(appLoca.newChannel)),
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
                          labelText: appLoca.idCanal,
                          hintText: appLoca.idCanalError,
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
                        return appLoca.idCanalError;
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
                      child: Text(appLoca.apuntarmeCanal),
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

class InfoChannel extends StatefulWidget {
  final Channel channel;
  const InfoChannel(this.channel, {super.key});

  @override
  State<StatefulWidget> createState() => _InfoChannel();
}

class _InfoChannel extends State<InfoChannel> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double sizeQr = min(Auxiliar.maxWidth, size.shortestSide) * 0.25;
    ThemeData td = Theme.of(context);
    ColorScheme colorScheme = td.colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              widget.channel.getLabel(lang: MyApp.currentLang),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            centerTitle: false,
            floating: true,
          ),
          SliverSafeArea(
            top: false,
            bottom: false,
            minimum: EdgeInsets.symmetric(
                horizontal: Auxiliar.getLateralMargin(size.width)),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: Auxiliar.maxWidth,
                    minWidth: Auxiliar.maxWidth,
                  ),
                  decoration: BoxDecoration(
                    color: td.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      EdgeInsets.all(Auxiliar.getLateralMargin(size.width)),
                  alignment: Alignment.centerLeft,
                  child: HtmlWidget(
                    widget.channel.getComment(lang: MyApp.currentLang),
                    textStyle: td.textTheme.bodyMedium!
                        .copyWith(color: colorScheme.onSecondaryContainer),
                    factoryBuilder: () => MyWidgetFactory(),
                  ),
                ),
              ),
            ),
          ),
          SliverSafeArea(
            top: false,
            bottom: false,
            minimum: EdgeInsets.all(Auxiliar.getLateralMargin(size.width)),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  padding:
                      EdgeInsets.all(Auxiliar.getLateralMargin(size.width)),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText.rich(
                        TextSpan(text: "Identificador del canal: ", children: [
                          TextSpan(
                              text: widget.channel.id,
                              style: td.textTheme.bodyMedium!.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onTertiaryContainer))
                        ]),
                        style: td.textTheme.bodyMedium!
                            .copyWith(color: colorScheme.onTertiaryContainer),
                      ),
                      Center(
                        child: SizedBox(
                          width: sizeQr,
                          height: sizeQr,
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<String?>(
                                    builder: (BuildContext context) =>
                                        FullScreenQR(widget.channel.id),
                                    fullscreenDialog: true),
                              );
                            },
                            child: QrImageView(
                              data: widget.channel.id,
                              version: QrVersions.auto,
                              gapless: false,
                              padding: EdgeInsets.only(
                                  top: Auxiliar.getLateralMargin(size.width)),
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
