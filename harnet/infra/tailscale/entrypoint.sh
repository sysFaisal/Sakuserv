#!/bin/sh
set -e

echo "[harnet-gateway] configuring firewall"

# ==============================
# Cleanup rule dari script lama
# ==============================

iptables -D FORWARD \
  -i eth0 -o tailscale0 \
  -j ACCEPT 2>/dev/null || true

iptables -D FORWARD \
  -i tailscale0 -o eth0 \
  -m conntrack \
  --ctstate ESTABLISHED,RELATED \
  -j ACCEPT 2>/dev/null || true

iptables -D FORWARD \
  -i tailscale0 -o eth0 \
  -p tcp \
  -d 172.19.0.3 \
  --dport 443 \
  -m conntrack \
  --ctstate NEW,ESTABLISHED,RELATED \
  -j ACCEPT 2>/dev/null || true

iptables -t nat -D PREROUTING \
  -i tailscale0 \
  -p tcp \
  --dport 443 \
  -j DNAT \
  --to-destination 172.19.0.3:443 2>/dev/null || true

iptables -t nat -D POSTROUTING \
  -s 172.19.0.0/16 \
  -o tailscale0 \
  -j MASQUERADE 2>/dev/null || true


# ==============================
# Tailnet -> Caddy
# ==============================

iptables -A FORWARD \
  -i tailscale0 \
  -o eth0 \
  -p tcp \
  -d 172.19.0.3 \
  --dport 443 \
  -m conntrack \
  --ctstate NEW,ESTABLISHED,RELATED \
  -j ACCEPT


# ==============================
# Caddy -> Tailnet return traffic
# ==============================

iptables -A FORWARD \
  -i eth0 \
  -o tailscale0 \
  -m conntrack \
  --ctstate ESTABLISHED,RELATED \
  -j ACCEPT


# ==============================
# Tailnet :443 -> Caddy :443
# ==============================

iptables -t nat -A PREROUTING \
  -i tailscale0 \
  -p tcp \
  --dport 443 \
  -j DNAT \
  --to-destination 172.19.0.3:443


# ==============================
# Docker -> Tailnet NAT
# ==============================

iptables -t nat -A POSTROUTING \
  -s 172.19.0.0/16 \
  -o tailscale0 \
  -j MASQUERADE


echo "[harnet-gateway] firewall ready"

exec /usr/local/bin/containerboot
