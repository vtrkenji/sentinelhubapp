import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String _githubUrl = 'https://github.com/vtrkenji/sentinelhubapp/releases/latest';

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
        _githubUrl = data['html_url'] ?? _githubUrl;

        if (data['assets'] != null) {
          final List assets = data['assets'];
          for (var asset in assets) {
            final name = asset['name'].toString().toLowerCase();
            if (Platform.isWindows && name.endsWith('.zip')) {
              _downloadUrl = asset['browser_download_url'];
            } else if (Platform.isLinux && name.endsWith('.tar.gz')) {
              _downloadUrl = asset['browser_download_url'];
            } else if (Platform.isAndroid && name.endsWith('.apk')) {
              _downloadUrl = asset['browser_download_url'];
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

  Future<void> _launchDownload() async {
    final url = _downloadUrl.isNotEmpty ? _downloadUrl : _githubUrl;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                  Icon(
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
                    Text(
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
                          border: Border.all(color: AppConfig.accentColor.withOpacity(0.3)),
                        ),
                        height: 120,
                        width: double.infinity,
                        child: SingleChildScrollView(
                          child: Text(_releaseNotes, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    ElevatedButton.icon(
                      onPressed: _launchDownload,
                      icon: const Icon(Icons.download),
                      label: const Text('Baixar Atualização'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConfig.accentColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
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
