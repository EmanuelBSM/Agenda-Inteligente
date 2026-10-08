import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/agenda_event.dart';
import '../models/agenda_task.dart';
import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import '../services/api_service.dart';
import '../state/app_store.dart';
import '../widgets/formatters.dart';

class AssistantTab extends StatefulWidget {
  const AssistantTab({
    super.key,
    required this.store,
    required this.apiService,
  });

  final AppStore store;
  final ApiService apiService;

  @override
  State<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<AssistantTab> {
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  final speechToText = stt.SpeechToText();
  final audioRecorder = AudioRecorder();
  String? selectedThreadId;
  bool sending = false;
  bool speechReady = false;
  bool listening = false;
  bool transcribingVoice = false;
  String voiceBaseText = '';

  @override
  void dispose() {
    speechToText.cancel();
    audioRecorder.dispose();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  ChatThread? get selectedThread =>
      selectedThreadId == null ? null : widget.store.threadById(selectedThreadId!);

  void _newChat() {
    final thread = widget.store.createThread();
    setState(() => selectedThreadId = thread.id);
  }

  void _openThread(String threadId) {
    setState(() => selectedThreadId = threadId);
    _scrollToBottom();
  }

  Future<void> _send() async {
    if (Platform.isWindows && listening) {
      await audioRecorder.cancel();
      if (mounted) setState(() => listening = false);
    } else if (speechToText.isListening) {
      await speechToText.stop();
      if (mounted) setState(() => listening = false);
    }
    final thread = selectedThread;
    final text = messageController.text.trim();
    if (thread == null || text.isEmpty || sending) return;
    messageController.clear();

    widget.store.addMessage(
      ChatMessage(
        id: 'user-${DateTime.now().microsecondsSinceEpoch}',
        threadId: thread.id,
        text: text,
        fromUser: true,
        createdAt: DateTime.now(),
      ),
    );
    setState(() => sending = true);
    _scrollToBottom();

    try {
      final currentThread = widget.store.threadById(thread.id);
      final selectedNames = currentThread?.selectedMaterialNames.toSet() ?? const <String>{};
      final selectedMaterials = widget.store.materials
          .where((item) => item.remote && selectedNames.contains(item.name))
          .toList();
      final reply = await widget.apiService.assistant(
        message: text,
        events: widget.store.events,
        tasks: widget.store.tasks,
        materials: selectedMaterials,
        previousInteractionId: currentThread?.previousInteractionId,
      );
      if (reply.interactionId != null && reply.interactionId!.isNotEmpty) {
        widget.store.updateThreadInteraction(thread.id, reply.interactionId);
      }
      widget.store.addMessage(
        ChatMessage(
          id: 'assistant-${DateTime.now().microsecondsSinceEpoch}',
          threadId: thread.id,
          text: reply.text,
          fromUser: false,
          createdAt: DateTime.now(),
          suggestedEvent: reply.suggestedEvent,
          suggestedTask: reply.suggestedTask,
          suggestedStudyBlocks: reply.suggestedStudyBlocks,
        ),
      );
    } on ApiException catch (error) {
      widget.store.addMessage(
        ChatMessage(
          id: 'error-${DateTime.now().microsecondsSinceEpoch}',
          threadId: thread.id,
          text: error.message,
          fromUser: false,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {
      widget.store.addMessage(
        ChatMessage(
          id: 'error-${DateTime.now().microsecondsSinceEpoch}',
          threadId: thread.id,
          text: 'Não consegui falar com o backend. Confira se ele está rodando.',
          fromUser: false,
          createdAt: DateTime.now(),
        ),
      );
    } finally {
      if (mounted) setState(() => sending = false);
      _scrollToBottom();
    }
  }

  Future<void> _toggleVoiceInput() async {
    if (sending || transcribingVoice) return;

    if (Platform.isWindows) {
      await _toggleWindowsVoiceInput();
      return;
    }

    if (speechToText.isListening) {
      await speechToText.stop();
      if (mounted) setState(() => listening = false);
      return;
    }

    if (!speechReady) {
      final available = await speechToText.initialize(
        onStatus: (_) {
          if (mounted) setState(() => listening = speechToText.isListening);
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => listening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível usar o microfone: ${error.errorMsg}')),
          );
        },
      );
      if (!mounted) return;
      speechReady = available;
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reconhecimento de voz indisponível ou sem permissão de microfone.')),
        );
        return;
      }
    }

    voiceBaseText = messageController.text.trimRight();
    await speechToText.listen(
      onResult: (result) {
        final spoken = result.recognizedWords.trim();
        final prefix = voiceBaseText.isEmpty ? '' : '$voiceBaseText ';
        final value = '$prefix$spoken'.trimRight();
        messageController.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
        if (mounted) setState(() => listening = speechToText.isListening);
      },
    );
    if (mounted) setState(() => listening = speechToText.isListening);
  }

  Future<void> _toggleWindowsVoiceInput() async {
    if (listening) {
      String? path;
      try {
        path = await audioRecorder.stop();
      } catch (_) {
        if (mounted) setState(() => listening = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não consegui finalizar a gravação.')),
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        listening = false;
        transcribingVoice = true;
      });

      if (path == null || path.isEmpty) {
        setState(() => transcribingVoice = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A gravação ficou vazia.')),
        );
        return;
      }

      final file = File(path);
      try {
        final spoken = await widget.apiService.transcribeAudio(file);
        final previous = messageController.text.trimRight();
        final value = previous.isEmpty ? spoken : '$previous $spoken';
        messageController.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error.message)),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Não consegui transcrever a gravação. Confira o backend.')),
          );
        }
      } finally {
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
        if (mounted) setState(() => transcribingVoice = false);
      }
      return;
    }

    try {
      final temp = await getTemporaryDirectory();
      final path = '${temp.path}${Platform.pathSeparator}agenda_voice_${DateTime.now().microsecondsSinceEpoch}.wav';
      await audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
      if (mounted) setState(() => listening = true);
    } catch (_) {
      if (mounted) {
        setState(() => listening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não consegui acessar o microfone do Windows. Verifique a permissão de microfone.'),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final thread = selectedThread;
        if (thread == null) return _buildThreadList();
        return _buildConversation(thread);
      },
    );
  }

  Widget _buildThreadList() {
    final threads = widget.store.threads;
    return SafeArea(
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Conversas com Gemini', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    key: const Key('assistant-new-chat-top'),
                    tooltip: 'Nova conversa',
                    onPressed: _newChat,
                    icon: const Icon(Icons.edit_note_rounded, size: 27),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Cada assunto fica em uma conversa separada.',
                style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 15),
              ),
              const SizedBox(height: 18),
              if (threads.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F6F6),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 42, color: Color(0xFF4A4A4A)),
                      SizedBox(height: 12),
                      Text('Nenhuma conversa ainda.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      SizedBox(height: 5),
                      Text('Crie uma conversa para começar.', style: TextStyle(color: Color(0xFF777777))),
                    ],
                  ),
                )
              else
                ...threads.map((thread) {
                  final messages = widget.store.messagesForThread(thread.id);
                  final preview = messages.isEmpty ? 'Conversa vazia' : messages.last.text;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      key: Key('thread-${thread.id}'),
                      onTap: () => _openThread(thread.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE1E1E1)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(color: Color(0xFFF0F0F0), shape: BoxShape.circle),
                              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF4A4A4A)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(thread.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF777777))),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'delete') await widget.store.deleteThread(thread.id);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'delete', child: Text('Excluir conversa')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
          Positioned(
            right: 22,
            bottom: 20,
            child: FloatingActionButton(
              key: const Key('assistant-new-chat'),
              onPressed: _newChat,
              backgroundColor: const Color(0xFF3A3A3A),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_rounded, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversation(ChatThread thread) {
    final messages = widget.store.messagesForThread(thread.id);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const Key('assistant-back-to-chats'),
                      onPressed: () => setState(() => selectedThreadId = null),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        thread.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (value) async {
                        if (value == 'clear') {
                          await widget.store.clearMessages(thread.id);
                        } else if (value == 'delete') {
                          await widget.store.deleteThread(thread.id);
                          if (mounted) setState(() => selectedThreadId = null);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'clear', child: Text('Limpar mensagens')),
                        PopupMenuItem(value: 'delete', child: Text('Excluir conversa')),
                      ],
                    ),
                  ],
                ),
                if (widget.store.materials.where((item) => item.remote).isNotEmpty)
                  Align(
                    alignment: Alignment.center,
                    child: TextButton.icon(
                      key: const Key('assistant-pdf-access'),
                      onPressed: _showAvailablePdfs,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(
                        '${thread.selectedMaterialNames.where((name) => widget.store.materials.any((item) => item.remote && item.name == name)).length} PDF(s) vinculados a esta conversa',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: messages.isEmpty && !sending
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Comece uma nova conversa com a Gemini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF777777), fontSize: 16),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                    itemCount: messages.length + (sending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (sending && index == messages.length) return const _TypingBubble();
                      final message = messages[index];
                      return _MessageBubble(
                        message: message,
                        onCreateEvent: message.suggestedEvent == null ? null : () => _createSuggestedEvent(message.suggestedEvent!),
                        onCreateTask: message.suggestedTask == null ? null : () => _createSuggestedTask(message.suggestedTask!),
                        onCreateStudyPlan: message.suggestedStudyBlocks.isEmpty
                            ? null
                            : () => _createStudyPlan(message.suggestedStudyBlocks),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE4E4E4))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('assistant-input'),
                    controller: messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Digite sua mensagem...',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: IconButton.filledTonal(
                    key: const Key('assistant-mic'),
                    tooltip: transcribingVoice
                        ? 'Transcrevendo...'
                        : (listening ? 'Parar gravação' : 'Falar mensagem'),
                    onPressed: (sending || transcribingVoice) ? null : _toggleVoiceInput,
                    style: IconButton.styleFrom(
                      backgroundColor: listening ? const Color(0xFFFFE4E4) : const Color(0xFFF0F0F0),
                      foregroundColor: listening ? const Color(0xFFB42318) : const Color(0xFF3E3E3E),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: transcribingVoice
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(listening ? Icons.stop_circle_outlined : Icons.mic_none_rounded),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: FilledButton(
                    key: const Key('assistant-send'),
                    onPressed: sending ? null : _send,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: const Color(0xFF4A4A4A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Icon(Icons.send_rounded),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAvailablePdfs() async {
    final thread = selectedThread;
    final materials = widget.store.materials.where((item) => item.remote).toList();
    if (thread == null || materials.isEmpty) return;

    final availableNames = materials.map((item) => item.name).toSet();
    final initial = thread.selectedMaterialNames.where(availableNames.contains).toSet();
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final checked = Set<String>.from(initial);
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'PDFs desta conversa',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'A Gemini pesquisará somente nos PDFs marcados. Alterar esta seleção reinicia o contexto interno da IA para evitar mistura entre materiais.',
                    style: TextStyle(color: Color(0xFF6B6B6B)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setSheetState(() {
                          checked
                            ..clear()
                            ..addAll(availableNames);
                        }),
                        child: const Text('Selecionar todos'),
                      ),
                      TextButton(
                        onPressed: () => setSheetState(checked.clear),
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView(
                      shrinkWrap: true,
                      children: materials
                          .map(
                            (item) => CheckboxListTile(
                              value: checked.contains(item.name),
                              contentPadding: EdgeInsets.zero,
                              secondary: const Icon(Icons.picture_as_pdf_outlined),
                              title: Text(item.displayName),
                              subtitle: item.category == 'Todos' ? null : Text(item.category),
                              onChanged: (value) => setSheetState(() {
                                if (value == true) {
                                  checked.add(item.name);
                                } else {
                                  checked.remove(item.name);
                                }
                              }),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('assistant-save-pdfs'),
                      onPressed: () => Navigator.pop(context, Set<String>.from(checked)),
                      child: const Text('Usar estes PDFs'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    widget.store.updateThreadMaterials(thread.id, selected.toList());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selected.isEmpty
              ? 'Esta conversa não usará PDFs.'
              : '${selected.length} PDF(s) vinculados. O contexto da Gemini foi reiniciado.',
        ),
      ),
    );
  }

  void _createSuggestedEvent(AgendaEvent event) {
    if (widget.store.hasConflict(event)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Existe outro compromisso nesse horário. Revise o calendário antes de confirmar.')),
      );
      return;
    }
    widget.store.addEvent(event);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${event.title} adicionado ao calendário.')));
  }

  void _createSuggestedTask(AgendaTask task) {
    widget.store.addTask(task);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${task.title} adicionada às tarefas.')));
  }

  void _createStudyPlan(List<AgendaEvent> blocks) {
    final conflicting = blocks.where(widget.store.hasConflict).toList();
    if (conflicting.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            conflicting.length == 1
                ? 'Um bloco de estudo conflita com a agenda atual. Peça para a Gemini reorganizar o plano.'
                : '${conflicting.length} blocos de estudo conflitam com a agenda atual. Peça para a Gemini reorganizar o plano.',
          ),
        ),
      );
      return;
    }

    for (final block in blocks) {
      widget.store.addEvent(block);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${blocks.length} bloco(s) de estudo adicionados ao calendário.')),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.onCreateEvent,
    this.onCreateTask,
    this.onCreateStudyPlan,
  });

  final ChatMessage message;
  final VoidCallback? onCreateEvent;
  final VoidCallback? onCreateTask;
  final VoidCallback? onCreateStudyPlan;

  @override
  Widget build(BuildContext context) {
    if (message.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 310),
          margin: const EdgeInsets.only(bottom: 14, left: 56),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(message.text, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(formatTime(message.createdAt), style: const TextStyle(fontSize: 12, color: Color(0xFF777777))),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14, right: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: Color(0xFF4B4B4B), shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.text, style: const TextStyle(fontSize: 16, height: 1.35)),
                  const SizedBox(height: 4),
                  Text(formatTime(message.createdAt), style: const TextStyle(fontSize: 12, color: Color(0xFF777777))),
                  if (message.suggestedEvent != null) ...[
                    const SizedBox(height: 14),
                    _SuggestedEventCard(event: message.suggestedEvent!),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: onCreateEvent,
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF424242)),
                        child: const Text('Criar evento', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                  if (message.suggestedTask != null) ...[
                    const SizedBox(height: 14),
                    _SuggestedTaskCard(task: message.suggestedTask!),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        key: const Key('create-suggested-task'),
                        onPressed: onCreateTask,
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF424242)),
                        child: const Text('Criar tarefa', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                  if (message.suggestedStudyBlocks.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _SuggestedStudyPlanCard(blocks: message.suggestedStudyBlocks),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        key: const Key('create-study-plan'),
                        onPressed: onCreateStudyPlan,
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF424242)),
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: const Text('Adicionar blocos à agenda', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedStudyPlanCard extends StatelessWidget {
  const _SuggestedStudyPlanCard({required this.blocks});

  final List<AgendaEvent> blocks;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = blocks.fold<int>(0, (sum, block) => sum + block.end.difference(block.start).inMinutes);
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final totalText = [
      if (hours > 0) '${hours}h',
      if (minutes > 0) '${minutes}min',
    ].join(' ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Plano de estudo • ${blocks.length} bloco(s)${totalText.isEmpty ? '' : ' • $totalText'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...blocks.map(
            (block) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 7, right: 9),
                    decoration: const BoxDecoration(color: Color(0xFF555555), shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(block.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          '${formatLongDate(block.start)} • ${formatTime(block.start)} - ${formatTime(block.end)}',
                          style: const TextStyle(color: Color(0xFF666666), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedEventCard extends StatelessWidget {
  const _SuggestedEventCard({required this.event});
  final AgendaEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(formatLongDate(event.start), style: const TextStyle(color: Color(0xFF666666))),
                Text('${formatTime(event.start)} - ${formatTime(event.end)}', style: const TextStyle(color: Color(0xFF666666))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedTaskCard extends StatelessWidget {
  const _SuggestedTaskCard({required this.task});
  final AgendaTask task;

  @override
  Widget build(BuildContext context) {
    final priority = switch (task.priority) {
      TaskPriority.alta => 'Alta',
      TaskPriority.media => 'Média',
      TaskPriority.baixa => 'Baixa',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_box_outlined, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                if (task.deadline != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    task.deadlineHasTime
                        ? 'Prazo: ${formatLongDate(task.deadline!)} às ${formatTime(task.deadline!)}'
                        : 'Prazo: ${formatLongDate(task.deadline!)}',
                    style: const TextStyle(color: Color(0xFF666666)),
                  ),
                ],
                const SizedBox(height: 3),
                Text('Prioridade: $priority', style: const TextStyle(color: Color(0xFF666666))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Color(0xFF4B4B4B), child: Icon(Icons.auto_awesome_rounded, color: Colors.white)),
          SizedBox(width: 10),
          DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFFF2F2F2), borderRadius: BorderRadius.all(Radius.circular(18))),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
        ],
      ),
    );
  }
}
