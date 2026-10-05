# Agenda Inteligente com Gemini

Esta versão já possui as principais funcionalidades, mas está sem banco de dados.

## O que falta fazer

- Login e cadastro
- Contas de usuário
- Persistência de eventos
- Persistência de tarefas
- Persistência de conversas
- Fazer e Testar versão mobile


## O que já possui

- Tela inicial
- Calendário
- Criação e exclusão de eventos
- Tarefas com data, horário e prioridade
- Chat com Gemini
- Conversas separadas durante a sessão
- Sugestão de eventos e tarefas pela IA
- Plano de estudos em blocos
- Upload de PDF
- Resumo de PDF
- Perguntas sobre PDF

## Requisitos
- Flutter 3.19 ou superior
- Dart 3.3 ou superior
- Node.js 20+
- Uma chave da Gemini API

## 1. Configurar a chave

Entre em `backend` e copie `.env.example` para `.env` se necessário.

Preencha:

```env
GEMINI_API_KEY=SUA_CHAVE_AQUI
GEMINI_MODEL=gemini-3.5-flash-lite
PORT=3000
```

## 2. Rodar o backend

```bash
cd backend
node server.js
```

Teste no navegador:

```text
http://localhost:3000/health
```

## 3. Preparar o Flutter

Na pasta `flutter_app`:

```bash
flutter pub get
```

Depois rode normalmente:

```bash
flutter run
```

Para Windows, se quiser selecionar explicitamente:

```bash
flutter run -d windows
```
