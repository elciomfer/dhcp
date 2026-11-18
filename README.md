# Laboratório Kea DHCP com Vagrant

Cria automaticamente o laboratório do servidor DHCP do trabalho de Redes de Computadores II (UDESC/CEPLAN): um servidor Kea DHCP e dois clientes no VirtualBox, ligados por uma rede interna. Um único comando cria as máquinas, configura a rede, instala o Kea e faz os clientes pedirem endereço.

## Topologia

| Máquina  | Papel                 | Rede interna          | Resultado esperado             |
| -------- | --------------------- | --------------------- | ------------------------------ |
| dhcp     | Servidor Kea DHCP     | 192.168.1.3/24 (fixo) | Serviço `active (running)`     |
| client01 | Cliente, IP dinâmico  | DHCP                  | IP entre .50 e .200 da VLAN 10 |
| client02 | Cliente, IP reservado | DHCP                  | 192.168.10.10                  |

Todas as máquinas têm também uma placa NAT, criada pelo Vagrant, usada para acesso SSH e para a instalação de pacotes.

## Pré-requisitos

- [VirtualBox](https://www.virtualbox.org/)
- [Vagrant](https://developer.hashicorp.com/vagrant/downloads)
- Acesso à internet na primeira execução, para baixar a imagem do Debian e o pacote do Kea.

## Uso

```bash
vagrant up            # cria e configura as três máquinas
vagrant status        # mostra o estado de cada uma
vagrant ssh client01  # entra em uma máquina
vagrant halt          # desliga tudo
vagrant destroy -f    # apaga tudo
```

A imagem padrão é o Debian 12. Para usar o Debian 13, se a imagem estiver publicada:

```bash
BOX=debian/trixie64 vagrant up
```

No PowerShell do Windows, defina a variável antes: `$env:BOX="debian/trixie64"; vagrant up`.

## Conferindo o resultado

```bash
# IP dos clientes
vagrant ssh client01 -c "ip -4 addr show"
vagrant ssh client02 -c "ip -4 addr show"

# Comunicação entre os clientes
vagrant ssh client01 -c "ping -c 3 192.168.10.10"

# Concessões registradas no servidor
vagrant ssh dhcp -c "sudo cat /var/lib/kea/kea-leases4.csv"

# Processo DORA no log do servidor
vagrant ssh dhcp -c "sudo journalctl -u kea-dhcp4-server --no-pager | grep -E 'DHCPDISCOVER|LEASE_OFFER|DHCPREQUEST|LEASE_ALLOC'"
```

## Estrutura

```
vagrantfile              # define as máquinas, a memória, as placas de rede e os MACs
settings/kea-dhcp4.conf  # configuração do Kea (as quatro VLANs do projeto)
scripts/server.sh        # IP fixo, instalação, validação e início do Kea
scripts/client.sh        # configura a interface da rede interna por DHCP
```

## Como funciona

- **Placas de rede:** o Vagrant cria a placa NAT. A segunda placa é ligada à rede interna `intnet-vagrant` com um MAC fixo, definido no `vagrantfile`.
- **Interface certa:** os scripts encontram a placa da rede interna pelo MAC, sem depender do nome da interface (`enp0s8`, `eth1` etc.). No servidor, esse nome substitui o marcador `__IFACE__` da configuração do Kea.
- **Reserva:** o MAC fixo do client02 (`08:00:27:a0:b0:12`) é o mesmo da reserva no `kea-dhcp4.conf`.
- **VLANs sem switch:** sem switch Layer 3, a VLAN 10 é simulada pelo parâmetro `interface` do Kea. As VLANs 20, 30 e 40 ficam configuradas para operar via DHCP Relay.

## Diferenças em relação ao laboratório manual

- **Placa NAT nos clientes:** o Vagrant exige essa placa em todas as máquinas, e a rota padrão dos clientes sai por ela. O IP, a máscara, o DNS e a reserva da rede interna funcionam igual ao laboratório manual.
- **Sem clonagem:** cada máquina é criada a partir da imagem base, então não há identificadores duplicados entre os clientes.
- **Versão do Kea:** com a imagem padrão (Debian 12), a versão do Kea é a dos repositórios do Debian 12, não a 2.6.3 usada no trabalho.

## Problemas comuns

- **"VirtualBox version not supported":** a versão do Vagrant não reconhece a versão instalada do VirtualBox. Atualize o Vagrant.
- **`$'\r': command not found` ao provisionar:** os scripts foram salvos com quebras de linha do Windows (CRLF). Converta os arquivos para LF no editor.
- **A VM não liga, com erro de VT-x/AMD-V:** ative a virtualização na BIOS/UEFI ou desative o Hyper-V do Windows.
- **Cliente sem IP:** confira se o servidor está ativo (`vagrant ssh dhcp -c "systemctl status kea-dhcp4-server"`) e reprovisione o cliente com `vagrant provision client01`.
