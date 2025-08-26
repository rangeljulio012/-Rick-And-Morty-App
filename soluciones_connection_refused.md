# Guía de Soluciones para "Connection Refused"

## 🚀 Soluciones Rápidas por Causa

### 1. Si el servicio no está corriendo

```bash
# Para servicios systemd
sudo systemctl status <servicio>
sudo systemctl start <servicio>
sudo systemctl enable <servicio>  # Para inicio automático

# Para Docker
docker ps -a  # Ver todos los contenedores
docker start <contenedor>
docker logs <contenedor>  # Ver logs si falla

# Para procesos normales
ps aux | grep <nombre-proceso>
# Iniciar el proceso manualmente
```

### 2. Si el puerto está bloqueado por firewall

```bash
# UFW (Ubuntu/Debian)
sudo ufw allow <puerto>/tcp
sudo ufw reload

# Firewalld (RHEL/CentOS/Fedora)
sudo firewall-cmd --add-port=<puerto>/tcp --permanent
sudo firewall-cmd --reload

# iptables directo
sudo iptables -A INPUT -p tcp --dport <puerto> -j ACCEPT
sudo iptables-save > /etc/iptables/rules.v4  # Guardar reglas
```

### 3. Si el servicio solo escucha en localhost

Busca en la configuración del servicio y cambia:

```
# Cambiar de:
bind = 127.0.0.1
listen = localhost

# A:
bind = 0.0.0.0
listen = 0.0.0.0
```

Ejemplos comunes:

- **MySQL/MariaDB**: `/etc/mysql/mysql.conf.d/mysqld.cnf`
  ```
  bind-address = 0.0.0.0
  ```

- **PostgreSQL**: `/etc/postgresql/*/main/postgresql.conf`
  ```
  listen_addresses = '*'
  ```

- **Redis**: `/etc/redis/redis.conf`
  ```
  bind 0.0.0.0
  ```

- **MongoDB**: `/etc/mongod.conf`
  ```yaml
  net:
    bindIp: 0.0.0.0
  ```

### 4. Si hay problemas de red

```bash
# Verificar conectividad
ping <host>
traceroute <host>

# Verificar resolución DNS
nslookup <hostname>
dig <hostname>

# Verificar rutas
ip route
route -n

# Reiniciar red
sudo systemctl restart NetworkManager
# o
sudo systemctl restart networking
```

### 5. Para contenedores Docker

```bash
# Verificar que el puerto esté mapeado
docker ps  # Ver mapeo de puertos

# Ejecutar con puerto expuesto
docker run -p <puerto-host>:<puerto-contenedor> <imagen>

# Para docker-compose
# En docker-compose.yml:
services:
  app:
    ports:
      - "8080:8080"  # puerto-host:puerto-contenedor

# Verificar red de Docker
docker network ls
docker network inspect bridge
```

### 6. Verificación de logs

```bash
# Logs del sistema
sudo journalctl -xe
sudo dmesg | tail -50

# Logs de servicios específicos
sudo journalctl -u <servicio> -f
sudo tail -f /var/log/syslog
sudo tail -f /var/log/messages

# Para aplicaciones específicas
tail -f /var/log/nginx/error.log
tail -f /var/log/apache2/error.log
tail -f /var/log/mysql/error.log
```

## 🔍 Comandos de Diagnóstico Esenciales

```bash
# Ver todos los puertos escuchando
ss -tuln
sudo netstat -tulpn

# Ver qué proceso usa un puerto específico
sudo lsof -i :<puerto>
sudo ss -tulpn | grep :<puerto>

# Probar conexión
telnet <host> <puerto>
nc -zv <host> <puerto>
curl -v telnet://<host>:<puerto>

# Ver conexiones activas
ss -tan
netstat -an

# Ver límites del sistema
ulimit -a
cat /proc/sys/net/core/somaxconn
```

## 📝 Checklist de Verificación

- [ ] ¿El servicio está corriendo? (`systemctl status`, `ps aux`)
- [ ] ¿El puerto está abierto? (`ss -tuln`)
- [ ] ¿El firewall permite la conexión? (`ufw status`, `iptables -L`)
- [ ] ¿El servicio escucha en la interfaz correcta? (no solo localhost)
- [ ] ¿La configuración del servicio es correcta?
- [ ] ¿Hay suficientes recursos? (memoria, CPU, file descriptors)
- [ ] ¿Los logs muestran algún error?
- [ ] ¿La red entre cliente y servidor funciona?
- [ ] ¿El DNS resuelve correctamente?
- [ ] ¿SELinux o AppArmor están bloqueando? (`getenforce`, `aa-status`)

## 🆘 Casos Especiales

### Para AWS/Cloud
- Verificar Security Groups
- Verificar Network ACLs
- Verificar que la instancia tenga IP pública (si es necesario)

### Para Kubernetes
```bash
kubectl get svc
kubectl get endpoints
kubectl describe svc <servicio>
kubectl port-forward <pod> <puerto>
```

### Para proxies/load balancers
- Verificar configuración del proxy (nginx, haproxy)
- Verificar health checks
- Verificar timeouts configurados