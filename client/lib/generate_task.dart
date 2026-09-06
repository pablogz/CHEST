import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:chest/l10n/generated/app_localizations.dart';
import 'package:chest/main.dart';
import 'package:chest/tasks.dart';
import 'package:chest/util/helpers/feature.dart';
import 'package:chest/util/helpers/tasks.dart';
import 'package:chest/util/queries.dart';

// ── Estado interno del wizard ────────────────────────────────────────────────

enum _GenState { form, loading, result, error }

// ── Widget principal ─────────────────────────────────────────────────────────

class GenerateTaskWithAI extends StatefulWidget {
  final Feature feature;
  const GenerateTaskWithAI(this.feature, {super.key});

  @override
  State<GenerateTaskWithAI> createState() => _GenerateTaskWithAIState();
}

class _GenerateTaskWithAIState extends State<GenerateTaskWithAI> {
  _GenState _state = _GenState.form;
  Task? _generatedTask;
  Map<String, dynamic>? _aiResponse;
  String _errorMsg = '';

  final _levelCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _bloomCtrl = TextEditingController();
  final _pedagogyCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _levelCtrl.dispose();
    _subjectCtrl.dispose();
    _bloomCtrl.dispose();
    _pedagogyCtrl.dispose();
    _skillsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Llamada al orquestador vía CHEST server ──────────────────────────────

  Future<void> _generate() async {
    setState(() => _state = _GenState.loading);
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final lang = MyApp.currentLang;

      final body = <String, dynamic>{
        'placeDescription': widget.feature.getALabel(lang: lang).isNotEmpty
            ? widget.feature.getALabel(lang: lang)
            : widget.feature.shortId,
      };
      _addIfNotEmpty(body, 'educational_level', _levelCtrl.text);
      _addIfNotEmpty(body, 'subject_area', _subjectCtrl.text);
      _addIfNotEmpty(body, 'bloom_level', _bloomCtrl.text);
      _addIfNotEmpty(body, 'pedagogical_approach', _pedagogyCtrl.text);
      _addIfNotEmpty(body, 'skills_to_develop', _skillsCtrl.text);
      _addIfNotEmpty(body, 'teacher_notes', _notesCtrl.text);

      final response = await http.post(
        Queries.generateTask(widget.feature.shortId),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final task = _parseAiResponse(data, lang);
        setState(() {
          _aiResponse = data;
          _generatedTask = task;
          _state = _GenState.result;
        });
      } else {
        setState(() {
          _errorMsg = '${response.statusCode}: ${response.body}';
          _state = _GenState.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
        _state = _GenState.error;
      });
    }
  }

  void _addIfNotEmpty(Map<String, dynamic> map, String key, String value) {
    if (value.trim().isNotEmpty) map[key] = value.trim();
  }

  // ── Mapeo JSON del orquestador → Task de CHEST ───────────────────────────

  Task _parseAiResponse(Map<String, dynamic> data, String lang) {
    final task = Task.empty(
      containerType: ContainerTask.spatialThing,
      idContainer: widget.feature.id,
    );

    // Tipo de tarea
    final rawType =
        (data['mo:LearningType'] as String? ?? '').replaceAll('mo:', '');
    switch (rawType) {
      case 'text':
        task.aT = AnswerType.text;
        break;
      case 'mcq':
        task.aT = AnswerType.mcq;
        break;
      case 'yesno':
        task.aT = AnswerType.tf;
        break;
      case 'photo':
        task.aT = AnswerType.photo;
        break;
      default:
        task.aT = AnswerType.text;
    }

    // Título
    final label = data['rdfs:label'];
    if (label is String && label.isNotEmpty) {
      task.setLabels({'lang': lang, 'value': label});
    }

    // Descripción / enunciado
    final comment = data['rdfs:comment'];
    if (comment is String && comment.isNotEmpty) {
      task.setComments({'lang': lang, 'value': comment});
    }

    // Espacios: físico + virtual (aprendizaje ubicuo)
    task.addSpace(Space.physical);
    task.addSpace(Space.virtual);

    // Opciones MCQ
    if (task.aT == AnswerType.mcq) {
      final correct = data['mo:correct'];
      final distractor = data['mo:distractor'];
      if (correct != null) task.setCorrectMCQ(correct);
      if (distractor != null) task.setDistractorMCQ(distractor);
    }

    // Respuesta Verdadero/Falso
    if (task.aT == AnswerType.tf && data['mo:correct'] is bool) {
      task.correctTF = data['mo:correct'] as bool;
    }

    return task;
  }

  // ── Construcción de la UI ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appLoca = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(appLoca.nTaskIA),
        centerTitle: false,
      ),
      body: SafeArea(
        child: switch (_state) {
          _GenState.form => _buildForm(appLoca),
          _GenState.loading => _buildLoading(appLoca),
          _GenState.result => _buildResult(appLoca),
          _GenState.error => _buildError(appLoca),
        },
      ),
    );
  }

  // ── Fase 1: formulario ───────────────────────────────────────────────────

  Widget _buildForm(AppLocalizations appLoca) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.feature.getALabel(lang: MyApp.currentLang),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(appLoca.iaGenerateDesc, style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          _field(_levelCtrl, appLoca.iaFieldLevel, appLoca.iaFieldLevelHint),
          const SizedBox(height: 12),
          _field(
              _subjectCtrl, appLoca.iaFieldSubject, appLoca.iaFieldSubjectHint),
          const SizedBox(height: 12),
          _field(_bloomCtrl, appLoca.iaFieldBloom, appLoca.iaFieldBloomHint),
          const SizedBox(height: 12),
          _field(_pedagogyCtrl, appLoca.iaFieldPedagogy,
              appLoca.iaFieldPedagogyHint),
          const SizedBox(height: 12),
          _field(_skillsCtrl, appLoca.iaFieldSkills, appLoca.iaFieldSkillsHint),
          const SizedBox(height: 12),
          _field(_notesCtrl, appLoca.iaFieldNotes, appLoca.iaFieldNotesHint,
              maxLines: 3),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.auto_awesome),
            label: Text(appLoca.iaGenerateButton),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        hintText: hint,
        hintMaxLines: 2,
        hintStyle: const TextStyle(overflow: TextOverflow.ellipsis),
      ),
      textCapitalization: TextCapitalization.sentences,
      textInputAction:
          maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
    );
  }

  // ── Fase 2: cargando ─────────────────────────────────────────────────────

  Widget _buildLoading(AppLocalizations appLoca) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(appLoca.iaGenerating),
        ],
      ),
    );
  }

  // ── Fase 3: resultado generado ───────────────────────────────────────────

  Widget _buildResult(AppLocalizations appLoca) {
    final data = _aiResponse!;
    final type =
        (data['mo:LearningType'] as String? ?? '').replaceAll('mo:', '');
    final label = data['rdfs:label'] as String? ?? '';
    final comment = data['rdfs:comment'] as String? ?? '';
    final ctx = data['mo:LearningContext'] as String? ?? '';
    final objective = data['mo:LearningObjetive'] as String? ?? '';
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(appLoca.iaGeneratedTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(appLoca.iaGeneratedDesc, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: 8, children: [
                    if (type.isNotEmpty) Chip(label: Text(type)),
                    if (ctx.isNotEmpty) Chip(label: Text(ctx)),
                  ]),
                  if (label.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(label, style: theme.textTheme.titleSmall),
                  ],
                  if (objective.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(objective, style: theme.textTheme.bodySmall),
                  ],
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(comment, maxLines: 5, overflow: TextOverflow.ellipsis),
                  ],
                  if (type == 'mcq') ...[
                    const SizedBox(height: 8),
                    _buildMcqPreview(data, theme),
                  ],
                  if (type == 'yesno' && data['mo:correct'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${data['mo:correct']}',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openFormTask,
            icon: const Icon(Icons.edit),
            label: Text(appLoca.iaEditAndSave),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _state = _GenState.form),
            icon: const Icon(Icons.refresh),
            label: Text(appLoca.iaRegenerate),
          ),
        ],
      ),
    );
  }

  Widget _buildMcqPreview(Map<String, dynamic> data, ThemeData theme) {
    final correct = data['mo:correct'];
    final distractor = data['mo:distractor'] as List? ?? [];
    final correctList =
        correct is List ? correct.cast<Object>() : [correct as Object];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in correctList)
          _optionRow(c.toString(), Icons.check_circle_outline, Colors.green),
        for (final d in distractor)
          _optionRow(d.toString(), Icons.cancel_outlined, Colors.red),
      ],
    );
  }

  Widget _optionRow(String text, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(text)),
      ]),
    );
  }

  Future<void> _openFormTask() async {
    final task = await Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (_) => FormTask(_generatedTask!),
        fullscreenDialog: true,
      ),
    );
    if (task != null && mounted) Navigator.pop(context, task);
  }

  // ── Fase 4: error ────────────────────────────────────────────────────────

  Widget _buildError(AppLocalizations appLoca) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(appLoca.iaError,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_errorMsg,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(() => _state = _GenState.form),
              icon: const Icon(Icons.refresh),
              label: Text(appLoca.iaErrorRetry),
            ),
          ],
        ),
      ),
    );
  }
}
