#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <WiFiUdp.h>
#include <Preferences.h>
#include <ArduinoJson.h>

#define CONFIG_PIN 0
#define DNS_PORT 53
#define DISCOVERY_PORT 4210

const char* apSsid = "SentinelHub-Setup";
const char* apPassword = "sentinel123";
const byte DNS_REPLY_IP[] = {192, 168, 4, 1};

Preferences preferences;
WebServer server(80);
DNSServer dnsServer;
WiFiUDP udp;

const char* DEVICE_NAME = "SentinelHub ESP32-C6 RF";
const char* MODULE_TYPE = "esp32c6-rf";
const char* DISCOVERY_PROTOCOL = "SENTINEL_DISCOVER_V1";

String storedSsid;
String storedPassword;
String storedTopic;
String storedDuckdom;
String storedDucktok;
String storedCamp1;
String storedCamp2;
String fcmTopic;

bool shouldStartAP = false;
unsigned long wifiAttemptStart = 0;
const unsigned long WIFI_TIMEOUT_MS = 10000;

void handleRoot() {
  String html = R"rawliteral(
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sentinel-Hub RF Setup</title>
  <style>
    body { font-family: Arial, sans-serif; background: #0f111a; color: #f1f5fb; margin: 0; padding: 0; }
    .container { max-width: 620px; margin: 24px auto; padding: 24px; background: #1f2233; border-radius: 14px; }
    h1 { margin: 0 0 12px; color: #00e5ff; }
    label { display: block; margin: 12px 0 4px; font-weight: 600; }
    input { width: 100%; padding: 10px; border: 1px solid #333652; border-radius: 8px; background: #101326; color: #fff; }
    button { margin-top: 20px; width: 100%; padding: 12px; border: none; border-radius: 10px; background: #00e5ff; color: #000; font-weight: 700; cursor: pointer; }
    p { margin: 12px 0 0; font-size: 0.95rem; color: #9aa3bf; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Configuração Gateway ESP32-C6 (RF)</h1>
    <form method="POST" action="/salvar">
      <label for="duckdom">DuckDNS Domínio</label>
      <input type="text" id="duckdom" name="duckdom" value=")rawliteral";
  html += storedDuckdom;
  html += R"rawliteral(" />
      <label for="ducktok">DuckDNS Token</label>
        <input type="password" id="ducktok" name="ducktok" autocomplete="new-password" />
      <label for="camp1">Código Campainha 1</label>
      <input type="text" id="camp1" name="camp1" value=")rawliteral";
  html += storedCamp1;
  html += R"rawliteral(" />
      <label for="camp2">Código Campainha 2</label>
      <input type="text" id="camp2" name="camp2" value=")rawliteral";
  html += storedCamp2;
  html += R"rawliteral(" />
      <label for="fcmtopic">Tópico FCM</label>
      <input type="text" id="fcmtopic" name="fcmtopic" value=")rawliteral";
  html += fcmTopic;
  html += R"rawliteral(" />
      <button type="submit">Salvar configuração</button>
    </form>
    <p>Este módulo RF não recebe Wi‑Fi nem Ntfy pelo formulário web.</p>
    <p>IP do ESP32 no AP: 192.168.4.1</p>
  </div>
</body>
</html>
)rawliteral";
  server.send(200, "text/html", html);
}

void handleConfig() {
  DynamicJsonDocument doc(512);
  doc["ssid"] = storedSsid;
  doc["topic"] = storedTopic;
  doc["connected"] = WiFi.isConnected();
  doc["ip"] = WiFi.localIP().toString();
  String payload;
  serializeJson(doc, payload);
  server.send(200, "application/json", payload);
}

// Validate FCM topic format
bool validateFcmTopic(const String& topic) {
  if (topic.isEmpty() || topic.length() > 900) {
    return false;
  }
  // Only letters, numbers, underscore, hyphen, dot, tilde, percent
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

void handleStatus() {
  DynamicJsonDocument doc(512);
  doc["status"] = "ok";
  doc["device"] = "ESP32";
  doc["moduleType"] = MODULE_TYPE;
  doc["name"] = DEVICE_NAME;
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
  String newFcmTopic;

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
    newFcmTopic = bodyDoc["fcmtopic"].as<String>();
  } else {
    duckdom = server.arg("duckdom");
    ducktok = server.arg("ducktok");
    camp1 = server.arg("camp1");
    camp2 = server.arg("camp2");
    newFcmTopic = server.arg("fcmtopic");
  }

  if (newFcmTopic.length() == 0 || !validateFcmTopic(newFcmTopic)) {
    DynamicJsonDocument errorDoc(256);
    errorDoc["error"] = "Tópico FCM inválido. Máximo 900 caracteres. Apenas letras, números, _, -, ., ~, %.";
    String payload;
    serializeJson(errorDoc, payload);
    server.send(400, "application/json", payload);
    return;
  }

  preferences.putString("duckdom", duckdom);
  preferences.putString("ducktok", ducktok);
  preferences.putString("camp1", camp1);
  preferences.putString("camp2", camp2);
  preferences.putString("fcmtopic", newFcmTopic);

  storedDuckdom = duckdom;
  storedDucktok = ducktok;
  storedCamp1 = camp1;
  storedCamp2 = camp2;
  fcmTopic = newFcmTopic;

  server.send(200, "application/json", "{\"success\": true}");

  delay(500);
  ESP.restart();
}

void handleDiscoveryRequest() {
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
  doc["device"] = "ESP32";
  doc["moduleType"] = MODULE_TYPE;
  doc["name"] = DEVICE_NAME;
  doc["ip"] = WiFi.localIP().toString();
  doc["httpPort"] = 80;

  String payload;
  serializeJson(doc, payload);
  udp.beginPacket(udp.remoteIP(), udp.remotePort());
  udp.write(payload.c_str());
  udp.endPacket();
}

void handleNotFound() {
  server.sendHeader("Location", String("http://") + WiFi.softAPIP().toString());
  server.send(302, "text/plain", "");
}

void startCaptivePortal() {
  WiFi.softAPConfig(IPAddress(192, 168, 4, 1), IPAddress(192, 168, 4, 1), IPAddress(255, 255, 255, 0));
  WiFi.softAP(apSsid, apPassword);
  dnsServer.start(DNS_PORT, "*", IPAddress(192, 168, 4, 1));

  server.on("/", handleRoot);
  server.on("/config", handleConfig);
  server.on("/updateConfig", HTTP_POST, handleSalvar);
  server.on("/salvar", HTTP_POST, handleSalvar);
  server.onNotFound(handleNotFound);
  server.begin();
}

bool connectToWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.begin(storedSsid.c_str(), storedPassword.c_str());
  wifiAttemptStart = millis();

  while (millis() - wifiAttemptStart < WIFI_TIMEOUT_MS) {
    if (WiFi.status() == WL_CONNECTED) {
      return true;
    }
    delay(500);
  }
  return false;
}

void loadPreferences() {
  preferences.begin("sentinel", false);
  storedSsid = preferences.getString("wifi_ssid", "");
  storedPassword = preferences.getString("wifi_password", "");
  storedTopic = preferences.getString("ntfy_topic", "sentinel_hub");
  storedDuckdom = preferences.getString("duckdom", "");
  storedDucktok = preferences.getString("ducktok", "");
  storedCamp1 = preferences.getString("camp1", "");
  storedCamp2 = preferences.getString("camp2", "");
  fcmTopic = preferences.getString("fcmtopic", "campainha");
}

void setup() {
  Serial.begin(115200);
  pinMode(CONFIG_PIN, INPUT_PULLUP);
  loadPreferences();

  WiFi.mode(WIFI_STA);
  bool configPressed = digitalRead(CONFIG_PIN) == LOW;
  bool hasWifiConfig = storedSsid.length() > 0 && storedPassword.length() > 0;

  if (!hasWifiConfig || configPressed || !connectToWiFi()) {
    shouldStartAP = true;
  }

  if (shouldStartAP) {
    startCaptivePortal();
    udp.begin(DISCOVERY_PORT);
  } else {
    WiFi.mode(WIFI_STA);
    Serial.printf("Conectado em: %s | IP: %s\n", storedSsid.c_str(), WiFi.localIP().toString().c_str());

    server.on("/status", handleStatus);
    server.on("/config", handleConfig);
    server.on("/salvar", HTTP_POST, handleSalvar);
    server.on("/trigger", []() {
      server.send(200, "application/json", "{\"triggered\": true}");
    });
    server.onNotFound([]() {
      server.send(404, "text/plain", "Not found");
    });
    server.begin();
    udp.begin(DISCOVERY_PORT);
  }
}

void loop() {
  if (shouldStartAP) {
    dnsServer.processNextRequest();
  }
  server.handleClient();
  handleDiscoveryRequest();
}
