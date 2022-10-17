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

# Metal artifacts are published to Artifactory and intended for running on real hardware.
# These are shipped to customers.
source "qemu" "sles15-base" {
  boot_command = [
    "<esc><enter><wait>",
    "linux netdevice=eth0 netsetup=dhcp install=cd:/<wait>",
    " lang=en_US autoyast=http://{{ .HTTPIP }}:{{ .HTTPPort }}/autoinst.xml<wait>",
    " textmode=1 password=${var.ssh_password}<wait>",
    "<enter><wait>"
  ]
  accelerator         = "${var.qemu_accelerator}"
  use_default_display = "${var.qemu_default_display}"
  display             = "${var.qemu_display}"
  format              = "${var.qemu_format}"
  boot_wait           = "${var.boot_wait}"
  cpus                = "${var.cpus}"
  memory              = "${var.memory}"
  disk_cache          = "${var.disk_cache}"
  disk_size           = "${var.disk_size}"
  disk_discard        = "unmap"
  disk_detect_zeroes  = "unmap"
  disk_compression    = true
  skip_compaction     = false
  headless            = "${var.headless}"
  http_directory      = "${path.root}/http"
  iso_checksum        = "${var.source_iso_checksum}"
  iso_url             = "${var.source_iso_uri}"
  shutdown_command    = "echo '${var.ssh_password}'|/sbin/halt -h -p"
  ssh_password        = "${var.ssh_password}"
  ssh_port            = 22
  ssh_username        = "${var.ssh_username}"
  ssh_wait_timeout    = "${var.ssh_wait_timeout}"
  output_directory    = "${var.output_directory}-qemu"
  vnc_bind_address    = "${var.vnc_bind_address}"
  vm_name             = "${var.image_name}.${var.qemu_format}"
}

# Google artifacts built and deployed into GCP and used in vShasta.
# NOTE: Unfortunately the googlecompute builder can not be used to build these base images, so
# qemu is used instead.
source "qemu" "sles15-google" {
  boot_command = [
    "<esc><enter><wait>",
    "linux netdevice=eth0 netsetup=dhcp install=cd:/<wait>",
    " lang=en_US autoyast=http://{{ .HTTPIP }}:{{ .HTTPPort }}/autoinst-google.xml<wait>",
    " textmode=1 password=${var.ssh_password}<wait>",
    "<enter><wait>"
  ]
  accelerator         = "${var.qemu_accelerator}"
  use_default_display = "${var.qemu_default_display}"
  display             = "${var.qemu_display}"
  format              = "${var.qemu_format}"
  boot_wait           = "${var.boot_wait}"
  cpus                = "${var.cpus}"
  memory              = "${var.memory}"
  disk_cache          = "${var.disk_cache}"
  disk_size           = "${var.disk_size}"
  headless            = "${var.headless}"
  http_directory      = "${path.root}/http"
  iso_checksum        = "${var.source_iso_checksum}"
  iso_url             = "${var.source_iso_uri}"
  shutdown_command    = "echo '${var.ssh_password}'|/sbin/halt -h -p"
  ssh_password        = "${var.ssh_password}"
  ssh_port            = 22
  ssh_username        = "${var.ssh_username}"
  ssh_wait_timeout    = "${var.ssh_wait_timeout}"
  output_directory    = "${var.output_directory}-google"
  vnc_bind_address    = "${var.vnc_bind_address}"
  vm_name             = "${var.image_name}-google.${var.qemu_format}"
}

# Vagrant artifacts are published to Artifactory and intended for developer/internal-user use.
source "vagrant" "sles15-base" {
  add_force    = false
  box_name     = "${var.box_name}"
  communicator = "ssh"
  insert_key   = true
  output_dir   = "${var.output_directory}-vagrant"
  provider     = "${var.vagrant_provider}"
  skip_add     = true
  source_path  = "${var.source_box_uri}"
  template     = "./scripts/vagrant/Vagrantfile"
}

# Not built by CI/CD; local-build-only.
# Intention: VirtualBox emulator for metal artifacts.
source "virtualbox-iso" "sles15-base" {
  boot_command = [
    "<esc><enter><wait>",
    "linux netdevice=eth0 netsetup=dhcp install=cd:/<wait>",
    " lang=en_US autoyast=http://{{ .HTTPIP }}:{{ .HTTPPort }}/autoinst.xml<wait>",
    " textmode=1 password=${var.ssh_password}<wait>",
    "<enter><wait>"
  ]
  boot_wait            = "${var.boot_wait}"
  cpus                 = "${var.cpus}"
  memory               = "${var.memory}"
  disk_size            = "${var.vbox_disk_size}"
  format               = "${var.vbox_format}"
  guest_additions_path = "VBoxGuestAdditions_{{ .Version }}.iso"
  guest_os_type        = "OpenSUSE_64"
  hard_drive_interface = "sata"
  headless             = "${var.headless}"
  http_directory       = "${path.root}/http"
  iso_checksum         = "${var.source_iso_checksum}"
  iso_url              = "${var.source_iso_uri}"
  sata_port_count      = 8
  shutdown_command     = "echo '${var.ssh_password}'|/sbin/halt -h -p"
  ssh_password         = "${var.ssh_password}"
  ssh_port             = 22
  ssh_username         = "${var.ssh_username}"
  ssh_wait_timeout     = "${var.ssh_wait_timeout}"
  output_directory     = "${var.output_directory}-virtualbox-iso"
  output_filename      = "${var.image_name}"
  vboxmanage           = [
    [
      "modifyvm",
      "{{ .Name }}",
      "--memory",
      "${var.memory}"
    ],
    [
      "modifyvm",
      "{{ .Name }}",
      "--cpus",
      "${var.cpus}"
    ]
  ]
  virtualbox_version_file = ".vbox_version"
}

build {
  sources = [
    "source.qemu.sles15-base",
    "source.qemu.sles15-google",
    "source.vagrant.sles15-base",
    "source.virtualbox-iso.sles15-base"
  ]

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/common/setup.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "SLES15_REGISTRATION_CODE=${var.sles15_registration_code}"
    ]
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/vagrant/setup.sh"
    only            = ["vagrant.sles15-base"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/common/install.sh"
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/google/install.sh"
    only            = ["qemu.sles15-google"]
  }

  provisioner "shell" {
    environment_vars = [
      "SLES15_INITIAL_ROOT_PASSWORD=${var.ssh_password}"
    ]
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/vagrant/install.sh"
    only            = ["vagrant.sles15-base"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/virtualbox/install.sh"
    only            = ["virtualbox-iso.sles15-base"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/common/cleanup.sh"
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/metal/cleanup.sh"
    only            = ["qemu.sles15-base"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/vagrant/cleanup.sh"
    only            = ["vagrant.sles15-base"]
  }

  post-processors {
    post-processor "shell-local" {
      inline = [
        "echo 'Saving variable file for use in google import'",
        "echo google_destination_project_id=\"${var.google_destination_project_id}\" > ./scripts/google/.variables",
        "echo output_directory=\"${var.output_directory}-google\" >> ./scripts/google/.variables",
        "echo image_name=\"${var.image_name}-google\" >> ./scripts/google/.variables",
        "echo version=\"${var.artifact_version}\" >> ./scripts/google/.variables",
        "echo qemu_format=\"${var.qemu_format}\" >> ./scripts/google/.variables",
        "echo google_destination_image_family=\"${var.google_destination_image_family}\" >> ./scripts/google/.variables",
        "echo google_network=\"${var.google_destination_project_network}\" >> ./scripts/google/.variables",
        "echo google_subnetwork=\"${var.google_subnetwork}\" >> ./scripts/google/.variables",
        "echo google_zone=\"${var.google_zone}\" >> ./scripts/google/.variables",
        "cat ./scripts/google/.variables"
      ]
      only = ["qemu.sles15-google"]
    }

    post-processor "shell-local" {
      # Packer will always make a package.box file from its vagrant builder (https://github.com/hashicorp/packer-plugin-vagrant/issues/16).
      # This renames package.box to ${source.name}.box, and removes the Vagrantfile since it contains sensitive information (e.g. the root password).
      inline = [
        "mv -v ${var.output_directory}-${source.type}/package.box ${var.output_directory}-${source.type}/${var.image_name}.box",
        "ls -l ${var.output_directory}-${source.type}/"
      ]
      only = ["vagrant.sles15-base"]
    }

    post-processor "shell-local" {
      # Create a volume for the next layer to auto-resolve, preventing race condiitons during parallel builds.
      inline = [
        "vagrant box add --name ${source.name} --provider ${var.vagrant_provider} ${var.output_directory}-${source.type}/${var.image_name}.box",
        "echo export name=\"${source.name}_vagrant_box_image_0_$(stat -c %Y ~/.vagrant.d/boxes/${source.name}/0/${var.vagrant_provider}/box.img )_box.img\" > ./scripts/vagrant/.variables",
        "echo export libvirt_uid=\"$(id -u libvirt-qemu)\" >> ./scripts/vagrant/.variables",
        "echo export libvirt_gid=\"$(getent group libvirt-qemu | awk -F : '{print $3}')\" >> ./scripts/vagrant/.variables",
        "echo export allocation=\"$(stat -c %s ~/.vagrant.d/boxes/${source.name}/0/${var.vagrant_provider}/box.img)\" >> ./scripts/vagrant/.variables",
        "echo export capacity=\"$(cat ~/.vagrant.d/boxes/${source.name}/0/${var.vagrant_provider}/metadata.json  | jq .virtual_size | awk '{print $1*1024*1024*1024}')\" >> ./scripts/vagrant/.variables",
        "cat ./scripts/vagrant/.variables",
        "bash -c '. ./scripts/vagrant/.variables; envsubst < ./scripts/vagrant/volume.template.xml > ./${var.output_directory}-${source.type}/volume.xml'",
        "sudo virsh vol-create default ./${var.output_directory}-${source.type}/volume.xml",
        "bash -c '. ./scripts/vagrant/.variables; sudo virsh vol-upload $name ~/.vagrant.d/boxes/${source.name}/0/${var.vagrant_provider}/box.img --pool default'"
      ]
      only = ["vagrant.sles15-base"]
    }
  }
}
