import 'dart:convert';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:chest/helpers/pair.dart';
import 'package:chest/helpers/queries.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/config.dart';
import 'package:chest/helpers/answers.dart';
import 'package:chest/helpers/auxiliar.dart';
import 'package:chest/helpers/pois.dart';
import 'package:chest/helpers/tasks.dart';
import 'package:chest/main.dart';
import 'package:chest/helpers/widget_facto.dart';
import 'package:chest/helpers/mobile_functions.dart'
    if (dart.library.html) 'package:chest/helpers/web_functions.dart';

class COTask extends StatefulWidget {
  final POI poi;
  final Task task;
  final Answer? answer;
  const COTask(this.poi, this.task, {required this.answer, super.key});
  @override
  State<StatefulWidget> createState() => _COTask();
}

class _COTask extends State<COTask> {
  late bool _selectTF, _guardado;
  late List<bool> _selectMCQ;
  late String _selectMCQR;
  late GlobalKey<FormState> _thisKey, _thisKeyMCQ;
  late Answer answer;
  late bool textoObligatorio;
  late String texto;
  late int _startTime;
  List<String> valoresMCQ = [];

  @override
  void initState() {
    _thisKey = GlobalKey<FormState>();
    _thisKeyMCQ = GlobalKey<FormState>();
    _guardado = false;
    _startTime = DateTime.now().millisecondsSinceEpoch;
    switch (widget.task.aT) {
      case AnswerType.mcq:
      case AnswerType.multiplePhotos:
      case AnswerType.photo:
      case AnswerType.noAnswer:
      case AnswerType.tf:
      case AnswerType.video:
        textoObligatorio = false;
        break;
      case AnswerType.multiplePhotosText:
      case AnswerType.photoText:
      case AnswerType.text:
      case AnswerType.videoText:
        textoObligatorio = true;
        break;
      default:
        break;
    }
    if (widget.answer == null) {
      answer =
          Answer.withoutAnswer(widget.poi.id, widget.task.id, widget.task.aT);
      answer.poi = widget.poi;
      answer.task = widget.task;
      if (widget.task.aT == AnswerType.tf) {
        _selectTF = Random.secure().nextBool();
      }
      if (widget.task.aT == AnswerType.mcq) {
        int tama =
            widget.task.distractors.length + widget.task.correctMCQ.length;
        _selectMCQ = widget.task.singleSelection
            ? List<bool>.generate(tama, (index) => index == 0)
            : List<bool>.filled(tama, false);
        for (PairLang ele in widget.task.distractors) {
          valoresMCQ.add(ele.value);
        }
        for (PairLang ele in widget.task.correctMCQ) {
          valoresMCQ.add(ele.value);
        }
        valoresMCQ.shuffle();
        _selectMCQR = valoresMCQ.first;
      }
      texto = '';
      answer.labelPoi = widget.poi.labelLang(MyApp.currentLang) ??
          widget.poi.labelLang('es') ??
          widget.poi.labels.first.value;
      answer.commentTask = widget.task.commentLang(MyApp.currentLang) ??
          widget.task.commentLang('es') ??
          widget.task.comments.first.value;
    } else {
      answer = widget.answer!;
      answer.poi = widget.poi;
      answer.task = widget.task;
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
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.task.hasLabel
              ? widget.task.labelLang(MyApp.currentLang) ??
                  widget.task.labelLang('es') ??
                  widget.task.labels.first.value
              : AppLocalizations.of(context)!.realizaTarea,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        // leading: const BackButton(color: Colors.white),
      ),
      floatingActionButton: widgetFAB(),
      body: SafeArea(
        minimum: const EdgeInsets.all(10),
        child: SingleChildScrollView(
            child: Center(
                child: Column(
          children: [
            wigetInfoTask(),
            const SizedBox(
              height: 20,
            ),
            widgetSolveTask(),
            const SizedBox(
              height: 20,
            ),
            widgetButtons(),
          ],
        ))),
      ),
    );
  }

  wigetInfoTask() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            constraints: const BoxConstraints(maxHeight: Auxiliar.maxWidth),
            child: HtmlWidget(
              widget.task.commentLang(MyApp.currentLang) ??
                  widget.task.commentLang('es') ??
                  widget.task.comments.first.value,
              factoryBuilder: () => MyWidgetFactory(),
              textStyle: Theme.of(context).textTheme.titleMedium,
            ))
      ],
    );
  }

  widgetSolveTask() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    Widget cuadrotexto = Form(
      key: _thisKey,
      child: Container(
        constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
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
      ),
    );

    Widget extra = Container();
    ThemeData td = Theme.of(context);
    switch (widget.task.aT) {
      case AnswerType.mcq:
        List<Widget> widgetsMCQ = [];
        if (widget.task.singleSelection) {
          for (int i = 0, tama = valoresMCQ.length; i < tama; i++) {
            String valor = valoresMCQ[i];
            bool falsa = widget.task.correctMCQ
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
            bool falsa = widget.task.correctMCQ
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
        extra = Form(
          key: _thisKeyMCQ,
          child: Column(mainAxisSize: MainAxisSize.min, children: widgetsMCQ),
        );
        break;
      case AnswerType.multiplePhotos:
      case AnswerType.photo:
      case AnswerType.multiplePhotosText:
      case AnswerType.photoText:
        //Visor de fotos
        break;
      case AnswerType.tf:
        bool rC = widget.task.correctTF;
        extra = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: RadioListTile<bool>(
                    tileColor: _guardado
                        ? !rC
                            ? td.colorScheme.error
                            : td.colorScheme.primary
                        : null,
                    title: Text(
                      appLoca.rbVFVNTVLabel,
                      style: _guardado
                          ? td.textTheme.bodyLarge!.copyWith(
                              color: !rC
                                  ? td.colorScheme.onError
                                  : td.colorScheme.onPrimary,
                            )
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
                      ? rC
                          ? td.colorScheme.error
                          : td.colorScheme.primary
                      : null,
                  title: Text(
                    appLoca.rbVFFNTLabel,
                    style: _guardado
                        ? td.textTheme.bodyLarge!.copyWith(
                            color: rC
                                ? td.colorScheme.onError
                                : td.colorScheme.onPrimary,
                          )
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
        break;
      case AnswerType.video:
      case AnswerType.videoText:
        //Visor de vídeo
        break;
      default:
        break;
    }

    return Column(
      children: [extra, cuadrotexto],
    );
  }

  widgetButtons() {
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    AppLocalizations? appLoca = AppLocalizations.of(context);
    List<Widget> botones = [];
    switch (widget.task.aT) {
      case AnswerType.multiplePhotos:
      case AnswerType.photo:
      case AnswerType.multiplePhotosText:
      case AnswerType.photoText:
      case AnswerType.video:
      case AnswerType.videoText:
        botones.add(Padding(
          padding: const EdgeInsets.only(right: 10),
          child: OutlinedButton.icon(
            onPressed: () async {
              // List<CameraDescription> cameras = await availableCameras();
              // await Navigator.push(
              //     context,
              //     MaterialPageRoute<Task>(
              //         builder: (BuildContext context) {
              //           return TakePhoto(cameras.first);
              //         },
              //         fullscreenDialog: true));
              await availableCameras()
                  .then((cameras) async => await Navigator.push(
                      context,
                      MaterialPageRoute<Task>(
                          builder: (BuildContext context) {
                            return TakePhoto(cameras.first);
                          },
                          fullscreenDialog: true)));
            },
            icon: const Icon(Icons.camera_alt),
            label: Text(appLoca!.abrirCamara),
          ),
        ));
        break;
      default:
    }
    botones.add(FilledButton.icon(
      onPressed: _guardado
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
                      if (widget.task.singleSelection) {
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
                          'timestamp': DateTime.now().millisecondsSinceEpoch,
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
                          'timestamp': DateTime.now().millisecondsSinceEpoch,
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
                      .post(Queries().newAnser(),
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': Template('Bearer {{{token}}}')
                                .renderString({
                              'token': await FirebaseAuth.instance.currentUser!
                                  .getIdToken()
                            })
                          },
                          body: json.encode(answer.answer2CHESTServer()))
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
                      content: Text(
                    error.toString(),
                  )));
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
              }
            },
      label: _guardado ? Text(appLoca!.finRevision) : Text(appLoca!.guardar),
      icon:
          _guardado ? const Icon(Icons.navigate_next) : const Icon(Icons.save),
    ));
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: botones,
    );
  }

  widgetFAB() {
    return null;
  }
}

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
  late bool _rgtf, _spaFis, _spaVir, errorEspacios, _mcqmu;
  List<Widget> widgetDistractors = [], widgetCorrects = [];
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
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                child: widgetComun(),
              ),
              Padding(
                padding: margenes,
                child: widgetVariable(),
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

  Widget widgetComun() {
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
      AnswerType.mcq: AppLocalizations.of(context)!.selectTipoRespuestaMcq,
      AnswerType.multiplePhotos:
          AppLocalizations.of(context)!.selectTipoRespuestaMultiPhotos,
      AnswerType.multiplePhotosText:
          AppLocalizations.of(context)!.selectTipoRespuestaMultiPhotosText,
      AnswerType.noAnswer: AppLocalizations.of(context)!.selectTipoRespuestaSR,
      AnswerType.photo: AppLocalizations.of(context)!.selectTipoRespuestaPhoto,
      AnswerType.photoText:
          AppLocalizations.of(context)!.selectTipoRespuestaPhotoText,
      AnswerType.text: AppLocalizations.of(context)!.selectTipoRespuestaTexto,
      AnswerType.tf: AppLocalizations.of(context)!.selectTipoRespuestaVF,
      AnswerType.video: AppLocalizations.of(context)!.selectTipoRespuestaVideo,
      AnswerType.videoText:
          AppLocalizations.of(context)!.selectTipoRespuestaVideoText
    };

    List<Widget> listaForm = [
      TextFormField(
        maxLines: 1,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: AppLocalizations.of(context)!.tituloNTLabel,
          hintText: AppLocalizations.of(context)!.tituloNT,
          helperText: AppLocalizations.of(context)!.requerido,
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
            return AppLocalizations.of(context)!.tituloNT;
          } else {
            widget.task
                .addLabel({'lang': MyApp.currentLang, 'value': value.trim()});
            return null;
          }
        },
      ),
      TextFormField(
        minLines: 1,
        maxLines: 5,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: AppLocalizations.of(context)!.textAsociadoNTLabel,
            hintText: AppLocalizations.of(context)!.textoAsociadoNT,
            helperText: AppLocalizations.of(context)!.requerido,
            hintMaxLines: 1,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.sentences,
        keyboardType: TextInputType.multiline,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        initialValue: widget.task.comments.isEmpty
            ? ''
            : widget.task.commentLang(MyApp.currentLang) ??
                widget.task.commentLang('es') ??
                widget.task.comments.first.value,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return AppLocalizations.of(context)!.textoAsociadoNT;
          } else {
            widget.task.addComment({'lang': MyApp.currentLang, 'value': value});
            return null;
          }
        },
      ),
      DropdownButtonFormField(
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: AppLocalizations.of(context)!.selectTipoRespuestaLabel,
            hintText:
                AppLocalizations.of(context)!.selectTipoRespuestaEnunciado,
            helperText: AppLocalizations.of(context)!.requerido),
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
            return AppLocalizations.of(context)!.selectTipoRespuestaEnunciado;
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

  Widget widgetVariable() {
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
                  if (_thisKey.currentState!.validate()) {
                    if (_spaFis || _spaVir) {
                      setState(() => errorEspacios = false);
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
                        "hasPoi": widget.task.poi
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
                        Uri.parse(Template('{{{addr}}}/tasks')
                            .renderString({'addr': Config.addServer})),
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
                            if (!Config.debug) {
                              await FirebaseAnalytics.instance.logEvent(
                                name: "newTask",
                                parameters: {
                                  "iri": widget.task.id.split('/').last
                                },
                              ).then(
                                (value) {
                                  widget.task.id =
                                      response.headers['location']!;
                                  Navigator.pop(context, widget.task);
                                  smState.clearSnackBars();
                                  smState.showSnackBar(SnackBar(
                                      content: Text(
                                          AppLocalizations.of(context)!
                                              .infoRegistrada)));
                                },
                              ).onError((error, stackTrace) {
                                print(error);
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
                    } else {
                      setState(() => errorEspacios = true);
                    }
                  } else {
                    if (_spaFis || _spaVir) {
                      setState(() => errorEspacios = false);
                    } else {
                      setState(() => errorEspacios = true);
                    }
                  }
                },
                label: Text(AppLocalizations.of(context)!.enviarTask),
                icon: const Icon(Icons.publish),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
