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

# Parts of this were borrowed from the official template
# https://github.com/hashicorp/packer-plugin-vagrant/blob/main/builder/vagrant/step_create_vagrantfile.go
Vagrant.configure("2") do |config|

  config.vagrant.plugins = "vagrant-libvirt"

  config.vm.define 'source', autostart: false do |source| 
    source.vm.box = '{{ .BoxName }}'
  end
  config.vm.define 'output' do |output|
    output.vm.box_url = 'file://package.box'
  end

  config.ssh.insert_key = '{{ .InsertKey }}'

  # Configure Vagrant's credentials (Packer does not use these values).
  config.vm.provider :libvirt do |domain|
    domain.autostart = true
    domain.cpus = $nproc
    domain.driver = 'kvm'
    domain.memory = 8192

    # Size in GB (needs integer). This will not automatically resize the root, that needs to be done
    # by hand.
    domain.machine_virtual_size = 42
    
    # For parallel builds to work, at least for assurance, they can't tear the network down.
    domain.management_network_keep = true
  end
end
