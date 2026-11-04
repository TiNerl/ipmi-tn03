# =============================================================================
#  Container de acesso TN03
#  Supermicro X9DBL-iF (MBD-X9DBL-IF-B) - BMC ATEN/Nuvoton WPCM450 (geracao X9)
#
#  - Desktop leve (Fluxbox) via VNC (5901) e noVNC no navegador (6080)
#  - Firefox ESR + OpenJDK 8 + IcedTea-Web (javaws) para abrir o
#    "Console Redirection" (launch.jnlp / iKVM) do painel web do IPMI
#  - Supermicro IPMIView (com JRE embutido)
#  - ZeroTier One para acesso remoto
# =============================================================================
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
# URL do IPMIView (Linux x64, bundleJRE). Se o arquivo .tar.gz for colocado em
# ./vendor/ ele tem prioridade e nada e baixado.
ARG IPMIVIEW_URL="https://www.supermicro.com/wdl/utility/IPMIView/Linux/IPMIView_2.21.0_build.221118_bundleJRE_Linux_x64.tar.gz"

ENV LANG=C.UTF-8 \
    TZ=America/Fortaleza \
    DISPLAY=:1 \
    JAVA8_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# ---------------------------------------------------------------------------
# Pacotes base: VNC, noVNC, WM, Java 8, IcedTea-Web, ferramentas IPMI
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg tzdata procps iproute2 iputils-ping \
        supervisor sudo xterm x11-utils xdg-utils \
        tigervnc-standalone-server tigervnc-common \
        novnc websockify \
        fluxbox feh \
        fonts-dejavu fonts-liberation \
        libxtst6 libxrender1 libxi6 libxrandr2 libgtk-3-0 libdbus-glib-1-2 libasound2 \
        openjdk-8-jre icedtea-netx \
        ipmitool \
    && rm -rf /var/lib/apt/lists/*

# Forca Java 8 como padrao (o iKVM das placas X9 nao funciona bem em Java 11+)
RUN update-alternatives --set java  ${JAVA8_HOME}/jre/bin/java \
 && (update-alternatives --set javaws /usr/lib/jvm/java-8-openjdk-amd64/jre/bin/javaws 2>/dev/null || true)

# Libera algoritmos antigos que o BMC X9 usa (TLS 1.0, 3DES, SHA1/MD5 em jars)
# ATENCAO: inseguro de proposito - restrito a este container.
RUN SEC=${JAVA8_HOME}/jre/lib/security/java.security \
 && printf '\n# --- TN03: compatibilidade com BMC Supermicro X9 ---\n' >> $SEC \
 && echo 'jdk.tls.disabledAlgorithms=NULL'          >> $SEC \
 && echo 'jdk.certpath.disabledAlgorithms=MD2'      >> $SEC \
 && echo 'jdk.jar.disabledAlgorithms=MD2'           >> $SEC \
 && echo 'jdk.security.legacyAlgorithms='           >> $SEC

# ---------------------------------------------------------------------------
# Firefox ESR (repositorio oficial da Mozilla, sem snap)
# ---------------------------------------------------------------------------
RUN install -d -m 0755 /etc/apt/keyrings \
 && curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg -o /etc/apt/keyrings/packages.mozilla.org.asc \
 && echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
      > /etc/apt/sources.list.d/mozilla.list \
 && printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' > /etc/apt/preferences.d/mozilla \
 && apt-get update && apt-get install -y --no-install-recommends firefox-esr \
 && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# ZeroTier One
# ---------------------------------------------------------------------------
RUN curl -fsSL 'https://download.zerotier.com/contact%40zerotier.com.gpg' \
      | gpg --dearmor -o /etc/apt/keyrings/zerotier.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/zerotier.gpg] http://download.zerotier.com/debian/jammy jammy main" \
      > /etc/apt/sources.list.d/zerotier.list \
 && apt-get update && apt-get install -y --no-install-recommends zerotier-one \
 && rm -rf /var/lib/apt/lists/* /var/lib/zerotier-one/*

# ---------------------------------------------------------------------------
# Supermicro IPMIView
# ---------------------------------------------------------------------------
COPY vendor/ /tmp/vendor/
RUN set -e; mkdir -p /opt/IPMIView; \
    TGZ=$(ls /tmp/vendor/IPMIView*.tar.gz 2>/dev/null | head -n1 || true); \
    if [ -z "$TGZ" ] && [ -n "$IPMIVIEW_URL" ]; then \
        echo ">> Baixando IPMIView de $IPMIVIEW_URL"; \
        curl -fL --retry 3 -o /tmp/ipmiview.tar.gz "$IPMIVIEW_URL" && TGZ=/tmp/ipmiview.tar.gz || true; \
    fi; \
    if [ -n "$TGZ" ] && [ -f "$TGZ" ]; then \
        tar -xzf "$TGZ" -C /opt/IPMIView --strip-components=1; \
        echo ">> IPMIView instalado em /opt/IPMIView"; \
    else \
        echo "!! AVISO: IPMIView NAO instalado. Coloque o IPMIView_*_bundleJRE_Linux_x64.tar.gz em ./vendor e reconstrua."; \
    fi; \
    rm -rf /tmp/vendor /tmp/ipmiview.tar.gz

# ---------------------------------------------------------------------------
# Usuario do desktop + arquivos de configuracao
# ---------------------------------------------------------------------------
RUN useradd -m -s /bin/bash -G sudo ipmi \
 && echo 'ipmi ALL=(ALL) NOPASSWD: /usr/sbin/zerotier-cli' > /etc/sudoers.d/ipmi-zt \
 && chown -R ipmi:ipmi /opt/IPMIView

COPY rootfs/ /
RUN chmod +x /usr/local/bin/*.sh /opt/skel/.fluxbox/startup \
 && cp -rT /opt/skel /home/ipmi && chown -R ipmi:ipmi /home/ipmi \
 && mkdir -p /usr/lib/firefox-esr/distribution \
 && cp /etc/firefox/policies/policies.json /usr/lib/firefox-esr/distribution/policies.json \
 && ln -sf /usr/share/novnc/vnc.html /usr/share/novnc/index.html

VOLUME ["/var/lib/zerotier-one", "/home/ipmi"]

# 5901 = VNC | 6080 = noVNC (navegador) | 9993/udp = ZeroTier
EXPOSE 5901 6080 9993/udp

HEALTHCHECK --interval=60s --timeout=5s --start-period=30s \
  CMD pgrep -x Xtigervnc >/dev/null || pgrep -x Xvnc >/dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
