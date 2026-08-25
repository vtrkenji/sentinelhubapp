import 'package:flutter/material.dart';
import '../models/camera.dart';
import '../services/camera_service.dart';

class CameraEditScreen extends StatefulWidget {
  final Camera? camera; // null for add, Camera object for edit

  const CameraEditScreen({super.key, this.camera});

  @override
  State<CameraEditScreen> createState() => _CameraEditScreenState();
}

class _CameraEditScreenState extends State<CameraEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _rtspUrlController;
  late TextEditingController _descriptionController;
  final CameraService _cameraService = CameraService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.camera?.name ?? '');
    _rtspUrlController =
        TextEditingController(text: widget.camera?.rtspUrl ?? '');
    _descriptionController =
        TextEditingController(text: widget.camera?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rtspUrlController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveCamera() async {
    if (_formKey.currentState?.validate() ?? false) {
      final baseCamera = widget.camera;
      final newCamera = (baseCamera ?? Camera(id: 0, name: '', rtspUrl: '')).copyWith(
        id: baseCamera?.id ?? 0,
        name: _nameController.text.trim(),
        rtspUrl: _rtspUrlController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (widget.camera == null) {
        await _cameraService.addCamera(newCamera);
      } else {
        await _cameraService.updateCamera(newCamera);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Câmera ${widget.camera == null ? 'adicionada' : 'atualizada'} com sucesso!')),
      );
      Navigator.pop(context, true); // Pop with true to indicate success
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.camera == null ? 'ADICIONAR CÂMERA' : 'EDITAR CÂMERA'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome da Câmera'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o nome da câmera';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _rtspUrlController,
                decoration: const InputDecoration(labelText: 'URL RTSP'),
                validator: (value) {
                  final trimmedValue = value?.trim() ?? '';
                  if (trimmedValue.isEmpty) {
                    return 'Por favor, insira a URL RTSP';
                  }
                  final uri = Uri.tryParse(trimmedValue);
                  if (uri == null ||
                      uri.scheme.toLowerCase() != 'rtsp' ||
                      uri.host.isEmpty) {
                    return 'A URL RTSP deve ser válida e conter host/porta';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration:
                    const InputDecoration(labelText: 'Descrição (opcional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveCamera,
                child: Text(widget.camera == null ? 'ADICIONAR' : 'SALVAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
