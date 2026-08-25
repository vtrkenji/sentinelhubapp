import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class UpdateService {
  static const String repoOwner = 'vtrkenji';
  static const String repoName = 'sentinelhubapp';

  /// Verifica se há nova versão no GitHub, baixa o APK e dispara a instalação
  static Future<void> checkAndDownloadUpdate(BuildContext context) async {
    try {
      // 1. Consulta o endpoint de última release da API do GitHub
      final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final response = await http.get(
        url,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Erro ao conectar ao GitHub: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);
      final String latestTag = data['tag_name'] ?? '';
      
      // (Opcional) Aqui você pode comparar 'latestTag' com a versão atual instalada do seu app
      
      // 2. Procura pelo arquivo .apk nos assets da release
      List assets = data['assets'] ?? [];
      String? apkDownloadUrl;
      
      for (var asset in assets) {
        String name = asset['name'] ?? '';
        if (name.endsWith('.apk')) {
          apkDownloadUrl = asset['browser_download_url'];
          break;
        }
      }

      if (apkDownloadUrl == null) {
        _showAlert(context, 'Atualização', 'Nenhum arquivo APK encontrado na última release ($latestTag).');
        return;
      }

      // 3. Notifica o usuário que o download vai começar
      _showAlert(context, 'Baixando Atualização', 'Versão $latestTag encontrada. Baixando em segundo plano...');

      // 4. Baixa o APK para o diretório de cache temporário do Android
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/update_$latestTag.apk';
      
      final apkResponse = await http.get(Uri.parse(apkDownloadUrl));
      if (apkResponse.statusCode != 200) {
        throw Exception('Falha ao baixar o arquivo do instalador.');
      }

      final file = File(filePath);
      await file.writeAsBytes(apkResponse.bodyBytes);

      // 5. Dispara a instalação usando o OpenFilex (que integra com o FileProvider)
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done) {
        throw Exception('Não foi possível iniciar a instalação: ${result.message}');
      }

    } catch (e) {
      debugPrint('[AutoUpdate] Erro crítico: $e');
      _showAlert(context, 'Erro na Atualização', 'Não foi possível concluir o processo: $e');
    }
  }

  static void _showAlert(BuildContext context, String title, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $message'),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}