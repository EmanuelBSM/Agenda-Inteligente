# Sobre a Agenda Inteligente com Gemini

A Agenda Inteligente com Gemini é um aplicativo desenvolvido em Flutter, com backend em Node.js e integração com a API Google Gemini, voltado à organização da rotina acadêmica.
O sistema permite gerenciar eventos e tarefas, visualizar compromissos no calendário, identificar conflitos de horários e utilizar inteligência artificial para criar sugestões e organizar planos de estudo em blocos. Também oferece suporte a arquivos PDF, permitindo gerar resumos e fazer perguntas sobre os materiais em conversas individuais com a IA.
Os dados são armazenados localmente em SQLite, com sistema de cadastro, login e persistência da sessão do usuário.

## Funcionalidades

- Autenticação: cadastro, login, redefinição local de senha e persistência da sessão do usuário.
- Agenda e calendário: criação, edição e exclusão de eventos, com verificação de conflitos de horários.
- Gerenciamento de tarefas: criação, edição e exclusão de tarefas, com data, horário, prioridade e status de conclusão.
- Assistente com Gemini: chat com inteligência artificial para auxiliar na organização da rotina acadêmica.
- Chat por voz: conversão de fala em texto para enviar mensagens à Gemini.
- Conversas individuais: chats separados, com histórico armazenado localmente.
- Planejamento de estudos: organização dos estudos em blocos de horário sugeridos pela IA.
- Gerenciamento de PDFs: envio e exclusão de materiais, geração de resumos e perguntas sobre o conteúdo.
- PDFs por conversa: seleção dos documentos utilizados como contexto em cada chat, com integração ao Gemini File Search.
- Persistência local: armazenamento de usuários, eventos, tarefas, materiais e conversas utilizando SQLite.
- Interface responsiva: telas adaptadas para desktop e dispositivos móveis.

## Requisitos
- Flutter 3.19 ou superior
- Dart 3.3 ou superior
- Node.js 20+
- Uma chave da Gemini API
- Conexão com a internet
- Microfone para usar o chat por voz

### Para Windows

- Visual Studio com o workload `Desktop development with C++`
- Permissão de acesso ao microfone ativada no Windows

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
