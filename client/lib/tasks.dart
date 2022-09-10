import 'dart:math';

import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'helpers/auxiliar.dart';
import 'helpers/pois.dart';
import 'helpers/tasks.dart';
import 'main.dart';

class COTask extends StatefulWidget {
  final POI poi;
  final Task task;
  const COTask(this.poi, this.task, {super.key});
  @override
  State<StatefulWidget> createState() => _COTask();
}

class _COTask extends State<COTask> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold();
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
  AnswerType? answerType;
  late bool _rgtf, _spaFis, _spaVir;
  @override
  void initState() {
    _thisKey = GlobalKey<FormState>();
    drop = null;
    _rgtf = Random.secure().nextBool();
    _spaFis = false;
    _spaVir = false;
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
          onPressed: () {},
          label: Text(AppLocalizations.of(context)!.enviarTask),
          icon: const Icon(Icons.publish)),
      body: SafeArea(
          minimum: const EdgeInsets.all(10),
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
                  ])))),
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
              initialValue: widget.task.labels.isEmpty
                  ? ''
                  : widget.task.labelLang(MyApp.currentLang) ??
                      (widget.task.labelLang('es') ??
                          (widget.task.labelLang('') ?? '')),
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
                // if (v == null ||
                //     v.toString().isEmpty ||
                //     !selects2uri.containsKey(v)) {
                //   return AppLocalizations.of(context)!
                //       .selectTipoRespuestaEnunciado;
                // }
                // widget.task.aTR = Mustache(map: {
                //   "t": selects2uri[v]
                // }).convert(
                //     "https://casuallearn.gsic.uva.es/answerType/{{t}}");
                return null;
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
                  initialValue: "", //TODO
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
                  initialValue:
                      '', //TODO widget.task.isEmpty ? "" : widget.task.mcqW1,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return AppLocalizations.of(context)!.rD1MCQ;
                    }
                    //TODO widget.task.mcqW1 = v;
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
                  initialValue:
                      '', //TODO widget.task.isEmpty ? "" : widget.task.mcqW2,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return AppLocalizations.of(context)!.rD2MCQ;
                    }
                    //TODO widget.task.mcqW2 = v;
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
                  initialValue:
                      '', //TODO widget.task.isEmpty ? "" : widget.task.mcqW3,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return AppLocalizations.of(context)!.rD3MCQ;
                    }
                    //widget.task.mcqW3 = v;
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
