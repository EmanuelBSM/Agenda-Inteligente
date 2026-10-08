import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:agenda_inteligente_gemini/models/material_item.dart';
import 'package:agenda_inteligente_gemini/services/api_service.dart';

void main() {
  test('tarefa sugerida preserva exatamente o horário local retornado', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'text': 'Tarefa sugerida.',
          'suggestedTask': {
            'title': 'Estudar matemática',
            'deadlineDate': '2026-10-02',
            'deadlineTime': '18:00',
            'deadlineHasTime': true,
            'priority': 'alta',
          },
          'interactionId': 'interaction-test',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = ApiService(client: client, baseUrl: 'http://localhost:3000');
    final reply = await api.assistant(message: 'Estudar amanhã às 18h', events: const [], tasks: const [], materials: const []);

    expect(reply.suggestedTask, isNotNull);
    expect(reply.suggestedTask!.deadline, DateTime(2026, 10, 2, 18, 0));
    expect(reply.suggestedTask!.deadlineHasTime, isTrue);
  });

  test('tarefa sem horário permanece sem horário', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'text': 'Tarefa sugerida.',
          'suggestedTask': {
            'title': 'Entregar trabalho',
            'deadlineDate': '2026-10-02',
            'deadlineTime': null,
            'deadlineHasTime': false,
            'priority': 'media',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = ApiService(client: client, baseUrl: 'http://localhost:3000');
    final reply = await api.assistant(message: 'Entregar amanhã', events: const [], tasks: const [], materials: const []);

    expect(reply.suggestedTask!.deadline, DateTime(2026, 10, 2));
    expect(reply.suggestedTask!.deadlineHasTime, isFalse);
  });

  test('assistente envia PDFs disponíveis ao backend', () async {
    late Map<String, dynamic> sentBody;
    final client = MockClient((request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({'text': 'Resposta com PDF.', 'interactionId': 'pdf-interaction'}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = ApiService(client: client, baseUrl: 'http://localhost:3000');
    await api.assistant(
      message: 'O que esse material fala sobre genética?',
      events: const [],
      tasks: const [],
      materials: const [
        MaterialItem(
          name: 'files/pdf-1',
          displayName: 'Genética.pdf',
          mimeType: 'application/pdf',
          category: 'Biologia',
          remote: true,
        ),
      ],
    );

    final materials = sentBody['materials'] as List<dynamic>;
    expect(materials, hasLength(1));
    expect((materials.first as Map<String, dynamic>)['name'], 'files/pdf-1');
    expect((materials.first as Map<String, dynamic>)['displayName'], 'Genética.pdf');
    expect((materials.first as Map<String, dynamic>)['category'], 'Biologia');
  });

  test('plano de estudo retorna vários blocos com horários preservados', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'text': 'Separei o estudo em dois blocos.',
          'suggestedStudyBlocks': [
            {
              'title': 'Estudar Matemática — bloco 1',
              'start': '2026-10-06T21:00:00.000Z',
              'end': '2026-10-06T22:30:00.000Z',
              'description': 'Revisão',
              'location': '',
            },
            {
              'title': 'Estudar Matemática — bloco 2',
              'start': '2026-10-08T21:00:00.000Z',
              'end': '2026-10-08T23:30:00.000Z',
              'description': 'Exercícios',
              'location': '',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final api = ApiService(client: client, baseUrl: 'http://localhost:3000');
    final reply = await api.assistant(
      message: 'Separe 4 horas de estudo em blocos',
      events: const [],
      tasks: const [],
      materials: const [],
    );

    expect(reply.suggestedStudyBlocks, hasLength(2));
    expect(reply.suggestedStudyBlocks.first.title, contains('bloco 1'));
    expect(reply.suggestedStudyBlocks.first.end.difference(reply.suggestedStudyBlocks.first.start), const Duration(minutes: 90));
    final total = reply.suggestedStudyBlocks.fold<Duration>(
      Duration.zero,
      (sum, block) => sum + block.end.difference(block.start),
    );
    expect(total, const Duration(hours: 4));
  });

}
