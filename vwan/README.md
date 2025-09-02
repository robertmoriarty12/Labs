# 🚀 Azure Virtual WAN Branch Connectivity PoC

This project demonstrates how to connect an **on-premises branch** (simulated with a Linux VM running strongSwan) to an **Azure Virtual WAN (VWAN)** hub using **site-to-site IPsec VPN**.  
The branch connects into **Central Hub**, routes through **Azure Firewall** (Routing Intent), and can reach workloads in both **Central VNet** and **West VNet** through **inter-hub routing**.

---

## 🏗️ Azure VWAN Setup

### Virtual WAN
- **Name**: `rmoriartyWAN`  
- **Region**: Central US (control plane location)

### Hubs
- **Central Hub**: `rmoriartyCentralHub` (Central US)  
  - Connected VNet: `vnetCentral` (`10.100.1.0/24`)  
  - Azure Firewall: `AZUREFIREWALL_RMORIARTYCENTRALHUB`  

- **West Hub**: `rmoriartyWestHub` (West US)  
  - Connected VNet: `vnetWest` (`10.101.1.0/24`)  
  - Azure Firewall: `AZUREFIREWALL_RMORIARTYWESTHUB`  

### Routing Intent
- **Private traffic → Firewall** (both hubs)  
- Ensures all branch ↔ VNet and inter-VNet flows pass through firewalls.

### VPN Gateway
- **Central Hub VPN Gateway**  
  - Instance0 IP: `172.168.154.224`  
  - Instance1 IP: `172.168.80.111`  
  - ASN: `65515`  

### VPN Site (Branch)
- **Name**: `ChicagoBranch1`  
- **Branch Public IP**: `52.165.80.112` (Linux VM public IP)  
- **Private address space**: `10.200.0.0/24`  
- **Pre-shared key (PSK)**: `test` (lab only)

---

## 🖥️ Linux Router (Branch Simulator)

### VM Setup
- **OS**: Ubuntu (Azure VM in `10.200.0.0/24`)  
- **NIC private IP**: `10.200.0.4`  
- **Public IP**: `52.165.80.112`

### StrongSwan Install & Sysctl
```bash
sudo apt update
sudo apt install -y strongswan tcpdump

# Enable IP forwarding
sudo bash -c 'cat >/etc/sysctl.d/99-branch-vpn.conf' <<'EOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=2
net.ipv4.conf.default.rp_filter=2
EOF
sudo sysctl --system
```

### IPsec Config (`/etc/ipsec.conf`)
```ini
config setup
  charondebug="ike 1, knl 1, cfg 1"

conn vwan
  keyexchange=ikev2
  ike=aes256-sha1-modp1024,aes256-sha256-modp1024,aes128-sha1-modp1024
  esp=aes256gcm16,aes256-sha1,aes128-sha1
  type=tunnel
  authby=psk
  dpdaction=restart
  dpddelay=20s
  ikelifetime=8h
  lifetime=1h

  left=%defaultroute
  leftid=52.165.80.112
  leftsubnet=10.200.0.0/24

  right=172.168.154.224
  rightid=172.168.154.224
  rightsubnet=10.100.1.0/24,10.101.1.0/24   # Central + West VNets

  forceencaps=yes
  auto=start
```

### Secrets (`/etc/ipsec.secrets`)
```ini
52.165.80.112 172.168.154.224 : PSK "test"
```

---

## 🔧 Blockers & Fixes

### 1. Tunnel up, no traffic matched
- **Symptom**: `ip -s xfrm state` showed `0 bytes`.  
- **Root cause**: We used `mark=42` (VTI mode), but no packets matched.  
- ✅ **Fix**: Removed `mark` → let policies capture traffic.

---

### 2. Wrong subnet selector
- **Symptom**: Tunnel established but still no bytes.  
- **Root cause**: Configured `rightsubnet=10.100.0.0/24`, but VM lived in `10.100.1.0/24`.  
- ✅ **Fix**: Corrected to `10.100.1.0/24` (later expanded to include `10.101.1.0/24`).

---

### 3. Ping failed, RDP worked
- **Symptom**: `ping` to 10.100.1.4 failed, but RDP port test succeeded.  
- **Root cause**: ICMP blocked by Azure Firewall or Windows host firewall.  
- ✅ **Fix**: Used `nc -vz host port` (TCP connectivity test) for validation.

---

### 4. No access to West VNet
- **Symptom**: Central reachable, West not.  
- **Root cause**: West subnet not included in tunnel.  
- ✅ **Fix**: Added `10.101.1.0/24` to `rightsubnet`.  
- ✅ **Result**: VWAN fabric routed Central Hub → West Hub → West VM automatically.

---

## ✅ Validation

From branch router:
```bash
# Central VM
nc -vz 10.100.1.4 3389
# Connection succeeded

# West VM (via inter-hub)
nc -vz 10.101.1.4 3389
# Connection succeeded

# Verify traffic encryption
sudo ip -s xfrm state
```

Counters incremented, confirming traffic was encapsulated in ESP.

---

## 📊 Architecture Diagram

```
Chicago Branch (10.200.0.0/24)
    |
    | IPsec (strongSwan, PSK)
    v
Azure VWAN Central Hub (rmoriartyCentralHub)
    |
    +--> Central Firewall --> vnetCentral (10.100.1.0/24)
    |
    +-- Inter-hub fabric --> West Firewall --> vnetWest (10.101.1.0/24)
```

---

## ✍️ Notes

- This PoC uses **static IPsec selectors**.  
- For production: enable **BGP** (VWAN Site ASN + FRR/Quagga on branch) for dynamic route exchange.  
- Routing Intent → Firewall means all traffic must be explicitly allowed in firewall policies.  
- **Effective routes** on Azure VM NICs are critical for troubleshooting. Check for:  
  ```
  10.200.0.0/24   Next hop: Virtual network gateway
  ```

---

## 🏁 Outcome

We successfully built a **Linux-based branch router** connected to Azure VWAN.  
- Central VM and West VM are reachable from the branch.  
- Traffic encrypts through IPsec and traverses Azure Firewall via Routing Intent.  
- Inter-hub routing worked automatically without extra config.  
- Blockers were resolved by fixing IPsec selectors, removing marks, and validating with TCP tests.

---
