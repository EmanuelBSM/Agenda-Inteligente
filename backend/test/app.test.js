import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import {
  createRequestHandler,
  extractGenerateText,
  extractInteractionText,
} from '../src/app.js';

async function withServer(handler, fn) {
  const server = http.createServer(handler);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  try {
    await fn(`http://127.0.0.1:${address.port}`);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

test('extractGenerateText junta as partes de texto', () => {
  assert.equal(
    extractGenerateText({candidates: [{content: {parts: [{text: 'Olá '}, {text: 'mundo'}]}}]}),
    'Olá mundo',
  );
});

test('extractInteractionText lê model_output da Interactions API', () => {
  assert.equal(
    extractInteractionText({steps: [{type: 'model_output', content: [{type: 'text', text: 'Resposta'}]}]}),
    'Resposta',
  );
});

test('GET /health funciona sem chave e não expõe segredo', async () => {
  const handler = createRequestHandler({apiKey: '', model: 'modelo-teste'});
  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/health`);
    assert.equal(response.status, 200);
    const data = await response.json();
    assert.equal(data.ok, true);
    assert.equal(data.apiKeyConfigured, false);
    assert.equal(data.model, 'modelo-teste');
    assert.equal('apiKey' in data, false);
  });
});

test('rotas Gemini retornam 503 quando a chave não foi configurada', async () => {
  const handler = createRequestHandler({apiKey: ''});
  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/gemini/assistant`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({message: 'Olá'}),
    });
    assert.equal(response.status, 503);
    const data = await response.json();
    assert.match(data.error, /chave da Gemini/i);
  });
});

test('rota inexistente retorna 404', async () => {
  const handler = createRequestHandler({apiKey: ''});
  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/nao-existe`);
    assert.equal(response.status, 404);
  });
});

test('assistente converte resposta estruturada em sugestão de evento', async () => {
  const fetchImpl = async (url, options) => {
    assert.match(String(url), /\/v1beta\/interactions$/);
    const body = JSON.parse(options.body);
    assert.equal(body.model, 'modelo-teste');
    assert.equal(body.input.includes('Tenho prova amanhã às 14h'), true);
    return new Response(JSON.stringify({
      id: 'interaction-123',
      model: 'modelo-teste',
      steps: [{
        type: 'model_output',
        content: [{
          type: 'text',
          text: JSON.stringify({
            reply: 'Posso criar a prova amanhã às 14h.',
            action: 'event',
            event_title: 'Prova de Matemática',
            event_start: '2026-10-01T14:00:00-03:00',
            event_end: '2026-10-01T16:00:00-03:00',
            event_description: '',
            event_location: '',
            task_title: '',
            task_due_date: '',
            task_due_time: '',
            task_priority: 'media',
          }),
        }],
      }],
    }), {status: 200, headers: {'Content-Type': 'application/json'}});
  };

  const handler = createRequestHandler({apiKey: 'test-key', model: 'modelo-teste', fetchImpl});
  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/gemini/assistant`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({message: 'Tenho prova amanhã às 14h'}),
    });
    assert.equal(response.status, 200);
    const data = await response.json();
    assert.equal(data.interactionId, 'interaction-123');
    assert.equal(data.suggestedEvent.title, 'Prova de Matemática');
    assert.match(data.suggestedEvent.start, /^2026-10-01T17:00:00\.000Z$/);
  });
});


test('assistente preserva o horário local informado em tarefa', async () => {
  const fetchImpl = async (url, options) => {
    assert.match(String(url), /\/v1beta\/interactions$/);
    const body = JSON.parse(options.body);
    assert.match(body.input, /preserve EXATAMENTE esse horário local/i);
    assert.equal(body.previous_interaction_id, 'interaction-before');
    return new Response(JSON.stringify({
      id: 'interaction-task-1',
      model: 'modelo-teste',
      steps: [{
        type: 'model_output',
        content: [{
          type: 'text',
          text: JSON.stringify({
            reply: 'Vou sugerir a tarefa para amanhã.',
            action: 'task',
            event_title: '',
            event_start: '',
            event_end: '',
            event_description: '',
            event_location: '',
            task_title: 'Estudar matemática',
            task_due_date: '2026-10-02',
            task_due_time: '18:00',
            task_priority: 'alta',
          }),
        }],
      }],
    }), {status: 200, headers: {'Content-Type': 'application/json'}});
  };

  const handler = createRequestHandler({apiKey: 'test-key', model: 'modelo-teste', fetchImpl});
  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/gemini/assistant`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        message: 'Adicione uma tarefa para estudar matemática amanhã às 18h',
        previousInteractionId: 'interaction-before',
      }),
    });
    assert.equal(response.status, 200);
    const data = await response.json();
    assert.equal(data.interactionId, 'interaction-task-1');
    assert.equal(data.suggestedEvent, null);
    assert.deepEqual(data.suggestedTask, {
      title: 'Estudar matemática',
      deadlineDate: '2026-10-02',
      deadlineTime: '18:00',
      deadlineHasTime: true,
      priority: 'alta',
    });
  });
});

test('assistente não inventa horário quando tarefa tem apenas data', async () => {
  const fetchImpl = async (_url, options) => {
    const body = JSON.parse(options.body);
    assert.match(body.input, /Não invente horário/i);
    return new Response(JSON.stringify({
      id: 'interaction-task-2',
      steps: [{
        type: 'model_output',
        content: [{
          type: 'text',
          text: JSON.stringify({
            reply: 'Tarefa para amanhã.',
            action: 'task',
            event_title: '',
            event_start: '',
            event_end: '',
            event_description: '',
            event_location: '',
            task_title: 'Entregar trabalho',
            task_due_date: '2026-10-02',
            task_due_time: '',
            task_priority: 'media',
          }),
        }],
      }],
    }), {status: 200, headers: {'Content-Type': 'application/json'}});
  };

  const handler = createRequestHandler({apiKey: 'test-key', model: 'modelo-teste', fetchImpl});
  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/gemini/assistant`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({message: 'Crie uma tarefa para entregar o trabalho amanhã'}),
    });
    assert.equal(response.status, 200);
    const data = await response.json();
    assert.equal(data.suggestedTask.deadlineDate, '2026-10-02');
    assert.equal(data.suggestedTask.deadlineTime, null);
    assert.equal(data.suggestedTask.deadlineHasTime, false);
  });
});

test('assistente transforma pedido de estudo em vários blocos sem conflito', async () => {
  const fetchImpl = async (url, options) => {
    assert.match(String(url), /\/v1beta\/interactions$/);
    const body = JSON.parse(options.body);
    assert.match(body.input, /action=study_plan/i);
    assert.match(body.input, /NÃO crie blocos que se sobreponham/i);
    assert.match(body.input, /PEDIDO_DE_PLANO_DE_ESTUDO=true/);
    assert.match(body.input, /Prova de Matemática/);

    return new Response(JSON.stringify({
      id: 'interaction-study-plan',
      model: 'modelo-teste',
      steps: [{
        type: 'model_output',
        content: [{
          type: 'text',
          text: JSON.stringify({
            reply: 'Separei as 4 horas em três blocos antes da prova.',
            action: 'study_plan',
            event_title: '',
            event_start: '',
            event_end: '',
            event_description: '',
            event_location: '',
            task_title: '',
            task_due_date: '',
            task_due_time: '',
            task_priority: 'media',
            study_blocks: [
              {
                title: 'Estudar Matemática — bloco 1',
                start: '2026-10-06T18:00:00-03:00',
                end: '2026-10-06T19:30:00-03:00',
                description: 'Revisão inicial',
              },
              {
                title: 'Estudar Matemática — bloco conflitante',
                start: '2026-10-07T19:30:00-03:00',
                end: '2026-10-07T20:30:00-03:00',
                description: 'Este deve ser removido pelo backend',
              },
              {
                title: 'Estudar Matemática — bloco 2',
                start: '2026-10-08T18:00:00-03:00',
                end: '2026-10-08T20:30:00-03:00',
                description: 'Exercícios e revisão final',
              },
            ],
          }),
        }],
      }],
    }), {status: 200, headers: {'Content-Type': 'application/json'}});
  };

  const handler = createRequestHandler({apiKey: 'test-key', model: 'modelo-teste', fetchImpl});
  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/gemini/assistant`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        message: 'Preciso estudar 4 horas para a prova, separa em blocos',
        events: [
          {
            id: 'exam',
            title: 'Prova de Matemática',
            start: '2026-10-09T14:00:00-03:00',
            end: '2026-10-09T16:00:00-03:00',
          },
          {
            id: 'busy',
            title: 'Academia',
            start: '2026-10-07T19:00:00-03:00',
            end: '2026-10-07T21:00:00-03:00',
          },
        ],
      }),
    });

    assert.equal(response.status, 200);
    const data = await response.json();
    assert.equal(data.suggestedEvent, null);
    assert.equal(data.suggestedTask, null);
    assert.equal(data.suggestedStudyBlocks.length, 2);
    assert.deepEqual(
      data.suggestedStudyBlocks.map((block) => block.title),
      ['Estudar Matemática — bloco 1', 'Estudar Matemática — bloco 2'],
    );
    const totalMinutes = data.suggestedStudyBlocks.reduce((sum, block) => {
      return sum + ((new Date(block.end) - new Date(block.start)) / 60000);
    }, 0);
    assert.equal(totalMinutes, 240);
  });
});

test('assistente usa File Search quando há PDFs disponíveis na conversa', async () => {
  const calls = [];
  const fetchImpl = async (url, options = {}) => {
    const u = String(url);
    calls.push({url: u, method: options.method || 'GET', body: options.body});

    if (u.endsWith('/v1beta/fileSearchStores') && (options.method || 'GET') === 'GET') {
      return new Response(JSON.stringify({
        fileSearchStores: [{
          name: 'fileSearchStores/agenda-123',
          displayName: 'Agenda Inteligente',
        }],
      }), {status: 200, headers: {'Content-Type': 'application/json'}});
    }

    if (u.endsWith('/v1beta/interactions')) {
      const body = JSON.parse(options.body);
      assert.deepEqual(body.tools, [{
        type: 'file_search',
        file_search_store_names: ['fileSearchStores/agenda-123'],
      }]);
      assert.equal(body.previous_interaction_id, 'interaction-before-pdf');
      assert.match(body.input, /Genética\.pdf/);
      assert.match(body.input, /use o File Search/i);

      return new Response(JSON.stringify({
        id: 'interaction-after-pdf',
        model: 'modelo-teste',
        steps: [{
          type: 'model_output',
          content: [{
            type: 'text',
            text: JSON.stringify({
              reply: 'Segundo o PDF de Genética, o material explica hereditariedade.',
              action: 'none',
              event_title: '',
              event_start: '',
              event_end: '',
              event_description: '',
              event_location: '',
              task_title: '',
              task_due_date: '',
              task_due_time: '',
              task_priority: 'media',
            }),
          }],
        }],
      }), {status: 200, headers: {'Content-Type': 'application/json'}});
    }

    throw new Error(`URL inesperada no teste: ${u}`);
  };

  const handler = createRequestHandler({apiKey: 'test-key', model: 'modelo-teste', fetchImpl});
  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/gemini/assistant`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({
        message: 'O que o PDF de Genética fala sobre hereditariedade?',
        previousInteractionId: 'interaction-before-pdf',
        materials: [{
          name: 'files/pdf-genetica',
          displayName: 'Genética.pdf',
          category: 'Biologia',
        }],
      }),
    });

    assert.equal(response.status, 200);
    const data = await response.json();
    assert.equal(data.fileSearchEnabled, true);
    assert.equal(data.fileSearchStoreName, 'fileSearchStores/agenda-123');
    assert.equal(data.interactionId, 'interaction-after-pdf');
    assert.match(data.text, /hereditariedade/i);
  });

  assert.equal(calls.some((call) => call.url.endsWith('/v1beta/fileSearchStores')), true);
  assert.equal(calls.some((call) => call.url.endsWith('/v1beta/interactions')), true);
});

test('upload PDF encaminha bytes para Files API e tenta indexar no File Search', async () => {
  const calls = [];
  const fetchImpl = async (url, options = {}) => {
    calls.push({url: String(url), method: options.method || 'GET'});
    const u = String(url);
    if (u.endsWith('/upload/v1beta/files')) {
      return new Response('', {status: 200, headers: {'x-goog-upload-url': 'https://upload.example/final'}});
    }
    if (u === 'https://upload.example/final') {
      return new Response(JSON.stringify({
        file: {
          name: 'files/pdf-123',
          displayName: 'apostila.pdf',
          mimeType: 'application/pdf',
          uri: 'https://generativelanguage.googleapis.com/v1beta/files/pdf-123',
          state: 'ACTIVE',
        },
      }), {status: 200, headers: {'Content-Type': 'application/json'}});
    }
    if (u.endsWith('/v1beta/fileSearchStores')) {
      if ((options.method || 'GET') === 'GET') {
        return new Response(JSON.stringify({fileSearchStores: []}), {status: 200, headers: {'Content-Type': 'application/json'}});
      }
      return new Response(JSON.stringify({name: 'fileSearchStores/agenda-123', displayName: 'Agenda Inteligente'}), {status: 200, headers: {'Content-Type': 'application/json'}});
    }
    if (u.endsWith('/v1beta/fileSearchStores/agenda-123:importFile')) {
      return new Response(JSON.stringify({name: 'operations/import-1', done: true}), {status: 200, headers: {'Content-Type': 'application/json'}});
    }
    throw new Error(`URL inesperada no teste: ${u}`);
  };

  const handler = createRequestHandler({apiKey: 'test-key', fetchImpl});
  await withServer(handler, async (baseUrl) => {
    const form = new FormData();
    form.append('file', new Blob([Buffer.from('%PDF-1.4\nmock')], {type: 'application/pdf'}), 'apostila.pdf');
    const response = await fetch(`${baseUrl}/api/materials/upload`, {method: 'POST', body: form});
    assert.equal(response.status, 201);
    const data = await response.json();
    assert.equal(data.file.name, 'files/pdf-123');
    assert.equal(data.fileSearch.store.name, 'fileSearchStores/agenda-123');
  });

  assert.equal(calls.some((call) => call.url.endsWith('/upload/v1beta/files')), true);
  assert.equal(calls.some((call) => call.url.endsWith(':importFile')), true);
});

test('resumo de PDF consulta arquivo e chama generateContent', async () => {
  const fetchImpl = async (url, options = {}) => {
    const u = String(url);
    if (u.endsWith('/v1beta/files/pdf-123')) {
      return new Response(JSON.stringify({
        name: 'files/pdf-123',
        displayName: 'apostila.pdf',
        mimeType: 'application/pdf',
        uri: 'https://example.test/pdf-123',
        state: 'ACTIVE',
      }), {status: 200, headers: {'Content-Type': 'application/json'}});
    }
    if (u.includes(':generateContent')) {
      const body = JSON.parse(options.body);
      assert.equal(body.contents[0].parts[1].fileData.fileUri, 'https://example.test/pdf-123');
      return new Response(JSON.stringify({
        candidates: [{content: {parts: [{text: 'Resumo do material'}]}}],
      }), {status: 200, headers: {'Content-Type': 'application/json'}});
    }
    throw new Error(`URL inesperada no teste: ${u}`);
  };

  const handler = createRequestHandler({apiKey: 'test-key', model: 'gemini-3.5-flash-lite', fetchImpl});
  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/materials/summary`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({fileName: 'files/pdf-123'}),
    });
    assert.equal(response.status, 200);
    const data = await response.json();
    assert.equal(data.text, 'Resumo do material');
  });
});

test('pergunta sobre material usa File Search na Interactions API', async () => {
  const fetchImpl = async (url, options = {}) => {
    const u = String(url);
    if (u.endsWith('/v1beta/files/pdf-123')) {
      return new Response(JSON.stringify({
        name: 'files/pdf-123',
        displayName: 'apostila.pdf',
        mimeType: 'application/pdf',
        uri: 'https://example.test/pdf-123',
        state: 'ACTIVE',
      }), {status: 200, headers: {'Content-Type': 'application/json'}});
    }
    if (u.endsWith('/v1beta/fileSearchStores') && (options.method || 'GET') === 'GET') {
      return new Response(JSON.stringify({
        fileSearchStores: [{name: 'fileSearchStores/agenda-123', displayName: 'Agenda Inteligente'}],
      }), {status: 200, headers: {'Content-Type': 'application/json'}});
    }
    if (u.endsWith('/v1beta/interactions')) {
      const body = JSON.parse(options.body);
      assert.deepEqual(body.tools, [{type: 'file_search', file_search_store_names: ['fileSearchStores/agenda-123']}]);
      return new Response(JSON.stringify({
        id: 'interaction-material-1',
        steps: [{type: 'model_output', content: [{type: 'text', text: 'Resposta baseada no material'}]}],
      }), {status: 200, headers: {'Content-Type': 'application/json'}});
    }
    throw new Error(`URL inesperada no teste: ${u}`);
  };

  const handler = createRequestHandler({apiKey: 'test-key', model: 'gemini-3.5-flash-lite', fetchImpl});
  await withServer(handler, async (baseUrl) => {
    const response = await fetch(`${baseUrl}/api/materials/ask`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({fileName: 'files/pdf-123', question: 'Qual é o tema principal?'}),
    });
    assert.equal(response.status, 200);
    const data = await response.json();
    assert.equal(data.text, 'Resposta baseada no material');
    assert.equal(data.interactionId, 'interaction-material-1');
  });
});
