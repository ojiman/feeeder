from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from functools import partial
from pathlib import Path
import sys
root=Path(sys.argv[1]);server=ThreadingHTTPServer(('127.0.0.1',0),partial(SimpleHTTPRequestHandler,directory=str(root/'web')))
(root/'port.txt').write_text(str(server.server_address[1]))
print(server.server_address,flush=True)
server.serve_forever()
