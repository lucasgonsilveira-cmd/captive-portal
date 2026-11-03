#!/usr/bin/env bash
# ======================================================================
#  Diagnóstico do portal "Eng-Software"
#
#  Como usar:
#    1) Deixe o portal ligado (bash iniciar.sh) em um terminal.
#    2) Conecte o celular na rede Eng-Software e espere uns 20 segundos.
#    3) Abra OUTRO terminal nesta pasta e rode:   bash diagnostico.sh
#    4) Copie tudo o que aparecer (ou tire print) e envie.
#
#  Este script só LÊ informações. Não muda nada na rede.
# ======================================================================
if [ "$(id -u)" -ne 0 ]; then exec sudo bash "$0" "$@"; fi
TMP=/tmp/portal-eng-software

sec() { echo; echo "===== $* ====="; }

# Qual interface é o ponto de acesso? (lê do hostapd.conf que o iniciar.sh gerou)
AP_IF="$(sed -n 's/^interface=//p' "$TMP/hostapd.conf" 2>/dev/null | head -n1)"
AP_IF="${AP_IF:-ap0}"
GW="$(ip -4 -o addr show dev "$AP_IF" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1)"

echo "Diagnóstico do portal Eng-Software — $(date '+%d/%m/%Y %H:%M:%S')"
echo "Interface do ponto de acesso: $AP_IF   |   IP do portal: ${GW:-(sem IP!)}"

sec "1. Programas rodando (precisa ter hostapd, dnsmasq e app.py)"
pgrep -af 'hostapd|dnsmasq|servidor/app.py' | grep -v pgrep || echo "  NENHUM — o iniciar.sh está ligado?"

sec "2. Interfaces Wi-Fi (ap0 deve ser 'type AP' e wlo1 'type managed', no mesmo canal)"
iw dev 2>&1 | grep -E 'Interface|addr|ssid|type|channel' | sed 's/^/  /'
echo "  --- endereços IP:"
ip -br addr 2>&1 | grep -E "^($AP_IF|wlo1|wl|enp|enx|usb)" | sed 's/^/  /'

sec "3. Celulares CONECTADOS no Wi-Fi (se estiver vazio, ninguém associou)"
iw dev "$AP_IF" station dump 2>&1 | grep -E '^Station|inactive time|rx packets|tx packets|signal:' | sed 's/^/  /'

sec "4. DHCP: quem recebeu IP? (vazio = o celular conectou no Wi-Fi mas não pegou IP)"
echo "  --- leases:"; cat "$TMP/dnsmasq.leases" 2>/dev/null | sed 's/^/  /'
echo "  --- últimas linhas do log:"; grep -E 'DHCP' "$TMP/dnsmasq.log" 2>/dev/null | tail -n 12 | sed 's/^/  /'

sec "5. Portas abertas no notebook (53 e 67 = DHCP/DNS, 80 = portal)"
ss -lunp 2>/dev/null | grep -E ':(53|67)\b' | sed 's/^/  /'
ss -ltnp 2>/dev/null | grep -E ':80\b' | sed 's/^/  /'

sec "6. O portal responde aqui no próprio notebook? (esperado: 200 e 302)"
if [ -n "$GW" ]; then
python3 - "$GW" <<'EOF'
import http.client, sys
gw = sys.argv[1]
for host, path in ((gw, "/"), ("connectivitycheck.gstatic.com", "/generate_204")):
    try:
        c = http.client.HTTPConnection(gw, 80, timeout=5)
        c.request("GET", path, headers={"Host": host})
        r = c.getresponse()
        print(f"  Host {host}{path} -> HTTP {r.status} {r.getheader('Location') or ''}")
    except Exception as e:
        print(f"  Host {host}{path} -> ERRO: {e}")
EOF
else
  echo "  A interface $AP_IF está sem IP — por isso nada responde."
fi

sec "7. Firewall: contadores (pkts > 0 em PORTAL_IN = pacotes do celular chegaram ao notebook)"
echo "  --- INPUT (a 1ª regra deve ser a do portal):"
iptables -L INPUT -n -v --line-numbers 2>&1 | head -n 5 | sed 's/^/  /'
echo "  --- PORTAL_IN:";  iptables -L PORTAL_IN -n -v 2>&1 | sed 's/^/  /'
echo "  --- PORTAL_PRE (desvio para o portal):"; iptables -t nat -L PORTAL_PRE -n -v 2>&1 | sed 's/^/  /'

sec "8. Log do hostapd (últimas linhas)"
tail -n 12 "$TMP/hostapd.log" 2>/dev/null | sed 's/^/  /'

sec "9. NetworkManager (ap0 deve estar 'unmanaged') e internet do notebook"
nmcli -t -f DEVICE,STATE device 2>&1 | sed 's/^/  /'
echo "  rota padrão: $(ip -4 route show default | head -n1)"

echo
echo "===== FIM — copie tudo acima e envie ====="
