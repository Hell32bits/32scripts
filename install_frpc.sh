#!/bin/bash

# install_frpc.sh - Script de instalação interativa do FRP Client (frpc)
# Autor: Gerado por assistente IA
# Descrição: Baixa, configura e instala o frpc como um serviço systemd.

set -e # Encerra o script se qualquer comando falhar

echo "========================================"
echo "  Instalação Interativa do FRP Cliente"
echo "========================================"

# 1. Solicitar informações básicas de conexão
echo ""
read -p "🔧 Endereço IP ou domínio do seu servidor FRP (frps): " SERVER_ADDR
read -p "🔧 Porta de conexão do servidor FRP (padrão: 7000): " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-7000}
read -p "🔧 Token de autenticação (deve ser o mesmo do frps): " AUTH_TOKEN

# 2. Determinar arquitetura do sistema e baixar o FRP
echo ""
echo "📦 Identificando a arquitetura do sistema e baixando o FRP..."
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo "❌ Arquitetura não suportada automaticamente: $ARCH"
        echo "   Por favor, baixe o binário manualmente de: https://github.com/fatedier/frp/releases"
        exit 1
        ;;
esac

# Obter a versão mais recente do GitHub
TAG=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
VERSION=${TAG#v} # Remove o 'v' da tag
DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/${TAG}/frp_${VERSION}_linux_${ARCH}.tar.gz"
INSTALL_DIR="/opt/frp"

echo "   Versão detectada: $TAG"
echo "   URL de download: $DOWNLOAD_URL"

# Criar diretório de instalação
sudo mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Baixar e extrair
sudo wget -q --show-progress -O frp.tar.gz "$DOWNLOAD_URL"
sudo tar -xzf frp.tar.gz --strip-components=1
sudo rm frp.tar.gz

echo "✅ Download e extração concluídos em $INSTALL_DIR"

# 3. Criar arquivo de configuração TOML interativo
echo ""
echo "⚙️  Criando arquivo de configuração frpc.toml..."
CONFIG_FILE="$INSTALL_DIR/frpc.toml"

sudo bash -c "cat > $CONFIG_FILE" <<EOF
# Configuração do FRP Cliente (frpc)
# Gerado automaticamente em $(date)
serverAddr = "$SERVER_ADDR"
serverPort = $SERVER_PORT

auth.method = "token"
auth.token = "$AUTH_TOKEN"

# ===== PROXY 1: Servidor Minecraft (TCP) =====
[[proxies]]
name = "minecraft-tcp"
type = "tcp"
localIP = "127.0.0.1"
localPort = 25565
remotePort = 25565

# ===== PROXY 2: Simple Voice Chat (UDP) =====
[[proxies]]
name = "voicechat-udp"
type = "udp"
localIP = "127.0.0.1"
localPort = 24454
remotePort = 24454

# ===== PROXY 2: SSH (ssh) =====
 [[proxies]]
 name = "ssh"
 type = "ssh"
 localIP = "127.0.0.1"
 localPort = 22
 remotePort = 90
EOF

echo "✅ Arquivo de configuração criado em: $CONFIG_FILE"

# 4. Criar serviço systemd para inicialização automática
echo ""
echo "🔄 Criando e ativando o serviço systemd (frpc.service)..."
SERVICE_FILE="/etc/systemd/system/frpc.service"

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=frp client service (fast reverse proxy)
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/frpc -c $CONFIG_FILE
ExecReload=/bin/kill -HUP \$MAINPID
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

# Recarregar systemd, iniciar e habilitar o serviço
sudo systemctl daemon-reload
sudo systemctl enable frpc
sudo systemctl start frpc

# 5. Verificar status do serviço
echo ""
echo "🔍 Verificando o status do serviço..."
sleep 2 # Dar um tempo para o serviço iniciar
SERVICE_STATUS=$(sudo systemctl is-active frpc)

if [ "$SERVICE_STATUS" = "active" ]; then
    echo "✅ Serviço frpc está ATIVO e rodando!"
    echo "📜 Você pode ver os logs com: sudo journalctl -u frpc -f"
else
    echo "⚠️  O serviço frpc não está ativo. Status: $SERVICE_STATUS"
    echo "   Verifique os logs para detalhes: sudo journalctl -u frpc"
fi

# 6. Resumo da instalação
echo ""
echo "========================================"
echo "         INSTALAÇÃO CONCLUÍDA"
echo "========================================"
echo "📁 Diretório de instalação: $INSTALL_DIR"
echo "⚙️  Arquivo de configuração: $CONFIG_FILE"
echo "🖥️  Serviço systemd: frpc"
echo ""
echo "🔧 Comandos úteis:"
echo "   sudo systemctl status frpc    # Verificar status"
echo "   sudo systemctl restart frpc   # Reiniciar serviço"
echo "   sudo systemctl stop frpc      # Parar serviço"
echo ""
echo "🎮 Seus proxies estão configurados:"
echo "   1. Minecraft (TCP): $SERVER_ADDR:25565 -> localhost:25565"
echo "   2. Voice Chat (UDP): $SERVER_ADDR:24454 -> localhost:24454"
echo ""
echo "⚠️  Lembre-se:"
echo "   - Verifique se as portas (ex.: 25565, 24454) estão abertas no firewall do seu SERVIDOR FRP (VPS)."
echo "   - Os serviços locais (Minecraft e Voice Chat) devem estar rodando neste computador."
echo "========================================"
