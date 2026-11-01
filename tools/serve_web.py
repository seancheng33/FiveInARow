#!/usr/bin/env python3
"""本地预览 Web 导出的静态服务器。

Godot 4.2 的 Web 模板是线程构建，wasm 里引用 SharedArrayBuffer，
所以浏览器要求页面处于「跨源隔离」状态，服务器必须发两个头：

    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp

少了这两个头，游戏会停在 "The following features required to run Godot
projects on the Web are missing" 的报错框上。普通的 `python -m http.server`
不带这两个头，所以不能用它来测。

用法：
    python tools/serve_web.py                # 默认 dist/web，端口 8060
    python tools/serve_web.py --port 9000
    python tools/serve_web.py --dir 其它目录
然后浏览器打开 http://127.0.0.1:8060/
"""

import argparse
import functools
import http.server
import os
import socketserver
import sys

HEADERS = {
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Embedder-Policy": "require-corp",
    # wasm 体积大，别让浏览器缓存旧版本
    "Cache-Control": "no-store",
}


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        for k, v in HEADERS.items():
            self.send_header(k, v)
        super().end_headers()

    def log_message(self, fmt: str, *args) -> None:
        # 只打错误，正常请求太吵
        if str(args[1] if len(args) > 1 else "") != "200":
            sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    default_dir = os.path.join(os.path.dirname(here), "dist", "web")

    ap = argparse.ArgumentParser(description="预览 Godot Web 导出（带跨源隔离头）")
    ap.add_argument("--dir", default=default_dir, help="静态目录，默认 dist/web")
    ap.add_argument("--port", type=int, default=8060)
    ap.add_argument("--bind", default="127.0.0.1")
    args = ap.parse_args()

    if not os.path.isfile(os.path.join(args.dir, "index.html")):
        print("找不到 %s/index.html" % args.dir, file=sys.stderr)
        print("先导出：godot --headless --path . --export-release \"Web\" dist/web/index.html", file=sys.stderr)
        return 1

    handler = functools.partial(Handler, directory=args.dir)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer((args.bind, args.port), handler) as httpd:
        print("serving %s" % args.dir)
        print("open    http://%s:%d/" % (args.bind, args.port))
        print("（已发 COOP/COEP 头，Ctrl+C 停止）")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nstopped")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
