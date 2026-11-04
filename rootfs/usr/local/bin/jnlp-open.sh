#!/bin/bash
# Abre o launch.jnlp do BMC (Console Redirection / iKVM) com IcedTea-Web em Java 8
# (o JRE usado e definido em ~/.config/icedtea-web/deployment.properties)
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre
export PATH="$JAVA_HOME/bin:$PATH"
/usr/bin/javaws -Xnofork "$@" >>"$HOME/javaws.log" 2>&1
