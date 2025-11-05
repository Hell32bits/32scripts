#!/bin/bash

# Script de instalação automatizada do PufferPanel
# Autor: Assistente
# Data: $(date +%Y-%m-%d)

echo "=========================================="
echo "  Instalador Automatizado do PufferPanel"
echo "=========================================="

# Função para verificar se é root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo "ERRO: Este script não deve ser executado como root."
        echo "Execute como usuário normal e use sudo quando necessário."
        exit 1
    fi
}

# Função para verificar e instalar wget
install_wget() {
    echo -e "\n[1/5] Verificando e instalando wget..."
    
    if ! command -v wget &> /dev/null; then
        echo "wget não encontrado. Instalando..."
        sudo apt update
        sudo apt install -y wget
        if [ $? -eq 0 ]; then
            echo "✓ wget instalado com sucesso!"
        else
            echo "✗ Erro na instalação do wget"
            exit 1
        fi
    else
        echo "✓ wget já está instalado"
    fi
}

# Função para baixar o PufferPanel
download_pufferpanel() {
    echo -e "\n[2/5] Baixando PufferPanel..."
    
    # Criar diretório de downloads se não existir
    mkdir -p ~/downloads
    
    cd ~/downloads
    
    # URL do PufferPanel (versão mais recente disponível)
    PUFFER_URL="https://github.com/pufferpanel/pufferpanel/releases/download/v3.0.0-rc.15/pufferpanel_3.0.0-rc.15_amd64.deb"
    
    echo "Baixando PufferPanel..."
    wget -c -O pufferpanel.deb "$PUFFER_URL"
    
    if [ $? -eq 0 ]; then
        echo "✓ Download concluído com sucesso!"
    else
        echo "✗ Erro no download do PufferPanel"
        exit 1
    fi
}

# Função para instalar o PufferPanel
install_pufferpanel() {
    echo -e "\n[3/5] Instalando PufferPanel..."
    
    if [ -f ~/downloads/pufferpanel.deb ]; then
        sudo dpkg -i ~/downloads/pufferpanel.deb
        
        # Resolver possíveis dependências
        sudo apt install -f -y
        
        echo "✓ PufferPanel instalado com sucesso!"
    else
        echo "✗ Arquivo pufferpanel.deb não encontrado"
        exit 1
    fi
}

# Função para criar usuário administrador
create_admin_user() {
    echo -e "\n[4/5] Criando usuário administrador..."
    
    echo "Por favor, crie um usuário administrador para o PufferPanel:"
    echo "Siga as instruções abaixo:"
    echo ""
    echo "Execute o comando:"
    echo "  pufferpanel user add"
    echo ""
    echo "Siga as instruções interativas para:"
    echo "  - Definir email"
    echo "  - Definir nome de usuário"
    echo "  - Definir senha"
    echo "  - Definir como administrador (S/n)"
    echo ""
    read -p "Pressione Enter para continuar e criar o usuário..."
    
    # Executar comando para criar usuário
    sudo pufferpanel user add
}

# Função para mostrar informações finais
show_final_info() {
    echo -e "\n[5/5] Instalação concluída!"
    echo "=========================================="
    echo "  PufferPanel instalado com sucesso!"
    echo "=========================================="
    echo ""
    echo "INFORMAÇÕES IMPORTANTES:"
    echo ""
    echo "1. Para iniciar o serviço do PufferPanel:"
    echo "   sudo systemctl start pufferpanel"
    echo ""
    echo "2. Para habilitar inicialização automática:"
    echo "   sudo systemctl enable pufferpanel"
    echo ""
    echo "3. Para verificar o status:"
    echo "   sudo systemctl status pufferpanel"
    echo ""
    echo "4. ACESSO:"
    echo "   http://localhost:8080"
    echo "   ou"
    echo "   http://$(hostname -I | awk '{print $1}'):8080"
    echo ""
    echo "5. Comandos úteis:"
    echo "   sudo systemctl stop pufferpanel    # Parar serviço"
    echo "   sudo systemctl restart pufferpanel # Reiniciar serviço"
    echo "   sudo pufferpanel user add          # Adicionar usuário"
    echo ""
    echo "=========================================="
}

# Função principal
main() {
    check_root
    install_wget
    download_pufferpanel
    install_pufferpanel
    create_admin_user
    show_final_info
}

# Executar função principal
main
