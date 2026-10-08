import fs from 'node:fs';
import path from 'node:path';

const GEMINI_BASE_URL = 'https://generativelanguage.googleapis.com';
const DEFAULT_STORE_DISPLAY_NAME = 'Agenda Inteligente';

export function loadEnvFile(filePath) {
  if (!fs.existsSync(filePath)) return;
  const raw = fs.readFileSync(filePath, 'utf8');
  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const index = trimmed.indexOf('=');
    if (index < 1) continue;
    const key = trimmed.slice(0, index).trim();
    const value = trimmed.slice(index + 1).trim();
    if (!process.env[key]) process.env[key] = value;
  }
}

export function createRequestHandler(config = {}) {
  const apiKey = config.apiKey ?? process.env.GEMINI_API_KEY ?? '';
  const model = config.model ?? process.env.GEMINI_MODEL ?? 'gemini-3.5-flash-lite';
  const audioModel = config.audioModel ?? process.env.GEMINI_AUDIO_MODEL ?? model;
  const embeddingModel = config.embeddingModel ?? process.env.GEMINI_EMBEDDING_MODEL ?? 'models/gemini-embedding-2';
  const fetchImpl = config.fetchImpl ?? globalThis.fetch;
  let cachedFileSearchStore = null;

  const assertApiKey = () => {
    if (!apiKey || apiKey === 'COLOQUE_SUA_API_KEY_AQUI') {
      const error = new Error('A chave da Gemini ainda não foi configurada em backend/.env.');
      error.statusCode = 503;
      throw error;
    }
  };

  const geminiFetch = async (pathname, options = {}) => {
    assertApiKey();
    const headers = {
      'x-goog-api-key': apiKey,
      ...(options.body && !(options.body instanceof Buffer) ? {'Content-Type': 'application/json'} : {}),
      ...(options.headers ?? {}),
    };
    const response = await fetchImpl(`${GEMINI_BASE_URL}${pathname}`, {...options, headers});
    const text = await response.text();
    let data = {};
    if (text) {
      try {
        data = JSON.parse(text);
      } catch {
        data = {raw: text};
      }
    }
    if (!response.ok) {
      const error = new Error(data?.error?.message || `Gemini API retornou ${response.status}.`);
      error.statusCode = response.status;
      error.details = data;
      throw error;
    }
    return {data, response};
  };

  const ensureFileSearchStore = async () => {
    if (cachedFileSearchStore?.name) return cachedFileSearchStore;
    const {data: list} = await geminiFetch('/v1beta/fileSearchStores', {method: 'GET'});
    const stores = Array.isArray(list.fileSearchStores) ? list.fileSearchStores : [];
    const existing = stores.find((store) => store.displayName === DEFAULT_STORE_DISPLAY_NAME);
    if (existing?.name) {
      cachedFileSearchStore = existing;
      return existing;
    }

    const {data: created} = await geminiFetch('/v1beta/fileSearchStores', {
      method: 'POST',
      body: JSON.stringify({
        displayName: DEFAULT_STORE_DISPLAY_NAME,
        embeddingModel,
      }),
    });
    cachedFileSearchStore = created;
    return created;
  };

  const importFileToSearch = async (fileName) => {
    const store = await ensureFileSearchStore();
    if (!store?.name) throw new Error('Não foi possível criar a biblioteca do File Search.');
    const {data} = await geminiFetch(`/v1beta/${store.name}:importFile`, {
      method: 'POST',
      body: JSON.stringify({fileName}),
    });
    let operation = data;
    if (operation?.name && operation.done !== true) {
      for (let attempt = 0; attempt < 10 && operation.done !== true; attempt += 1) {
        await delay(1000);
        const result = await geminiFetch(`/v1beta/${operation.name}`, {method: 'GET'});
        operation = result.data;
        if (operation?.error) throw new Error(operation.error.message || 'Falha ao indexar o PDF no File Search.');
      }
    }
    return {store, operation};
  };

  const handleTranscribeAudio = async (req, res) => {
    const body = await readJson(req, 16 * 1024 * 1024);
    const audioBase64 = String(body.audioBase64 ?? '').trim();
    const mimeType = String(body.mimeType ?? 'audio/wav').trim().toLowerCase();

    if (!audioBase64) {
      return sendJson(res, 400, {error: 'Envie uma gravação de voz.'});
    }

    const allowedMimeTypes = new Set([
      'audio/wav',
      'audio/x-wav',
      'audio/mpeg',
      'audio/mp3',
      'audio/aac',
      'audio/ogg',
      'audio/flac',
    ]);
    if (!allowedMimeTypes.has(mimeType)) {
      return sendJson(res, 400, {error: 'Formato de áudio não suportado.'});
    }

    const estimatedBytes = Math.floor((audioBase64.length * 3) / 4);
    if (estimatedBytes > 10 * 1024 * 1024) {
      return sendJson(res, 413, {error: 'A gravação deve ter no máximo 10 MB.'});
    }

    const {data} = await geminiFetch('/v1beta/interactions', {
      method: 'POST',
      body: JSON.stringify({
        model: audioModel,
        input: [
          {
            type: 'text',
            text: 'Transcreva somente a fala deste áudio em português do Brasil. Retorne apenas o texto falado, sem aspas, comentários ou explicações.',
          },
          {
            type: 'audio',
            data: audioBase64,
            mime_type: mimeType,
          },
        ],
      }),
    });

    const text = extractInteractionText(data).trim();
    if (!text) {
      return sendJson(res, 422, {error: 'Não foi possível entender a gravação.'});
    }
    return sendJson(res, 200, {text});
  };

  const handleAssistant = async (req, res) => {
    const body = await readJson(req);
    const message = String(body.message ?? '').trim();
    if (!message) return sendJson(res, 400, {error: 'Digite uma mensagem.'});

    const events = Array.isArray(body.events) ? body.events.slice(0, 50) : [];
    const tasks = Array.isArray(body.tasks) ? body.tasks.slice(0, 50) : [];
    const materials = Array.isArray(body.materials)
      ? body.materials.slice(0, 100).map((item) => ({
          name: String(item?.name ?? '').trim(),
          displayName: String(item?.displayName ?? '').trim(),
          category: String(item?.category ?? '').trim(),
        })).filter((item) => item.name || item.displayName)
      : [];
    const previousInteractionId = String(body.previousInteractionId ?? '').trim();
    const studyPlanRequested = /(?:blocos?|sess(?:ão|ões)|plano de estudos?|separ|divid|distribu)/i.test(message)
      && /(?:estud|prova|revis|horas?|tempo)/i.test(message);

    let fileSearchStore = null;
    if (materials.length > 0) {
      fileSearchStore = await ensureFileSearchStore();
    }

    const prompt = [
      'Você é o assistente de uma Agenda Inteligente acadêmica.',
      'Responda em português do Brasil, de forma curta e prática.',
      'Classifique a ação como none, event, task ou study_plan.',
      'Use action=task quando o usuário pedir para criar/adicionar uma tarefa, atividade, dever, estudo ou lembrete.',
      'Tarefas PODEM ter data e horário. Se o usuário informar um horário, preserve EXATAMENTE esse horário local em task_due_time no formato HH:mm. Não converta fuso e não some/subtraia horas.',
      'Se a tarefa tiver data mas nenhum horário informado, deixe task_due_time vazio. Não invente horário.',
      'Use task_due_date no formato YYYY-MM-DD quando houver uma data/prazo claro.',
      'Use action=event para compromissos com duração/intervalo, como aula, consulta, prova com horário, reunião ou evento.',
      'Use action=study_plan quando o usuário pedir para separar, dividir ou distribuir tempo de estudo em blocos/sessões, ou pedir um plano de estudos com horários.',
      'Quando action=study_plan, devolva study_blocks com vários blocos de estudo. Cada bloco deve ter title, start, end e description.',
      'Os blocos de estudo são compromissos reais da agenda: use horários locais em ISO 8601 completo com offset e duração maior que zero.',
      'Respeite os EVENTOS já existentes e NÃO crie blocos que se sobreponham a eles nem entre si.',
      'Se houver uma prova ou prazo no contexto, distribua os blocos ANTES dela. Nunca coloque bloco depois da prova/prazo.',
      'Se o usuário informar um total de estudo, tente fazer a soma dos blocos atingir esse total. Prefira blocos de 45 a 120 minutos, salvo se o usuário pedir outra duração.',
      'Se o pedido de blocos não tiver informações suficientes e o contexto anterior também não tiver, use action=none e pergunte o que falta (por exemplo data da prova ou quantidade de horas).',
      'Se não houver dados suficientes, use action=none e explique o que falta; não invente data nem horário.',
      'Para eventos, preserve o horário local informado pelo usuário.',
      'Prioridade de tarefa deve ser alta, media ou baixa. Use media quando o usuário não indicar prioridade.',
      'Você também pode consultar os PDFs enviados pelo usuário quando eles estiverem disponíveis no File Search.',
      'Quando a pergunta mencionar um PDF, apostila, material, capítulo, documento ou conteúdo estudado, use o File Search para responder com base nesses materiais.',
      'Se o usuário citar o nome de um PDF, priorize esse documento. Se não encontrar a resposta nos materiais, diga claramente que não encontrou; não invente conteúdo.',
      'Perguntas sobre PDFs normalmente usam action=none, a menos que o usuário também peça explicitamente para criar evento ou tarefa.',
      `DATA_LOCAL_ATUAL=${String(body.today ?? '')}`,
      `OFFSET_FUSO_MINUTOS=${Number(body.timezoneOffsetMinutes ?? 0)}`,
      `EVENTOS=${JSON.stringify(events)}`,
      `TAREFAS=${JSON.stringify(tasks)}`,
      `MATERIAIS_DISPONIVEIS=${JSON.stringify(materials)}`,
      `PEDIDO_DE_PLANO_DE_ESTUDO=${studyPlanRequested}`,
      `MENSAGEM=${message}`,
    ].join('\n');

    const interactionBody = {
      model,
      input: prompt,
      response_format: {
        type: 'text',
        mime_type: 'application/json',
        schema: {
          type: 'object',
          properties: {
            reply: {type: 'string'},
            action: {type: 'string', enum: ['none', 'event', 'task', 'study_plan']},
            event_title: {type: 'string'},
            event_start: {type: 'string', description: 'ISO 8601 completo com offset quando action=event.'},
            event_end: {type: 'string', description: 'ISO 8601 completo com offset quando action=event.'},
            event_description: {type: 'string'},
            event_location: {type: 'string'},
            task_title: {type: 'string'},
            task_due_date: {type: 'string', description: 'YYYY-MM-DD. Vazio se não houver data/prazo.'},
            task_due_time: {type: 'string', description: 'HH:mm em horário local. Vazio se o usuário não informou horário.'},
            task_priority: {type: 'string', enum: ['alta', 'media', 'baixa']},
            study_blocks: {
              type: 'array',
              description: 'Blocos de estudo quando action=study_plan. Use [] nas demais ações.',
              items: {
                type: 'object',
                properties: {
                  title: {type: 'string'},
                  start: {type: 'string', description: 'ISO 8601 completo com offset.'},
                  end: {type: 'string', description: 'ISO 8601 completo com offset.'},
                  description: {type: 'string'},
                },
                required: ['title', 'start', 'end', 'description'],
              },
            },
          },
          required: [
            'reply', 'action',
            'event_title', 'event_start', 'event_end', 'event_description', 'event_location',
            'task_title', 'task_due_date', 'task_due_time', 'task_priority', 'study_blocks'
          ],
        },
      },
    };
    if (previousInteractionId) interactionBody.previous_interaction_id = previousInteractionId;
    if (fileSearchStore?.name) {
      interactionBody.tools = [{
        type: 'file_search',
        file_search_store_names: [fileSearchStore.name],
      }];
    }

    const {data} = await geminiFetch('/v1beta/interactions', {
      method: 'POST',
      body: JSON.stringify(interactionBody),
    });
    const text = extractInteractionText(data);
    let parsed;
    try {
      parsed = JSON.parse(text);
    } catch {
      parsed = {reply: text || 'Resposta recebida.', action: 'none'};
    }

    let suggestedEvent = null;
    let suggestedTask = null;
    let suggestedStudyBlocks = [];
    if (parsed.action === 'event') {
      const start = safeIso(parsed.event_start);
      const end = safeIso(parsed.event_end);
      if (start && end && end > start && String(parsed.event_title ?? '').trim()) {
        suggestedEvent = {
          title: String(parsed.event_title).trim(),
          start: start.toISOString(),
          end: end.toISOString(),
          description: String(parsed.event_description ?? '').trim(),
          location: String(parsed.event_location ?? '').trim(),
        };
      }
    }

    if (parsed.action === 'task') {
      const title = String(parsed.task_title ?? '').trim();
      const dueDate = normalizeDateOnly(parsed.task_due_date);
      const dueTime = normalizeLocalTime(parsed.task_due_time);
      if (title) {
        suggestedTask = {
          title,
          deadlineDate: dueDate,
          deadlineTime: dueTime,
          deadlineHasTime: Boolean(dueDate && dueTime),
          priority: ['alta', 'media', 'baixa'].includes(parsed.task_priority) ? parsed.task_priority : 'media',
        };
      }
    }

    if (parsed.action === 'study_plan' && Array.isArray(parsed.study_blocks)) {
      const occupied = events
        .map((event) => ({
          start: safeIso(event?.start),
          end: safeIso(event?.end),
        }))
        .filter((event) => event.start && event.end && event.end > event.start);

      for (const rawBlock of parsed.study_blocks.slice(0, 12)) {
        const start = safeIso(rawBlock?.start);
        const end = safeIso(rawBlock?.end);
        const title = String(rawBlock?.title ?? '').trim();
        if (!start || !end || end <= start || !title) continue;

        const conflictsExisting = occupied.some((event) => start < event.end && end > event.start);
        const conflictsSuggested = suggestedStudyBlocks.some((block) => {
          const blockStart = new Date(block.start);
          const blockEnd = new Date(block.end);
          return start < blockEnd && end > blockStart;
        });
        if (conflictsExisting || conflictsSuggested) continue;

        suggestedStudyBlocks.push({
          title,
          start: start.toISOString(),
          end: end.toISOString(),
          description: String(rawBlock?.description ?? '').trim(),
          location: '',
        });
      }
    }

    return sendJson(res, 200, {
      text: String(parsed.reply ?? 'Resposta recebida.'),
      suggestedEvent,
      suggestedTask,
      suggestedStudyBlocks,
      interactionId: data.id ?? null,
      usage: data.usage ?? null,
      model: data.model ?? model,
      fileSearchEnabled: Boolean(fileSearchStore?.name),
      fileSearchStoreName: fileSearchStore?.name ?? null,
    });
  };

  const handleListMaterials = async (_req, res) => {
    const {data} = await geminiFetch('/v1beta/files', {method: 'GET'});
    return sendJson(res, 200, {files: Array.isArray(data.files) ? data.files : []});
  };

  const handleUploadMaterial = async (req, res) => {
    const part = await parseSingleMultipartFile(req, 22 * 1024 * 1024);
    if (!part) return sendJson(res, 400, {error: 'Envie um arquivo no campo "file".'});
    const isPdf = part.mimeType === 'application/pdf' || part.filename.toLowerCase().endsWith('.pdf');
    if (!isPdf) return sendJson(res, 400, {error: 'Somente arquivos PDF são aceitos nesta versão.'});
    if (part.data.length > 20 * 1024 * 1024) return sendJson(res, 413, {error: 'O PDF deve ter no máximo 20 MB.'});

    const uploaded = await uploadGeminiFile({
      apiKey,
      fetchImpl,
      data: part.data,
      mimeType: 'application/pdf',
      displayName: part.filename,
    });

    let fileSearch = null;
    try {
      fileSearch = await importFileToSearch(uploaded.name);
    } catch (error) {
      fileSearch = {warning: error.message};
    }

    return sendJson(res, 201, {file: uploaded, fileSearch});
  };

  const handleDeleteMaterial = async (req, res, fileName) => {
    validateFileName(fileName);
    await geminiFetch(`/v1beta/${fileName}`, {method: 'DELETE'});
    return sendJson(res, 200, {ok: true});
  };

  const handleSummary = async (req, res) => {
    const body = await readJson(req);
    const fileName = String(body.fileName ?? '').trim();
    validateFileName(fileName);
    const file = await getActiveFile(geminiFetch, fileName);
    const {data} = await geminiFetch(`/v1beta/models/${encodeURIComponent(model)}:generateContent`, {
      method: 'POST',
      body: JSON.stringify({
        contents: [{
          role: 'user',
          parts: [
            {text: 'Faça um resumo de estudo deste PDF em português do Brasil. Use tópicos curtos, destaque conceitos principais e finalize com 5 pontos para revisão.'},
            {fileData: {mimeType: file.mimeType || 'application/pdf', fileUri: file.uri, displayName: file.displayName}},
          ],
        }],
      }),
    });
    return sendJson(res, 200, {text: extractGenerateText(data), usageMetadata: data.usageMetadata ?? null});
  };

  const handleAskMaterial = async (req, res) => {
    const body = await readJson(req);
    const fileName = String(body.fileName ?? '').trim();
    const question = String(body.question ?? '').trim();
    validateFileName(fileName);
    if (!question) return sendJson(res, 400, {error: 'Digite uma pergunta.'});

    const file = await getActiveFile(geminiFetch, fileName);
    const store = await ensureFileSearchStore();
    const prompt = `Responda em português do Brasil com base nos materiais da biblioteca. A pergunta foi feita sobre o arquivo "${file.displayName || fileName}". Se a resposta não estiver nos materiais, diga isso. Pergunta: ${question}`;
    const {data} = await geminiFetch('/v1beta/interactions', {
      method: 'POST',
      body: JSON.stringify({
        model,
        input: prompt,
        tools: [{type: 'file_search', file_search_store_names: [store.name]}],
      }),
    });
    return sendJson(res, 200, {text: extractInteractionText(data), interactionId: data.id ?? null});
  };

  return async function requestHandler(req, res) {
    try {
      if (req.method === 'OPTIONS') return sendEmpty(res, 204);

      const requestUrl = new URL(req.url, 'http://localhost');
      const pathname = requestUrl.pathname;

      if (req.method === 'GET' && pathname === '/health') {
        return sendJson(res, 200, {
          ok: true,
          apiKeyConfigured: Boolean(apiKey && apiKey !== 'COLOQUE_SUA_API_KEY_AQUI'),
          model,
        });
      }
      if (req.method === 'POST' && pathname === '/api/gemini/assistant') return await handleAssistant(req, res);
      if (req.method === 'POST' && pathname === '/api/gemini/transcribe-audio') return await handleTranscribeAudio(req, res);
      if (req.method === 'GET' && pathname === '/api/materials') return await handleListMaterials(req, res);
      if (req.method === 'POST' && pathname === '/api/materials/upload') return await handleUploadMaterial(req, res);
      if (req.method === 'POST' && pathname === '/api/materials/summary') return await handleSummary(req, res);
      if (req.method === 'POST' && pathname === '/api/materials/ask') return await handleAskMaterial(req, res);

      const materialDeleteMatch = pathname.match(/^\/api\/materials\/(.+)$/);
      if (req.method === 'DELETE' && materialDeleteMatch) {
        return await handleDeleteMaterial(req, res, decodeURIComponent(materialDeleteMatch[1]));
      }

      return sendJson(res, 404, {error: 'Rota não encontrada.'});
    } catch (error) {
      return sendJson(res, Number(error.statusCode) || 500, {
        error: error.message || 'Erro interno.',
      });
    }
  };
}

export function extractGenerateText(data) {
  const parts = data?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return '';
  return parts.map((part) => (typeof part?.text === 'string' ? part.text : '')).join('').trim();
}

export function extractInteractionText(data) {
  const texts = [];
  if (Array.isArray(data?.steps)) {
    for (const step of data.steps) {
      if (!Array.isArray(step?.content)) continue;
      for (const item of step.content) {
        if (typeof item?.text === 'string') texts.push(item.text);
      }
    }
  }
  if (texts.length) return texts.join('').trim();
  if (typeof data?.output_text === 'string') return data.output_text.trim();
  if (typeof data?.outputText === 'string') return data.outputText.trim();
  return '';
}

export async function readJson(req, maxBytes = 2 * 1024 * 1024) {
  const buffer = await readBody(req, maxBytes);
  if (!buffer.length) return {};
  try {
    return JSON.parse(buffer.toString('utf8'));
  } catch {
    const error = new Error('JSON inválido no corpo da requisição.');
    error.statusCode = 400;
    throw error;
  }
}

export async function readBody(req, maxBytes) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > maxBytes) {
      const error = new Error('Corpo da requisição grande demais.');
      error.statusCode = 413;
      throw error;
    }
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

export async function parseSingleMultipartFile(req, maxBytes) {
  const contentType = String(req.headers['content-type'] ?? '');
  const boundaryMatch = contentType.match(/boundary=(?:"([^"]+)"|([^;]+))/i);
  if (!boundaryMatch) {
    const error = new Error('Content-Type multipart/form-data inválido.');
    error.statusCode = 400;
    throw error;
  }
  const boundary = boundaryMatch[1] || boundaryMatch[2];
  const body = await readBody(req, maxBytes);
  const marker = Buffer.from(`--${boundary}`);
  let cursor = 0;

  while (true) {
    const start = body.indexOf(marker, cursor);
    if (start < 0) break;
    const headerStart = start + marker.length + 2;
    const headerEnd = body.indexOf(Buffer.from('\r\n\r\n'), headerStart);
    if (headerEnd < 0) break;
    const nextBoundary = body.indexOf(marker, headerEnd + 4);
    if (nextBoundary < 0) break;

    const headers = body.slice(headerStart, headerEnd).toString('utf8');
    const disposition = headers.match(/content-disposition:\s*form-data;[^\r\n]*name="([^"]+)"[^\r\n]*filename="([^"]*)"/i);
    if (disposition && disposition[1] === 'file') {
      const mimeMatch = headers.match(/content-type:\s*([^\r\n]+)/i);
      let dataEnd = nextBoundary;
      if (body[dataEnd - 2] === 13 && body[dataEnd - 1] === 10) dataEnd -= 2;
      return {
        fieldName: disposition[1],
        filename: sanitizeDisplayName(disposition[2] || 'arquivo.pdf'),
        mimeType: (mimeMatch?.[1] || 'application/octet-stream').trim(),
        data: body.slice(headerEnd + 4, dataEnd),
      };
    }
    cursor = nextBoundary;
  }
  return null;
}

export async function uploadGeminiFile({apiKey, fetchImpl, data, mimeType, displayName}) {
  if (!apiKey || apiKey === 'COLOQUE_SUA_API_KEY_AQUI') {
    const error = new Error('A chave da Gemini ainda não foi configurada em backend/.env.');
    error.statusCode = 503;
    throw error;
  }
  const startResponse = await fetchImpl(`${GEMINI_BASE_URL}/upload/v1beta/files`, {
    method: 'POST',
    headers: {
      'x-goog-api-key': apiKey,
      'X-Goog-Upload-Protocol': 'resumable',
      'X-Goog-Upload-Command': 'start',
      'X-Goog-Upload-Header-Content-Length': String(data.length),
      'X-Goog-Upload-Header-Content-Type': mimeType,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({file: {display_name: displayName}}),
  });
  if (!startResponse.ok) {
    const payload = await safeJson(startResponse);
    const error = new Error(payload?.error?.message || `Falha ao iniciar upload (${startResponse.status}).`);
    error.statusCode = startResponse.status;
    throw error;
  }
  const uploadUrl = startResponse.headers.get('x-goog-upload-url');
  if (!uploadUrl) throw new Error('A Gemini não retornou a URL de upload.');

  const uploadResponse = await fetchImpl(uploadUrl, {
    method: 'POST',
    headers: {
      'Content-Length': String(data.length),
      'X-Goog-Upload-Offset': '0',
      'X-Goog-Upload-Command': 'upload, finalize',
    },
    body: data,
  });
  const payload = await safeJson(uploadResponse);
  if (!uploadResponse.ok) {
    const error = new Error(payload?.error?.message || `Falha no upload (${uploadResponse.status}).`);
    error.statusCode = uploadResponse.status;
    throw error;
  }
  if (!payload?.file?.name) throw new Error('Resposta de upload sem metadados do arquivo.');
  return payload.file;
}

async function getActiveFile(geminiFetch, fileName) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const {data} = await geminiFetch(`/v1beta/${fileName}`, {method: 'GET'});
    const state = String(data.state ?? 'ACTIVE').toUpperCase();
    if (state === 'ACTIVE' || !data.state) return data;
    if (state === 'FAILED') throw new Error('A Gemini não conseguiu processar este arquivo.');
    await delay(1500);
  }
  throw new Error('O arquivo ainda está sendo processado. Tente novamente em alguns segundos.');
}

function validateFileName(fileName) {
  if (!fileName.startsWith('files/') || fileName.includes('..')) {
    const error = new Error('Identificador de arquivo inválido.');
    error.statusCode = 400;
    throw error;
  }
}

function normalizeDateOnly(value) {
  const text = String(value ?? '').trim();
  const match = text.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) return null;
  return `${match[1]}-${match[2]}-${match[3]}`;
}

function normalizeLocalTime(value) {
  const text = String(value ?? '').trim();
  if (!text) return null;
  const match = text.match(/^(\d{2}):(\d{2})$/);
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return `${match[1]}:${match[2]}`;
}

function safeIso(value) {
  const date = new Date(String(value ?? ''));
  return Number.isNaN(date.getTime()) ? null : date;
}

function sanitizeDisplayName(value) {
  return path.basename(String(value)).replace(/[\r\n]/g, '').slice(0, 255) || 'arquivo.pdf';
}

function setCommonHeaders(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
}

export function sendJson(res, statusCode, data) {
  setCommonHeaders(res);
  res.statusCode = statusCode;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.end(JSON.stringify(data));
}

function sendEmpty(res, statusCode) {
  setCommonHeaders(res);
  res.statusCode = statusCode;
  res.end();
}

function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function safeJson(response) {
  try {
    return await response.json();
  } catch {
    return {};
  }
}
