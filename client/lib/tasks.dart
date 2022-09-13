import 'dart:convert';
import 'dart:math';

import 'package:chest/helpers/widget_facto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'config.dart';
import 'helpers/answers.dart';
import 'helpers/auxiliar.dart';
import 'helpers/pois.dart';
import 'helpers/tasks.dart';
import 'main.dart';

class COTask extends StatefulWidget {
  final POI poi;
  final Task task;
  final Answer? answer;
  const COTask(this.poi, this.task, {required this.answer, super.key});
  @override
  State<StatefulWidget> createState() => _COTask();
}

class _COTask extends State<COTask> {
  late bool _selectTF;
  late GlobalKey<FormState> _thisKey;
  late Answer answer;
  late bool textoObligatorio;
  late String texto;
  @override
  void initState() {
    _thisKey = GlobalKey<FormState>();
    if (widget.answer == null) {
      answer =
          Answer.withoutAnswer(widget.poi.id, widget.task.id, widget.task.aT);
      if (widget.task.aT == AnswerType.tf) {
        _selectTF = Random.secure().nextBool();
      }
      texto = '';
      answer.labelPoi = widget.poi.labelLang(MyApp.currentLang) ??
          widget.poi.labelLang('es') ??
          widget.poi.labelLang('') ??
          '';
      answer.commentTask = widget.task.commentLang(MyApp.currentLang) ??
          widget.task.commentLang('es') ??
          widget.task.commentLang('') ??
          '';
    } else {
      answer = widget.answer!;
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
          widget.task.labelLang(MyApp.currentLang) ??
              widget.task.labelLang('es') ??
              widget.task.labelLang('') ??
              AppLocalizations.of(context)!.realizaTarea,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Theme.of(context).primaryColorDark,
        leading: const BackButton(color: Colors.white),
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
            constraints: const BoxConstraints(maxHeight: Auxiliar.MAX_WIDTH),
            child: HtmlWidget(
              widget.task.commentLang(MyApp.currentLang) ??
                  widget.task.commentLang('es') ??
                  widget.task.commentLang('') ??
                  '',
              factoryBuilder: () => MyWidgetFactory(),
              textStyle: Theme.of(context).textTheme.headline5,
            ))
      ],
    );
  }

  widgetSolveTask() {
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

    Widget cuadrotexto = Form(
        key: _thisKey,
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
          child: TextFormField(
            maxLines: textoObligatorio ? 5 : 2,
            initialValue: texto,
            decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: textoObligatorio
                    ? AppLocalizations.of(context)!.respondePreguntaTextualLabel
                    : AppLocalizations.of(context)!.notasOpcionalesLabel,
                hintText: textoObligatorio
                    ? AppLocalizations.of(context)!.respondePreguntaTextual
                    : AppLocalizations.of(context)!.notasOpcionales,
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
                    return AppLocalizations.of(context)!
                        .respondePreguntaTextual;
                  }
                } else {
                  texto = value.trim();
                  return null;
                }
              } else {
                return AppLocalizations.of(context)!.respondePreguntaTextual;
              }
            },
          ),
        ));

    Widget extra = Container();
    switch (widget.task.aT) {
      case AnswerType.mcq:
        //Selectores
        break;
      case AnswerType.multiplePhotos:
      case AnswerType.photo:
      case AnswerType.multiplePhotosText:
      case AnswerType.photoText:
        //Visor de fotos
        break;
      case AnswerType.tf:
        extra = Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
                child: Text(
                  AppLocalizations.of(context)!.verdaderoNTDivLabel,
                  textAlign: TextAlign.start,
                )),
            Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
                child: RadioListTile<bool>(
                    title: Text(AppLocalizations.of(context)!.rbVFVNTVLabel),
                    value: true,
                    groupValue: _selectTF,
                    onChanged: (bool? v) {
                      setState(() => _selectTF = v!);
                    })),
            Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
                child: RadioListTile<bool>(
                    title: Text(AppLocalizations.of(context)!.rbVFFNTLabel),
                    value: false,
                    groupValue: _selectTF,
                    onChanged: (bool? v) {
                      setState(() => _selectTF = v!);
                    })),
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
    List<Widget> botones = [];
    switch (widget.task.aT) {
      case AnswerType.multiplePhotos:
      case AnswerType.photo:
      case AnswerType.multiplePhotosText:
      case AnswerType.photoText:
      case AnswerType.video:
      case AnswerType.videoText:
        botones.add(TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.camera_alt),
            label: Text(AppLocalizations.of(context)!.abrirCamara)));
        break;
      default:
    }
    botones.add(ElevatedButton.icon(
        onPressed: () {
          if (_thisKey.currentState!.validate()) {
            try {
              switch (answer.answerType) {
                case AnswerType.mcq:
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
                      'timeStamp': DateTime.now().millisecondsSinceEpoch,
                      'extraText': texto.trim()
                    };
                  } else {
                    answer.answer = _selectTF;
                  }
                  break;
                case AnswerType.video:
                  break;
                case AnswerType.videoText:
                  break;
                default:
              }
              Auxiliar.userCHEST.answers.add(answer);
              //TODO Send answer to the server
              Navigator.pop(context);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:
                      Text(AppLocalizations.of(context)!.respuestaGuardada)));
            } catch (error) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(error.toString())));
            }
          }
        },
        label: Text(AppLocalizations.of(context)!.enviarRespuesta),
        icon: const Icon(Icons.publish)));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: botones,
    );
  }

  widgetFAB() {
    return null;
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
  List<String> distractors = [];
  AnswerType? answerType;
  late bool _rgtf, _spaFis, _spaVir, errorEspacios;
  @override
  void initState() {
    _thisKey = GlobalKey<FormState>();
    drop = null;
    _rgtf = widget.task.hasCorrectTF
        ? widget.task.correctTF
        : Random.secure().nextBool();
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColorDark,
        leading: const BackButton(color: Colors.white),
        title: Text(AppLocalizations.of(context)!.nTask),
      ),
      floatingActionButton: FloatingActionButton.extended(
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
                //TODO envío al servidor
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
                        bodyRequest["correct"] = widget.task.correctMCQ;
                      }
                      bodyRequest["distractors"] = widget.task.distractors;
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
                      'token':
                          await FirebaseAuth.instance.currentUser!.getIdToken(),
                    })
                  },
                  body: json.encode(bodyRequest),
                )
                    .then((response) {
                  switch (response.statusCode) {
                    case 201:
                    case 202:
                      //Devuelvo a la pantalla anterior la tarea que se acaba de crear para reprsentarla
                      widget.task.id = response.headers['location']!;
                      Navigator.pop(context, widget.task);
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              AppLocalizations.of(context)!.infoRegistrada)));
                      break;
                    default:
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(response.statusCode.toString())));
                  }
                }).onError((error, stackTrace) {
                  print(error.toString());
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
          icon: const Icon(Icons.publish)),
      body: SafeArea(
          minimum: const EdgeInsets.all(10),
          child: Center(
              child: Form(
                  key: _thisKey,
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        widgetComun(),
                        const SizedBox(height: 10),
                        widgetVariable(),
                        const SizedBox(height: 10),
                        widgetSpaces(),
                      ]))))),
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
    return Container(
        constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
        child: ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            TextFormField(
              maxLines: 1,
              decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.tituloNTLabel,
                  hintText: AppLocalizations.of(context)!.tituloNT,
                  hintMaxLines: 1,
                  hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
              textCapitalization: TextCapitalization.words,
              keyboardType: TextInputType.text,
              initialValue: widget.task.hasLabel
                  ? widget.task.labels.isEmpty
                      ? ''
                      : widget.task.labelLang(MyApp.currentLang) ??
                          (widget.task.labelLang('es') ??
                              (widget.task.labelLang('') ?? ''))
                  : '',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppLocalizations.of(context)!.tituloNT;
                } else {
                  widget.task.addLabel(
                      {'lang': MyApp.currentLang, 'value': value.trim()});
                  return null;
                }
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: AppLocalizations.of(context)!.textAsociadoNTLabel,
                  hintText: AppLocalizations.of(context)!.textoAsociadoNT,
                  hintMaxLines: 1,
                  hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              initialValue: widget.task.comments.isEmpty
                  ? ''
                  : widget.task.commentLang(MyApp.currentLang) ??
                      (widget.task.commentLang('es') ??
                          (widget.task.commentLang('') ?? '')),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return AppLocalizations.of(context)!.textoAsociadoNT;
                } else {
                  widget.task
                      .addComment({'lang': MyApp.currentLang, 'value': value});
                  return null;
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField(
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText:
                    AppLocalizations.of(context)!.selectTipoRespuestaLabel,
                hintText:
                    AppLocalizations.of(context)!.selectTipoRespuestaEnunciado,
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
                  child: value == null
                      ? const Text('')
                      : Text(atString[aTTextUser]!),
                );
              }).toList(),
              validator: (v) {
                if (v == null) {
                  return AppLocalizations.of(context)!
                      .selectTipoRespuestaEnunciado;
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
          ],
        ));
  }

  Widget widgetVariable() {
    Widget widgetV;
    if (answerType != null) {
      //TODO Finish!!
      switch (answerType) {
        case AnswerType.mcq:
          widgetV = Column(
            children: [
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
                      widget.task.hasCorrectMCQ ? widget.task.correctMCQ : '',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return AppLocalizations.of(context)!.rVMCQ;
                    }
                    //TODO widget.task.mcqCA = v;
                    return null;
                  }),
              const SizedBox(
                height: 10,
              ),
              TextFormField(
                  maxLines: 1,
                  decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: AppLocalizations.of(context)!.rD1MCQLabel,
                      hintText: AppLocalizations.of(context)!.rD1MCQ,
                      hintMaxLines: 1,
                      hintStyle:
                          const TextStyle(overflow: TextOverflow.ellipsis)),
                  textCapitalization: TextCapitalization.sentences,
                  initialValue: distractors.isNotEmpty ? distractors.first : '',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return AppLocalizations.of(context)!.rD1MCQ;
                    }
                    widget.task.distractors.add(v.trim());
                    return null;
                  }),
              const SizedBox(
                height: 10,
              ),
              TextFormField(
                  maxLines: 1,
                  decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: AppLocalizations.of(context)!.rD2MCQLabel,
                      hintText: AppLocalizations.of(context)!.rD2MCQ,
                      hintMaxLines: 1,
                      hintStyle:
                          const TextStyle(overflow: TextOverflow.ellipsis)),
                  textCapitalization: TextCapitalization.sentences,
                  initialValue: distractors.length >= 2 ? distractors[1] : '',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return AppLocalizations.of(context)!.rD2MCQ;
                    }
                    widget.task.distractors.add(v.trim());
                    return null;
                  }),
              const SizedBox(
                height: 10,
              ),
              TextFormField(
                  maxLines: 1,
                  decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: AppLocalizations.of(context)!.rD3MCQLabel,
                      hintText: AppLocalizations.of(context)!.rD3MCQ,
                      hintMaxLines: 1,
                      hintStyle:
                          const TextStyle(overflow: TextOverflow.ellipsis)),
                  textCapitalization: TextCapitalization.sentences,
                  initialValue: distractors.length >= 3 ? distractors[2] : '',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return AppLocalizations.of(context)!.rD3MCQ;
                    }
                    widget.task.distractors.add(v.trim());
                    return null;
                  }),
            ],
          );
          break;
        case AnswerType.tf:
          widgetV = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.verdaderoNTDivLabel,
                textAlign: TextAlign.left,
              ),
              RadioListTile<bool>(
                  contentPadding: const EdgeInsets.all(0),
                  title: Text(AppLocalizations.of(context)!.rbVFVNTVLabel),
                  value: true,
                  groupValue: _rgtf,
                  onChanged: (bool? v) {
                    setState(() => _rgtf = v!);
                  }),
              RadioListTile<bool>(
                  contentPadding: const EdgeInsets.all(0),
                  title: Text(AppLocalizations.of(context)!.rbVFFNTLabel),
                  value: false,
                  groupValue: _rgtf,
                  onChanged: (bool? v) {
                    setState(() => _rgtf = v!);
                  }),
            ],
          );
          break;
        default:
          widgetV = Container();
      }
    } else {
      widgetV = Container();
    }
    return Container(
      padding: const EdgeInsets.only(top: 10),
      constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
      child: widgetV,
    );
  }

  widgetSpaces() {
    return Container(
        constraints: const BoxConstraints(maxWidth: Auxiliar.MAX_WIDTH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.cbEspacioDivLabel,
            ),
            Visibility(
              visible: errorEspacios,
              child: const SizedBox(height: 10),
            ),
            Visibility(
              visible: errorEspacios,
              child: Text(
                AppLocalizations.of(context)!.cbEspacioDivError,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(color: Theme.of(context).errorColor),
              ),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 80),
          ],
        ));
  }
}
