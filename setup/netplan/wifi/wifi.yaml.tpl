network:
  version: 2
  renderer: networkd
  wifis:
    ${WIFI_IFACE}:
      dhcp4: no
      addresses: 
        - ${STATIC_IP}
      routes:
        - to: default
          via: ${GATEWAY}
      nameservers:
        addresses: [${DNS}]
      access-points:
        "${WIFI_SSID}":
          password: "${WIFI_PASSWORD}"
