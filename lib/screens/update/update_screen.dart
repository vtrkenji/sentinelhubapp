import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/app_config.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  bool _isChecking = true;
  bool _hasUpdate = false;
  String _currentVersion = '';
  String _latestVersion = '';
  String _releaseNotes = '';
  String _downloadUrl = '';
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatusText = '';

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isChecking = true;
    });

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      String localVersion = packageInfo.version;
      if (!localVersion.startsWith('v')) {
        localVersion = 'v$localVersion';
      }
      _currentVersion = localVersion;

      final response = await http.get(Uri.parse('https://api.github.com/repos/vtrkenji/sentinelhubapp/releases/latest'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _latestVersion = data['tag_name'] ?? '';
        _releaseNotes = data['body'] ?? '';

        if (data['assets'] != null) {
          final List assets = data['assets'];
          // Prefer APK on Android; on Linux accept several common package types
          for (var asset in assets) {
            final name = asset['name'].toString();
            final lname = name.toLowerCase();
            if (Platform.isAndroid && lname.endsWith('.apk')) {
              _downloadUrl = asset['browser_download_url'];
              break;
            }
            if (Platform.isLinux) {
              // Common Linux release asset patterns
              if (lname.endsWith('.appimage') || lname.endsWith('.deb') || lname.endsWith('.tar.gz') || lname.endsWith('.zip') || lname.endsWith('.run')) {
                _downloadUrl = asset['browser_download_url'];
                break;
              }
              // Fallback: any asset without extension (possible executable)
              if (!lname.contains('.') && _downloadUrl.isEmpty) {
                _downloadUrl = asset['browser_download_url'];
              }
            }
          }
        }

        if (_latestVersion.isNotEmpty && _latestVersion != _currentVersion) {
          _hasUpdate = true;
        } else {
          _hasUpdate = false;
        }
      }
    } catch (e) {
      debugPrint('Erro ao verificar atualizações: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _startDownloadAndInstall() async {
    if (_downloadUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL de download não encontrada para este sistema.')),
      );
      return;
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatusText = 'Preparando download...';
    });

    try {
      final dir = await getTemporaryDirectory();
      final fileName = _downloadUrl.split('/').last;
      final savePath = '${dir.path}/$fileName';

      final dio = Dio();
      await dio.download(
        _downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            setState(() {
              _downloadProgress = received / total;
              _downloadStatusText = 'Baixando: ${(received / 1024 / 1024).toStringAsFixed(1)} MB / ${(total / 1024 / 1024).toStringAsFixed(1)} MB';
            });
          }
        },
      );

      setState(() {
        _downloadStatusText = 'Download concluído! Iniciando instalação...';
      });

      // Handle platform-specific installation / self-update
      if (Platform.isAndroid) {
        // Android: open APK to trigger system installer
        final result = await OpenFilex.open(savePath);
        if (result.type != ResultType.done) {
          setState(() {
            _downloadStatusText = 'Erro ao abrir o arquivo: ${result.message}';
          });
        } else {
          setState(() {
            _downloadStatusText = 'Instalador aberto com sucesso.';
          });
        }
      } else if (Platform.isLinux) {
        try {
          final execPath = Platform.resolvedExecutable;
          final scriptPath = '${dir.path}/update.sh';
          final script = '''#!/bin/bash
sleep 2
mv "$savePath" "$execPath"
chmod +x "$execPath"
"$execPath" &
rm -- "\$0"
''';

          await File(scriptPath).writeAsString(script);
          await Process.run('chmod', ['+x', scriptPath]);
          // Execute script in shell and exit current app so the script can replace the binary
          await Process.run(scriptPath, [], runInShell: true);
          exit(0);
        } catch (e) {
          setState(() {
            _downloadStatusText = 'Erro ao aplicar atualização: $e';
          });
        }
      } else if (Platform.isWindows) {
        try {
          final execPath = Platform.resolvedExecutable;
          final scriptPath = '${dir.path}/update.bat';
          final script = '@echo off\r\ntimeout /t 2 /nobreak\r\nmove /y "$savePath" "$execPath"\r\nstart "" "$execPath"\r\ndel "%~f0"\r\n';

          await File(scriptPath).writeAsString(script);
          // Run the batch file in shell; it will move the new binary and start it
          await Process.run(scriptPath, [], runInShell: true);
          exit(0);
        } catch (e) {
          setState(() {
            _downloadStatusText = 'Erro ao aplicar atualização (Windows): $e';
          });
        }
      } else {
        // Fallback: try to open with system handler
        final result = await OpenFilex.open(savePath);
        if (result.type != ResultType.done) {
          setState(() {
            _downloadStatusText = 'Erro ao abrir o arquivo: ${result.message}';
          });
        } else {
          setState(() {
            _downloadStatusText = 'Arquivo aberto com sucesso.';
          });
        }
      }

    } catch (e) {
      setState(() {
        _downloadStatusText = 'Erro durante o download: $e';
      });
    } finally {
      if (mounted) {
        // Delay para o usuário ler a mensagem de sucesso antes de voltar o botão
        await Future.delayed(const Duration(seconds: 3));
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atualizações do VSGuard'),
        backgroundColor: AppConfig.cardColor,
      ),
      backgroundColor: AppConfig.backgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            color: AppConfig.cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.system_update_alt,
                    size: 64,
                    color: AppConfig.accentColor,
                  ),
                  const SizedBox(height: 24),
                  if (_isChecking) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Buscando atualizações no servidor...', style: TextStyle(fontSize: 16)),
                  ] else if (_hasUpdate) ...[
                    const Text(
                      'Nova versão disponível!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppConfig.accentColor),
                    ),
                    const SizedBox(height: 16),
                    Text('Versão atual: $_currentVersion', style: const TextStyle(color: Colors.grey)),
                    Text('Nova versão: $_latestVersion', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    if (_releaseNotes.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppConfig.accentColor.withAlpha((0.3 * 255).round())),
                        ),
                        height: 120,
                        width: double.infinity,
                        child: SingleChildScrollView(
                          child: Text(_releaseNotes, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_isDownloading) ...[
                      Column(
                        children: [
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: Colors.black26,
                            color: AppConfig.accentColor,
                            minHeight: 12,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _downloadStatusText,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppConfig.accentColor,
                              ),
                          ),
                        ],
                      )
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: _startDownloadAndInstall,
                        icon: const Icon(Icons.download),
                        label: const Text('Baixar e Instalar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.accentColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                      ),
                    ]
                  ] else ...[
                    const Text(
                      'Seu sistema está atualizado!',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text('Versão instalada: $_currentVersion', style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _checkForUpdates,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Verificar novamente'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
