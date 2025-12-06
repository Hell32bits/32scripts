#!/bin/bash

# install_frpc.sh - Script de instalação interativa do FRP Client (frpc)
set -e

echo "========================================"
echo "  Instalação Interativa do FRP Cliente"
echo "========================================"

# Função corrigida para validação obrigatória
obter_valor() {
    local prompt="$1"
    local valor_padrao="$2"
    local variavel=""
    
    while true; do
        if [ -n "$valor_padrao" ]; then
            read -p "$prompt (padrão: $valor_padrao): " variavel
            # Se estiver vazio, usa o padrão
            if [ -z "$variavel" ]; then
                variavel="$valor_padrao"
            fi
        else
            read -p "$prompt: " variavel
        fi
        
        # Se tiver valor, retorna
        if [ -n "$variavel" ]; then
            echo "$variavel"
            return 0
        fi
        # Se chegou aqui e está vazio, mostra erro e continua no loop
        echo "❌ Este campo é obrigatório."
    done
}

# 1. Solicitar informações básicas de conexão
echo ""
echo "📋 INFORMAÇÕES DE CONEXÃO (OBRIGATÓRIAS)"
echo "----------------------------------------"

# Endereço do servidor
echo "🔧 Endereço IP ou domínio do seu servidor FRP (frps):"
SERVER_ADDR=$(obter_valor "  → Digite o endereço" "")

# Porta
echo ""
echo "🔧 Porta de conexão do servidor FRP:"
PORTA_INPUT=$(obter_valor "  → Digite a porta" "7000")

# Validar porta
while ! [[ "$PORTA_INPUT" =~ ^[0-9]+$ ]] || [ "$PORTA_INPUT" -lt 1 ] || [ "$PORTA_INPUT" -gt 65535 ]; do
    echo "⚠️  Porta inválida. Use um número entre 1 e 65535."
    PORTA_INPUT=$(obter_valor "  → Digite a porta novamente" "7000")
done
SERVER_PORT="$PORTA_INPUT"

# Token
echo ""
echo "🔧 Token de autenticação (deve ser o mesmo do frps):"
AUTH_TOKEN=$(obter_valor "  → Digite o token" "")

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
echo "   Obtendo versão mais recente do GitHub..."
TAG=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null || echo "v0.54.0")

# Se não conseguir obter do GitHub, usa versão padrão
if [ -z "$TAG" ] || [ "$TAG" = "null" ]; then
    TAG="v0.54.0"
    echo "   ⚠️  Não foi possível obter a versão do GitHub, usando: $TAG"
fi

VERSION=${TAG#v}
DOWNLOAD_URL="https://github.com/fatedier/frp/releases/download/${TAG}/frp_${VERSION}_linux_${ARCH}.tar.gz"
INSTALL_DIR="/opt/frp"

echo "   Versão: $TAG"
echo "   Arquitetura: $ARCH"
echo "   URL: $DOWNLOAD_URL"
echo "   Diretório: $INSTALL_DIR"

# Criar diretório e baixar
echo "   Criando diretório de instalação..."
sudo mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "   Baixando FRP..."
if ! sudo wget -q --show-progress -O frp.tar.gz "$DOWNLOAD_URL" 2>/dev/null; then
    echo "❌ Falha ao baixar FRP. Verifique sua conexão."
    exit 1
fi

echo "   Extraindo arquivos..."
sudo tar -xzf frp.tar.gz --strip-components=1 2>/dev/null
sudo rm -f frp.tar.gz

# Verificar se o frpc foi extraído
if [ ! -f "frpc" ]; then
    echo "❌ Arquivo frpc não encontrado após extração."
    echo "   Tentando listar arquivos extraídos:"
    ls -la "$INSTALL_DIR"
    exit 1
fi

echo "✅ Download concluído em $INSTALL_DIR"

# 3. Criar arquivo de configuração
echo ""
echo "⚙️  Criando arquivo de configuração frpc.toml..."
CONFIG_FILE="$INSTALL_DIR/frpc.toml"

# Criar arquivo com permissões corretas
sudo tee "$CONFIG_FILE" > /dev/null <<EOF
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

sudo chmod 644 "$CONFIG_FILE"
echo "✅ Arquivo criado: $CONFIG_FILE"

# Verificar conteúdo do arquivo
echo "   Verificando conteúdo do arquivo..."
if [ -f "$CONFIG_FILE" ]; then
    echo "   Conteúdo do arquivo de configuração:"
    echo "   ------------------------------------"
    sudo cat "$CONFIG_FILE"
    echo "   ------------------------------------"
else
    echo "❌ Arquivo de configuração não foi criado!"
    exit 1
fi

# 4. Criar e iniciar serviço systemd
echo ""
echo "🔄 Configurando serviço systemd..."
SERVICE_FILE="/etc/systemd/system/frpc.service"

# Verificar caminho do frpc
FRPC_PATH="$INSTALL_DIR/frpc"
if [ ! -f "$FRPC_PATH" ]; then
    echo "❌ Binário frpc não encontrado em: $FRPC_PATH"
    exit 1
fi

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=frp client service
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
WorkingDirectory=$INSTALL_DIR
ExecStart=$FRPC_PATH -c $CONFIG_FILE
ExecReload=/bin/kill -HUP \$MAINPID
LimitNOFILE=1048576
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "   Recarregando systemd..."
sudo systemctl daemon-reload

echo "   Habilitando serviço..."
sudo systemctl enable frpc

echo "   Iniciando serviço..."
sudo systemctl start frpc

# 5. Verificar status
echo ""
echo "🔍 Verificando status..."
sleep 3

if sudo systemctl is-active frpc >/dev/null 2>&1; then
    echo "✅ Serviço frpc está ATIVO!"
    echo ""
    echo "📜 Últimas linhas do log:"
    sudo journalctl -u frpc -n 10 --no-pager
    echo ""
    echo "Para ver logs em tempo real: sudo journalctl -u frpc -f"
else
    echo "⚠️  Serviço não está ativo."
    echo ""
    echo "📜 Verificando logs de erro:"
    sudo journalctl -u frpc -n 20 --no-pager
    echo ""
    echo "Status do serviço:"
    sudo systemctl status frpc --no-pager
fi

# 6. Resumo
echo ""
echo "========================================"
echo "         INSTALAÇÃO CONCLUÍDA"
echo "========================================"
echo "📊 CONFIGURAÇÃO APLICADA:"
echo "   • Servidor FRP: $SERVER_ADDR:$SERVER_PORT"
echo "   • Token (início): ${AUTH_TOKEN:0:10}..."
echo "   • Diretório: $INSTALL_DIR"
echo "   • Config: $CONFIG_FILE"
echo ""
echo "🎮 PROXIES CONFIGURADOS:"
echo "   1. Minecraft TCP: $SERVER_ADDR:25565 → localhost:25565"
echo "   2. Voice Chat UDP: $SERVER_ADDR:24454 → localhost:24454"
echo "   3. SSH TCP: $SERVER_ADDR:90 → localhost:22"
echo ""
echo "🔧 COMANDOS DE GERENCIAMENTO:"
echo "   sudo systemctl status frpc      # Verificar status"
echo "   sudo systemctl restart frpc     # Reiniciar serviço"
echo "   sudo systemctl stop frpc        # Parar serviço"
echo "   sudo journalctl -u frpc -f      # Ver logs em tempo real"
echo ""
echo "⚠️  PRÓXIMOS PASSOS:"
echo "   1. No seu servidor FRP (VPS), abra as portas:"
echo "      - TCP 25565 (Minecraft)"
echo "      - UDP 24454 (Voice Chat)"
echo "      - TCP 90 (SSH)"
echo "   2. Teste as conexões remotamente"
echo "   3. Configure os serviços locais para rodar"
echo "========================================"
