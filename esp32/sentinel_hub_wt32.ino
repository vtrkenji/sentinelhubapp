#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <WiFiManager.h>
#include <WebServer.h>
#include <WiFiUdp.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <RCSwitch.h>
#include <esp_mac.h>

#define ENABLE_SERVICE_AUTH
#define ENABLE_MESSAGING
#include <FirebaseClient.h>

// ==========================================
// FIREBASE
// ==========================================

#define FIREBASE_PROJECT_ID "ktsentinel-aa307"
#define FIREBASE_CLIENT_EMAIL "firebase-adminsdk-fbsvc@ktsentinel-aa307.iam.gserviceaccount.com"

const char FIREBASE_PRIVATE_KEY[] PROGMEM = R"rawliteral(
[CHAVE_REMOVIDA]
)rawliteral";

// ==========================================
// HARDWARE / REDE
// ==========================================
constexpr uint8_t PINO_RF = 35;
constexpr unsigned long INTERVALO_COOLDOWN_MS = 3000;
constexpr uint16_t HTTP_PORT = 80;
constexpr uint16_t DISCOVERY_PORT = 4210;

const char* MODULE_TYPE = "wt32-eth01";
const char* DEVICE_NAME = "SentinelHub WT32";
const char* DISCOVERY_PROTOCOL = "SENTINEL_DISCOVER_V1";

RCSwitch receptorRF;
WebServer server(HTTP_PORT);
WiFiUDP udp;
Preferences preferencias;

WiFiClientSecure sslClient;
using AsyncClient = AsyncClientClass;
AsyncClient asyncClient(sslClient);

FirebaseApp app;
Messaging messaging;

ServiceAuth serviceAuth(
  FIREBASE_CLIENT_EMAIL,
  FIREBASE_PROJECT_ID,
  FIREBASE_PRIVATE_KEY,
  3000
);

bool firebasePronto = false;
bool firebaseInicializado = false;
unsigned long ultimoDisparo = 0;

// Configuração persistida, exposta via /status e /salvar
String fcmTopic = "campainha";
String storedDuckdom;
String storedDucktok;
String storedCamp1;
String storedCamp2;

// ==========================================
// UTILITARIOS
// ==========================================
String getWifiMac() {
  uint8_t mac[6];
  esp_read_mac(mac, ESP_MAC_WIFI_STA);

  char macText[18];

  snprintf(
    macText,
    sizeof(macText),
    "%02X:%02X:%02X:%02X:%02X:%02X",
    mac[0], mac[1], mac[2],
    mac[3], mac[4], mac[5]
  );

  return String(macText);
}

void printResult(AsyncResult &resultado) {
  if (!resultado.isResult()) {
    return;
  }

  if (resultado.isError()) {
    Serial.printf(
      "[Firebase] Erro - tarefa: %s, codigo: %d, mensagem: %s\n",
      resultado.uid().c_str(),
      resultado.error().code(),
      resultado.error().message().c_str()
    );
  }

  if (resultado.available()) {
    Serial.printf(
      "[Firebase] Resposta - tarefa: %s, payload: %s\n",
      resultado.uid().c_str(),
      resultado.c_str()
    );
  }
}

// Valida o formato do tópico FCM (mesmas regras usadas pelo app e pelo gateway ESP32-C6)
bool validateFcmTopic(const String& topic) {
  if (topic.isEmpty() || topic.length() > 900) {
    return false;
  }
  for (int i = 0; i < topic.length(); i++) {
    char c = topic[i];
    bool valid = (c >= 'a' && c <= 'z') ||
                 (c >= 'A' && c <= 'Z') ||
                 (c >= '0' && c <= '9') ||
                 c == '_' || c == '-' || c == '.' || c == '~' || c == '%';
    if (!valid) return false;
  }
  return true;
}

// ==========================================
// PREFERENCIAS
// ==========================================
void carregarPreferencias() {
  preferencias.begin("sentinel", false);
  fcmTopic = preferencias.getString("fcmtopic", "campainha");
  storedDuckdom = preferencias.getString("duckdom", "");
  storedDucktok = preferencias.getString("ducktok", "");
  storedCamp1 = preferencias.getString("camp1", "");
  storedCamp2 = preferencias.getString("camp2", "");
}

// ==========================================
// WIFI
// ==========================================
void conectarWiFi() {
  WiFi.mode(WIFI_STA);

  Serial.print("[NET] MAC Wi-Fi: ");
  Serial.println(getWifiMac());

  WiFiManager wm;

  String portalInfo =
    "<p><b>WT32-ETH01 - MAC Wi-Fi:</b> " +
    getWifiMac() +
    "</p>"
    "<p>Use este MAC para criar uma reserva DHCP no roteador.</p>";

  wm.setCustomHeadElement(portalInfo.c_str());

  Serial.println("[NET] Iniciando WiFiManager...");

  if (!wm.autoConnect("SentinelHub-WT32-Setup")) {
    Serial.println("[NET] Falha ao conectar. Reiniciando...");
    delay(3000);
    ESP.restart();
  }

  Serial.println("[NET] Wi-Fi conectado!");
  Serial.print("[NET] IP local: ");
  Serial.println(WiFi.localIP());
}

// ==========================================
// NTP
// ==========================================
bool sincronizarHora() {
  configTzTime(
    "BRT3BRST,M10.3.0/0,M2.3.0/0",
    "time.google.com",
    "pool.ntp.org",
    "time.cloudflare.com"
  );

  Serial.print("[NTP] Sincronizando hora");

  const unsigned long inicio = millis();

  while (time(nullptr) < 1700000000L) {
    Serial.print(".");
    delay(1000);

    if (millis() - inicio > 60000) {
      Serial.println("\n[NTP] Timeout. Verifique Internet e DNS.");
      return false;
    }
  }

  Serial.println("\n[NTP] Hora sincronizada!");
  return true;
}

// ==========================================
// FIREBASE / FCM
// ==========================================
void iniciarFirebase() {
  sslClient.setInsecure();

  app.setTime(time(nullptr));

  Serial.println("[FCM] Inicializando Firebase...");

  initializeApp(
    asyncClient,
    app,
    getAuth(serviceAuth),
    printResult,
    "authTask"
  );

  app.getApp<Messaging>(messaging);
  firebaseInicializado = true;
}

void enviarAlertaFCM(const String &mensagem) {
  if (!firebaseInicializado || !app.ready()) {
    Serial.println("[FCM] Firebase ainda nao esta pronto.");
    return;
  }

  Messages::Message mensagemFcm;
  mensagemFcm.topic(fcmTopic);

  Messages::Notification notificacao;
  notificacao
    .title("kTsentinel - Casa")
    .body(mensagem.c_str());

  mensagemFcm.notification(notificacao);

  Serial.println("[FCM] Enviando alerta...");

  messaging.send(
    asyncClient,
    Messages::Parent(FIREBASE_PROJECT_ID),
    mensagemFcm,
    printResult,
    "fcmSendTask"
  );
}

// ==========================================
// HTTP (/status e /salvar)
// ==========================================
void handleStatus() {
  DynamicJsonDocument doc(512);
  doc["status"] = "online";
  doc["device"] = DEVICE_NAME;
  doc["moduleType"] = MODULE_TYPE;
  doc["mac"] = getWifiMac();
  doc["duckdom"] = storedDuckdom;
  doc["camp1"] = storedCamp1;
  doc["camp2"] = storedCamp2;
  doc["fcmtopic"] = fcmTopic;

  String payload;
  serializeJson(doc, payload);
  server.send(200, "application/json", payload);
}

void handleSalvar() {
  String duckdom;
  String ducktok;
  String camp1;
  String camp2;
  String novoFcmTopic;

  if (server.hasArg("plain") && server.arg("plain").length() > 0) {
    DynamicJsonDocument bodyDoc(512);
    DeserializationError error = deserializeJson(bodyDoc, server.arg("plain"));
    if (error) {
      server.send(400, "application/json", "{\"error\": \"Payload JSON inválido\"}");
      return;
    }
    duckdom = bodyDoc["duckdom"].as<String>();
    ducktok = bodyDoc["ducktok"].as<String>();
    camp1 = bodyDoc["camp1"].as<String>();
    camp2 = bodyDoc["camp2"].as<String>();
    novoFcmTopic = bodyDoc["fcmtopic"].as<String>();
  } else {
    duckdom = server.arg("duckdom");
    ducktok = server.arg("ducktok");
    camp1 = server.arg("camp1");
    camp2 = server.arg("camp2");
    novoFcmTopic = server.arg("fcmtopic");
  }

  if (!validateFcmTopic(novoFcmTopic)) {
    DynamicJsonDocument errorDoc(256);
    errorDoc["error"] = "Tópico FCM inválido. Máximo 900 caracteres. Apenas letras, números, _, -, ., ~, %.";
    String payload;
    serializeJson(errorDoc, payload);
    server.send(400, "application/json", payload);
    return;
  }

  preferencias.putString("duckdom", duckdom);
  preferencias.putString("ducktok", ducktok);
  preferencias.putString("camp1", camp1);
  preferencias.putString("camp2", camp2);
  preferencias.putString("fcmtopic", novoFcmTopic);

  storedDuckdom = duckdom;
  storedDucktok = ducktok;
  storedCamp1 = camp1;
  storedCamp2 = camp2;
  fcmTopic = novoFcmTopic;

  server.send(200, "application/json", "{\"success\": true}");

  delay(500);
  ESP.restart();
}

void iniciarServidorHttp() {
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/salvar", HTTP_POST, handleSalvar);
  server.onNotFound([]() {
    server.send(404, "text/plain", "Not found");
  });
  server.begin();
  Serial.println("[HTTP] Servidor iniciado na porta 80");
}

// ==========================================
// DESCOBERTA UDP
// ==========================================
void iniciarDescobertaUdp() {
  udp.begin(DISCOVERY_PORT);
  Serial.print("[UDP] Descoberta escutando na porta ");
  Serial.println(DISCOVERY_PORT);
}

void tratarDescobertaUdp() {
  int packetSize = udp.parsePacket();
  if (packetSize == 0) {
    return;
  }

  char packetBuffer[128];
  int len = udp.read(packetBuffer, sizeof(packetBuffer) - 1);
  if (len <= 0) {
    return;
  }
  packetBuffer[len] = '\0';

  String request(packetBuffer);
  if (request != DISCOVERY_PROTOCOL) {
    return;
  }

  DynamicJsonDocument doc(512);
  doc["protocol"] = DISCOVERY_PROTOCOL;
  doc["device"] = DEVICE_NAME;
  doc["moduleType"] = MODULE_TYPE;
  doc["name"] = DEVICE_NAME;
  doc["ip"] = WiFi.localIP().toString();
  doc["httpPort"] = HTTP_PORT;
  doc["mac"] = getWifiMac();

  String payload;
  serializeJson(doc, payload);
  udp.beginPacket(udp.remoteIP(), udp.remotePort());
  udp.write(payload.c_str());
  udp.endPacket();
}

// ==========================================
// SETUP
// ==========================================
void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println("\n[WT32] Iniciando gateway RF");

  carregarPreferencias();

  conectarWiFi();

  iniciarServidorHttp();
  iniciarDescobertaUdp();

  receptorRF.enableReceive(digitalPinToInterrupt(PINO_RF));

  Serial.print("[RF] Receptor iniciado no GPIO ");
  Serial.println(PINO_RF);

  if (sincronizarHora()) {
    iniciarFirebase();
  } else {
    Serial.println("[FCM] Desativado neste boot: horario NTP indisponivel.");
  }
}

// ==========================================
// LOOP
// ==========================================
void loop() {
  server.handleClient();
  tratarDescobertaUdp();

  if (firebaseInicializado) {
    app.loop();

    if (app.ready() && !firebasePronto) {
      firebasePronto = true;
      Serial.println("[FCM] Firebase autenticado e pronto!");
    }
  }

  if (!receptorRF.available()) {
    return;
  }

  const unsigned long codigo = receptorRF.getReceivedValue();
  const unsigned int protocolo = receptorRF.getReceivedProtocol();
  const unsigned int bits = receptorRF.getReceivedBitlength();

  receptorRF.resetAvailable();

  if (codigo == 0) {
    Serial.println("[RF] Sinal recebido, mas codigo invalido.");
    return;
  }

  if (millis() - ultimoDisparo < INTERVALO_COOLDOWN_MS) {
    Serial.println("[RF] Ignorado pelo cooldown.");
    return;
  }

  Serial.printf(
    "[RF] Codigo capturado: %lu | Protocolo: %u | Bits: %u\n",
    codigo,
    protocolo,
    bits
  );

  enviarAlertaFCM(
    "Campainha acionada! Codigo RF: " + String(codigo)
  );

  ultimoDisparo = millis();
}
