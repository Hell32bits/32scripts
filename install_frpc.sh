#!/bin/bash

# install_frpc.sh - Script de instalação interativa do FRP Client (frpc)
# Autor: Gerado por assistente IA
# Descrição: Baixa, configura e instala o frpc como um serviço systemd.

set -e # Encerra o script se qualquer comando falhar

echo "========================================"
echo "  Instalação Interativa do FRP Cliente"
echo "========================================"

# Função para validação obrigatória
obter_valor() {
    local prompt="$1"
    local variavel=""
    local valor_padrao="$2"
    
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
            echo "❌ Este campo é obrigatório. Por favor, insira um valor."
        fi
    done
}

# Função para validar formato de IP/Domínio
validar_endereco() {
    local endereco="$1"
    # Expressão regular para validar IP ou domínio
    if [[ "$endereco" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || 
       [[ "$endereco" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9](\.[a-zA-Z]{2,})+$ ]] || 
       [[ "$endereco" == "localhost" ]]; then
        return 0
    else
        echo "⚠️  Formato de endereço inválido. Certifique-se de usar um IP válido (ex: 192.168.1.1) ou domínio (ex: servidor.com)"
        return 1
    fi
}

# Função para validar porta
validar_porta() {
    local porta="$1"
    if [[ "$porta" =~ ^[0-9]+$ ]] && [ "$porta" -ge 1 ] && [ "$porta" -le 65535 ]; then
        return 0
    else
        echo "⚠️  Porta inválida. Deve ser um número entre 1 e 65535."
        return 1
    fi
}

# 1. Solicitar informações básicas de conexão (OBRIGATÓRIAS)
echo ""
echo "📋 INFORMAÇÕES DE CONEXÃO (OBRIGATÓRIAS)"
echo "----------------------------------------"

# Endereço do servidor (com validação)
while true; do
    SERVER_ADDR=$(obter_valor "🔧 Endereço IP ou domínio do seu servidor FRP (frps)" "")
    if validar_endereco "$SERVER_ADDR"; then
        break
    fi
done

# Porta (com validação e padrão)
while true; do
    PORTA_INPUT=$(obter_valor "🔧 Porta de conexão do servidor FRP" "7000")
    if validar_porta "$PORTA_INPUT"; then
        SERVER_PORT="$PORTA_INPUT"
        break
    fi
done

# Token (obrigatório sem validação de formato)
AUTH_TOKEN=$(obter_valor "🔧 Token de autenticação (deve ser o mesmo do frps)" "")

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

# ===== PROXY 3: SSH (TCP) =====
[[proxies]]
name = "ssh"
type = "tcp"
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
echo "📊 CONFIGURAÇÃO APLICADA:"
echo "   • Servidor FRP: $SERVER_ADDR:$SERVER_PORT"
echo "   • Token: ${AUTH_TOKEN:0:10}..." # Mostra apenas os primeiros 10 caracteres do token
echo ""
echo "🎮 PROXIES CONFIGURADOS:"
echo "   1. Minecraft (TCP): $SERVER_ADDR:25565 → localhost:25565"
echo "   2. Voice Chat (UDP): $SERVER_ADDR:24454 → localhost:24454"
echo "   3. SSH (TCP): $SERVER_ADDR:90 → localhost:22"
echo ""
echo "🔧 COMANDOS ÚTEIS:"
echo "   sudo systemctl status frpc    # Verificar status"
echo "   sudo systemctl restart frpc   # Reiniciar serviço"
echo "   sudo journalctl -u frpc -f    # Ver logs em tempo real"
echo ""
echo "⚠️  PRÓXIMOS PASSOS:"
echo "   1. Verifique se as portas estão abertas no firewall do SERVIDOR FRP (VPS)"
echo "   2. Configure os serviços locais (Minecraft, Voice Chat) para rodar"
echo "   3. Teste as conexões remotamente"
echo "========================================"
