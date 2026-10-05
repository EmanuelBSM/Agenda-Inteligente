import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/agenda_event.dart';
import '../models/agenda_task.dart';
import '../models/material_item.dart';

class AssistantReply {
  const AssistantReply({
    required this.text,
    this.suggestedEvent,
    this.suggestedTask,
    this.suggestedStudyBlocks = const [],
    this.interactionId,
  });

  final String text;
  final AgendaEvent? suggestedEvent;
  final AgendaTask? suggestedTask;
  final List<AgendaEvent> suggestedStudyBlocks;
  final String? interactionId;
}

class ApiService {
  ApiService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? _resolveBaseUrl();

  final http.Client _client;
  final String baseUrl;

  static String _resolveBaseUrl() {
    const configured = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (configured.isNotEmpty) return configured;
    return Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000';
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> health() async {
    final response = await _client.get(_uri('/health')).timeout(const Duration(seconds: 6));
    return _json(response);
  }

  Future<AssistantReply> assistant({
    required String message,
    required List<AgendaEvent> events,
    required List<AgendaTask> tasks,
    required List<MaterialItem> materials,
    String? previousInteractionId,
  }) async {
    final response = await _client
        .post(
          _uri('/api/gemini/assistant'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'message': message,
            'events': events.map((event) => event.toJson()).toList(),
            'tasks': tasks
                .map((task) => {
                      'id': task.id,
                      'title': task.title,
                      'deadline': task.deadline?.toIso8601String(),
                      'deadlineHasTime': task.deadlineHasTime,
                      'priority': task.priority.name,
                      'completed': task.completed,
                    })
                .toList(),
            'materials': materials
                .where((item) => item.remote)
                .map((item) => {
                      'name': item.name,
                      'displayName': item.displayName,
                      'category': item.category,
                    })
                .toList(),
            'today': DateTime.now().toIso8601String(),
            'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
            'previousInteractionId': previousInteractionId,
          }),
        )
        .timeout(const Duration(seconds: 45));

    final data = _json(response);

    AgendaEvent? event;
    final suggestedEvent = data['suggestedEvent'];
    if (suggestedEvent is Map<String, dynamic>) {
      final parsedStart = DateTime.tryParse('${suggestedEvent['start']}');
      final parsedEnd = DateTime.tryParse('${suggestedEvent['end']}');
      if (parsedStart != null && parsedEnd != null) {
        event = AgendaEvent(
          id: 'ai-event-${DateTime.now().microsecondsSinceEpoch}',
          title: '${suggestedEvent['title'] ?? 'Evento'}',
          start: parsedStart.toLocal(),
          end: parsedEnd.toLocal(),
          description: suggestedEvent['description']?.toString(),
          location: suggestedEvent['location']?.toString(),
        );
      }
    }

    AgendaTask? task;
    final suggestedTask = data['suggestedTask'];
    if (suggestedTask is Map<String, dynamic>) {
      final title = '${suggestedTask['title'] ?? ''}'.trim();
      final rawDate = suggestedTask['deadlineDate']?.toString().trim() ?? '';
      final rawTime = suggestedTask['deadlineTime']?.toString().trim() ?? '';
      final dateMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(rawDate);
      final timeMatch = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(rawTime);
      DateTime? deadline;
      var hasTime = false;
      if (dateMatch != null) {
        final year = int.parse(dateMatch.group(1)!);
        final month = int.parse(dateMatch.group(2)!);
        final day = int.parse(dateMatch.group(3)!);
        if (timeMatch != null) {
          final hour = int.parse(timeMatch.group(1)!);
          final minute = int.parse(timeMatch.group(2)!);
          if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
            deadline = DateTime(year, month, day, hour, minute);
            hasTime = true;
          }
        }
        deadline ??= DateTime(year, month, day);
      }
      if (title.isNotEmpty) {
        task = AgendaTask(
          id: 'ai-task-${DateTime.now().microsecondsSinceEpoch}',
          title: title,
          deadline: deadline,
          deadlineHasTime: hasTime,
          priority: _taskPriority('${suggestedTask['priority'] ?? ''}'),
        );
      }
    }

    final studyBlocks = <AgendaEvent>[];
    final suggestedStudyBlocks = data['suggestedStudyBlocks'];
    if (suggestedStudyBlocks is List) {
      final baseId = DateTime.now().microsecondsSinceEpoch;
      for (var index = 0; index < suggestedStudyBlocks.length; index += 1) {
        final raw = suggestedStudyBlocks[index];
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final parsedStart = DateTime.tryParse('${map['start'] ?? ''}');
        final parsedEnd = DateTime.tryParse('${map['end'] ?? ''}');
        final title = '${map['title'] ?? ''}'.trim();
        if (parsedStart == null || parsedEnd == null || !parsedEnd.isAfter(parsedStart) || title.isEmpty) continue;
        studyBlocks.add(
          AgendaEvent(
            id: 'ai-study-$baseId-$index',
            title: title,
            start: parsedStart.toLocal(),
            end: parsedEnd.toLocal(),
            description: map['description']?.toString(),
            location: map['location']?.toString(),
          ),
        );
      }
    }

    return AssistantReply(
      text: '${data['text'] ?? 'Resposta recebida.'}',
      suggestedEvent: event,
      suggestedTask: task,
      suggestedStudyBlocks: studyBlocks,
      interactionId: data['interactionId']?.toString(),
    );
  }

  TaskPriority _taskPriority(String value) {
    switch (value.toLowerCase()) {
      case 'alta':
      case 'high':
        return TaskPriority.alta;
      case 'baixa':
      case 'low':
        return TaskPriority.baixa;
      default:
        return TaskPriority.media;
    }
  }

  Future<List<MaterialItem>> listFiles() async {
    final response = await _client.get(_uri('/api/materials')).timeout(const Duration(seconds: 20));
    final data = _json(response);
    final files = (data['files'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MaterialItem.fromJson)
        .toList();
    return files;
  }

  Future<MaterialItem> uploadPdf(File file) async {
    final request = http.MultipartRequest('POST', _uri('/api/materials/upload'));
    request.files.add(await http.MultipartFile.fromPath('file', file.path, filename: file.uri.pathSegments.last));
    final streamed = await request.send().timeout(const Duration(minutes: 2));
    final response = await http.Response.fromStream(streamed);
    final data = _json(response);
    return MaterialItem.fromJson(Map<String, dynamic>.from(data['file'] as Map));
  }

  Future<void> deleteFile(String fileName) async {
    final response = await _client
        .delete(_uri('/api/materials/${Uri.encodeComponent(fileName)}'))
        .timeout(const Duration(seconds: 20));
    _json(response);
  }

  Future<String> summarizeFile(String fileName) async {
    final response = await _client
        .post(
          _uri('/api/materials/summary'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fileName': fileName}),
        )
        .timeout(const Duration(minutes: 2));
    final data = _json(response);
    return '${data['text'] ?? ''}'.trim();
  }

  Future<String> askMaterial({required String fileName, required String question}) async {
    final response = await _client
        .post(
          _uri('/api/materials/ask'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'fileName': fileName, 'question': question}),
        )
        .timeout(const Duration(minutes: 2));
    final data = _json(response);
    return '${data['text'] ?? ''}'.trim();
  }

  Map<String, dynamic> _json(http.Response response) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Resposta inválida do servidor (${response.statusCode}).');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('${data['error'] ?? 'Erro no servidor (${response.statusCode}).'}');
    }
    return data;
  }
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
