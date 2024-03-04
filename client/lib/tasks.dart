import 'dart:convert';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:chest/util/helpers/pair.dart';
import 'package:chest/util/helpers/queries.dart';
import 'package:chest/util/helpers/user.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';
import 'package:quill_html_editor/quill_html_editor.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/util/config.dart';
import 'package:chest/util/helpers/answers.dart';
import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/tasks.dart';
import 'package:chest/main.dart';
import 'package:chest/util/helpers/widget_facto.dart';
import 'package:chest/util/helpers/auxiliar_mobile.dart'
    if (dart.library.html) 'package:chest/util/helpers/auxiliar_web.dart';

class COTask extends StatefulWidget {
  final String shortIdFeature, shortIdTask;
  final Answer? answer;
  final bool preview;
  final bool userIsNear;

  const COTask(
      {required this.shortIdFeature,
      required this.shortIdTask,
      this.answer,
      this.preview = false,
      this.userIsNear = false,
      super.key});

  @override
  State<StatefulWidget> createState() => _COTask();
}

// class COTask extends StatefulWidget {
//   final Feature poi;
//   final Task task;
//   final Answer? answer;
//   final bool vistaPrevia;
//   const COTask(this.poi, this.task,
//       {required this.answer, this.vistaPrevia = false, super.key});
//   @override
//   State<StatefulWidget> createState() => _COTask();
// }

class _COTask extends State<COTask> {
  Task? task;

  late bool _selectTF, _guardado;
  late List<bool> _selectMCQ;
  late String _selectMCQR;
  late GlobalKey<FormState> _thisKey, _thisKeyMCQ;
  late Answer answer;
  late bool textoObligatorio;
  late String texto;
  late int _startTime;
  List<String> valoresMCQ = [];
  bool showMessageGoBack = false;

  @override
  void initState() {
    task = Task.empty(widget.shortIdFeature);
    super.initState();
  }

  Future<Map> _getLearningTask() async {
    Map data = await http
        .get(Queries().getTask(widget.shortIdFeature, widget.shortIdTask))
        .then((response) =>
            response.statusCode == 200 ? json.decode(response.body) : {})
        .onError((error, stackTrace) => {});
    return data;
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    AppLocalizations? appLoca = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.preview ? appLoca!.vistaPrevia : appLoca!.realizaTarea),
      ),
      body: task!.isEmpty
          ? FutureBuilder(
              future: _getLearningTask(),
              builder: (context, snapshot) {
                if (snapshot.hasData && !snapshot.hasError) {
                  if (snapshot.data != null &&
                      (snapshot.data as Map).isNotEmpty) {
                    Map<String, dynamic> tdata =
                        snapshot.data as Map<String, dynamic>;
                    tdata['task'] = Auxiliar.shortId2Id(widget.shortIdTask);
                    task = Task(snapshot.data!,
                        Auxiliar.shortId2Id(widget.shortIdFeature)!);
                    if (Auxiliar.userCHEST.crol != Rol.teacher) {
                      if (!task!.spaces.contains(Space.physical) ||
                          (task!.spaces.contains(Space.physical) &&
                              task!.spaces.length > 1)) {
                        showMessageGoBack = false;
                      } else {
                        showMessageGoBack = !widget.userIsNear;
                      }
                    }

                    _initValues();
                    return SafeArea(
                        top: false,
                        bottom: false,
                        minimum: EdgeInsets.symmetric(
                            horizontal: Auxiliar.getLateralMargin(size.width)),
                        child: CustomScrollView(slivers: _showTask()));
                  } else {
                    return SafeArea(
                        top: false,
                        bottom: false,
                        minimum: EdgeInsets.symmetric(
                            horizontal: Auxiliar.getLateralMargin(size.width)),
                        child: CustomScrollView(slivers: [
                          SliverToBoxAdapter(
                            child: Text(appLoca.tareaNoEncontrada),
                          )
                        ]));
                  }
                } else {
                  if (snapshot.hasError) {
                    return SafeArea(
                        top: false,
                        bottom: false,
                        minimum: EdgeInsets.symmetric(
                            horizontal: Auxiliar.getLateralMargin(size.width)),
                        child: CustomScrollView(slivers: [
                          SliverToBoxAdapter(
                            child: Text(appLoca.tareaNoEncontrada),
                          )
                        ]));
                  } else {
                    return SafeArea(
                        top: false,
                        bottom: false,
                        minimum: EdgeInsets.symmetric(
                            horizontal: Auxiliar.getLateralMargin(size.width)),
                        child: const CustomScrollView(
                          slivers: [
                            SliverToBoxAdapter(
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            )
                          ],
                        ));
                  }
                }
              })
          : SafeArea(
              top: false,
              bottom: false,
              minimum: EdgeInsets.symmetric(
                  horizontal: Auxiliar.getLateralMargin(size.width)),
              child: CustomScrollView(slivers: _showTask())),
    );
  }

  void _initValues() {
    _thisKey = GlobalKey<FormState>();
    _thisKeyMCQ = GlobalKey<FormState>();
    _guardado = false;
    _startTime = DateTime.now().millisecondsSinceEpoch;

    Set<AnswerType> atRT = {
      AnswerType.multiplePhotosText,
      AnswerType.photoText,
      AnswerType.text,
      AnswerType.videoText
    };
    textoObligatorio = atRT.contains(task!.aT);

    if (widget.answer == null) {
      answer = Answer.withoutAnswer(
        widget.shortIdFeature,
        widget.shortIdTask,
        task!.aT,
      );
      // TODO faltaría agregar el objGeo. ¿Lo traigo desde la pantalla anterior? ¿Hago la consulta al servidor?
      // answer.poi = widget.poi;
      answer.task = task!;
      switch (task!.aT) {
        case AnswerType.mcq:
          int tama = task!.distractors.length + task!.correctMCQ.length;
          _selectMCQ = task!.singleSelection
              ? List<bool>.generate(tama, (index) => index == 0)
              : List<bool>.filled(tama, false);
          for (PairLang ele in task!.distractors) {
            valoresMCQ.add(ele.value);
          }
          for (PairLang ele in task!.correctMCQ) {
            valoresMCQ.add(ele.value);
          }
          valoresMCQ.shuffle();
          _selectMCQR = valoresMCQ.first;
          break;
        case AnswerType.tf:
          _selectTF = Random.secure().nextBool();

          break;
        default:
      }
      texto = '';
      // TODO
      // answer.labelPoi = widget.poi.labelLang(MyApp.currentLang) ??
      //     widget.poi.labelLang('es') ??
      //     widget.poi.labels.first.value;
      // answer.commentTask = widget.task.commentLang(MyApp.currentLang) ??
      //     widget.task.commentLang('es') ??
      //     widget.task.comments.first.value;
    } else {
      answer = widget.answer!;
      // TODO
      // answer.poi = widget.poi;
      answer.task = task!;
      switch (answer.answerType) {
        case AnswerType.mcq:
        case AnswerType.multiplePhotos:
        case AnswerType.noAnswer:
        case AnswerType.photo:
        case AnswerType.tf:
        case AnswerType.video:
          if (answer.hasAnswer && answer.hasExtraText) {
            texto = answer.answer['extraText'];
          } else {
            texto = '';
          }
          break;
        case AnswerType.multiplePhotosText:
        case AnswerType.photoText:
        case AnswerType.text:
        case AnswerType.videoText:
          if (answer.hasAnswer) {
            texto = answer.answer['answer'];
          } else {
            texto = '';
          }
          break;
        default:
          texto = '';
      }
    }
  }

  List<Widget> _showTask() {
    List<Widget> out = [_widgetInfoTask(), _widgetSolveTask()];
    if (showMessageGoBack) {
      out.add(_goBack());
    }
    out.add(_widgetButtons());
    return out;
    // return SliverList(
    //     delegate: SliverChildBuilderDelegate(
    //   (context, index) => lstWidgetTask.elementAt(index),
    //   childCount: lstWidgetTask.length,
    // ));
  }

  Widget _widgetInfoTask() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 40, bottom: 20),
      sliver: SliverToBoxAdapter(
        child: HtmlWidget(
          task!.commentLang(MyApp.currentLang) ??
              task!.commentLang('en') ??
              task!.comments.first.value,
          factoryBuilder: () => MyWidgetFactory(),
          textStyle: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }

  Widget _widgetSolveTask() {
    List<Widget> lista = [];
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ThemeData td = Theme.of(context);
    Widget cuadrotexto = Form(
      key: _thisKey,
      child: TextFormField(
        maxLines: textoObligatorio ? 5 : 2,
        initialValue: texto,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: textoObligatorio
                ? appLoca!.respondePreguntaTextualLabel
                : appLoca!.notasOpcionalesLabel,
            hintText: textoObligatorio
                ? appLoca.respondePreguntaTextual
                : appLoca.notasOpcionales,
            hintMaxLines: 2,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.text,
        validator: (value) {
          if (value != null) {
            if (textoObligatorio) {
              if (value.trim().isNotEmpty) {
                texto = value.trim();
                return null;
              } else {
                return appLoca.respondePreguntaTextual;
              }
            } else {
              texto = value.trim();
              return null;
            }
          } else {
            return appLoca.respondePreguntaTextual;
          }
        },
      ),
    );

    switch (task!.aT) {
      case AnswerType.mcq:
        List<Widget> widgetsMCQ = [];
        if (task!.singleSelection) {
          for (int i = 0, tama = valoresMCQ.length; i < tama; i++) {
            String valor = valoresMCQ[i];
            bool falsa = task!.correctMCQ
                    .indexWhere((PairLang element) => element.value == valor) ==
                -1;
            widgetsMCQ.add(
              Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: RadioListTile<String>(
                    tileColor: _guardado
                        ? falsa
                            ? td.colorScheme.error
                            : td.colorScheme.primary
                        : null,
                    title: Text(
                      valor,
                      style: _guardado
                          ? td.textTheme.bodyLarge!.copyWith(
                              color: falsa
                                  ? td.colorScheme.onError
                                  : td.colorScheme.onPrimary,
                            )
                          : td.textTheme.bodyLarge,
                    ),
                    value: valor,
                    groupValue: _selectMCQR,
                    onChanged: !_guardado
                        ? (String? v) {
                            setState(() {
                              _selectMCQR = v!;
                            });
                          }
                        : null,
                  ),
                ),
              ),
            );
          }
        } else {
          for (int i = 0, tama = valoresMCQ.length; i < tama; i++) {
            String valor = valoresMCQ[i];
            bool falsa = task!.correctMCQ
                    .indexWhere((PairLang element) => element.value == valor) ==
                -1;
            widgetsMCQ.add(
              Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: CheckboxListTile(
                    tileColor: _guardado
                        ? falsa
                            ? td.colorScheme.error
                            : td.colorScheme.primary
                        : null,
                    value: _selectMCQ[i],
                    title: Text(
                      valor,
                      style: _guardado
                          ? td.textTheme.bodyLarge!.copyWith(
                              color: falsa
                                  ? td.colorScheme.onError
                                  : td.colorScheme.onPrimary,
                            )
                          : td.textTheme.bodyLarge,
                    ),
                    onChanged: (value) => setState(() {
                      _selectMCQ[i] = !_selectMCQ[i];
                    }),
                    enabled: !_guardado,
                  ),
                ),
              ),
            );
          }
        }
        lista.add(
          Form(
            key: _thisKeyMCQ,
            child: Column(mainAxisSize: MainAxisSize.min, children: widgetsMCQ),
          ),
        );
        break;
      case AnswerType.multiplePhotos:
      case AnswerType.photo:
      case AnswerType.multiplePhotosText:
      case AnswerType.photoText:
        // TODO Visor de fotos
        break;
      case AnswerType.tf:
        bool? rC = task!.hasCorrectTF ? task!.correctTF : null;
        Widget extra = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: RadioListTile<bool>(
                    tileColor: _guardado
                        ? task!.hasCorrectTF
                            ? !rC!
                                ? td.colorScheme.error
                                : td.colorScheme.primary
                            : null
                        : null,
                    title: Text(
                      appLoca.rbVFVNTVLabel,
                      style: _guardado
                          ? task!.hasCorrectTF
                              ? td.textTheme.bodyLarge!.copyWith(
                                  color: !rC!
                                      ? td.colorScheme.onError
                                      : td.colorScheme.onPrimary,
                                )
                              : td.textTheme.bodyLarge
                          : td.textTheme.bodyLarge,
                    ),
                    value: true,
                    groupValue: _selectTF,
                    onChanged: (bool? v) {
                      setState(() => _selectTF = v!);
                    }),
              ),
            ),
            Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: RadioListTile<bool>(
                  tileColor: _guardado
                      ? task!.hasCorrectTF
                          ? rC!
                              ? td.colorScheme.error
                              : td.colorScheme.primary
                          : null
                      : null,
                  title: Text(
                    appLoca.rbVFFNTLabel,
                    style: _guardado
                        ? task!.hasCorrectTF
                            ? td.textTheme.bodyLarge!.copyWith(
                                color: rC!
                                    ? td.colorScheme.onError
                                    : td.colorScheme.onPrimary,
                              )
                            : td.textTheme.bodyLarge
                        : td.textTheme.bodyLarge,
                  ),
                  value: false,
                  groupValue: _selectTF,
                  onChanged: (bool? v) {
                    setState(() => _selectTF = v!);
                  }),
            ),
            const SizedBox(
              height: 10,
            )
          ],
        );
        lista.add(extra);
        break;
      case AnswerType.video:
      case AnswerType.videoText:
        // TODO Visor de vídeo
        break;
      default:
    }

    lista.add(cuadrotexto);

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 20),
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

  Widget _goBack() {
    return SliverToBoxAdapter(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(Auxiliar.mediumMargin),
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          padding: const EdgeInsets.all(Auxiliar.mediumMargin),
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: Center(
            child: TextButton(
              child: Text(
                "Vuelve a la pantalla anterior para que podamos comprobar si te encuentras cercano al lugar",
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
              ),
              onPressed: () => setState(
                () => context.go('/map/features/${widget.shortIdFeature}'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _widgetButtons() {
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> botones = [];
    switch (task!.aT) {
      case AnswerType.multiplePhotos:
      case AnswerType.photo:
      case AnswerType.multiplePhotosText:
      case AnswerType.photoText:
      case AnswerType.video:
      case AnswerType.videoText:
        botones.add(Padding(
          padding: const EdgeInsets.only(right: 10),
          child: OutlinedButton.icon(
            onPressed: null,
            //  () async {
            //   // List<CameraDescription> cameras = await availableCameras();
            //   // await Navigator.push(
            //   //     context,
            //   //     MaterialPageRoute<Task>(
            //   //         builder: (BuildContext context) {
            //   //           return TakePhoto(cameras.first);
            //   //         },
            //   //         fullscreenDialog: true));
            //   await availableCameras()
            //       .then((cameras) async => await Navigator.push(
            //           context,
            //           MaterialPageRoute<Task>(
            //               builder: (BuildContext context) {
            //                 return TakePhoto(cameras.first);
            //               },
            //               fullscreenDialog: true)));
            // },
            icon: const Icon(Icons.camera_alt),
            label: Text(appLoca!.abrirCamara),
          ),
        ));
        break;
      default:
    }
    botones.add(FilledButton.icon(
      onPressed: widget.preview
          ? null
          : showMessageGoBack
              ? null
              : _guardado
                  ? () {
                      switch (answer.answerType) {
                        case AnswerType.mcq:
                        case AnswerType.tf:
                          Navigator.pop(context);
                          break;
                        default:
                      }
                    }
                  : () async {
                      if (_thisKey.currentState!.validate()) {
                        try {
                          int now = DateTime.now().millisecondsSinceEpoch;
                          answer.time2Complete = now - _startTime;
                          answer.timestamp = now;
                          switch (answer.answerType) {
                            case AnswerType.mcq:
                              String answ = "";
                              if (task!.singleSelection) {
                                answ = _selectMCQR;
                              } else {
                                List<String> a = [];
                                for (int i = 0, tama = _selectMCQ.length;
                                    i < tama;
                                    i++) {
                                  if (_selectMCQ[i]) {
                                    a.add(valoresMCQ[i]);
                                  }
                                }
                                answ = a.toString();
                              }
                              if (texto.trim().isNotEmpty) {
                                answer.answer = {
                                  'answer': answ,
                                  'timestamp':
                                      DateTime.now().millisecondsSinceEpoch,
                                  'extraText': texto.trim()
                                };
                              } else {
                                answer.answer = answ;
                              }
                              Auxiliar.userCHEST.answers.add(answer);
                              setState(() => _guardado = true);
                              break;
                            case AnswerType.multiplePhotos:
                              break;
                            case AnswerType.multiplePhotosText:
                              break;
                            case AnswerType.noAnswer:
                              break;
                            case AnswerType.photo:
                              break;
                            case AnswerType.photoText:
                              break;
                            case AnswerType.text:
                              answer.answer = texto;
                              break;
                            case AnswerType.tf:
                              if (texto.trim().isNotEmpty) {
                                answer.answer = {
                                  'answer': _selectTF,
                                  'timestamp':
                                      DateTime.now().millisecondsSinceEpoch,
                                  'extraText': texto.trim()
                                };
                              } else {
                                answer.answer = _selectTF;
                              }
                              Auxiliar.userCHEST.answers.add(answer);
                              setState(() => _guardado = true);
                              break;
                            case AnswerType.video:
                              break;
                            case AnswerType.videoText:
                              break;
                            default:
                          }
                          http
                              .post(Queries().newAnswer(),
                                  headers: {
                                    'Content-Type': 'application/json',
                                    // 'Authorization': Template('Bearer {{{token}}}')
                                    //     .renderString({
                                    //   'token': await FirebaseAuth.instance.currentUser!
                                    //       .getIdToken()
                                    // })
                                  },
                                  body:
                                      json.encode(answer.answer2CHESTServer()))
                              .then((response) {
                            switch (response.statusCode) {
                              case 201:
                                String idAnswer = response.headers['location']!;
                                answer.id = idAnswer;
                                break;
                              default:
                            }
                          }).onError((error, stackTrace) {
                            debugPrint(error.toString());
                          });
                        } catch (error) {
                          smState.clearSnackBars();
                          smState.showSnackBar(SnackBar(
                            content: Text(error.toString()),
                          ));
                        }
                        smState.clearSnackBars();
                        smState.showSnackBar(SnackBar(
                          content: Text(appLoca!.respuestaGuardada),
                          action: kIsWeb
                              ? SnackBarAction(
                                  label: appLoca.descargar,
                                  onPressed: () {
                                    AuxiliarFunctions.downloadAnswerWeb(
                                      answer,
                                      titlePage: appLoca.tareaCompletadaCHEST,
                                    );
                                  })
                              : null,
                        ));
                        if (!Config.development) {
                          await FirebaseAnalytics.instance.logEvent(
                            name: "taskCompleted",
                            parameters: {
                              "feature": widget.shortIdFeature,
                              "task": widget.shortIdTask
                            },
                          );
                        }
                      }
                    },
      label: _guardado ? Text(appLoca!.finRevision) : Text(appLoca!.guardar),
      icon:
          _guardado ? const Icon(Icons.navigate_next) : const Icon(Icons.save),
    ));
    // TODO REMOVE
    switch (task!.aT) {
      case AnswerType.multiplePhotos:
      case AnswerType.multiplePhotosText:
      case AnswerType.photo:
      case AnswerType.photoText:
      case AnswerType.video:
      case AnswerType.videoText:
        botones = [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.camera_alt),
              label: Text(appLoca.abrirCamara),
            ),
          ),
          FilledButton.icon(
            onPressed: null,
            label: Text(appLoca.guardar),
            icon: const Icon(Icons.save),
          ),
        ];
        break;
      default:
    }
    List<Widget> lista = [
      Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: botones,
      )
    ];
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
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
}

// class _COTask extends State<COTask> {
//   late bool _selectTF, _guardado;
//   late List<bool> _selectMCQ;
//   late String _selectMCQR;
//   late GlobalKey<FormState> _thisKey, _thisKeyMCQ;
//   late Answer answer;
//   late bool textoObligatorio;
//   late String texto;
//   late int _startTime;
//   List<String> valoresMCQ = [];

//   @override
//   void initState() {
//     _thisKey = GlobalKey<FormState>();
//     _thisKeyMCQ = GlobalKey<FormState>();
//     _guardado = false;
//     _startTime = DateTime.now().millisecondsSinceEpoch;
//     switch (widget.task.aT) {
//       case AnswerType.mcq:
//       case AnswerType.multiplePhotos:
//       case AnswerType.photo:
//       case AnswerType.noAnswer:
//       case AnswerType.tf:
//       case AnswerType.video:
//         textoObligatorio = false;
//         break;
//       case AnswerType.multiplePhotosText:
//       case AnswerType.photoText:
//       case AnswerType.text:
//       case AnswerType.videoText:
//         textoObligatorio = true;
//         break;
//       default:
//         break;
//     }
//     if (widget.answer == null) {
//       answer =
//           Answer.withoutAnswer(widget.poi.id, widget.task.id, widget.task.aT);
//       answer.poi = widget.poi;
//       answer.task = widget.task;
//       if (widget.task.aT == AnswerType.tf) {
//         _selectTF = Random.secure().nextBool();
//       }
//       if (widget.task.aT == AnswerType.mcq) {
//         int tama =
//             widget.task.distractors.length + widget.task.correctMCQ.length;
//         _selectMCQ = widget.task.singleSelection
//             ? List<bool>.generate(tama, (index) => index == 0)
//             : List<bool>.filled(tama, false);
//         for (PairLang ele in widget.task.distractors) {
//           valoresMCQ.add(ele.value);
//         }
//         for (PairLang ele in widget.task.correctMCQ) {
//           valoresMCQ.add(ele.value);
//         }
//         valoresMCQ.shuffle();
//         _selectMCQR = valoresMCQ.first;
//       }
//       texto = '';
//       answer.labelPoi = widget.poi.labelLang(MyApp.currentLang) ??
//           widget.poi.labelLang('es') ??
//           widget.poi.labels.first.value;
//       answer.commentTask = widget.task.commentLang(MyApp.currentLang) ??
//           widget.task.commentLang('es') ??
//           widget.task.comments.first.value;
//     } else {
//       answer = widget.answer!;
//       answer.poi = widget.poi;
//       answer.task = widget.task;
//       switch (answer.answerType) {
//         case AnswerType.mcq:
//         case AnswerType.multiplePhotos:
//         case AnswerType.noAnswer:
//         case AnswerType.photo:
//         case AnswerType.tf:
//         case AnswerType.video:
//           if (answer.hasAnswer && answer.hasExtraText) {
//             texto = answer.answer['extraText'];
//           } else {
//             texto = '';
//           }
//           break;
//         case AnswerType.multiplePhotosText:
//         case AnswerType.photoText:
//         case AnswerType.text:
//         case AnswerType.videoText:
//           if (answer.hasAnswer) {
//             texto = answer.answer['answer'];
//           } else {
//             texto = '';
//           }
//           break;
//         default:
//           texto = '';
//       }
//     }
//     super.initState();
//   }

//   @override
//   void dispose() {
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: CustomScrollView(
//         slivers: [
//           SliverAppBar(
//             title: Text(
//               widget.vistaPrevia
//                   ? AppLocalizations.of(context)!.vistaPrevia
//                   : widget.task.hasLabel
//                       ? widget.task.labelLang(MyApp.currentLang) ??
//                           widget.task.labelLang('es') ??
//                           widget.task.labels.first.value
//                       : AppLocalizations.of(context)!.realizaTarea,
//               overflow: TextOverflow.ellipsis,
//               maxLines: 2,
//             ),
//           ),
//           widgetInfoTask(),
//           widgetSolveTask(),
//           widgetButtons(),
//         ],
//       ),
//     );
//   }

//   Widget widgetInfoTask() {
//     List<Widget> lista = [
//       HtmlWidget(
//         widget.task.commentLang(MyApp.currentLang) ??
//             widget.task.commentLang('es') ??
//             widget.task.comments.first.value,
//         factoryBuilder: () => MyWidgetFactory(),
//         textStyle: Theme.of(context).textTheme.titleMedium,
//       )
//     ];
//     return SliverPadding(
//       padding: const EdgeInsets.only(top: 40, bottom: 20, left: 10, right: 10),
//       sliver: SliverList(
//         delegate: SliverChildBuilderDelegate(
//           (context, index) => Center(
//             child: Container(
//               constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
//               child: lista.elementAt(index),
//             ),
//           ),
//           childCount: lista.length,
//         ),
//       ),
//     );
//   }

//   Widget widgetSolveTask() {
//     List<Widget> lista = [];
//     AppLocalizations? appLoca = AppLocalizations.of(context);
//     ThemeData td = Theme.of(context);
//     Widget cuadrotexto = Form(
//       key: _thisKey,
//       child: TextFormField(
//         maxLines: textoObligatorio ? 5 : 2,
//         initialValue: texto,
//         decoration: InputDecoration(
//             border: const OutlineInputBorder(),
//             labelText: textoObligatorio
//                 ? appLoca!.respondePreguntaTextualLabel
//                 : appLoca!.notasOpcionalesLabel,
//             hintText: textoObligatorio
//                 ? appLoca.respondePreguntaTextual
//                 : appLoca.notasOpcionales,
//             hintMaxLines: 2,
//             hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
//         textCapitalization: TextCapitalization.sentences,
//         keyboardType: TextInputType.text,
//         validator: (value) {
//           if (value != null) {
//             if (textoObligatorio) {
//               if (value.trim().isNotEmpty) {
//                 texto = value.trim();
//                 return null;
//               } else {
//                 return appLoca.respondePreguntaTextual;
//               }
//             } else {
//               texto = value.trim();
//               return null;
//             }
//           } else {
//             return appLoca.respondePreguntaTextual;
//           }
//         },
//       ),
//     );

//     switch (widget.task.aT) {
//       case AnswerType.mcq:
//         List<Widget> widgetsMCQ = [];
//         if (widget.task.singleSelection) {
//           for (int i = 0, tama = valoresMCQ.length; i < tama; i++) {
//             String valor = valoresMCQ[i];
//             bool falsa = widget.task.correctMCQ
//                     .indexWhere((PairLang element) => element.value == valor) ==
//                 -1;
//             widgetsMCQ.add(
//               Container(
//                 constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
//                 child: Padding(
//                   padding: const EdgeInsets.only(bottom: 2),
//                   child: RadioListTile<String>(
//                     tileColor: _guardado
//                         ? falsa
//                             ? td.colorScheme.error
//                             : td.colorScheme.primary
//                         : null,
//                     title: Text(
//                       valor,
//                       style: _guardado
//                           ? td.textTheme.bodyLarge!.copyWith(
//                               color: falsa
//                                   ? td.colorScheme.onError
//                                   : td.colorScheme.onPrimary,
//                             )
//                           : td.textTheme.bodyLarge,
//                     ),
//                     value: valor,
//                     groupValue: _selectMCQR,
//                     onChanged: !_guardado
//                         ? (String? v) {
//                             setState(() {
//                               _selectMCQR = v!;
//                             });
//                           }
//                         : null,
//                   ),
//                 ),
//               ),
//             );
//           }
//         } else {
//           for (int i = 0, tama = valoresMCQ.length; i < tama; i++) {
//             String valor = valoresMCQ[i];
//             bool falsa = widget.task.correctMCQ
//                     .indexWhere((PairLang element) => element.value == valor) ==
//                 -1;
//             widgetsMCQ.add(
//               Container(
//                 constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
//                 child: Padding(
//                   padding: const EdgeInsets.only(bottom: 2),
//                   child: CheckboxListTile(
//                     tileColor: _guardado
//                         ? falsa
//                             ? td.colorScheme.error
//                             : td.colorScheme.primary
//                         : null,
//                     value: _selectMCQ[i],
//                     title: Text(
//                       valor,
//                       style: _guardado
//                           ? td.textTheme.bodyLarge!.copyWith(
//                               color: falsa
//                                   ? td.colorScheme.onError
//                                   : td.colorScheme.onPrimary,
//                             )
//                           : td.textTheme.bodyLarge,
//                     ),
//                     onChanged: (value) => setState(() {
//                       _selectMCQ[i] = !_selectMCQ[i];
//                     }),
//                     enabled: !_guardado,
//                   ),
//                 ),
//               ),
//             );
//           }
//         }
//         lista.add(
//           Form(
//             key: _thisKeyMCQ,
//             child: Column(mainAxisSize: MainAxisSize.min, children: widgetsMCQ),
//           ),
//         );
//         break;
//       case AnswerType.multiplePhotos:
//       case AnswerType.photo:
//       case AnswerType.multiplePhotosText:
//       case AnswerType.photoText:
//         //Visor de fotos
//         break;
//       case AnswerType.tf:
//         bool? rC = widget.task.hasCorrectTF ? widget.task.correctTF : null;
//         Widget extra = Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
//               child: Padding(
//                 padding: const EdgeInsets.only(bottom: 2),
//                 child: RadioListTile<bool>(
//                     tileColor: _guardado
//                         ? widget.task.hasCorrectTF
//                             ? !rC!
//                                 ? td.colorScheme.error
//                                 : td.colorScheme.primary
//                             : null
//                         : null,
//                     title: Text(
//                       appLoca.rbVFVNTVLabel,
//                       style: _guardado
//                           ? widget.task.hasCorrectTF
//                               ? td.textTheme.bodyLarge!.copyWith(
//                                   color: !rC!
//                                       ? td.colorScheme.onError
//                                       : td.colorScheme.onPrimary,
//                                 )
//                               : td.textTheme.bodyLarge
//                           : td.textTheme.bodyLarge,
//                     ),
//                     value: true,
//                     groupValue: _selectTF,
//                     onChanged: (bool? v) {
//                       setState(() => _selectTF = v!);
//                     }),
//               ),
//             ),
//             Container(
//               constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
//               child: RadioListTile<bool>(
//                   tileColor: _guardado
//                       ? widget.task.hasCorrectTF
//                           ? rC!
//                               ? td.colorScheme.error
//                               : td.colorScheme.primary
//                           : null
//                       : null,
//                   title: Text(
//                     appLoca.rbVFFNTLabel,
//                     style: _guardado
//                         ? widget.task.hasCorrectTF
//                             ? td.textTheme.bodyLarge!.copyWith(
//                                 color: rC!
//                                     ? td.colorScheme.onError
//                                     : td.colorScheme.onPrimary,
//                               )
//                             : td.textTheme.bodyLarge
//                         : td.textTheme.bodyLarge,
//                   ),
//                   value: false,
//                   groupValue: _selectTF,
//                   onChanged: (bool? v) {
//                     setState(() => _selectTF = v!);
//                   }),
//             ),
//             const SizedBox(
//               height: 10,
//             )
//           ],
//         );
//         lista.add(extra);
//         break;
//       case AnswerType.video:
//       case AnswerType.videoText:
//         //Visor de vídeo
//         break;
//       default:
//     }

//     lista.add(cuadrotexto);

//     return SliverPadding(
//       padding: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
//       sliver: SliverList(
//         delegate: SliverChildBuilderDelegate(
//           (context, index) => Center(
//             child: Container(
//               constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
//               child: lista.elementAt(index),
//             ),
//           ),
//           childCount: lista.length,
//         ),
//       ),
//     );
//   }

//   Widget widgetButtons() {
//     ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
//     AppLocalizations? appLoca = AppLocalizations.of(context);
//     List<Widget> botones = [];
//     switch (widget.task.aT) {
//       case AnswerType.multiplePhotos:
//       case AnswerType.photo:
//       case AnswerType.multiplePhotosText:
//       case AnswerType.photoText:
//       case AnswerType.video:
//       case AnswerType.videoText:
//         botones.add(Padding(
//           padding: const EdgeInsets.only(right: 10),
//           child: OutlinedButton.icon(
//             onPressed: null,
//             //  () async {
//             //   // List<CameraDescription> cameras = await availableCameras();
//             //   // await Navigator.push(
//             //   //     context,
//             //   //     MaterialPageRoute<Task>(
//             //   //         builder: (BuildContext context) {
//             //   //           return TakePhoto(cameras.first);
//             //   //         },
//             //   //         fullscreenDialog: true));
//             //   await availableCameras()
//             //       .then((cameras) async => await Navigator.push(
//             //           context,
//             //           MaterialPageRoute<Task>(
//             //               builder: (BuildContext context) {
//             //                 return TakePhoto(cameras.first);
//             //               },
//             //               fullscreenDialog: true)));
//             // },
//             icon: const Icon(Icons.camera_alt),
//             label: Text(appLoca!.abrirCamara),
//           ),
//         ));
//         break;
//       default:
//     }
//     botones.add(FilledButton.icon(
//       onPressed: widget.vistaPrevia
//           ? null
//           : _guardado
//               ? () {
//                   switch (answer.answerType) {
//                     case AnswerType.mcq:
//                     case AnswerType.tf:
//                       Navigator.pop(context);
//                       break;
//                     default:
//                   }
//                 }
//               : () async {
//                   if (_thisKey.currentState!.validate()) {
//                     try {
//                       int now = DateTime.now().millisecondsSinceEpoch;
//                       answer.time2Complete = now - _startTime;
//                       answer.timestamp = now;
//                       switch (answer.answerType) {
//                         case AnswerType.mcq:
//                           String answ = "";
//                           if (widget.task.singleSelection) {
//                             answ = _selectMCQR;
//                           } else {
//                             List<String> a = [];
//                             for (int i = 0, tama = _selectMCQ.length;
//                                 i < tama;
//                                 i++) {
//                               if (_selectMCQ[i]) {
//                                 a.add(valoresMCQ[i]);
//                               }
//                             }
//                             answ = a.toString();
//                           }
//                           if (texto.trim().isNotEmpty) {
//                             answer.answer = {
//                               'answer': answ,
//                               'timestamp':
//                                   DateTime.now().millisecondsSinceEpoch,
//                               'extraText': texto.trim()
//                             };
//                           } else {
//                             answer.answer = answ;
//                           }
//                           Auxiliar.userCHEST.answers.add(answer);
//                           setState(() => _guardado = true);
//                           break;
//                         case AnswerType.multiplePhotos:
//                           break;
//                         case AnswerType.multiplePhotosText:
//                           break;
//                         case AnswerType.noAnswer:
//                           break;
//                         case AnswerType.photo:
//                           break;
//                         case AnswerType.photoText:
//                           break;
//                         case AnswerType.text:
//                           answer.answer = texto;
//                           break;
//                         case AnswerType.tf:
//                           if (texto.trim().isNotEmpty) {
//                             answer.answer = {
//                               'answer': _selectTF,
//                               'timestamp':
//                                   DateTime.now().millisecondsSinceEpoch,
//                               'extraText': texto.trim()
//                             };
//                           } else {
//                             answer.answer = _selectTF;
//                           }
//                           Auxiliar.userCHEST.answers.add(answer);
//                           setState(() => _guardado = true);
//                           break;
//                         case AnswerType.video:
//                           break;
//                         case AnswerType.videoText:
//                           break;
//                         default:
//                       }
//                       http
//                           .post(Queries().newAnswer(),
//                               headers: {
//                                 'Content-Type': 'application/json',
//                                 // 'Authorization': Template('Bearer {{{token}}}')
//                                 //     .renderString({
//                                 //   'token': await FirebaseAuth.instance.currentUser!
//                                 //       .getIdToken()
//                                 // })
//                               },
//                               body: json.encode(answer.answer2CHESTServer()))
//                           .then((response) {
//                         switch (response.statusCode) {
//                           case 201:
//                             String idAnswer = response.headers['location']!;
//                             answer.id = idAnswer;
//                             break;
//                           default:
//                         }
//                       }).onError((error, stackTrace) {
//                         debugPrint(error.toString());
//                       });
//                     } catch (error) {
//                       smState.clearSnackBars();
//                       smState.showSnackBar(SnackBar(
//                         content: Text(error.toString()),
//                       ));
//                     }
//                     smState.clearSnackBars();
//                     smState.showSnackBar(SnackBar(
//                       content: Text(appLoca!.respuestaGuardada),
//                       action: kIsWeb
//                           ? SnackBarAction(
//                               label: appLoca.descargar,
//                               onPressed: () {
//                                 AuxiliarFunctions.downloadAnswerWeb(
//                                   answer,
//                                   titlePage: appLoca.tareaCompletadaCHEST,
//                                 );
//                               })
//                           : null,
//                     ));
//                     if (!Config.development) {
//                       await FirebaseAnalytics.instance.logEvent(
//                         name: "taskCompleted",
//                         parameters: {
//                           "poi": widget.poi.shortId,
//                           "iri": widget.task.id.split('/').last
//                         },
//                       );
//                     }
//                   }
//                 },
//       label: _guardado ? Text(appLoca!.finRevision) : Text(appLoca!.guardar),
//       icon:
//           _guardado ? const Icon(Icons.navigate_next) : const Icon(Icons.save),
//     ));
//     // TODO REMOVE
//     switch (widget.task.aT) {
//       case AnswerType.multiplePhotos:
//       case AnswerType.multiplePhotosText:
//       case AnswerType.photo:
//       case AnswerType.photoText:
//       case AnswerType.video:
//       case AnswerType.videoText:
//         botones = [
//           Padding(
//             padding: const EdgeInsets.only(right: 10),
//             child: OutlinedButton.icon(
//               onPressed: null,
//               icon: const Icon(Icons.camera_alt),
//               label: Text(appLoca.abrirCamara),
//             ),
//           ),
//           FilledButton.icon(
//             onPressed: null,
//             label: Text(appLoca.guardar),
//             icon: const Icon(Icons.save),
//           ),
//         ];
//         break;
//       default:
//     }
//     List<Widget> lista = [
//       Row(
//         mainAxisSize: MainAxisSize.min,
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: botones,
//       )
//     ];
//     return SliverPadding(
//       padding: const EdgeInsets.only(bottom: 20, left: 10, right: 10),
//       sliver: SliverList(
//         delegate: SliverChildBuilderDelegate(
//           (context, index) => Center(
//             child: Container(
//               constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
//               child: lista.elementAt(index),
//             ),
//           ),
//           childCount: lista.length,
//         ),
//       ),
//     );
//   }
// }

class TakePhoto extends StatefulWidget {
  final CameraDescription cameraDescription;
  const TakePhoto(this.cameraDescription, {super.key});
  @override
  State<StatefulWidget> createState() => _TakePhoto();
}

class _TakePhoto extends State<TakePhoto> {
  late CameraController _cameraController;
  late Future<void> _cameraFuture;
  @override
  void initState() {
    _cameraController =
        CameraController(widget.cameraDescription, ResolutionPreset.medium);
    _cameraFuture = _cameraController.initialize();
    super.initState();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: FutureBuilder<void>(
      future: _cameraFuture,
      builder: ((context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return CameraPreview(_cameraController);
        } else {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
      }),
    ));
  }
}

class FormTask extends StatefulWidget {
  final Task task;
  const FormTask(this.task, {super.key});
  @override
  State<StatefulWidget> createState() => _FormTask();
}

class _FormTask extends State<FormTask> {
  late GlobalKey<FormState> _thisKey;
  late String? drop;
  List<PairLang> distractors = [];
  AnswerType? answerType;
  late bool _rgtf,
      _spaFis,
      _spaVir,
      errorEspacios,
      _mcqmu,
      focusQuillEditorController,
      errorTaskStatement;
  List<Widget> widgetDistractors = [], widgetCorrects = [];
  late String textoTask;
  late QuillEditorController quillEditorController;
  late List<ToolBarStyle> toolbarElements;

  @override
  void initState() {
    _thisKey = GlobalKey<FormState>();
    drop = null;
    _rgtf = widget.task.hasCorrectTF
        ? widget.task.correctTF
        : Random.secure().nextBool();
    _mcqmu = Random.secure().nextBool();
    if (widget.task.distractors.isNotEmpty) {
      distractors.addAll(widget.task.distractors);
    }
    for (var element in distractors) {
      widget.task.removeDistractor(element);
    }
    _spaFis = widget.task.spaces.isEmpty
        ? false
        : widget.task.spaces.contains(Space.physical);
    _spaVir = widget.task.spaces.isEmpty
        ? false
        : widget.task.spaces.contains(Space.virtual);
    errorEspacios = false;
    // htmlEditorController = HtmlEditorController();
    toolbarElements = Auxiliar.getToolbarElements();
    quillEditorController = QuillEditorController();
    focusQuillEditorController = false;
    quillEditorController.onEditorLoaded(() {
      quillEditorController.unFocus();
      quillEditorController.setText('');
    });
    errorTaskStatement = false;
    textoTask = '';
    super.initState();
  }

  @override
  void dispose() {
    quillEditorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    const EdgeInsets margenes = EdgeInsets.only(top: 15, right: 10, left: 10);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.nTask),
      ),
      body: Form(
        key: _thisKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 50, right: 10, left: 10),
                child: widgetComun(size),
              ),
              Padding(
                padding: margenes,
                child: widgetVariable(size),
              ),
              Padding(
                padding: margenes,
                child: widgetSpaces(),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                child: buttonAddTask(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget widgetComun(Size size) {
    ThemeData td = Theme.of(context);
    ColorScheme cS = td.colorScheme;
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<String?> selects = [
      null,
      AnswerType.mcq.name,
      AnswerType.multiplePhotos.name,
      AnswerType.multiplePhotosText.name,
      AnswerType.noAnswer.name,
      AnswerType.photo.name,
      AnswerType.photoText.name,
      AnswerType.text.name,
      AnswerType.tf.name,
      AnswerType.video.name,
      AnswerType.videoText.name
    ];
    Map<AnswerType, String> atString = {
      AnswerType.mcq: appLoca!.selectTipoRespuestaMcq,
      AnswerType.multiplePhotos: appLoca.selectTipoRespuestaMultiPhotos,
      AnswerType.multiplePhotosText: appLoca.selectTipoRespuestaMultiPhotosText,
      AnswerType.noAnswer: appLoca.selectTipoRespuestaSR,
      AnswerType.photo: appLoca.selectTipoRespuestaPhoto,
      AnswerType.photoText: appLoca.selectTipoRespuestaPhotoText,
      AnswerType.text: appLoca.selectTipoRespuestaTexto,
      AnswerType.tf: appLoca.selectTipoRespuestaVF,
      AnswerType.video: appLoca.selectTipoRespuestaVideo,
      AnswerType.videoText: appLoca.selectTipoRespuestaVideoText
    };

    List<Widget> listaForm = [
      TextFormField(
        maxLines: 1,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: appLoca.tituloNTLabel,
          hintText: appLoca.tituloNT,
          hintMaxLines: 1,
          hintStyle: const TextStyle(overflow: TextOverflow.ellipsis),
        ),
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.text,
        initialValue: widget.task.hasLabel
            ? widget.task.labels.isEmpty
                ? ''
                : widget.task.labelLang(MyApp.currentLang) ??
                    widget.task.labelLang('es') ??
                    widget.task.labels.first.value
            : '',
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return appLoca.tituloNT;
          } else {
            widget.task
                .addLabel({'lang': MyApp.currentLang, 'value': value.trim()});
            return null;
          }
        },
      ),
      Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          border: Border.fromBorderSide(
            BorderSide(
                color: errorTaskStatement
                    ? cS.error
                    : focusQuillEditorController
                        ? cS.primary
                        : td.disabledColor,
                width: focusQuillEditorController ? 2 : 1),
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
                appLoca.textAsociadoNTLabel,
                style: td.textTheme.bodySmall!.copyWith(
                    color: errorTaskStatement
                        ? cS.error
                        : focusQuillEditorController
                            ? cS.primary
                            : td.disabledColor),
              ),
            ),
            QuillHtmlEditor(
              controller: quillEditorController,
              hintText: '',
              minHeight: size.height * 0.2,
              isEnabled: true,
              ensureVisible: false,
              autoFocus: false,
              backgroundColor: cS.surface,
              textStyle: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: cS.onSurface),
              padding: const EdgeInsets.all(5),
              onFocusChanged: (focus) =>
                  setState(() => focusQuillEditorController = focus),
              onTextChanged: (text) async {
                textoTask = text;
              },
            ),
            ToolBar(
              controller: quillEditorController,
              crossAxisAlignment: WrapCrossAlignment.start,
              alignment: WrapAlignment.spaceEvenly,
              direction: Axis.horizontal,
              toolBarColor: cS.primaryContainer,
              iconColor: cS.onPrimaryContainer,
              activeIconColor: cS.tertiary,
              toolBarConfig: toolbarElements,
              customButtons: [
                InkWell(
                  focusColor: cS.tertiary,
                  onTap: () async {
                    quillEditorController
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
                            AppLocalizations.of(context)!.seleccionaTexto,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                                    color:
                                        Theme.of(context).colorScheme.onError),
                          ),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ));
                      }
                    });
                  },
                  child: Icon(
                    Icons.link,
                    color: cS.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            Visibility(
              visible: errorTaskStatement,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  appLoca.textoAsociadoNT,
                  style: td.textTheme.bodySmall!.copyWith(
                    color: cS.error,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      DropdownButtonFormField(
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: appLoca.selectTipoRespuestaLabel,
          hintText: appLoca.selectTipoRespuestaEnunciado,
        ),
        value: drop,
        onChanged: (String? nv) {
          setState(() {
            drop = nv;
            setState(() {
              if (drop != null) {
                for (var value in AnswerType.values) {
                  if (drop == value.name) {
                    answerType = value;
                    break;
                  }
                }
              } else {
                answerType = null;
              }
            });
          });
        },
        items: selects.map<DropdownMenuItem<String>>((String? value) {
          late AnswerType aTTextUser;
          if (value != null) {
            for (var v in AnswerType.values) {
              if (value == v.name) {
                aTTextUser = v;
                break;
              }
            }
          }
          return DropdownMenuItem(
            value: value,
            child: value == null ? const Text('') : Text(atString[aTTextUser]!),
          );
        }).toList(),
        validator: (v) {
          if (v == null) {
            return appLoca.selectTipoRespuestaEnunciado;
          } else {
            for (var at in AnswerType.values) {
              if (at.name == v) {
                widget.task.aT = at;
                break;
              }
            }
            return null;
          }
        },
      ),
    ];
    return ListView.builder(
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
            child: listaForm.elementAt(index),
          ),
        ),
      ),
      itemCount: listaForm.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  Widget _showURLDialog() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
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
              appLoca!.agregaEnlace,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              maxLines: 1,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: "${appLoca.enlace}*",
                // hintText: appLoca.hintEnlace,
                hintText: 'https://example.com',
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
                      quillEditorController
                          .getSelectedText()
                          .then((textoSeleccionado) async {
                        if (textoSeleccionado != null &&
                            textoSeleccionado is String &&
                            textoSeleccionado.isNotEmpty) {
                          quillEditorController.setFormat(
                              format: 'link', value: uri);
                          Navigator.of(context).pop();
                          setState(() {
                            focusQuillEditorController = true;
                          });
                          quillEditorController.focus();
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

  Widget widgetVariable(Size size) {
    List<Widget> wV;
    if (answerType != null) {
      switch (answerType) {
        case AnswerType.mcq:
          wV = [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(AppLocalizations.of(context)!.elEstudianteVaAPoder),
            ),
            RadioListTile<bool>(
                contentPadding: const EdgeInsets.all(0),
                title: Text(AppLocalizations.of(context)!.unaComoVerdadera),
                value: false,
                groupValue: _mcqmu,
                onChanged: (bool? v) {
                  setState(() => _mcqmu = v!);
                }),
            RadioListTile<bool>(
                contentPadding: const EdgeInsets.all(0),
                title: Text(AppLocalizations.of(context)!.variasComoVerdaderas),
                // title: Text(AppLocalizations.of(context)!.rbVFVNTVLabel),
                value: true,
                groupValue: _mcqmu,
                onChanged: (bool? v) {
                  setState(() => _mcqmu = v!);
                }),
            const SizedBox(height: 15),
            TextFormField(
                maxLines: 1,
                decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: AppLocalizations.of(context)!.rVMCQLabel,
                    hintText: AppLocalizations.of(context)!.rVMCQ,
                    hintMaxLines: 1,
                    hintStyle:
                        const TextStyle(overflow: TextOverflow.ellipsis)),
                textCapitalization: TextCapitalization.sentences,
                initialValue:
                    '', //widget.task.hasCorrectMCQ ? widget.task.correctMCQ : '', //TODO
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return AppLocalizations.of(context)!.rVMCQ;
                  }
                  widget.task.addCorrectMCQ(v.trim(), lang: MyApp.currentLang);
                  return null;
                }),
            Column(children: widgetCorrects),
            TextButton(
                onPressed: _mcqmu
                    ? () async {
                        setState(() {
                          Key randomKey = UniqueKey();
                          widgetCorrects.add(
                            Column(
                              key: randomKey,
                              children: [
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      constraints: BoxConstraints(
                                          maxWidth: min(
                                              MediaQuery.of(context)
                                                      .size
                                                      .width -
                                                  80,
                                              Auxiliar.maxWidth - 80)),
                                      child: TextFormField(
                                          maxLines: 1,
                                          decoration: InputDecoration(
                                            border: const OutlineInputBorder(),
                                            labelText:
                                                AppLocalizations.of(context)!
                                                    .rVMCQLabel,
                                            hintText:
                                                AppLocalizations.of(context)!
                                                    .rVMCQ,
                                            hintMaxLines: 1,
                                            hintStyle: const TextStyle(
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ),
                                          textCapitalization:
                                              TextCapitalization.sentences,
                                          initialValue: '',
                                          validator: (v) {
                                            if (v == null || v.trim().isEmpty) {
                                              return AppLocalizations.of(
                                                      context)!
                                                  .rVMCQ;
                                            }
                                            widget.task.addCorrectMCQ(v.trim(),
                                                lang: MyApp.currentLang);
                                            return null;
                                          }),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      onPressed: () async {
                                        setState(() {
                                          widgetCorrects.removeWhere(
                                              (Widget element) =>
                                                  element.key == randomKey);
                                        });
                                      },
                                      icon: const Icon(Icons.remove_circle),
                                    )
                                  ],
                                )
                              ],
                            ),
                          );
                        });
                      }
                    : null,
                child: Text(AppLocalizations.of(context)!.addrV)),
            const SizedBox(height: 15),
            TextFormField(
                maxLines: 1,
                decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: AppLocalizations.of(context)!.rDMCQLable,
                    hintText: AppLocalizations.of(context)!.rDMCQ,
                    hintMaxLines: 1,
                    hintStyle:
                        const TextStyle(overflow: TextOverflow.ellipsis)),
                textCapitalization: TextCapitalization.sentences,
                initialValue: '',
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return AppLocalizations.of(context)!.rDMCQ;
                  }
                  // widget.task.distractors.add(v.trim());
                  widget.task
                      .addDistractor(PairLang(MyApp.currentLang, v.trim()));
                  return null;
                }),
            Column(children: widgetDistractors),
            TextButton(
                onPressed: () async {
                  setState(() {
                    Key randomKey = UniqueKey();
                    widgetDistractors.add(
                      Column(
                        key: randomKey,
                        children: [
                          const SizedBox(
                            height: 10,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                constraints: BoxConstraints(
                                    maxWidth: min(
                                        MediaQuery.of(context).size.width - 80,
                                        Auxiliar.maxWidth - 80)),
                                child: TextFormField(
                                    maxLines: 1,
                                    decoration: InputDecoration(
                                      border: const OutlineInputBorder(),
                                      labelText: AppLocalizations.of(context)!
                                          .rDMCQLable,
                                      hintText:
                                          AppLocalizations.of(context)!.rDMCQ,
                                      hintMaxLines: 1,
                                      hintStyle: const TextStyle(
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    initialValue: '',
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return AppLocalizations.of(context)!
                                            .rDMCQ;
                                      }
                                      widget.task.addDistractor(PairLang(
                                          MyApp.currentLang, v.trim()));
                                      return null;
                                    }),
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              IconButton(
                                  onPressed: () async {
                                    setState(() {
                                      widgetDistractors.removeWhere(
                                          (Widget element) =>
                                              element.key == randomKey);
                                    });
                                  },
                                  icon: const Icon(Icons.remove_circle))
                            ],
                          )
                        ],
                      ),
                    );
                  });
                },
                child: Text(AppLocalizations.of(context)!.addrD)),
          ];
          break;
        case AnswerType.tf:
          widget.task.correctTF = _rgtf;
          wV = [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppLocalizations.of(context)!.verdaderoNTDivLabel,
              ),
            ),
            RadioListTile<bool>(
                contentPadding: const EdgeInsets.all(0),
                title: Text(AppLocalizations.of(context)!.rbVFVNTVLabel),
                value: true,
                groupValue: _rgtf,
                onChanged: (bool? v) {
                  setState(() => _rgtf = v!);
                  widget.task.correctTF = true;
                }),
            RadioListTile<bool>(
                contentPadding: const EdgeInsets.all(0),
                title: Text(AppLocalizations.of(context)!.rbVFFNTLabel),
                value: false,
                groupValue: _rgtf,
                onChanged: (bool? v) {
                  setState(() => _rgtf = v!);
                  widget.task.correctTF = false;
                })
          ];
          break;
        default:
          wV = [Container()];
      }
    } else {
      wV = [Container()];
    }
    return ListView.builder(
      itemBuilder: (context, index) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          child: wV.elementAt(index),
        ),
      ),
      itemCount: wV.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  widgetSpaces() {
    List<Widget> lstW = [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          AppLocalizations.of(context)!.cbEspacioDivLabel,
        ),
      ),
      Visibility(
        visible: errorEspacios,
        child: const SizedBox(height: 20),
      ),
      Visibility(
        visible: errorEspacios,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            AppLocalizations.of(context)!.cbEspacioDivError,
            style: Theme.of(context)
                .textTheme
                .bodySmall!
                .copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ),
      const SizedBox(height: 20),
      CheckboxListTile(
          contentPadding: const EdgeInsets.all(0),
          value: _spaFis,
          onChanged: (v) {
            setState(() {
              _spaFis = v!;
            });
          },
          title: Text(AppLocalizations.of(context)!.rbEspacio1Label)),
      CheckboxListTile(
          contentPadding: const EdgeInsets.all(0),
          value: _spaVir,
          onChanged: (v) {
            setState(() {
              _spaVir = v!;
            });
          },
          title: Text(AppLocalizations.of(context)!.rbEspacio2Label)),
    ];
    return ListView.builder(
      itemBuilder: (context, index) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          child: lstW.elementAt(index),
        ),
      ),
      itemCount: lstW.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  Widget buttonAddTask() {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () async {
                  bool noError = _thisKey.currentState!.validate();
                  setState(() {
                    errorTaskStatement = textoTask.trim().isEmpty;
                    errorEspacios = !(_spaVir || _spaFis);
                  });
                  if (noError && !errorEspacios && !errorTaskStatement) {
                    // if (_spaFis || _spaVir) {
                    // setState(() => errorEspacios = false);
                    textoTask = Auxiliar.quill2Html(textoTask);
                    quillEditorController.setText(textoTask);
                    widget.task.addComment(
                        {'lang': MyApp.currentLang, 'value': textoTask});
                    List<String> inSpace = [];
                    if (_spaFis) {
                      inSpace.add(Space.physical.name);
                    }
                    if (_spaVir) {
                      inSpace.add(Space.virtual.name);
                    }
                    Map<String, dynamic> bodyRequest = {
                      "aT": widget.task.aT.name,
                      "inSpace": inSpace,
                      "label": widget.task.labels2List(),
                      "comment": widget.task.comments2List(),
                      "hasFeature": widget.task.idFeature
                    };
                    switch (widget.task.aT) {
                      case AnswerType.mcq:
                        if (widget.task.distractors.isNotEmpty) {
                          if (widget.task.hasCorrectMCQ) {
                            if (_mcqmu) {
                              bodyRequest["correct"] =
                                  widget.task.correctsMCQ2List();
                            } else {
                              bodyRequest["correct"] =
                                  widget.task.correctsMCQ2List().first;
                            }
                            bodyRequest["singleSelection"] = !_mcqmu;
                          }
                          bodyRequest["distractors"] =
                              widget.task.distractorsMCQ2List();
                        }
                        break;
                      case AnswerType.tf:
                        if (widget.task.hasCorrectTF) {
                          bodyRequest["correct"] = widget.task.correctTF;
                        }
                        break;
                      default:
                    }
                    http
                        .post(
                      // Uri.parse(Template('{{{addr}}}/tasks')
                      //     .renderString({'addr': Config.addServer})),
                      Queries()
                          .newTask(Auxiliar.id2shortId(widget.task.idFeature)!),
                      headers: {
                        'Content-Type': 'application/json',
                        'Authorization':
                            Template('Bearer {{{token}}}').renderString({
                          'token': await FirebaseAuth.instance.currentUser!
                              .getIdToken(),
                        })
                      },
                      body: json.encode(bodyRequest),
                    )
                        .then((response) async {
                      ScaffoldMessengerState smState =
                          ScaffoldMessenger.of(context);
                      switch (response.statusCode) {
                        case 201:
                        case 202:
                          widget.task.id = response.headers['location']!;
                          if (!Config.development) {
                            await FirebaseAnalytics.instance.logEvent(
                              name: "newTask",
                              parameters: {
                                "iri": widget.task.id.split('/').last
                              },
                            ).then(
                              (value) {
                                widget.task.id = response.headers['location']!;
                                Navigator.pop(context, widget.task);
                                smState.clearSnackBars();
                                smState.showSnackBar(SnackBar(
                                    content: Text(AppLocalizations.of(context)!
                                        .infoRegistrada)));
                              },
                            ).onError((error, stackTrace) {
                              debugPrint(error.toString());
                              widget.task.id = response.headers['location']!;
                              Navigator.pop(context, widget.task);
                              smState.clearSnackBars();
                              smState.showSnackBar(SnackBar(
                                  content: Text(AppLocalizations.of(context)!
                                      .infoRegistrada)));
                            });
                          } else {
                            //Devuelvo a la pantalla anterior la tarea que se acaba de crear para reprsentarla
                            widget.task.id = response.headers['location']!;
                            Navigator.pop(context, widget.task);
                            smState.clearSnackBars();
                            smState.showSnackBar(SnackBar(
                                content: Text(AppLocalizations.of(context)!
                                    .infoRegistrada)));
                          }
                          break;
                        default:
                          ThemeData td = Theme.of(context);
                          smState.clearSnackBars();
                          smState.showSnackBar(SnackBar(
                            backgroundColor: td.colorScheme.error,
                            content: Text(
                              response.statusCode.toString(),
                              style: td.textTheme.bodyMedium!.copyWith(
                                color: td.colorScheme.onError,
                              ),
                            ),
                          ));
                      }
                    }).onError((error, stackTrace) {
                      //print(error.toString());
                    });
                    // }
                    // else {
                    //   setState(() => errorEspacios = true);
                    // }
                  }
                  // else {
                  //   if (_spaFis || _spaVir) {
                  //     setState(() => errorEspacios = false);
                  //   } else {
                  //     setState(() => errorEspacios = true);
                  //   }
                  // }
                },
                label: Text(AppLocalizations.of(context)!.enviarTask),
                icon: const Icon(Icons.publish),
              ),
            ),
          ),
        ),
        const SizedBox(height: 500),
      ],
    );
  }
}
