# Container de acesso TN03 — IPMI Supermicro X9DBL-iF

Desktop remoto (VNC/noVNC) com tudo que é preciso para administrar o BMC da
placa **Supermicro X9DBL-iF (MBD-X9DBL-IF-B)**:

| Componente | Para quê |
|---|---|
| Firefox ESR (com TLS 1.0 / 3DES liberados) | Painel web do IPMI da geração X9 |
| OpenJDK 8 + IcedTea-Web (`javaws`) | Abre o *Console Redirection* (`launch.jnlp` / iKVM) |
| Supermicro IPMIView (JRE embutido) | Gerência IPMI, KVM, Virtual Media, SOL |
| ZeroTier One | Acesso remoto ao container sem abrir portas |
| TigerVNC + noVNC + Fluxbox | Desktop acessível por cliente VNC ou navegador |
| ipmitool | Linha de comando (`ipmitool -I lanplus -H <ip> -U ADMIN ...`) |

## 1. Preparar

```bash
cp .env.example .env      # ajuste VNC_PASSWORD, IPMI_URL e ZT_NETWORK_ID
```

**IPMIView:** o Dockerfile tenta baixar o pacote do site da Supermicro
(`IPMIVIEW_URL`). Como o nome do arquivo muda a cada versão, o mais confiável é
baixar manualmente o `IPMIView_<versão>_bundleJRE_Linux_x64.tar.gz` em
<https://www.supermicro.com/en/solutions/management-software/ipmi-utilities>
e colocá-lo na pasta `vendor/`. Ele tem prioridade sobre o download.

## 2. Construir e subir

```bash
docker compose up -d --build
docker compose logs -f        # mostra o node ID do ZeroTier
```

Sem compose:

```bash
docker build -t ipmi-tn03 .
docker run -d --name ipmi-tn03 --env-file .env \
  --cap-add NET_ADMIN --device /dev/net/tun --shm-size 1g \
  -p 5901:5901 -p 6080:6080 \
  -v zt:/var/lib/zerotier-one -v home:/home/ipmi ipmi-tn03
```

## 3. ZeroTier

1. Defina `ZT_NETWORK_ID` no `.env`.
2. Nos logs aparece `200 info <NODE_ID> ...`. Em <https://my.zerotier.com> →
   sua rede → **Members**, autorize esse node.
3. `docker exec ipmi-tn03 zerotier-cli listnetworks` mostra o IP atribuído.
4. De qualquer máquina na mesma rede ZeroTier, acesse
   `http://<IP_ZT>:6080/vnc.html` ou um cliente VNC em `<IP_ZT>:5901`.

O volume `zerotier` preserva a identidade — não é preciso reautorizar após recriar o container.

## 4. Usar

- **Painel web:** o Firefox abre `IPMI_URL`. Aceite o certificado autoassinado do BMC.
- **Console KVM:** *Remote Control → Console Redirection → Launch Console*. O
  `launch.jnlp` é aberto automaticamente pelo IcedTea-Web com Java 8. Se surgir
  aviso de segurança, marque *Always trust* e *Run*. Log em `~/javaws.log`.
- **IPMIView:** menu do Fluxbox (clique direito na área de trabalho) → *IPMIView*.
  Adicione o host com o IP do BMC; o KVM/Virtual Media funcionam por ele também.
- Credenciais de fábrica X9: `ADMIN` / `ADMIN`.

## Portas usadas pelo BMC X9

O container precisa alcançar o BMC (via LAN do host ou ZeroTier) em:
TCP 80/443 (web), **5900** (iKVM vídeo), **623** (Virtual Media / IPMI), UDP 623 (IPMI LAN).

## Solução de problemas

| Sintoma | Causa / solução |
|---|---|
| Firefox: `SSL_ERROR_UNSUPPORTED_VERSION` / `NO_CYPHER_OVERLAP` | Firmware muito antigo. Atualize o firmware do BMC (recomendado) ou use o IPMIView. |
| Console abre e fecha / "Connection failed" | Porta 5900 bloqueada entre container e BMC. |
| `javaws` reclama de assinatura/jar | Já relaxado em `java.security`; abra *Configurações IcedTea-Web* no menu e confira o nível de segurança. |
| ZeroTier não sobe | Faltou `--cap-add NET_ADMIN --device /dev/net/tun`. |

## Segurança

As configurações de criptografia do Java e do Firefox foram **propositalmente
enfraquecidas** para falar com o BMC antigo. Use o container apenas para isso,
troque `VNC_PASSWORD` e prefira expor 5901/6080 somente pela rede ZeroTier
(ex.: `ports: ["127.0.0.1:6080:6080"]`). Nunca exponha o BMC à internet.
