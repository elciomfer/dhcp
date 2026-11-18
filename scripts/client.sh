#!/usr/bin/env bash
# Provisiona um cliente DHCP.
# Argumento: MAC da placa da rede interna (ex.: 080027A0B011).
set -euo pipefail

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

# --- Garante um cliente DHCP instalado -------------------------------------
# Feito antes de configurar a rede interna, enquanto a rota padrão ainda é a NAT.
if ! command -v dhclient >/dev/null 2>&1 && ! command -v dhcpcd >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -q
  apt-get install -y -q isc-dhcp-client || apt-get install -y -q dhcpcd-base
fi

# --- Interface da rede interna por DHCP ------------------------------------
grep -q 'interfaces.d' /etc/network/interfaces || \
  echo 'source /etc/network/interfaces.d/*' >> /etc/network/interfaces

cat > /etc/network/interfaces.d/rede-interna <<EOF
auto $IFACE
iface $IFACE inet dhcp
EOF

ifdown "$IFACE" 2>/dev/null || true
ifup "$IFACE"

echo ">> Endereço recebido:"
ip -4 addr show "$IFACE"