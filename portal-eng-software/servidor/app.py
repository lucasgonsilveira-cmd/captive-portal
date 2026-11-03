#!/usr/bin/env python3
"""Servidor do portal cativo "Eng-Software" (Flask).

- Serve o front-end da pasta ../frontend
- Rotas da API usadas pelo front-end: /api/liberar, /api/evento,
  /api/inscrever-notificacoes, /api/login, /api/avisos
- Libera a internet de no máximo MAX_CLIENTES aparelhos (regras de iptables)
- Qualquer outro endereço é redirecionado para o portal (é isso que faz o
  Android/iOS/Windows abrirem a tela de "fazer login na rede")

Quem inicia tudo é o iniciar.sh. Variáveis vêm do config.env.
"""
import csv
import ipaddress
import json
import logging
import os
import re
import subprocess
import threading
from datetime import datetime
from pathlib import Path

from flask import Flask, Response, jsonify, redirect, request, send_from_directory
from werkzeug.exceptions import NotFound

BASE = Path(__file__).resolve().parent.parent
FRONT = BASE / "frontend"
DADOS = BASE / "dados"
DADOS.mkdir(exist_ok=True)

GATEWAY_IP = os.environ.get("GATEWAY_IP", "10.77.0.1")
MAX_CLIENTES = int(os.environ.get("MAX_CLIENTES", "10"))
DNS_REAL = os.environ.get("DNS_REAL", "8.8.8.8")
PORTA = int(os.environ.get("PORTAL_PORT", "80"))
SIMULACAO = os.environ.get("PORTAL_SIMULACAO") == "1"   # modo teste: não mexe no firewall
PORTAL_URL = os.environ.get("PORTAL_URL", f"http://{GATEWAY_IP}/")
REDE = ipaddress.ip_network(f"{GATEWAY_IP}/24", strict=False)
COMENTARIO = "portal-eng"          # marca das regras de firewall (o iniciar.sh usa para limpar)
HOSTS_DO_PORTAL = {GATEWAY_IP, "localhost", "127.0.0.1", ""}

app = Flask(__name__, static_folder=None)
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024

lock = threading.Lock()
liberados = {}   # mac -> {"ip": ..., "hora": ...}


def agora():
    return datetime.now().strftime("%H:%M:%S")


# ---------------------------------------------------------------- firewall
def iptables(*args, silencioso=False):
    cmd = ["iptables", "-w", *args]
    if SIMULACAO:
        print("   [simulação]", " ".join(cmd), flush=True)
        return True
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        if not silencioso:
            print("   ERRO iptables:", r.stderr.strip(), flush=True)
        return False
    return True


def _regras(ip, mac):
    """Regras de UM aparelho liberado, na ordem em que devem valer."""
    base = ["-s", ip, "-m", "mac", "--mac-source", mac,
            "-m", "comment", "--comment", COMENTARIO]
    return [
        # DNS de quem já foi liberado passa a ser o DNS real (não o do portal)
        ("nat", "PORTAL_PRE", base + ["-p", "udp", "--dport", "53", "-j", "DNAT", "--to-destination", DNS_REAL]),
        ("nat", "PORTAL_PRE", base + ["-p", "tcp", "--dport", "53", "-j", "DNAT", "--to-destination", DNS_REAL]),
        # ...e o resto do tráfego não é mais desviado para o portal
        ("nat", "PORTAL_PRE", base + ["-j", "RETURN"]),
        # permite encaminhar para a internet
        ("filter", "PORTAL_FWD", base + ["-j", "ACCEPT"]),
    ]


def aplicar_liberacao(ip, mac):
    # -I ... 1 coloca no topo; por isso inserimos de trás para frente
    for tabela, cadeia, regra in reversed(_regras(ip, mac)):
        if not iptables("-t", tabela, "-I", cadeia, "1", *regra):
            remover_liberacao(ip, mac)
            return False
    return True


def remover_liberacao(ip, mac):
    for tabela, cadeia, regra in _regras(ip, mac):
        iptables("-t", tabela, "-D", cadeia, *regra, silencioso=True)


# ---------------------------------------------------------------- cliente
def ip_do_cliente():
    if SIMULACAO:
        return request.headers.get("X-Cliente-Teste") or request.remote_addr
    return request.remote_addr


def mac_do_ip(ip):
    if SIMULACAO:
        n = int(ipaddress.ip_address(ip)) & 0xFFFFFFFF
        return "02:00:" + ":".join(f"{(n >> s) & 255:02x}" for s in (24, 16, 8, 0))
    try:
        with open("/proc/net/arp") as f:
            next(f)
            for linha in f:
                c = linha.split()
                if len(c) >= 4 and c[0] == ip and c[3] != "00:00:00:00:00:00":
                    return c[3].lower()
    except OSError:
        pass
    return None


# ---------------------------------------------------------------- API
@app.post("/api/liberar")
def api_liberar():
    ip = ip_do_cliente()
    if ip in ("127.0.0.1", "::1", GATEWAY_IP):
        # Clique no navegador do próprio notebook (apresentador): ele já tem internet,
        # então só mostramos a tela de sucesso, sem gastar uma das vagas.
        print(f"[{agora()}] clique no próprio notebook (nada a liberar)", flush=True)
        return jsonify(ok=True, mensagem="Este é o notebook do apresentador; ele já tem internet.")
    try:
        endereco = ipaddress.ip_address(ip)
    except ValueError:
        return jsonify(ok=False, erro="Não foi possível identificar o seu aparelho."), 400

    if not SIMULACAO and (endereco not in REDE or str(endereco) == GATEWAY_IP):
        return jsonify(ok=False, erro="Conecte-se pelo celular à rede Eng-Software para liberar o acesso."), 400

    mac = mac_do_ip(ip)
    if not mac:
        return jsonify(ok=False, erro="Não consegui identificar o seu aparelho na rede. Tente de novo."), 400

    with lock:
        if mac in liberados:
            antigo = liberados[mac]["ip"]
            if antigo != ip:               # o aparelho trocou de IP
                remover_liberacao(antigo, mac)
                if not aplicar_liberacao(ip, mac):
                    del liberados[mac]
                    return jsonify(ok=False, erro="Erro ao liberar o acesso. Tente novamente."), 500
                liberados[mac]["ip"] = ip
            return jsonify(ok=True, mensagem="Seu acesso já estava liberado.")

        if len(liberados) >= MAX_CLIENTES:
            print(f"[{agora()}] RECUSADO (limite {MAX_CLIENTES} atingido): {ip} {mac}", flush=True)
            return jsonify(
                ok=False,
                erro=f"As {MAX_CLIENTES} vagas de internet desta apresentação já foram usadas.",
            ), 429

        if not aplicar_liberacao(ip, mac):
            return jsonify(ok=False, erro="Erro ao liberar o acesso. Tente novamente."), 500
        liberados[mac] = {"ip": ip, "hora": agora()}
        print(f"[{agora()}] LIBERADO {len(liberados)}/{MAX_CLIENTES}: {ip} {mac}", flush=True)
    return jsonify(ok=True)


_EVENTOS = {"ver_curso", "interesse"}
_ID_CURSO = re.compile(r"^[a-z]{1,10}$")


def _csv_seguro(valor):
    """Evita que uma célula comece com = + - @ (injeção de fórmula no Excel/Calc)."""
    valor = str(valor)
    return "'" + valor if valor[:1] in ("=", "+", "-", "@") else valor


def _acrescentar_csv(nome, cabecalho, linha):
    caminho = DADOS / nome
    novo = not caminho.exists()
    with caminho.open("a", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        if novo:
            w.writerow(cabecalho)
        w.writerow(linha)


@app.post("/api/evento")
def api_evento():
    d = request.get_json(silent=True) or {}
    tipo, curso = str(d.get("tipo", "")), str(d.get("curso", ""))
    if tipo in _EVENTOS and _ID_CURSO.match(curso):
        with lock:
            _acrescentar_csv("eventos.csv", ["data_hora", "tipo", "curso"],
                             [datetime.now().isoformat(timespec="seconds"), tipo, curso])
    return jsonify(ok=True)


_EMAIL = re.compile(r"^[^@\s]{1,64}@[^@\s]{1,255}\.[^@\s]{2,}$")
_TOPICOS = {"vestibular", "inicio_aulas", "eventos_cursos", "curso", "eventos"}


@app.post("/api/inscrever-notificacoes")
def api_inscrever():
    d = request.get_json(silent=True) or {}
    email = str(d.get("email", "")).strip().lower()
    curso = str(d.get("curso", "") or "")
    origem = str(d.get("origem", ""))[:30]
    topicos = sorted({t for t in (d.get("topicos") or []) if t in _TOPICOS})

    if not _EMAIL.match(email):
        return jsonify(ok=False, erro="Informe um e-mail válido."), 400
    if d.get("consentimento") is not True:
        return jsonify(ok=False, erro="É preciso concordar em receber os avisos."), 400
    if curso and not _ID_CURSO.match(curso):
        return jsonify(ok=False, erro="Curso inválido."), 400
    if not topicos:
        return jsonify(ok=False, erro="Escolha pelo menos um tipo de aviso."), 400

    arquivo = DADOS / "inscricoes.csv"
    with lock:
        if arquivo.exists():
            with arquivo.open(newline="", encoding="utf-8") as f:
                for linha in csv.DictReader(f):
                    if linha.get("email", "").lstrip("'") == email and linha.get("curso", "") == curso:
                        return jsonify(ok=True, mensagem="Esse e-mail já estava cadastrado. Obrigado!")
        _acrescentar_csv(
            "inscricoes.csv",
            ["data_hora", "email", "curso", "topicos", "origem", "consentimento"],
            [datetime.now().isoformat(timespec="seconds"), _csv_seguro(email), curso,
             ";".join(topicos), origem, "sim"],
        )
    print(f"[{agora()}] INSCRIÇÃO: {email} curso={curso or '-'}", flush=True)
    return jsonify(ok=True, mensagem="Cadastro confirmado! (Protótipo de demonstração: o e-mail fica só no notebook do apresentador e nenhum aviso é enviado.)")


def _ler_json(nome, padrao):
    try:
        return json.loads((DADOS / nome).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return padrao


@app.get("/api/avisos")
def api_avisos():
    return jsonify(avisos=_ler_json("avisos.json", []))


_RA = re.compile(r"^[0-9A-Za-z]{1,20}$")


@app.post("/api/login")
def api_login():
    d = request.get_json(silent=True) or {}
    ra = str(d.get("ra", "")).strip()
    aluno = _ler_json("alunos.json", {}).get(ra) if _RA.match(ra) else None
    if not aluno:
        return jsonify(ok=False, erro="RA não encontrado. Confira o número e tente novamente."), 404
    return jsonify(ok=True, nome=aluno.get("nome", ""), avisos=aluno.get("avisos", []),
                   horarios=aluno.get("horarios", []))


# ---------------------------------------------------------------- painel do apresentador
def _so_local():
    return request.remote_addr in ("127.0.0.1", "::1", GATEWAY_IP)


@app.get("/admin")
def admin():
    if not _so_local():
        return redirect(PORTAL_URL, 302)
    with lock:
        itens = sorted(liberados.items(), key=lambda kv: kv[1]["hora"])
    linhas = "".join(
        f"<tr><td>{v['hora']}</td><td>{v['ip']}</td><td>{m}</td>"
        f"<td><form method='post' action='/admin/remover'><input type='hidden' name='mac' value='{m}'>"
        f"<button>Remover</button></form></td></tr>"
        for m, v in itens
    ) or "<tr><td colspan='4'>Ninguém liberado ainda.</td></tr>"
    html = f"""<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
<meta http-equiv="refresh" content="5"><title>Painel do apresentador</title>
<style>body{{font-family:system-ui,sans-serif;max-width:760px;margin:30px auto;padding:0 16px}}
h1{{margin:0 0 4px}}.n{{font-size:46px;font-weight:800;color:{'#c9001c' if len(itens) >= MAX_CLIENTES else '#087849'}}}
table{{border-collapse:collapse;width:100%;margin:14px 0}}td,th{{border-bottom:1px solid #ddd;padding:8px;text-align:left}}
button{{padding:6px 12px;cursor:pointer}}</style></head><body>
<h1>Painel do apresentador</h1><p>Rede <b>Eng-Software</b> · atualiza sozinho a cada 5 s</p>
<div class="n">{len(itens)}/{MAX_CLIENTES}</div><div>aparelhos com internet liberada</div>
<table><tr><th>Hora</th><th>IP</th><th>MAC</th><th></th></tr>{linhas}</table>
<form method="post" action="/admin/zerar" onsubmit="return confirm('Remover o acesso de todos?')">
<button>Zerar todos</button></form></body></html>"""
    return Response(html, mimetype="text/html")


@app.post("/admin/remover")
def admin_remover():
    if not _so_local():
        return redirect(PORTAL_URL, 302)
    mac = request.form.get("mac", "")
    with lock:
        item = liberados.pop(mac, None)
        if item:
            remover_liberacao(item["ip"], mac)
            print(f"[{agora()}] REMOVIDO: {item['ip']} {mac}", flush=True)
    return redirect("/admin", 303)


@app.post("/admin/zerar")
def admin_zerar():
    if not _so_local():
        return redirect(PORTAL_URL, 302)
    with lock:
        for mac, item in list(liberados.items()):
            remover_liberacao(item["ip"], mac)
        liberados.clear()
        print(f"[{agora()}] TODOS REMOVIDOS", flush=True)
    return redirect("/admin", 303)


# ---------------------------------------------------------------- site + captura
@app.route("/", defaults={"caminho": ""})
@app.route("/<path:caminho>")
def site(caminho):
    host = request.host.split(":")[0]
    if host not in HOSTS_DO_PORTAL:
        # Qualquer site digitado (ou o teste de "tem internet?" do celular) cai no portal
        return redirect(PORTAL_URL, 302)
    try:
        return send_from_directory(FRONT, caminho or "index.html")
    except NotFound:
        return redirect(PORTAL_URL, 302)


@app.after_request
def sem_cache(resp):
    resp.headers["Cache-Control"] = "no-cache"
    return resp


if __name__ == "__main__":
    logging.getLogger("werkzeug").setLevel(logging.WARNING)
    try:                                   # tira o aviso "development server" do terminal (só poluía a tela)
        import flask.cli
        flask.cli.show_server_banner = lambda *args, **kwargs: None
    except Exception:
        pass
    modo = "SIMULAÇÃO (firewall não é alterado)" if SIMULACAO else "REDE REAL"
    print(f"Portal no ar [{modo}] · porta {PORTA} · limite {MAX_CLIENTES} aparelhos", flush=True)
    app.run(host="0.0.0.0", port=PORTA, threaded=True)
