#!/bin/bash

# Ubuntu Static IP Konfigürasyon Script'i
# Bu script Ubuntu sunucunuza static IP adresi atar

set -e

# Yetki kontrolü
if [[ $EUID -ne 0 ]]; then
    echo "⚠️  UYARI: Bu script root yetkisi gerektiriyor."
    echo "   'sudo ./network.sh' veya root kullanıcısı ile çalıştırmanız önerilir."
    read -r -p "   Yine de devam etmek istiyor musunuz? [e/H]: " _DEVAM
    _DEVAM=${_DEVAM:-H}
    if [[ ! "$_DEVAM" =~ ^[Ee]$ ]]; then
        echo "❌ İşlem iptal edildi."
        exit 1
    fi
fi

echo "🌐 Ubuntu Static IP Konfigürasyon Script'i"
echo "=========================================="

# Mevcut network interface'leri göster
echo "📡 Mevcut network durumu:"
ip addr show | grep -E "(inet |UP|DOWN)" --color=never
echo ""

# Aktif network interface'ini otomatik tespit et
echo "🔍 Aktif network interface'i tespit ediliyor..."

# Default route üzerinden aktif interface'i bul
INTERFACE=$(ip route show default | grep -oP 'dev \K\w+' | head -n1)

if [[ -z "$INTERFACE" ]]; then
    # Alternatif method: UP durumundaki ve IP'si olan interface'i bul
    INTERFACE=$(ip addr show | grep -B1 "inet.*scope global" | grep "UP" | head -n1 | cut -d: -f2 | sed 's/^ *//')
fi

if [[ -z "$INTERFACE" ]]; then
    echo "❌ Aktif network interface'i tespit edilemedi!"
    echo "📡 Mevcut interface'ler:"
    ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | sed 's/^ *//' | grep -v lo
    echo ""
    read -p "🔌 Network interface adını manuel olarak girin: " INTERFACE
else
    echo "✅ Aktif interface tespit edildi: $INTERFACE"
    
    # Mevcut IP bilgilerini göster
    echo "📋 Mevcut $INTERFACE interface bilgileri:"
    ip addr show "$INTERFACE" | grep "inet " | head -n1
    echo ""
    
    # Kullanıcıya onay sor
    read -p "🤔 Bu interface'i ($INTERFACE) kullanmak istiyor musunuz? (Y/n): " USE_DETECTED
    if [[ "$USE_DETECTED" =~ ^[Nn]$ ]]; then
        echo "📡 Mevcut interface'ler:"
        ip link show | grep -E "^[0-9]+:" | cut -d: -f2 | sed 's/^ *//' | grep -v lo
        echo ""
        read -p "🔌 Kullanmak istediğiniz interface adını girin: " INTERFACE
    fi
fi

# Interface'in var olup olmadığını kontrol et
if ! ip link show "$INTERFACE" > /dev/null 2>&1; then
    echo "❌ '$INTERFACE' interface'i bulunamadı!"
    exit 1
fi

echo "✅ Interface '$INTERFACE' bulundu."
echo ""

# IP bilgilerini topla
read -p "🏠 Static IP adresini girin (örn: 10.101.7.100): " STATIC_IP
read -p "🎯 Subnet mask'ı CIDR formatında girin (örn: 24 for /24): " SUBNET
read -p "🚪 Gateway IP adresini girin (örn: 10.101.7.1): " GATEWAY
read -p "🌍 Birincil DNS sunucusunu girin (örn: 8.8.8.8): " DNS1
read -p "🌍 İkincil DNS sunucusunu girin (örn: 1.1.1.1 veya boş bırakın): " DNS2

# IP formatlarını doğrula (basit kontrol)
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

if ! validate_ip "$STATIC_IP"; then
    echo "❌ Geçersiz IP adresi formatı: $STATIC_IP"
    exit 1
fi

if ! validate_ip "$GATEWAY"; then
    echo "❌ Geçersiz gateway adresi formatı: $GATEWAY"
    exit 1
fi

if ! validate_ip "$DNS1"; then
    echo "❌ Geçersiz DNS adresi formatı: $DNS1"
    exit 1
fi

if [[ -n "$DNS2" ]] && ! validate_ip "$DNS2"; then
    echo "❌ Geçersiz ikinci DNS adresi formatı: $DNS2"
    exit 1
fi

# Subnet kontrolü
if ! [[ "$SUBNET" =~ ^[0-9]+$ ]] || [ "$SUBNET" -lt 1 ] || [ "$SUBNET" -gt 32 ]; then
    echo "❌ Geçersiz subnet mask: $SUBNET (1-32 arası olmalı)"
    exit 1
fi

echo ""
echo "📄 Konfigürasyon Özeti:"
echo "Interface: $INTERFACE"
echo "Static IP: $STATIC_IP/$SUBNET"
echo "Gateway: $GATEWAY"
echo "DNS1: $DNS1"
echo "DNS2: ${DNS2:-'Belirtilmedi'}"
echo ""

read -p "✅ Bu ayarlarla devam etmek istiyor musunuz? (y/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "❌ İşlem iptal edildi."
    exit 0
fi

# Netplan konfigürasyon dosyasını bul
NETPLAN_DIR="/etc/netplan"
NETPLAN_FILE=""

# Mevcut netplan dosyalarını listele
for file in "$NETPLAN_DIR"/*.yaml "$NETPLAN_DIR"/*.yml; do
    if [[ -f "$file" ]]; then
        NETPLAN_FILE="$file"
        break
    fi
done

# Eğer netplan dosyası bulunamazsa, yeni bir tane oluştur
if [[ -z "$NETPLAN_FILE" ]]; then
    NETPLAN_FILE="$NETPLAN_DIR/01-static-ip.yaml"
    echo "⚠️ Mevcut netplan dosyası bulunamadı. Yeni dosya oluşturuluyor: $NETPLAN_FILE"
else
    echo "📁 Mevcut netplan dosyası bulundu: $NETPLAN_FILE"
fi

# Mevcut konfigürasyonu yedekle
BACKUP_FILE="${NETPLAN_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
if [[ -f "$NETPLAN_FILE" ]]; then
    echo "💾 Mevcut konfigürasyon yedekleniyor: $BACKUP_FILE"
    cp "$NETPLAN_FILE" "$BACKUP_FILE"
fi

# DNS yapılandırması
if [[ -n "$DNS2" ]]; then
    DNS_CONFIG="[$DNS1, $DNS2]"
else
    DNS_CONFIG="[$DNS1]"
fi

# Yeni netplan konfigürasyonunu oluştur
echo "📝 Yeni netplan konfigürasyonu yazılıyor..."

cat > "$NETPLAN_FILE" << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $STATIC_IP/$SUBNET
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: $DNS_CONFIG
EOF

echo "✅ Netplan konfigürasyonu yazıldı."

# Konfigürasyon dosyasını göster
echo ""
echo "📋 Yeni konfigürasyon dosyası içeriği:"
echo "======================================"
cat "$NETPLAN_FILE"
echo "======================================"
echo ""

# Konfigürasyonu uygula
echo "🔄 Netplan konfigürasyonu uygulanıyor..."
netplan apply
echo ""
echo "🎉 Static IP konfigürasyonu başarıyla uygulandı!"
echo ""
echo "📊 Yeni network durumu:"
ip addr show "$INTERFACE"

echo ""
echo "📝 Önemli Notlar:"
echo "• Network konfigürasyonu kalıcı olarak değiştirildi"
echo "• Yedek dosya: $BACKUP_FILE"
echo "• SSH bağlantınız kopmadıysa ayarlar doğru çalışıyor"
echo "• Sorun yaşarsanız yedek dosyayı geri yükleyebilirsiniz:"
echo "  sudo mv $BACKUP_FILE $NETPLAN_FILE && sudo netplan apply"
echo ""
echo "🎯 Yeni IP adresiniz: $STATIC_IP"
echo "=========================================="
