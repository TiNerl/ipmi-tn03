#!/bin/bash
# Entrypoint do container de acesso TN03
set -e

: "${VNC_PASSWORD:=trocar123}"
: "${VNC_RESOLUTION:=1600x900}"
: "${IPMI_URL:=}"
: "${ZT_NETWORK_ID:=}"
: "${TZ:=America/Fortaleza}"

ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone

# --- Senha do VNC -----------------------------------------------------------
install -d -o ipmi -g ipmi -m 700 /home/ipmi/.vnc
echo "$VNC_PASSWORD" | vncpasswd -f > /home/ipmi/.vnc/passwd
chown ipmi:ipmi /home/ipmi/.vnc/passwd && chmod 600 /home/ipmi/.vnc/passwd
if [ "$VNC_PASSWORD" = "trocar123" ]; then
  echo "!! AVISO: usando a senha VNC padrao. Defina VNC_PASSWORD." >&2
fi

# --- Pagina inicial do Firefox = painel IPMI --------------------------------
POL=/etc/firefox/policies/policies.json
if [ -n "$IPMI_URL" ]; then
  sed -i "s#\"URL\": \"[^\"]*\"#\"URL\": \"${IPMI_URL}\"#" "$POL"
  [ -d /usr/lib/firefox-esr/distribution ] && cp "$POL" /usr/lib/firefox-esr/distribution/policies.json
fi

# --- ZeroTier ---------------------------------------------------------------
if [ -c /dev/net/tun ]; then
  export ZT_ENABLED=true
else
  echo "!! AVISO: /dev/net/tun ausente - ZeroTier nao sera iniciado." >&2
  echo "   Rode com: --cap-add NET_ADMIN --device /dev/net/tun" >&2
  sed -i 's/^autostart=true/autostart=false/' /etc/supervisor/conf.d/zerotier.conf
fi

export VNC_RESOLUTION ZT_NETWORK_ID
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
