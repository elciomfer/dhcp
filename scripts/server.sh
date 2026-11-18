#!/usr/bin/env bash
# Provisiona o servidor Kea DHCP.
# Argumento: MAC da placa da rede interna (ex.: 080027A0B001).
set -euo pipefail

IP="192.168.1.3"
MASCARA="255.255.255.0"
CONF="/etc/kea/kea-dhcp4.conf"

# --- Descobre a interface da rede interna pelo MAC -------------------------
mac=$(echo "${1:?informe o MAC da placa da rede interna}" | tr 'A-F' 'a-f' | sed 's/../&:/g; s/:$//')
IFACE=""
for dev in /sys/class/net/*; do
  if [ "$(cat "$dev/address")" = "$mac" ]; then
    IFACE=$(basename "$dev")
  fi
done
if [ -z "$IFACE" ]; then
  echo "ERRO: nenhuma interface com o MAC $mac" >&2
  exit 1
fi
echo ">> Interface da rede interna: $IFACE"

# --- 1. IP fixo -------------------------------------------------------------
grep -q 'interfaces.d' /etc/network/interfaces || \
  echo 'source /etc/network/interfaces.d/*' >> /etc/network/interfaces

cat > /etc/network/interfaces.d/rede-interna <<EOF
auto $IFACE
iface $IFACE inet static
    address $IP
    netmask $MASCARA
EOF

ifdown "$IFACE" 2>/dev/null || true
ifup "$IFACE"
ip -4 addr show "$IFACE"

# --- 2. Instalação do Kea ---------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q kea-dhcp4-server

# --- 3. Configuração --------------------------------------------------------
sed "s/__IFACE__/$IFACE/g" /tmp/kea-dhcp4.conf > "$CONF"
chmod 644 "$CONF"

# --- 4. Validação -----------------------------------------------------------
# No Debian 13, o AppArmor impede o Kea de rodar como root fora do usuário _kea,
# por isso o teste é feito com runuser quando esse usuário existe.
if id _kea >/dev/null 2>&1; then
  runuser -u _kea -- kea-dhcp4 -t "$CONF"
else
  kea-dhcp4 -t "$CONF"
fi

# --- 5. Início do serviço ---------------------------------------------------
systemctl enable kea-dhcp4-server
systemctl restart kea-dhcp4-server
sleep 2
systemctl is-active --quiet kea-dhcp4-server
echo ">> kea-dhcp4-server ativo em $IFACE ($IP)"