import os
import json
from http.server import BaseHTTPRequestHandler
import firebase_admin
from firebase_admin import credentials, messaging

# Inicializa o Firebase Admin SDK apenas uma vez (evita duplicação)
if not firebase_admin._apps:
    cred_json = os.environ.get("FIREBASE_CREDENTIALS_JSON")
    if cred_json:
        try:
            cred_dict = json.loads(cred_json)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
        except Exception as e:
            print(f"Erro ao carregar credenciais do Firebase: {e}")
    else:
        print("Aviso: Variável FIREBASE_CREDENTIALS_JSON não encontrada.")

class handler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            # Lê o corpo da requisição (payload enviado pelo Sentinel-Hub)
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.do_read_body(content_length)
            
            data = json.loads(body.decode('utf-8'))
            token = data.get("token") # Token FCM do dispositivo do usuário
            title = data.get("title", "Alerta do Sentinel-Hub")
            message = data.get("message", "Movimento detectado no sensor 433MHz!")

            if not token:
                self.send_response(400)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({"error": "Token FCM ausente"}).encode('utf-8'))
                return

            # Cria a mensagem de Notificação Push
            message_payload = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=message,
                ),
                token=token,
            )

            # Envia a notificação via Firebase Cloud Messaging
            response = messaging.send(message_payload)

            # Resposta de sucesso
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"success": True, "message_id": response}).encode('utf-8'))

        except Exception as e:
            self.send_response(500)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"success": False, "error": str(e)}).encode('utf-8'))

    def do_GET(self):
        # Apenas para testar se a API está no ar
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({"status": "Sentinel-Hub API online e operacional"}).encode('utf-8'))

    def do_read_body(self, length):
        if length > 0:
            return self.rfile.read(length)
        return b""
