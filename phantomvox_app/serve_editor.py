import http.server, socketserver, os

class Handler(http.server.SimpleHTTPRequestHandler):
    ext = http.server.SimpleHTTPRequestHandler.extensions_map.copy()
    ext.update({'.wasm':'application/wasm','.js':'application/javascript','.mjs':'application/javascript'})
    extensions_map = ext

    def translate_path(self, path):
        # /editor/* -> public/editor/dist/*
        if path.startswith('/editor/') or path == '/editor':
            base = os.path.join(os.path.dirname(__file__), 'public', 'editor', 'dist')
            rel = path.replace('/editor', '', 1).lstrip('/')
            return os.path.join(base, rel) if rel else os.path.join(base, 'index.html')
        # /* -> build/web/*
        base = os.path.join(os.path.dirname(__file__), 'build', 'web')
        return os.path.join(base, path.lstrip('/'))

with socketserver.TCPServer(('0.0.0.0', 8900), Handler) as httpd:
    print('Serving Flutter on /, Editor on /editor/')
    httpd.serve_forever()
