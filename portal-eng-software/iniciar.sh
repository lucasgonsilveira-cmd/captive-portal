#!/usr/bin/env bash
# ======================================================================
#  Portal cativo "Eng-Software" — UM comando liga tudo
#
#     bash iniciar.sh            rede Wi-Fi + portal (para a apresentação)
#     bash iniciar.sh preparar   só instala o que falta (faça isso COM internet, antes)
#     bash iniciar.sh teste      só o site no navegador (não mexe na rede)
#
#  Para encerrar: Ctrl+C  (o notebook volta ao normal sozinho)
# ======================================================================
set -u
DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$DIR" || exit 1
# shellcheck disable=SC1091
source "$DIR/config.env"
PORTAL_PORT="${PORTAL_PORT:-80}"
TMP=/tmp/portal-eng-software
SYS_NET="${SYS_NET:-/sys/class/net}"      # (só muda nos testes automáticos)

NEGRITO=$'\e[1m'; VERDE=$'\e[32m'; AMARELO=$'\e[33m'; VERMELHO=$'\e[31m'; FIM=$'\e[0m'
info()  { echo "${NEGRITO}➜${FIM} $*"; }
ok()    { echo "${VERDE}✔${FIM} $*"; }
aviso() { echo "${AMARELO}!${FIM} $*"; }
falha() { echo "${VERMELHO}✘ $*${FIM}"; }

uso() {
  echo "Uso:  bash iniciar.sh            liga a rede Wi-Fi + portal (apresentação)"
  echo "      bash iniciar.sh preparar   instala o que falta (precisa de internet)"
  echo "      bash iniciar.sh teste      só o site em http://localhost:8080 (sem mexer na rede)"
}

# ----------------------------------------------------------------------
# O portal abre ANTES da internet ser liberada, então não pode usar CDN:
# o Bootstrap 5.3.3 já vem dentro do projeto (frontend/vendor/bootstrap).
# ----------------------------------------------------------------------
for f in frontend/index.html frontend/vendor/bootstrap/bootstrap.min.css frontend/vendor/bootstrap/bootstrap.bundle.min.js; do
  [ -f "$DIR/$f" ] || { falha "Arquivo faltando no projeto: $f (extraia o .zip de novo)"; exit 1; }
done

# ----------------------------------------------------------------------
# Modo teste: só o site, sem rede e sem sudo
# ----------------------------------------------------------------------
modo_teste() {
  command -v python3 >/dev/null 2>&1 || { falha "python3 não encontrado."; exit 1; }
  python3 -c "import flask" 2>/dev/null || { falha "Falta o Flask. Rode:  bash iniciar.sh preparar   (com internet)"; exit 1; }
  export PORTAL_SIMULACAO=1 PORTAL_PORT=8080 PORTAL_URL="http://localhost:8080/"
  export GATEWAY_IP="${REDE_BASE}.1" MAX_CLIENTES DNS_REAL
  echo
  ok "Modo teste. Abra no navegador:  http://localhost:8080"
  echo "   Painel do apresentador:        http://localhost:8080/admin"
  echo "   (Ctrl+C para sair)"
  echo
  exec python3 "$DIR/servidor/app.py"
}

SO_PREPARAR=0
case "${1:-}" in
  teste) modo_teste ;;
  preparar) SO_PREPARAR=1 ;;
  ""|iniciar) ;;
  -h|--ajuda|ajuda) uso; exit 0 ;;
  *) uso; exit 1 ;;
esac

# ----------------------------------------------------------------------
# Precisa de administrador (criar rede, firewall)
# ----------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
  info "Pedindo a senha de administrador (necessária para criar a rede)..."
  exec sudo bash "$DIR/iniciar.sh" "$@"
fi
mkdir -p "$TMP"

# ----------------------------------------------------------------------
# 1) Programas necessários (instala sozinho se faltar; precisa de internet)
# ----------------------------------------------------------------------
faltam=()
command -v hostapd  >/dev/null 2>&1 || faltam+=(hostapd)
command -v iw       >/dev/null 2>&1 || faltam+=(iw)
command -v iptables >/dev/null 2>&1 || faltam+=(iptables)
command -v rfkill   >/dev/null 2>&1 || faltam+=(rfkill)
command -v dnsmasq  >/dev/null 2>&1 || [ -x /usr/sbin/dnsmasq ] || faltam+=(dnsmasq-base)
python3 -c "import flask" 2>/dev/null || faltam+=(python3-flask)
if [ ${#faltam[@]} -gt 0 ]; then
  info "Instalando o que falta: ${faltam[*]}  (precisa de internet)"
  apt-get update -qq || true
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${faltam[@]}" || {
    falha "Não consegui instalar. Confira se o notebook está com internet e rode de novo."
    exit 1
  }
fi
if [ "$SO_PREPARAR" = 1 ]; then
  ok "Tudo instalado. Agora é só rodar:  bash iniciar.sh"
  exit 0
fi
# serviços do sistema que atrapalhariam (se existirem)
systemctl stop hostapd dnsmasq 2>/dev/null || true
DNSMASQ="$(command -v dnsmasq || echo /usr/sbin/dnsmasq)"

# ----------------------------------------------------------------------
# Limpeza / restauração (roda no começo e no final)
# ----------------------------------------------------------------------
matar_pidfile() { local f="$TMP/$1.pid"; [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null; rm -f "$f"; }

#### LIMPEZA-INICIO
limpar_regras() {
  local dump
  dump="$(iptables-save 2>/dev/null)" || return 0
  [ -n "$dump" ] || return 0
  if printf '%s\n' "$dump" | grep -q -e 'portal-eng' -e 'PORTAL_'; then
    printf '%s\n' "$dump" | grep -v -e 'portal-eng' -e 'PORTAL_' | iptables-restore
  fi
}
#### LIMPEZA-FIM

desfazer_interface() {
  if iw dev ap0 info >/dev/null 2>&1; then
    ip link set ap0 down 2>/dev/null
    iw dev ap0 del 2>/dev/null
  fi
  if [ -f "$TMP/modo_cabo" ]; then          # a placa Wi-Fi foi usada como ponto de acesso
    local w; w="$(cat "$TMP/modo_cabo")"
    ip addr flush dev "$w" 2>/dev/null
    ip link set "$w" down 2>/dev/null
    iw dev "$w" set type managed 2>/dev/null
    command -v nmcli >/dev/null 2>&1 && nmcli device set "$w" managed yes 2>/dev/null
    ip link set "$w" up 2>/dev/null
    rm -f "$TMP/modo_cabo"
  fi
}

limpar_tudo() {
  matar_pidfile hostapd
  matar_pidfile dnsmasq
  pkill -f "$TMP/hostapd.conf" 2>/dev/null
  pkill -f "$DIR/servidor/app.py" 2>/dev/null
  limpar_regras
  desfazer_interface
}

parar() {
  trap - EXIT INT TERM
  echo
  info "Encerrando e devolvendo o notebook ao normal..."
  limpar_tudo
  [ -n "${FWD_ANTIGO:-}" ] && echo "$FWD_ANTIGO" > /proc/sys/net/ipv4/ip_forward
  if [ -n "${SUDO_USER:-}" ]; then
    chown -R "$SUDO_USER": "$DIR/dados" 2>/dev/null
  fi
  ok "Tudo restaurado. Pode fechar."
}
trap 'exit 130' INT TERM HUP     # Ctrl+C ou fechar o terminal também restauram tudo
trap parar EXIT

# ----------------------------------------------------------------------
# 2) Limpa restos de uma execução anterior e examina a rede
# ----------------------------------------------------------------------
limpar_tudo
rfkill unblock wifi 2>/dev/null || true       # "WLAN soft blocked"

if [ -z "${WIFI_IF:-}" ]; then
  # (ignora o "ap0": é a interface virtual que ESTE script cria; nunca é a placa de verdade)
  WIFI_IF="$(for d in "$SYS_NET"/*/wireless; do [ -e "$d" ] && basename "$(dirname "$d")"; done | grep -vx 'ap0' | head -n1)"
fi
[ -n "$WIFI_IF" ] || { falha "Não encontrei nenhuma placa Wi-Fi neste notebook."; exit 1; }
iw list 2>/dev/null | grep -q '\* AP$' || { falha "A placa Wi-Fi não suporta criar rede (modo AP)."; exit 1; }

UP_IF="$(ip -4 route show default | awk '{for(i=1;i<NF;i++) if($i=="dev"){print $(i+1); exit}}')"
if [ -z "$UP_IF" ]; then
  falha "O notebook está SEM internet."
  echo "   Conecte o notebook ao Wi-Fi do celular (hotspot ligado) — ou use o cabo USB com"
  echo "   'Tethering USB' — e rode de novo."
  exit 1
fi
ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 || aviso "A conexão '$UP_IF' não respondeu ao teste de internet. Confira o 4G do celular."

if [ -d "$SYS_NET/$UP_IF/wireless" ]; then MODO=wifi; else MODO=cabo; fi

# faixa de IP livre?
if ip -4 route show | awk -v n="${REDE_BASE}." 'index($1, n)==1 {f=1} END{exit !f}'; then
  aviso "A faixa $REDE_BASE.0/24 já está em uso pelo celular; usando 10.88.0.0/24."
  REDE_BASE="10.88.0"
fi
GATEWAY_IP="$REDE_BASE.1"
SUBNET="$REDE_BASE.0/24"

# porta do portal livre?
if ss -ltnH "sport = :$PORTAL_PORT" 2>/dev/null | grep -q .; then
  falha "A porta $PORTAL_PORT já está em uso por outro programa (apache/nginx?)."
  echo "   Descubra qual com:  sudo ss -ltnp 'sport = :$PORTAL_PORT'   e pare esse programa."
  exit 1
fi

# ----------------------------------------------------------------------
# 3) Interface do ponto de acesso
# ----------------------------------------------------------------------
dica_plano_b() {
  echo
  echo "   PLANO B: usar o celular por CABO USB (ou um cabo de rede com internet)."
  echo "   1) Conecte o cabo USB ao notebook"
  echo "   2) No celular, ligue 'Tethering USB' (a opção só aparece depois de conectar o cabo)"
  echo "   3) Desconecte o notebook do Wi-Fi do celular"
  echo "   4) Rode  bash iniciar.sh  de novo (ele percebe sozinho)"
}

# Pede ao NetworkManager para largar a interface (senão ele briga com o hostapd)
soltar_do_nm() {
  command -v nmcli >/dev/null 2>&1 || return 0
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    nmcli device set "$1" managed no 2>/dev/null
    nmcli -t -f DEVICE,STATE device 2>/dev/null | grep -q "^$1:unmanaged" && return 0
    sleep 0.4
  done
  return 0
}

if [ "$MODO" = "wifi" ]; then
  info "Internet vem do Wi-Fi do celular ($UP_IF). Criando a rede '$SSID' na mesma placa..."
  freq="$(iw dev "$UP_IF" link 2>/dev/null | awk '/freq:/ {printf "%d", $2; exit}')"
  if [ -z "$freq" ]; then falha "Não consegui ler o canal do Wi-Fi do celular."; dica_plano_b; exit 1; fi
  if [[ $freq -ge 2412 && $freq -le 2472 ]]; then
    HW_MODE=g; CANAL=$(( (freq - 2407) / 5 ))
  elif [[ ( $freq -ge 5180 && $freq -le 5240 ) || ( $freq -ge 5745 && $freq -le 5825 ) ]]; then
    HW_MODE=a; CANAL=$(( (freq - 5000) / 5 ))
  else
    falha "O hotspot do celular está num canal (${freq} MHz) que não dá para repetir."
    echo "   No celular, configure o hotspot para a banda 2,4 GHz e reconecte o notebook."
    dica_plano_b; exit 1
  fi
  ok "Canal do celular: $CANAL (${freq} MHz). A rede Eng-Software usará o mesmo canal."
  iw dev "$UP_IF" set power_save off 2>/dev/null || true
  AP_IF=ap0
  if ! iw dev "$UP_IF" interface add "$AP_IF" type __ap 2>"$TMP/iw.err"; then
    falha "A placa não deixou criar a rede enquanto está ligada ao celular:"; cat "$TMP/iw.err"
    dica_plano_b; exit 1
  fi
  soltar_do_nm "$AP_IF"
  mac_up="$(cat "$SYS_NET/$UP_IF/address")"; mac_ap="$(cat "$SYS_NET/$AP_IF/address")"
  if [ "$mac_up" = "$mac_ap" ]; then            # precisa ser um endereço diferente
    ultimo=$((16#${mac_up##*:}))
    ip link set dev "$AP_IF" address "${mac_up%:*}:$(printf '%02x' $(( (ultimo + 1) % 256 )))" 2>/dev/null || true
  fi
else
  info "Internet vem de '$UP_IF' (cabo/USB). Usando a placa Wi-Fi ($WIFI_IF) para criar a rede '$SSID'..."
  AP_IF="$WIFI_IF"; HW_MODE=g; CANAL=6
  echo "$WIFI_IF" > "$TMP/modo_cabo"
  if command -v nmcli >/dev/null 2>&1; then
    nmcli device disconnect "$AP_IF" >/dev/null 2>&1 || true
    soltar_do_nm "$AP_IF"
  fi
  ip addr flush dev "$AP_IF" 2>/dev/null || true
fi
ip link set "$AP_IF" up

# ----------------------------------------------------------------------
# 4) Wi-Fi aberto (hostapd) — tenta a configuração completa e, se falhar,
#    uma bem simples (algumas placas não aceitam todas as opções)
# ----------------------------------------------------------------------
subir_hostapd() {   # $1 = completo | simples
  {
    echo "interface=$AP_IF"
    echo "driver=nl80211"
    echo "ssid=$SSID"
    echo "hw_mode=$HW_MODE"
    echo "channel=$CANAL"
    if [ "$1" = completo ]; then
      printf '%s\n' "country_code=BR" "ieee80211d=1" "ieee80211n=1" "wmm_enabled=1" \
                    "auth_algs=1" "ignore_broadcast_ssid=0" "ap_isolate=1" "max_num_sta=30"
    fi
  } > "$TMP/hostapd.conf"
  stdbuf -oL -eL hostapd "$TMP/hostapd.conf" >"$TMP/hostapd.log" 2>&1 &
  echo $! > "$TMP/hostapd.pid"
  local i
  for i in $(seq 1 30); do
    if grep -q 'AP-ENABLED' "$TMP/hostapd.log" 2>/dev/null; then return 0; fi
    kill -0 "$(cat "$TMP/hostapd.pid")" 2>/dev/null || return 1
    sleep 0.5
  done
  return 1
}

if ! subir_hostapd completo; then
  aviso "A primeira tentativa de abrir a rede falhou; tentando com uma configuração mais simples..."
  matar_pidfile hostapd; pkill -f "$TMP/hostapd.conf" 2>/dev/null
  cp "$TMP/hostapd.log" "$TMP/hostapd-tentativa1.log" 2>/dev/null
  sleep 1
  if ! subir_hostapd simples; then
    falha "O hostapd não conseguiu abrir a rede '$SSID'. Últimas linhas:"
    tail -n 12 "$TMP/hostapd.log" | sed 's/^/   /'
    if [ "$MODO" = wifi ] && [ "${freq:-0}" -ge 5000 ]; then
      aviso "O hotspot do celular está em 5 GHz. Mude a banda para 2,4 GHz no celular, reconecte o notebook e rode de novo."
    fi
    dica_plano_b
    exit 1
  fi
fi
ok "Rede Wi-Fi aberta '$SSID' no ar."

ip addr flush dev "$AP_IF" 2>/dev/null || true
ip addr add "$GATEWAY_IP/24" dev "$AP_IF"

# ----------------------------------------------------------------------
# 5) DHCP + DNS do portal (dnsmasq): todo nome vira o endereço do portal
# ----------------------------------------------------------------------
cat > "$TMP/dnsmasq.conf" <<EOF
user=root
interface=$AP_IF
bind-interfaces
listen-address=$GATEWAY_IP
except-interface=lo
no-resolv
no-hosts
no-poll
dhcp-authoritative
dhcp-range=$REDE_BASE.10,$REDE_BASE.200,255.255.255.0,1h
dhcp-option=3,$GATEWAY_IP
dhcp-option=6,$GATEWAY_IP
address=/#/$GATEWAY_IP
dhcp-leasefile=$TMP/dnsmasq.leases
log-dhcp
log-facility=$TMP/dnsmasq.log
EOF

subir_dnsmasq() {   # $1 = programa
  "$1" -k -C "$TMP/dnsmasq.conf" >"$TMP/dnsmasq.out" 2>&1 &
  echo $! > "$TMP/dnsmasq.pid"
  sleep 1
  kill -0 "$(cat "$TMP/dnsmasq.pid")" 2>/dev/null
}

if ! subir_dnsmasq "$DNSMASQ"; then
  # Plano B: usa uma cópia do programa (o AppArmor do Ubuntu/Mint às vezes barra o original)
  if cp "$DNSMASQ" "$TMP/dnsmasq-portal" 2>/dev/null && chmod 755 "$TMP/dnsmasq-portal" && subir_dnsmasq "$TMP/dnsmasq-portal"; then
    aviso "O dnsmasq só iniciou usando uma cópia do programa (normal em alguns sistemas)."
  else
    falha "O dnsmasq (DHCP/DNS) não iniciou:"
    cat "$TMP/dnsmasq.out" "$TMP/dnsmasq.log" 2>/dev/null | tail -n 8 | sed 's/^/   /'
    exit 1
  fi
fi
ok "DHCP e DNS do portal no ar."

# ----------------------------------------------------------------------
# 6) Firewall: quem não foi liberado só enxerga o portal
# ----------------------------------------------------------------------
#### FIREWALL-INICIO (o teste automático extrai este trecho; não apague as marcas)
ipt() { iptables -w "$@" || { falha "Erro no firewall: iptables $*"; exit 1; }; }
C=(-m comment --comment portal-eng)
FWD_ANTIGO="$(cat /proc/sys/net/ipv4/ip_forward)"
echo 1 > /proc/sys/net/ipv4/ip_forward

ipt -N PORTAL_FWD
ipt -N PORTAL_IN
ipt -t nat -N PORTAL_PRE

# encaminhamento (internet): bloqueado, exceto aparelhos liberados pelo servidor
ipt -A PORTAL_FWD -p tcp "${C[@]}" -j REJECT --reject-with tcp-reset
ipt -A PORTAL_FWD "${C[@]}" -j REJECT --reject-with icmp-port-unreachable
ipt -I FORWARD 1 -i "$AP_IF" "${C[@]}" -j PORTAL_FWD
ipt -I FORWARD 2 -o "$AP_IF" -m conntrack --ctstate RELATED,ESTABLISHED "${C[@]}" -j ACCEPT

# o que os celulares podem acessar NO notebook: DHCP, DNS e o portal
ipt -A PORTAL_IN -m conntrack --ctstate RELATED,ESTABLISHED "${C[@]}" -j ACCEPT
ipt -A PORTAL_IN -p udp --dport 67 "${C[@]}" -j ACCEPT
ipt -A PORTAL_IN -p udp --dport 53 "${C[@]}" -j ACCEPT
ipt -A PORTAL_IN -p tcp --dport 53 "${C[@]}" -j ACCEPT
ipt -A PORTAL_IN -p tcp --dport "$PORTAL_PORT" "${C[@]}" -j ACCEPT
ipt -A PORTAL_IN -p icmp "${C[@]}" -j ACCEPT
ipt -A PORTAL_IN -p tcp "${C[@]}" -j REJECT --reject-with tcp-reset
ipt -A PORTAL_IN "${C[@]}" -j REJECT --reject-with icmp-port-unreachable
ipt -I INPUT 1 -i "$AP_IF" "${C[@]}" -j PORTAL_IN

# desvio: DNS vai para o dnsmasq do portal e qualquer site http cai no portal
ipt -t nat -A PORTAL_PRE -p udp --dport 53 "${C[@]}" -j DNAT --to-destination "$GATEWAY_IP"
ipt -t nat -A PORTAL_PRE -p tcp --dport 53 "${C[@]}" -j DNAT --to-destination "$GATEWAY_IP"
ipt -t nat -A PORTAL_PRE -p tcp --dport 80 "${C[@]}" -j REDIRECT --to-ports "$PORTAL_PORT"
ipt -t nat -I PREROUTING 1 -i "$AP_IF" "${C[@]}" -j PORTAL_PRE
ipt -t nat -A POSTROUTING -s "$SUBNET" -o "$UP_IF" "${C[@]}" -j MASQUERADE
#### FIREWALL-FIM
ok "Firewall do portal configurado."

# ----------------------------------------------------------------------
# 7) Servidor do portal (Flask)
# ----------------------------------------------------------------------
export GATEWAY_IP MAX_CLIENTES DNS_REAL PORTAL_PORT
export PORTAL_URL="http://$GATEWAY_IP/"
python3 "$DIR/servidor/app.py" &
FLASK_PID=$!
sleep 2
if ! kill -0 "$FLASK_PID" 2>/dev/null; then falha "O servidor do portal não iniciou (veja a mensagem acima)."; exit 1; fi

if [ "$MODO" = "wifi" ]; then ORIGEM="Wi-Fi do celular ($UP_IF, canal $CANAL)"; else ORIGEM="cabo/USB ($UP_IF)"; fi
echo
echo "${VERDE}${NEGRITO}══════════════════════════════════════════════════════════${FIM}"
echo "${NEGRITO}  REDE PRONTA${FIM}"
echo "  Wi-Fi:      $SSID  (aberta)"
echo "  Portal:     http://$GATEWAY_IP     (se não abrir sozinho no celular, digite isso)"
echo "  Internet:   $ORIGEM"
echo "  Limite:     $MAX_CLIENTES aparelhos com internet"
echo "  Painel:     http://$GATEWAY_IP/admin   (abra no navegador DESTE notebook)"
echo "  Encerrar:   Ctrl+C"
echo "${VERDE}${NEGRITO}══════════════════════════════════════════════════════════${FIM}"
echo

wait "$FLASK_PID"
aviso "O servidor do portal parou (veja as mensagens acima). Encerrando a rede."
