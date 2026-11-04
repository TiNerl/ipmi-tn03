#!/bin/bash
# Aguarda o zerotier-one subir e entra na rede definida em ZT_NETWORK_ID
for i in $(seq 1 60); do
  zerotier-cli info >/dev/null 2>&1 && break
  sleep 1
done

echo ">> ZeroTier: $(zerotier-cli info)"

if [ -n "$ZT_NETWORK_ID" ]; then
  for net in ${ZT_NETWORK_ID//,/ }; do
    zerotier-cli join "$net"
    echo ">> Pedido de entrada na rede $net enviado."
  done
  echo ">> Autorize o node ID acima em https://my.zerotier.com (Members)."
else
  echo ">> ZT_NETWORK_ID nao definido - nenhuma rede sera acessada."
fi

# Mostra o status periodicamente no log
while true; do
  sleep 300
  zerotier-cli listnetworks
done
