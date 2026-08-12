#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <Preferences.h>
#include <ArduinoJson.h>

#define CONFIG_PIN 0
#define DNS_PORT 53

const char* apSsid = "SentinelHub-Setup";
const char* apPassword = "sentinel123";
const byte DNS_REPLY_IP[] = {192, 168, 4, 1};

Preferences preferences;
WebServer server(80);
DNSServer dnsServer;

String storedSsid;
String storedPassword;
String storedTopic;

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
  <title>Sentinel-Hub Setup</title>
  <style>
    body { font-family: Arial, sans-serif; background: #0f111a; color: #f1f5fb; margin: 0; padding: 0; }
    .container { max-width: 600px; margin: 24px auto; padding: 24px; background: #1f2233; border-radius: 14px; }
    h1 { margin: 0 0 12px; color: #00e5ff; }
    label { display: block; margin: 12px 0 4px; font-weight: 600; }
    input { width: 100%; padding: 10px; border: 1px solid #333652; border-radius: 8px; background: #101326; color: #fff; }
    button { margin-top: 20px; width: 100%; padding: 12px; border: none; border-radius: 10px; background: #00e5ff; color: #000; font-weight: 700; cursor: pointer; }
    p { margin: 12px 0 0; font-size: 0.95rem; color: #9aa3bf; }
  </style>
</head>
<body>
  <div class="container">
    <h1>Setup Sentinel-Hub</h1>
    <form method="POST" action="/updateConfig">
      <label for="ssid">SSID da rede Wi-Fi</label>
      <input type="text" id="ssid" name="ssid" required value=")rawliteral";
  html += storedSsid;
  html += R"rawliteral(" />
      <label for="password">Senha Wi-Fi</label>
      <input type="password" id="password" name="password" required />
      <label for="topic">Tópico ntfy.sh</label>
      <input type="text" id="topic" name="topic" required value=")rawliteral";
  html += storedTopic;
  html += R"rawliteral(" />
      <button type="submit">Salvar configuração</button>
    </form>
    <p>Após salvar, o dispositivo tentará conectar à sua rede Wi-Fi. Se necessário, reconecte-se ao AP do ESP32.</p>
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

void handleStatus() {
  DynamicJsonDocument doc(512);
  doc["connected"] = WiFi.isConnected();
  doc["ip"] = WiFi.localIP().toString();
  doc["ssid"] = storedSsid;
  doc["topic"] = storedTopic;
  String payload;
  serializeJson(doc, payload);
  server.send(200, "application/json", payload);
}

void handleUpdateConfig() {
  String ssid;
  String password;
  String topic;

  if (server.hasArg("plain") && server.arg("plain").length() > 0) {
    DynamicJsonDocument bodyDoc(512);
    DeserializationError error = deserializeJson(bodyDoc, server.arg("plain"));
    if (error) {
      server.send(400, "application/json", "{\"error\": \"Payload JSON inválido\"}");
      return;
    }
    ssid = bodyDoc["ssid"].as<String>();
    password = bodyDoc["password"].as<String>();
    topic = bodyDoc["topic"].as<String>();
  } else {
    ssid = server.arg("ssid");
    password = server.arg("password");
    topic = server.arg("topic");
  }

  if (ssid.isEmpty() || password.isEmpty() || topic.isEmpty()) {
    server.send(400, "application/json", "{\"error\": \"Campos obrigatórios ausentes\"}");
    return;
  }

  preferences.putString("wifi_ssid", ssid);
  preferences.putString("wifi_password", password);
  preferences.putString("ntfy_topic", topic);

  storedSsid = ssid;
  storedPassword = password;
  storedTopic = topic;

  server.send(200, "application/json", "{\"success\": true}");

  delay(500);
  ESP.restart();
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
  server.on("/updateConfig", HTTP_POST, handleUpdateConfig);
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
}

void setup() {
  Serial.begin(115200);
  pinMode(CONFIG_PIN, INPUT_PULLUP);
  loadPreferences();

  bool configPressed = digitalRead(CONFIG_PIN) == LOW;
  bool hasWifiConfig = storedSsid.length() > 0 && storedPassword.length() > 0;

  if (!hasWifiConfig || configPressed || !connectToWiFi()) {
    shouldStartAP = true;
  }

  if (shouldStartAP) {
    startCaptivePortal();
  } else {
    WiFi.mode(WIFI_STA);
    Serial.printf("Conectado em: %s | IP: %s\n", storedSsid.c_str(), WiFi.localIP().toString().c_str());

    server.on("/status", handleStatus);
    server.on("/config", handleConfig);
    server.on("/updateConfig", HTTP_POST, handleUpdateConfig);
    server.on("/trigger", []() {
      server.send(200, "application/json", "{\"triggered\": true}");
    });
    server.onNotFound([]() {
      server.send(404, "text/plain", "Not found");
    });
    server.begin();
  }
}

void loop() {
  if (shouldStartAP) {
    dnsServer.processNextRequest();
  }
  server.handleClient();
}
