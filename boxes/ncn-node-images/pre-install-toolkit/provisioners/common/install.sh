#!/bin/bash
#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
set -euo pipefail

echo "export PYTHONPATH=\"/srv/cray/utilities/common\"" >> /etc/profile.d/cray.sh

echo "Enabling/disabling services"
systemctl disable mdcheck_continue.service
systemctl disable mdcheck_start.service
systemctl disable mdmonitor-oneshot.service
systemctl disable mdmonitor.service
systemctl disable --now postfix.service
systemctl enable apache2.service
systemctl enable basecamp.service
systemctl enable ca-certificates.service
systemctl enable chronyd.service
systemctl enable dnsmasq.service
systemctl enable getty@tty1.service
systemctl enable issue-generator.service
systemctl enable kdump-early.service
systemctl enable kdump.service
systemctl enable lldpad.service
systemctl enable multi-user.target
systemctl enable nexus.service
systemctl enable purge-kernels.service
systemctl enable rc-local.service
systemctl enable rollback.service
systemctl enable serial-getty@ttyS0.service
systemctl enable sshd.service
systemctl enable wicked.service
systemctl enable wickedd-auto4.service
systemctl enable wickedd-dhcp4.service
systemctl enable wickedd-dhcp6.service
systemctl enable wickedd-nanny.service
systemctl set-default multi-user.target

# Setup apparmor for dnsmasq
# TODO: Move this into the metal-ipxe.spec file.
# NOTE: editing local/usr.sbin.dnsmasq apparmor profile does not work
echo 'Adding `/var/www/boot` to apparmor for dnsmasq'
sed -i -E 's/(@\{TFTP_DIR\}=.*)/\1 \/var\/www\/boot/g' /etc/apparmor.d/usr.sbin.dnsmasq
rm -fv /etc/dnsmasq.conf.rpmnew

#======================================
# Add custom aliases and environment
# variables
#--------------------------------------
cat << EOF >> /root/.bashrc
alias ip='ip -c'
alias ll='ls -l --color'
alias lid='for file in \$(ls -1d /sys/bus/pci/drivers/*/0000\:*/net/*); do printf "% -6s %s\n" "\$(basename \$file)" \$(grep PCI_ID "\$(dirname \$(dirname \$file))/uevent" | cut -f 2 -d '='); done'
alias wipeoff="for script in /var/www/ncn-*/script.ipxe; do sed -i 's/metal.no-wipe=0/metal.no-wipe=1/g' \\\$script; done; wipestat"
alias wipeon="for script in /var/www/ncn-*/script.ipxe; do sed -i 's/metal.no-wipe=1/metal.no-wipe=0/g' \\\$script; done; wipestat"
alias wipestat='grep -o metal.no-wipe=[01] /var/www/ncn-*/script.ipxe'
source <(kubectl completion bash) 2>/dev/null
EOF
