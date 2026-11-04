#!/bin/bash
# Inicia o Supermicro IPMIView (usa o JRE embutido no pacote)
cd /opt/IPMIView || exit 1
if [ -x ./IPMIView20 ]; then
  exec ./IPMIView20
elif ls jre/bin/java >/dev/null 2>&1 && ls IPMIView20.jar >/dev/null 2>&1; then
  exec ./jre/bin/java -jar IPMIView20.jar
else
  xmessage -center "IPMIView nao esta instalado. Coloque o IPMIView_*_bundleJRE_Linux_x64.tar.gz em ./vendor e reconstrua a imagem."
fi
