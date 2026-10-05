import http from 'node:http';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

import {createRequestHandler, loadEnvFile} from './src/app.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
loadEnvFile(path.join(__dirname, '.env'));

const port = Number(process.env.PORT || 3000);
const handler = createRequestHandler();
const server = http.createServer(handler);

server.listen(port, '0.0.0.0', () => {
  const configured = Boolean(process.env.GEMINI_API_KEY && process.env.GEMINI_API_KEY !== 'COLOQUE_SUA_API_KEY_AQUI');
  console.log(`Agenda Inteligente API: http://localhost:${port}`);
  console.log(`Gemini API key configurada: ${configured ? 'sim' : 'não'}`);
  console.log(`Modelo: ${process.env.GEMINI_MODEL || 'gemini-3.8-flash'}`);
});
