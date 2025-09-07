# 🚀 Azure VWAN + StrongSwan + FRR BGP Lab

This guide documents how to set up a **site-to-site VPN** from a Linux VM (simulating on-prem) into **Azure Virtual WAN (VWAN)**, then bring up **BGP peering** between FRR and Azure.

---

## 🌐 Azure VWAN Settings

- **VWAN Name**: rmoriartyWAN  
- **Region**: Central US  
- **Central Hub**: rmoriartyCentralHub  
  - Connected VNet: `vnetCentral (10.100.1.0/24)`  
  - Azure Firewall: `AZUREFIREWALL_RMORIARTYCENTRALHUB`  
- **VPN Gateway**: Auto-created by VWAN hub  
- **BGP Peers**:  
  - `10.100.0.12` (Azure peer)  
  - `10.100.0.13` (Azure peer)  
  - ASN: `65515`  
- **On-prem (Simulated Branch)**:  
  - Public IP: `52.165.80.112`  
  - Internal ASN: `65010`  
  - Router-ID: `10.200.0.4`  

---

## 🔐 strongSwan Configuration (`/etc/ipsec.conf`)

```conf
config setup
  charondebug="ike 1, cfg 1, knl 1, enc 1"

conn vwan-central
  keyexchange=ikev2
  type=tunnel
  authby=psk
  ike=aes256-sha1-modp1024,aes128-sha1-modp1024,3des-sha1-modp1024!
  esp=aes256-sha1,aes128-sha1,3des-sha1!
  dpdaction=restart
  dpddelay=30s
  dpdtimeout=150s
  rekey=no
  fragmentation=yes
  mobike=no

  left=%defaultroute
  leftid=52.165.80.112
  leftsubnet=0.0.0.0/0

  right=172.168.154.224
  rightid=%any
  rightsubnet=0.0.0.0/0

  installpolicy=no
  mark=42

  auto=start
```

Secrets go into `/etc/ipsec.secrets`:

```conf
52.165.80.112 172.168.154.224 : PSK "your-shared-key-here"
```

---

## 🔧 VTI Setup Script (`/usr/local/sbin/vti-setup.sh`)

```bash
#!/bin/bash
set -e

# Delete if exists
ip link del vti0 2>/dev/null || true

# Create VTI bound to on-prem public IP
ip link add vti0 type vti local 52.165.80.112 remote 172.168.154.224 key 42
ip addr add 10.200.0.4/32 dev lo || true
ip link set vti0 up mtu 1436

# Disable kernel policy
echo 1 > /proc/sys/net/ipv4/conf/vti0/disable_xfrm
echo 1 > /proc/sys/net/ipv4/conf/vti0/disable_policy
echo 0 > /proc/sys/net/ipv4/conf/vti0/rp_filter

# Add static routes to Azure BGP peers
ip route replace 10.100.0.12/32 dev vti0 src 10.200.0.4
ip route replace 10.100.0.13/32 dev vti0 src 10.200.0.4
```

Make executable:

```bash
sudo chmod +x /usr/local/sbin/vti-setup.sh
```

---

## ⚙️ Systemd Unit (`/etc/systemd/system/vti-setup.service`)

```ini
[Unit]
Description=VTI setup for Azure VWAN
After=network-online.target strongswan.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/vti-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Enable:

```bash
sudo systemctl daemon-reload
sudo systemctl enable vti-setup.service
sudo systemctl start vti-setup.service
```

---

## 🖧 FRR Configuration (`/etc/frr/frr.conf`)

```conf
router bgp 65010
 bgp router-id 10.200.0.4
 no bgp ebgp-requires-policy
 timers bgp 5 15
 neighbor 10.100.0.12 remote-as 65515
 neighbor 10.100.0.12 ebgp-multihop 5
 neighbor 10.100.0.12 update-source 10.200.0.4
 neighbor 10.100.0.13 remote-as 65515
 neighbor 10.100.0.13 ebgp-multihop 5
 neighbor 10.100.0.13 update-source 10.200.0.4
 !
 address-family ipv4 unicast
  network 10.200.0.0/24
  neighbor 10.100.0.12 activate
  neighbor 10.100.0.13 activate
 exit-address-family
```

Restart FRR:

```bash
sudo systemctl restart frr
```

---

## ✅ Verification Steps

- Check tunnel:
  ```bash
  sudo ipsec statusall
  sudo ip -s xfrm state
  ```

- Check BGP:
  ```bash
  sudo vtysh -c "show ip bgp summary"
  sudo vtysh -c "show ip bgp neighbors 10.100.0.12"
  ```

- Packet capture:
  ```bash
  sudo tcpdump -ni eth0 udp port 500 or udp port 4500 -vv
  sudo tcpdump -ni vti0 port 179 -vv
  ```

---

## 🚑 Troubleshooting

1. **IPsec not coming up**  
   - Confirm matching proposals in Azure & `ipsec.conf` (`aes256-sha1-modp1024`).  
   - Check `sudo journalctl -xeu strongswan`.  

2. **Tunnel up but no BGP packets**  
   - Ensure `disable_xfrm` and `disable_policy` are set on `vti0`.  
   - Confirm routes:  
     ```bash
     ip route get 10.100.0.12 from 10.200.0.4
     ```  

3. **BGP stuck in Active/Idle**  
   - Verify FRR update-source matches `10.200.0.4`.  
   - Make sure dummy loopback exists for `10.200.0.4`.  

4. **No traffic passing**  
   - Check Azure VWAN **connection shared key**.  
   - Ensure on-prem public IP matches Azure’s `Local Network Gateway` definition.  

5. **Debugging commands**  
   ```bash
   sudo ip xfrm policy
   sudo ip xfrm state
   sudo vtysh -c "debug bgp neighbor-events"
   ```

---

## 🎯 Final Notes

With this config:
- IPsec tunnel comes up automatically.  
- VTI interface `vti0` is restored on reboot.  
- FRR peers with Azure and exchanges routes.  

This README + configs = reproducible lab ✅
