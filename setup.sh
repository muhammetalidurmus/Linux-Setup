#!/bin/bash

# Ubuntu Docker Kurulum ve Sistem Yapılandırma Script'i
# Bu script yeni bir Ubuntu makinesinde Docker kurulumu yapar ve temel güvenlik yapılandırması gerçekleştirir

set -e  # Hata durumunda script'i durdur

# Yetki kontrolü
if [[ $EUID -ne 0 ]]; then
    echo "⚠️  UYARI: Bu script root yetkisi gerektiriyor."
    echo "   'sudo ./setup.sh' veya root kullanıcısı ile çalıştırmanız önerilir."
    read -r -p "   Yine de devam etmek istiyor musunuz? [e/H]: " _DEVAM
    _DEVAM=${_DEVAM:-H}
    if [[ ! "$_DEVAM" =~ ^[Ee]$ ]]; then
        echo "❌ İşlem iptal edildi."
        exit 1
    fi
fi

echo "🚀 Ubuntu Docker Kurulum ve Yapılandırma Script'i başlatılıyor..."
echo "=================================================="

# Root olarak çalışıyorsa sudo komutlarını düz çalıştır
if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Saat dilimi ayarı
echo "🕐 Saat dilimi Europe/Istanbul olarak ayarlanıyor..."
$SUDO timedatectl set-timezone Europe/Istanbul

# Sistem güncellemesi
echo "📦 Sistem paketleri güncelleniyor..."
$SUDO apt update && $SUDO apt upgrade -y

# Gerekli paketlerin kurulumu
echo "🔧 Gerekli paketler kuruluyor..."
$SUDO apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    git \
    build-essential

# Docker'ın eski sürümlerini kaldır
echo "🧹 Eski Docker sürümleri temizleniyor..."
$SUDO apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Docker GPG anahtarını ekle
echo "🔐 Docker GPG anahtarı ekleniyor..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Docker deposunu ekle
echo "📋 Docker deposu ekleniyor..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null

# Paket listesini güncelle
echo "🔄 Paket listesi güncelleniyor..."
$SUDO apt update

# Docker Engine'i kur
echo "🐳 Docker Engine kuruluyor..."
$SUDO apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker servisini başlat ve otomatik başlatmayı etkinleştir
echo "⚡ Docker servisi başlatılıyor..."
$SUDO systemctl start docker
$SUDO systemctl enable docker

# Kullanıcıyı docker grubuna ekle
echo "👤 Kullanıcı docker grubuna ekleniyor..."
$SUDO usermod -aG docker $USER

# SSH Konfigürasyonu - PermitRootLogin yes
echo "🔑 SSH PermitRootLogin ayarlanıyor..."
$SUDO sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
$SUDO sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
if ! grep -q "PermitRootLogin" /etc/ssh/sshd_config; then
    echo "PermitRootLogin yes" | $SUDO tee -a /etc/ssh/sshd_config
fi
echo "🔄 SSH servisi yeniden başlatılıyor..."
$SUDO systemctl restart ssh

# UFW güvenlik duvarını kur ve yapılandır
echo "🛡️ UFW güvenlik duvarı yapılandırılıyor..."
$SUDO apt install -y ufw

$SUDO ufw default deny incoming
$SUDO ufw default allow outgoing

echo "🔓 SSH portu (22) açılıyor..."
$SUDO ufw allow ssh

echo "🌐 HTTP (80) ve HTTPS (443) portları açılıyor..."
$SUDO ufw allow 80/tcp
$SUDO ufw allow 443/tcp

echo "✅ UFW etkinleştiriliyor..."
$SUDO ufw --force enable

# Docker Compose kurulumu (standalone sürüm)
echo "🏗️ Docker Compose standalone sürümü kuruluyor..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
$SUDO curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
$SUDO chmod +x /usr/local/bin/docker-compose

# Node.js 22.x LTS kurulumu
read -r -p "📦 Node.js 22.x LTS kurulsun mu? [E/h]: " INSTALL_NODE
INSTALL_NODE=${INSTALL_NODE:-E}
if [[ "$INSTALL_NODE" =~ ^[Ee]$ ]]; then
    echo "📦 Node.js 22.x LTS kuruluyor..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    $SUDO apt install -y nodejs

    # npm'i en son sürüme güncelle
    echo "🔄 npm güncelleniyor..."
    $SUDO npm install -g npm@latest

    # Claude Code kurulumu
    read -r -p "🤖 Claude Code kurulsun mu? [E/h]: " INSTALL_CLAUDE
    INSTALL_CLAUDE=${INSTALL_CLAUDE:-E}
    if [[ "$INSTALL_CLAUDE" =~ ^[Ee]$ ]]; then
        echo "🤖 Claude Code kuruluyor..."
        $SUDO npm install -g @anthropic-ai/claude-code
    else
        echo "⏭️  Claude Code kurulumu atlandı."
    fi
else
    echo "⏭️  Node.js kurulumu atlandı. Claude Code da atlanıyor."
fi

# Kurulum kontrolü
echo "🔍 Kurulum kontrol ediliyor..."
echo "Docker sürümü:"
docker --version

echo "Docker Compose sürümü:"
docker-compose --version

if [[ "$INSTALL_NODE" =~ ^[Ee]$ ]]; then
    echo "Node.js sürümü:"
    node --version
    echo "npm sürümü:"
    npm --version
fi

if [[ "$INSTALL_NODE" =~ ^[Ee]$ ]] && [[ "$INSTALL_CLAUDE" =~ ^[Ee]$ ]]; then
    echo "Claude Code sürümü:"
    claude --version
fi

echo "UFW durumu:"
$SUDO ufw status

echo "=================================================="
echo "✅ Kurulum tamamlandı!"
echo ""
echo "📝 Önemli notlar:"
echo "• Docker kullanabilmek için oturumu kapatıp tekrar açmanız gerekebilir"
echo "• Veya 'newgrp docker' komutunu çalıştırabilirsiniz"
echo "• UFW güvenlik duvarı etkinleştirildi"
echo "• Açık portlar: 22 (SSH), 80 (HTTP), 443 (HTTPS)"
if [[ "$INSTALL_NODE" =~ ^[Ee]$ ]]; then
    echo "• Node.js 22.x LTS kuruldu"
fi
if [[ "$INSTALL_NODE" =~ ^[Ee]$ ]] && [[ "$INSTALL_CLAUDE" =~ ^[Ee]$ ]]; then
    echo "• Claude Code kuruldu - API key'inizi ayarlamayı unutmayın"
fi
echo ""
if [[ "$INSTALL_NODE" =~ ^[Ee]$ ]] && [[ "$INSTALL_CLAUDE" =~ ^[Ee]$ ]]; then
    echo "🔑 Claude Code kurulumu:"
    echo "• API key ayarlamak için: claude auth"
    echo "• Veya environment variable: export ANTHROPIC_API_KEY=your_key_here"
    echo ""
fi
echo "🧪 Test komutları:"
echo "• Docker: docker run hello-world"
if [[ "$INSTALL_NODE" =~ ^[Ee]$ ]]; then
    echo "• Node.js: node --version"
fi
if [[ "$INSTALL_NODE" =~ ^[Ee]$ ]] && [[ "$INSTALL_CLAUDE" =~ ^[Ee]$ ]]; then
    echo "• Claude Code: claude --help"
fi
echo "=================================================="
