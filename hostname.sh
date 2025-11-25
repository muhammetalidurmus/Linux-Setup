#!/bin/bash

# Ubuntu Hostname Değiştirme Script'i
# Bu script Ubuntu sunucunuzun hostname'ini değiştirir

set -e

echo "🖥️  Ubuntu Hostname Değiştirme Script'i"
echo "========================================"

# Mevcut hostname'i göster
CURRENT_HOSTNAME=$(hostname)
echo "📋 Mevcut hostname: $CURRENT_HOSTNAME"
echo ""

# Yeni hostname'i kullanıcıdan al
read -p "✏️  Yeni hostname'i girin: " NEW_HOSTNAME

# Hostname boş mu kontrol et
if [[ -z "$NEW_HOSTNAME" ]]; then
    echo "❌ Hostname boş olamaz!"
    exit 1
fi

# Hostname format kontrolü (alfanumerik, tire ve nokta karakterleri)
if ! [[ "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9\.-]*[a-zA-Z0-9]$ ]] && ! [[ "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9]$ ]]; then
    echo "❌ Geçersiz hostname formatı!"
    echo "   Hostname sadece harf, rakam, tire (-) ve nokta (.) içerebilir"
    echo "   Başlangıç ve bitiş karakterleri harf veya rakam olmalıdır"
    exit 1
fi

# Hostname uzunluk kontrolü (maksimum 63 karakter)
if [[ ${#NEW_HOSTNAME} -gt 63 ]]; then
    echo "❌ Hostname çok uzun! (Maksimum 63 karakter)"
    exit 1
fi

# Konfigürasyon özeti
echo ""
echo "📄 Değişiklik Özeti:"
echo "Eski hostname: $CURRENT_HOSTNAME"
echo "Yeni hostname: $NEW_HOSTNAME"
echo ""

read -p "✅ Bu değişikliği yapmak istiyor musunuz? (y/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "❌ İşlem iptal edildi."
    exit 0
fi

# /etc/hostname dosyasını güncelle
echo "📝 /etc/hostname dosyası güncelleniyor..."
echo "$NEW_HOSTNAME" > /etc/hostname

# /etc/hosts dosyasını güncelle
echo "📝 /etc/hosts dosyası güncelleniyor..."

# Eğer /etc/hosts dosyasında eski hostname varsa güncelle
if grep -q "127.0.1.1.*$CURRENT_HOSTNAME" /etc/hosts 2>/dev/null; then
    # 127.0.1.1 satırını yeni hostname ile değiştir
    sed -i "s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
elif grep -q "^127.0.1.1" /etc/hosts 2>/dev/null; then
    # 127.0.1.1 satırı varsa ama eski hostname yoksa, satırı güncelle
    sed -i "s/^127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
else
    # 127.0.1.1 satırı yoksa ekle
    echo -e "127.0.1.1\t$NEW_HOSTNAME" >> /etc/hosts
fi

# hostnamectl ile hostname'i değiştir (geçerli oturum için)
echo "🔄 Hostname değiştiriliyor..."
hostnamectl set-hostname "$NEW_HOSTNAME"

echo ""
echo "✅ Hostname başarıyla değiştirildi!"
echo ""
echo "📊 Yeni hostname:"
hostname
echo ""
echo "📝 Önemli Notlar:"
echo "• Hostname değişikliği uygulandı"
echo "• Değişikliğin tam olarak etkili olması için oturumu kapatıp açmanız önerilir"
echo "• Veya 'exec bash' komutu ile yeni shell başlatabilirsiniz"
echo ""
echo "🎯 Yeni hostname: $NEW_HOSTNAME"
echo "========================================"

