import http.server
import socketserver

PORT = 8000


class CustomRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Required headers for cross-origin isolation
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        return super().end_headers()


with socketserver.TCPServer(("", PORT), CustomRequestHandler) as httpd:
    print(f"Serving at port {PORT}")
    httpd.serve_forever()
