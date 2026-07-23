# 🎯 SENTINEL-HUB - Sistema de Segurança com Flutter

Sistema integrado de monitoramento de segurança que combina DVR analógico AITEK, câmera IP, ESP32 com 433MHz, e notificações via ntfy.sh.

## 📋 Arquitetura

```
┌─────────────────────────────────────────────┐
│         SENTINEL-HUB (Flutter App)          │
│                                             │
│  ┌─────────────┐  ┌─────────────┐         │
│  │ Home Screen │  │ Live View   │         │
│  │ (Alertas)   │  │ (Câmeras)   │         │
│  └─────────────┘  └─────────────┘         │
│  ┌─────────────┐  ┌─────────────┐         │
│  │ Recordings  │  │ Grid 4x     │         │
│  │ (Playback)  │  │ (Escalável) │         │
│  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────┘
         ↓              ↓              ↓
    ┌────────────┐ ┌─────────┐ ┌──────────┐
    │ DVR AITEK  │ │ ntfy.sh │ │ Câmera IP│
    │ 4 canais   │ │ Alertas │ │ RTSP     │
    │ + HD       │ │         │ │          │
    └────────────┘ └─────────┘ └──────────┘
         ↓
    ┌──────────┐
    │  ESP32   │
    │ 433 MHz  │
    │(Trigger) │
    └──────────┘
```

## 🚀 Como Rodar

### Pré-requisitos
- Flutter SDK >= 3.4.0
- Dart >= 3.4.0
- Android Studio ou Xcode (para emulador)
- Conexão com o DVR na rede

### Dependências
```bash
cd sentinel_hub
flutter pub get
```

### Desenvolvimento
```bash
flutter run
```

### Build
```bash
# Android
flutter build apk

# iOS
flutter build ios

# Desktop (Linux)
flutter run -d linux
```

## 📁 Estrutura de Pastas

```
lib/
├── main.dart                 # Entry point
├── config/
│   └── app_config.dart      # Configurações centralizadas
├── models/
│   ├── camera.dart          # Modelo de câmera
│   ├── recording.dart       # Modelo de gravação
│   └── alert_event.dart     # Modelo de alerta
├── services/
│   ├── dvr_service.dart     # Comunicação com DVR AITEK
│   ├── ntfy_service.dart    # Alertas via ntfy
│   └── camera_service.dart  # Gerenciamento de câmeras
├── screens/
│   ├── home_screen.dart     # Tela principal (alertas + acesso rápido)
│   ├── live_view_screen.dart # Visualização ao vivo de câmera
│   ├── recordings_screen.dart # Consultia de gravações
│   └── camera_grid_screen.dart # Grid de 4 câmeras
└── widgets/
    └── (componentes reutilizáveis)
```

## 🔧 Configuração

### Credenciais do DVR
Edite `lib/config/app_config.dart`:

```dart
static const String dvrUsername = 'sptj';
static const String dvrPassword = 'kenji6721';
static const String dvrHost = '192.168.1.55:554';
```

### Câmera IP
```dart
static const String cameraIpUsername = 'admin';
static const String cameraIpPassword = 'admin123456';
static const String cameraIpHost = '192.168.15.19:8554';
```

### ntfy.sh
```dart
static const String ntfyTopic = 'sentinel_hub_vitor';
```

## 📺 Funcionalidades

### ✅ Implementado
- [x] Alertas em tempo real via ntfy.sh
- [x] Interface dark mode
- [x] Tela de home com status de alertas
- [x] Visualização de câmeras (RTSP URLs configuradas)
- [x] Grid preparado para 4 câmeras
- [x] Consulta de gravações (simulado)
- [x] Disparo manual de alertas
- [x] Arquitetura escalável

### 🔄 Em Desenvolvimento
- [ ] Streaming de vídeo RTSP (better_player)
- [ ] API XMeye para buscar gravações reais do DVR
- [ ] Sincronização com nuvem (opcional)
- [ ] Histórico de eventos persistente
- [ ] Notificações push
- [ ] Controle de câmeras PTZ (quando houver)

## 🎨 Tema
- **Cor Primária**: Cyan Accent (#00E5FF)
- **Cor de Alerta**: Red (#FF1744)
- **Background**: Dark (#0F111A)
- **Cards**: Dark Gray (#1F2233)

## 🐛 Troubleshooting

### "Câmera não conecta"
1. Verifique se o DVR está na mesma rede
2. Teste a URL RTSP no VLC primeiro
3. Confirme credenciais em `app_config.dart`

### "Não recebe alertas do ntfy"
1. Verifique a URL do tópico ntfy
2. Teste em: `https://ntfy.sh/sentinel_hub_vitor/json`
3. Verifique se o ESP32 está enviando mensagens

### "App congela ao abrir câmera"
1. Redimensione o vídeo (frame drop se muita lag)
2. Use H.264 ao invés de H.265 no DVR

## 📝 Próximos Passos
1. Integrar `better_player` para streaming RTSP real
2. Implementar API XMeye completa
3. Adicionar persistência com SQLite
4. Implementar notificações push
5. Criar dashboard web complementar

## 📞 Suporte
Para integração com seu DVR AITEK específico, consulte a documentação XMeye:
- Manual: Geralmente no /docs do DVR
- API: Disponível via web interface do DVR

---

**Desenvolvido para Sistema de Segurança Inteligente com ESP32**
