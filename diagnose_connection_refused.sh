#!/bin/bash

# Script de diagnóstico para errores "Connection Refused"
# Uso: ./diagnose_connection_refused.sh <host> <puerto>

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ $# -lt 2 ]; then
    echo "Uso: $0 <host> <puerto>"
    echo "Ejemplo: $0 localhost 8080"
    exit 1
fi

HOST=$1
PORT=$2

echo "======================================="
echo "Diagnóstico de Connection Refused"
echo "Host: $HOST | Puerto: $PORT"
echo "======================================="
echo

# 1. Verificar conectividad básica con el host
echo -e "${YELLOW}1. Verificando conectividad con el host...${NC}"
if ping -c 1 -W 2 $HOST > /dev/null 2>&1; then
    echo -e "${GREEN}✓ El host responde a ping${NC}"
else
    echo -e "${RED}✗ El host NO responde a ping (puede tener ICMP bloqueado)${NC}"
fi
echo

# 2. Verificar si el puerto está abierto
echo -e "${YELLOW}2. Verificando si el puerto está abierto...${NC}"
if timeout 2 bash -c "echo >/dev/tcp/$HOST/$PORT" 2>/dev/null; then
    echo -e "${GREEN}✓ El puerto $PORT está ABIERTO en $HOST${NC}"
else
    echo -e "${RED}✗ El puerto $PORT está CERRADO o FILTRADO en $HOST${NC}"
    
    # Si es localhost, verificar si algo está escuchando
    if [ "$HOST" = "localhost" ] || [ "$HOST" = "127.0.0.1" ]; then
        echo -e "${YELLOW}   Verificando servicios locales escuchando...${NC}"
        LISTENING=$(ss -tuln | grep ":$PORT ")
        if [ -n "$LISTENING" ]; then
            echo -e "${GREEN}   Encontrado servicio escuchando:${NC}"
            echo "   $LISTENING"
        else
            echo -e "${RED}   No hay ningún servicio escuchando en el puerto $PORT${NC}"
        fi
    fi
fi
echo

# 3. Verificar procesos escuchando (solo si es local)
if [ "$HOST" = "localhost" ] || [ "$HOST" = "127.0.0.1" ]; then
    echo -e "${YELLOW}3. Procesos escuchando en puertos locales:${NC}"
    echo "   Puertos TCP:"
    ss -tlnp 2>/dev/null | grep LISTEN | head -5
    echo "   Para ver todos: ss -tlnp"
    echo
fi

# 4. Verificar firewall local
echo -e "${YELLOW}4. Verificando reglas de firewall local...${NC}"

# Verificar iptables
if command -v iptables &> /dev/null; then
    IPTABLES_RULES=$(sudo iptables -L -n 2>/dev/null | grep -E "REJECT|DROP" | wc -l)
    if [ $? -eq 0 ]; then
        if [ $IPTABLES_RULES -gt 0 ]; then
            echo -e "${YELLOW}   iptables: Hay $IPTABLES_RULES reglas de REJECT/DROP${NC}"
            echo "   Ejecuta 'sudo iptables -L -n' para ver detalles"
        else
            echo -e "${GREEN}   iptables: No hay reglas bloqueando evidentes${NC}"
        fi
    fi
fi

# Verificar ufw
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(sudo ufw status 2>/dev/null | grep -i "Status:" | grep -i "active")
    if [ -n "$UFW_STATUS" ]; then
        echo -e "${YELLOW}   ufw está ACTIVO - verifica las reglas con 'sudo ufw status numbered'${NC}"
    else
        echo -e "${GREEN}   ufw está inactivo o no configurado${NC}"
    fi
fi

# Verificar firewalld
if command -v firewall-cmd &> /dev/null; then
    if systemctl is-active firewalld >/dev/null 2>&1; then
        echo -e "${YELLOW}   firewalld está ACTIVO${NC}"
        echo "   Puertos abiertos:"
        sudo firewall-cmd --list-ports 2>/dev/null
    else
        echo -e "${GREEN}   firewalld está inactivo${NC}"
    fi
fi
echo

# 5. Verificar resolución DNS (si no es IP)
if ! [[ $HOST =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${YELLOW}5. Verificando resolución DNS...${NC}"
    DNS_RESULT=$(getent hosts $HOST 2>/dev/null | awk '{print $1}')
    if [ -n "$DNS_RESULT" ]; then
        echo -e "${GREEN}   $HOST resuelve a: $DNS_RESULT${NC}"
    else
        echo -e "${RED}   No se puede resolver $HOST${NC}"
    fi
    echo
fi

# 6. Intentar conexión con telnet/nc
echo -e "${YELLOW}6. Intentando conexión directa...${NC}"
if command -v nc &> /dev/null; then
    echo -e "   Probando con nc..."
    timeout 2 nc -zv $HOST $PORT 2>&1
elif command -v telnet &> /dev/null; then
    echo -e "   Probando con telnet..."
    timeout 2 telnet $HOST $PORT 2>&1 | head -5
else
    echo -e "   Instala 'nc' o 'telnet' para pruebas adicionales"
fi
echo

# 7. Recomendaciones
echo -e "${YELLOW}=======================================${NC}"
echo -e "${YELLOW}RECOMENDACIONES:${NC}"
echo -e "${YELLOW}=======================================${NC}"

if [ "$HOST" = "localhost" ] || [ "$HOST" = "127.0.0.1" ]; then
    echo "Para servicios locales:"
    echo "1. Verifica que el servicio esté iniciado:"
    echo "   systemctl status <nombre-servicio>"
    echo "   docker ps (si es un contenedor)"
    echo ""
    echo "2. Revisa los logs del servicio:"
    echo "   journalctl -u <nombre-servicio> -f"
    echo "   docker logs <contenedor>"
    echo ""
    echo "3. Verifica la configuración del servicio:"
    echo "   - Que esté escuchando en 0.0.0.0 o la IP correcta"
    echo "   - Que el puerto configurado sea $PORT"
else
    echo "Para servicios remotos:"
    echo "1. Verifica con el administrador del servidor remoto"
    echo "2. Comprueba que no haya un proxy o VPN interfiriendo"
    echo "3. Verifica las reglas de seguridad de red (Security Groups, etc.)"
fi

echo ""
echo "Comandos útiles adicionales:"
echo "- ss -tuln                    # Ver todos los puertos escuchando"
echo "- sudo netstat -tulpn         # Ver puertos con procesos"
echo "- sudo lsof -i :$PORT        # Ver qué proceso usa el puerto $PORT"
echo "- curl -v telnet://$HOST:$PORT  # Probar conexión con curl"