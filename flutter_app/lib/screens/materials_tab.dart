import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/material_item.dart';
import '../services/api_service.dart';
import '../state/app_store.dart';
import '../widgets/formatters.dart';

class MaterialsTab extends StatefulWidget {
  const MaterialsTab({
    super.key,
    required this.store,
    required this.apiService,
  });

  final AppStore store;
  final ApiService apiService;

  @override
  State<MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialsTabState extends State<MaterialsTab> {
  String category = 'Todos';
  String? selectedName;
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final materials = widget.store.materials.where((item) {
          return category == 'Todos' || item.category == category;
        }).toList();
        final selected = _selectedMaterial();

        return SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Meus Materiais', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      InkWell(
                        key: const Key('materials-upload'),
                        borderRadius: BorderRadius.circular(18),
                        onTap: loading ? null : _pickAndUploadPdf,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFD8D8D8)),
                          ),
                          child: Column(
                            children: [
                              if (loading)
                                const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3))
                              else
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: const BoxDecoration(color: Color(0xFFEFEFEF), shape: BoxShape.circle),
                                  child: const Icon(Icons.cloud_upload_outlined, size: 44, color: Color(0xFF555555)),
                                ),
                              const SizedBox(height: 12),
                              Text(loading ? 'Enviando...' : 'Enviar PDF', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 5),
                              const Text('Toque para selecionar um arquivo', style: TextStyle(fontSize: 15, color: Color(0xFF666666))),
                              const Text('PDF (máx. 20 MB)', style: TextStyle(fontSize: 14, color: Color(0xFF777777))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['Todos', 'Matemática', 'História', 'Biologia'].map((label) {
                            final selectedChip = category == label;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                showCheckmark: false,
                                label: Text(label),
                                selected: selectedChip,
                                onSelected: (_) => setState(() => category = label),
                                selectedColor: const Color(0xFF3E3E3E),
                                backgroundColor: Colors.white,
                                labelStyle: TextStyle(color: selectedChip ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
                                side: const BorderSide(color: Color(0xFFD9D9D9)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...materials.map((item) {
                        final selectedRow = selectedName == item.name;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() => selectedName = item.name),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: selectedRow ? const Color(0xFFF3F3F3) : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selectedRow ? const Color(0xFF777777) : const Color(0xFFE0E0E0),
                                  width: selectedRow ? 1.3 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.insert_drive_file_outlined, size: 31),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${formatBytes(item.sizeBytes)} • ${item.createTime == null ? 'sem data' : formatShortDate(item.createTime!)}',
                                          style: const TextStyle(fontSize: 13, color: Color(0xFF777777)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'delete') _delete(item);
                                    },
                                    itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Excluir'))],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      if (materials.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text('Nenhum material nesta categoria.')),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        key: const Key('materials-summary'),
                        onPressed: selected == null || loading ? null : () => _summarize(selected),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3E3E3E)),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Resumir PDF', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: selected == null || loading ? null : () => _ask(selected),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.black, side: const BorderSide(color: Color(0xFF555555))),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Perguntar ao material', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  MaterialItem? _selectedMaterial() {
    if (selectedName == null) return null;
    for (final item in widget.store.materials) {
      if (item.name == selectedName) return item;
    }
    return null;
  }

  Future<void> _pickAndUploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final file = File(path);
    final size = await file.length();
    if (size > 20 * 1024 * 1024) {
      _showMessage('O PDF deve ter no máximo 20 MB.');
      return;
    }

    setState(() => loading = true);
    try {
      final uploaded = await widget.apiService.uploadPdf(file);
      widget.store.addMaterial(uploaded);
      setState(() => selectedName = uploaded.name);
      _showMessage('PDF enviado com sucesso.');
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Falha ao enviar o PDF. Verifique o backend.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  Future<void> _delete(MaterialItem item) async {
    if (!item.remote) {
      widget.store.removeMaterial(item.name);
      return;
    }
    setState(() => loading = true);
    try {
      await widget.apiService.deleteFile(item.name);
      widget.store.removeMaterial(item.name);
      if (selectedName == item.name) selectedName = null;
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _summarize(MaterialItem item) async {
    if (!item.remote) {
      _showMessage('Envie um PDF real para usar a IA. Os arquivos exibidos inicialmente são exemplos do wireframe.');
      return;
    }
    setState(() => loading = true);
    try {
      final summary = await widget.apiService.summarizeFile(item.name);
      if (!mounted) return;
      await _showResult('Resumo de ${item.displayName}', summary);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _ask(MaterialItem item) async {
    if (!item.remote) {
      _showMessage('Envie um PDF real para fazer perguntas sobre o conteúdo.');
      return;
    }
    final controller = TextEditingController();
    final question = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perguntar ao material'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Ex.: Explique os conceitos principais.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Perguntar')),
        ],
      ),
    );
    controller.dispose();
    if (question == null || question.isEmpty) return;

    setState(() => loading = true);
    try {
      final answer = await widget.apiService.askMaterial(fileName: item.name, question: question);
      if (!mounted) return;
      await _showResult('Resposta', answer);
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _showResult(String title, String text) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(22),
          child: ListView(
            controller: scrollController,
            children: [
              Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              SelectableText(text, style: const TextStyle(fontSize: 16, height: 1.45)),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
