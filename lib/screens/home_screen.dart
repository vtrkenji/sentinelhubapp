import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import 'update_screen.dart'; // Para o botão de update na barra superior, se quiser manter

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      body: Row(
        children: [
          // ==========================================
          // 1. MENU LATERAL ESQUERDO
          // ==========================================
          Container(
            width: 200,
            color: AppConfig.cardColor.withAlpha((0.5 * 255).round()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    '05',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppConfig.accentColor,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'INDUSTRIAL\nCFTV / Infraestrutura',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildMenuItem(0, Icons.grid_view, 'Painel'),
                _buildMenuItem(1, Icons.videocam_outlined, 'Módulos-Câmeras'),
                _buildMenuItem(2, Icons.settings_outlined, 'Configurações'),
              ],
            ),
          ),

          // ==========================================
          // 2. PAINEL PRINCIPAL (CONTEÚDO)
          // ==========================================
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho / Topo do Painel
                  Row(
                    mainAxisAlignment: MainAxisAlignment.between,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VSGUARD OS',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Row(
                            children: [
                              Text('Painel', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              SizedBox(width: 8),
                              Text('• v1.0.9 (Ativo)', style: TextStyle(color: AppConfig.accentColor, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_none, color: AppConfig.accentColor),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.system_update, color: AppConfig.accentColor),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const UpdateScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Grid de Módulos e Câmeras
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.8,
                      children: [
                        _buildModuleCard('DVR AITEK (CANAL 1)', Icons.storage, false),
                        _buildModuleCard('CAMERAS IP LOCAL', Icons.videocam, false),
                        _buildModuleCard('IP2', Icons.router, false),
                      ],
                    ),
                  ),

                  // Banner de Alerta na Base
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F110B), // Tom de alerta escuro
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppConfig.alertColor.withAlpha((0.5 * 255).round())),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppConfig.alertColor, size: 36),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ATENÇÃO',
                              style: TextStyle(
                                color: AppConfig.alertColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '3 dispositivos offline no momento',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppConfig.accentColor),
                            foregroundColor: AppConfig.accentColor,
                          ),
                          child: const Text('VER ALERTAS'),
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

  Widget _buildMenuItem(int index, IconData icon, String label) {
    final bool isSelected = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppConfig.accentColor.withAlpha((0.15 * 255).round()) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? AppConfig.accentColor : Colors.grey),
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppConfig.accentColor : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildModuleCard(String title, IconData icon, bool isOnline) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConfig.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConfig.accentColor.withAlpha((0.3 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: AppConfig.accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(color: isOnline ? Colors.green : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConfig.accentColor,
                foregroundColor: Colors.black,
                padding: EdgeInsets.zero,
              ),
              child: const Text('CONECTAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}