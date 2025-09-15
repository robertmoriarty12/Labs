# Part 2 – Enabling BGP Peering with Azure Virtual WAN

This continues from [Part 1](../README.md) where we built the IPsec tunnel from **Chicago Branch Router (Linux VM)** to **Azure VWAN Central Hub**. In Part 2, we enable **dynamic routing with BGP** so that branch prefixes can be advertised and learned automatically.  NOTE This was working temporarily, but needs to be revisited.

---

## 🔹 Architecture Recap
- **Branch VM (Chicago)**
  - Public IP: `52.165.80.112`
  - BGP ASN: `65010`
  - BGP router ID: `10.200.0.4`

- **Azure VWAN Central Hub**
  - BGP peers: `10.100.0.12`, `10.100.0.13`
  - ASN: `65515`

- Tunnel: **IPsec/IKEv2 (route-based, VTI)**
  - VTI local: `169.254.200.1/30`
  - VTI remote: `169.254.200.2/30`
  - `mark=42` used to bind traffic to this tunnel.

---

## 🚀 Final Config Steps

### 1. strongSwan IPsec
`/etc/ipsec.conf`:
```ini
config setup
  charondebug="ike 1, knl 1, cfg 1"

conn vwan-central-a
  keyexchange=ikev2
  ike=aes256-sha1-modp1024!
  esp=aes256gcm16!
  type=tunnel
  authby=psk
  left=52.165.80.112
  leftid=52.165.80.112
  right=172.168.154.224
  mark=42
  installpolicy=no
  leftsubnet=0.0.0.0/0
  rightsubnet=0.0.0.0/0
  dpdaction=restart
  dpddelay=20s
  ikelifetime=8h
  lifetime=1h
  auto=start
```

Restart strongSwan:
```bash
sudo ipsec restart
```

---

### 2. VTI Interface
```bash
sudo ip link add vti0 type vti local 10.200.0.4 remote 172.168.154.224 key 42
sudo ip addr add 169.254.200.1/30 dev vti0
sudo ip link set vti0 up

# Critical sysctls
echo 1 | sudo tee /proc/sys/net/ipv4/conf/vti0/disable_xfrm
echo 1 | sudo tee /proc/sys/net/ipv4/conf/vti0/disable_policy
echo 0 | sudo tee /proc/sys/net/ipv4/conf/vti0/rp_filter
```

Make these persistent in `/etc/sysctl.d/99-vti.conf`:
```ini
net.ipv4.conf.vti0.disable_xfrm=1
net.ipv4.conf.vti0.disable_policy=1
net.ipv4.conf.vti0.rp_filter=0
```

Reload:
```bash
sudo sysctl --system
```

---

### 3. Policy Routing & Marks

#### Add routing table:
```bash
echo "42 vti42" | sudo tee -a /etc/iproute2/rt_tables
sudo ip rule add fwmark 42 table vti42
sudo ip route add default dev vti0 table vti42
```

#### Add host routes:
```bash
sudo ip route replace 10.100.0.12/32 dev vti0
sudo ip route replace 10.100.0.13/32 dev vti0
```

#### iptables rules:
```bash
sudo iptables -t mangle -A OUTPUT -d 10.100.0.0/16 -j MARK --set-mark 42
sudo iptables -t mangle -A OUTPUT -p tcp --dport 179 -j MARK --set-mark 42
sudo iptables -t mangle -A OUTPUT -p tcp --sport 179 -j MARK --set-mark 42
```

Persist them:
```bash
sudo apt-get install -y iptables-persistent
sudo netfilter-persistent save
```

---

### 4. FRR BGP

`/etc/frr/frr.conf`:
```frr
router bgp 65010
 bgp router-id 10.200.0.4
 neighbor 10.100.0.12 remote-as 65515
 neighbor 10.100.0.12 ebgp-multihop 5
 neighbor 10.100.0.12 update-source 10.200.0.4
 neighbor 10.100.0.13 remote-as 65515
 neighbor 10.100.0.13 ebgp-multihop 5
 neighbor 10.100.0.13 update-source 10.200.0.4

 address-family ipv4 unicast
  network 10.200.0.0/24
  neighbor 10.100.0.12 activate
  neighbor 10.100.0.13 activate
 exit-address-family

 no bgp ebgp-requires-policy
```

Restart FRR:
```bash
sudo systemctl restart frr
```

---

## 🛑 Blocks Encountered & Resolutions

1. **BGP stuck Active/Idle**  
   - Cause: traffic not being steered into VTI.  
   - Fix: iptables fwmark + `ip rule` → `vti42` table.

2. **No ESP outbound traffic**  
   - Cause: VTI had policy enforcement enabled.  
   - Fix: `disable_xfrm` + `disable_policy` sysctls.

3. **FRR required outbound policy**  
   - Cause: FRR default eBGP policy requirement.  
   - Fix: `no bgp ebgp-requires-policy`.

4. **Only 1 gateway instance responded**  
   - Cause: Azure had only one active.  
   - Fix: fine to peer with `.12` alone.

---

## ✅ Validation

```bash
# IPsec tunnel
sudo ipsec statusall

# Security associations
sudo ip -s xfrm state

# BGP sessions
sudo vtysh -c "show ip bgp summary"
sudo vtysh -c "show ip bgp"

# Linux routing table
ip route | grep proto zebra
```

Expected:
- At least one peer (`10.100.0.12`) **Established**.  
- Prefixes exchanged (`PfxRcd` / `PfxSnt > 0`).  
- Routes installed by FRR into kernel.

---

## ♻️ Persistence

- **sysctls** → `/etc/sysctl.d/99-vti.conf`  
- **iptables rules** → `iptables-persistent`  
- **FRR config** → saved in `/etc/frr/frr.conf`  
- **ipsec.conf** → `/etc/ipsec.conf`  

This ensures the setup survives reboots.

---

## 📌 Next Steps
- Validate propagation to other VNets.  
- Add second peer (`10.100.0.13`) once active.  
- Extend to additional branch routers.

