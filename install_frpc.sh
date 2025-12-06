#!/bin/bash

# install_frpc.sh - Script de instalação interativa do FRP Client (frpc)
set -e

echo "========================================"
echo "  Instalação Interativa do FRP Cliente"
echo "========================================"

# Função para validação obrigatória (SIMPLIFICADA)
obter_valor() {
    local prompt="$1"
    local valor_padrao="$2"
    local variavel=""
    
    while true; do
        if [ -n "$valor_padrao" ]; then
            read -p "$prompt (padrão: $valor_padrao): " variavel
            [ -z "$variavel" ] && variavel="$valor_padrao"
        else
            read -p "$prompt: " variavel
        fi
        
        if [ -n "$variavel" ]; then
            echo "$variavel"
            return 0
        else
            echo "❌ Este campo é obrigatório."
        fi
    done
}

# 1. Solicitar informações básicas de conexão
echo ""
echo "📋 INFORMAÇÕES DE CONEXÃO (OBRIGATÓRIAS)"
echo "----------------------------------------"

# Endereço do servidor (VALIDAÇÃO SIMPLIFICADA)
while true; do
    SERVER_ADDR=$(obter_valor "🔧 Endereço IP ou domínio do seu servidor FRP (frps)" "")
    
    # Aceita QUALQUER valor não vazio
    if [ -n "$SERVER_ADDR" ]; then
        break
    fi
done

# Porta (com validação numérica)
while true; do
    PORTA_INPUT=$(obter_valor "🔧 Porta de conexão do servidor FRP" "7000")
    if [[ "$PORTA_INPUT" =~ ^[0-9]+$ ]] && [ "$PORTA_INPUT" -ge 1 ] && [ "$PORTA_INPUT" -le 65535 ]; then
        SERVER_PORT="$PORTA_INPUT"
        break
    else
        echo "⚠️  Porta inválida. Use um número entre 1 e 65535."
    fi
done

# Token (obrigatório)
AUTH_TOKEN=$(obter_valor "🔧 Token de autenticação (deve ser o mesmo do frps)" "")

# 2. Determinar arquitetura do sistema
echo ""
echo "📦 Identificando arquitetura e baixando o FRP..."
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *)
        echo "❌ Arquitetura não suportada: $ARCH"
        echo "   Baixe manualmente: https://github.com/fatedier/frp/releases"
        exit 1
        ;;
esac

# Obter versão mais recente
TAG=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')
VERSION=${TAG#v}
DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/${TAG}/frp_${VERSION}_linux_${ARCH}.tar.gz"
INSTALL_DIR="/opt/frp"

echo "   Versão: $TAG"
echo "   URL: $DOWNLOAD_URL"

# Criar diretório e baixar
sudo mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
sudo wget -q --show-progress -O frp.tar.gz "$DOWNLOAD_URL"
sudo tar -xzf frp.tar.gz --strip-components=1
sudo rm frp.tar.gz

echo "✅ Download concluído em $INSTALL_DIR"

# 3. Criar arquivo de configuração
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

# ===== PROXY 3: SSH (TCP) =====
[[proxies]]
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 90
EOF

echo "✅ Arquivo criado: $CONFIG_FILE"

# 4. Criar e iniciar serviço systemd
echo ""
echo "🔄 Configurando serviço systemd..."
SERVICE_FILE="/etc/systemd/system/frpc.service"

sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=frp client service
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/frpc -c $CONFIG_FILE
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable frpc
sudo systemctl start frpc

# 5. Verificar status
echo ""
echo "🔍 Verificando status..."
sleep 2
if sudo systemctl is-active frpc >/dev/null 2>&1; then
    echo "✅ Serviço frpc está ATIVO!"
    echo "📜 Logs: sudo journalctl -u frpc -f"
else
    echo "⚠️  Serviço não está ativo."
    echo "   Verifique: sudo journalctl -u frpc"
fi

# 6. Resumo
echo ""
echo "========================================"
echo "         INSTALAÇÃO CONCLUÍDA"
echo "========================================"
echo "📊 CONFIGURAÇÃO:"
echo "   • Servidor: $SERVER_ADDR:$SERVER_PORT"
echo "   • Token: ${AUTH_TOKEN:0:10}..."
echo ""
echo "🎮 PROXIES:"
echo "   1. Minecraft TCP: $SERVER_ADDR:25565"
echo "   2. Voice Chat UDP: $SERVER_ADDR:24454"
echo "   3. SSH TCP: $SERVER_ADDR:90"
echo ""
echo "🔧 COMANDOS:"
echo "   sudo systemctl status frpc"
echo "   sudo systemctl restart frpc"
echo "========================================"
