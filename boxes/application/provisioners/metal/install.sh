#!/bin/bash

set -e

# Agentless Management Service only works on servers with iLO4/5; disable by default.
if rpm -qi amsd ; then
    echo "Disabling Agentless Management Daemon"
    systemctl disable ahslog
    systemctl disable amsd
    systemctl disable cpqFca
    systemctl disable cpqIde
    systemctl disable cpqScsi
    systemctl disable smad
    systemctl stop ahslog
    systemctl stop amsd
    systemctl stop cpqFca
    systemctl stop cpqIde
    systemctl stop cpqScsi
    systemctl stop smad
fi

# Allow domains.
sed -i 's/^DHCLIENT_FQDN_ENABLED=.*/DHCLIENT_FQDN_ENABLED="enabled"/' /etc/sysconfig/network/dhcp
# Notify update on hostname change.
sed -i 's/^DHCLIENT_FQDN_UPDATE=.*/DHCLIENT_FQDN_UPDATE="both"/' /etc/sysconfig/network/dhcp
# Let DHCP set hostname
sed -i 's/^DHCLIENT_SET_HOSTNAME=.*/DHCLIENT_SET_HOSTNAME="yes"/' /etc/sysconfig/network/dhcp
