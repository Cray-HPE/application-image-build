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

# Google artifacts built and deployed into GCP and used in vShasta.
source "googlecompute" "application" {
  instance_name           = "vshasta-${var.image_name}-builder-${var.artifact_version}"
  project_id              = "${var.google_destination_project_id}"
  network_project_id      = "${var.google_network_project_id}"
  source_image_project_id = "${var.google_source_image_project_id}"
  source_image_family     = "${var.google_source_image_family}"
  source_image            = "${var.google_source_image_name}"
  service_account_email   = "${var.google_service_account_email}"
  ssh_username            = "root"
  zone                    = "${var.google_zone}"
  image_family            = "${var.google_destination_image_family}"
  image_name              = "vshasta-${var.image_name}-${var.artifact_version}"
  image_description       = "build_source-artifact = ${var.google_source_image_url}, build_url = ${var.build_url}"
  machine_type            = "${var.google_machine_type}"
  subnetwork              = "${var.google_subnetwork}"
  disk_size               = "${var.google_disk_size_gb}"
  use_internal_ip         = "${var.google_use_internal_ip}"
  omit_external_ip        = "${var.google_use_internal_ip}"
}

# Artifacts are published to Artifactory and intended for running on real hardware.
# These are shipped to customers.
source "qemu" "application" {
  accelerator         = "${var.qemu_accelerator}"
  cpus                = "${var.cpus}"
  disk_cache          = "${var.disk_cache}"
  disk_discard        = "unmap"
  disk_detect_zeroes  = "unmap"
  disk_compression    = "${var.qemu_disk_compression}"
  skip_compaction     = "${var.qemu_skip_compaction}"
  disk_image          = true
  disk_size           = "${var.disk_size}"
  display             = "${var.qemu_display}"
  use_default_display = "${var.qemu_default_display}"
  memory              = "${var.memory}"
  headless            = "${var.headless}"
  iso_checksum        = "${var.source_iso_checksum}"
  iso_url             = "${var.source_iso_uri}"
  shutdown_command    = "echo '${var.ssh_password}'|/sbin/halt -h -p"
  ssh_password        = "${var.ssh_password}"
  ssh_username        = "${var.ssh_username}"
  ssh_wait_timeout    = "${var.ssh_wait_timeout}"
  output_directory    = "${var.output_directory}/application-qemu"
  vnc_bind_address    = "${var.vnc_bind_address}"
  vm_name             = "${var.image_name}.${var.qemu_format}"
  format              = "${var.qemu_format}"
}

# Vagrant artifacts are published to Artifactory and intended for developer/internal-user use.
source "vagrant" "application" {
  add_force    = false
  box_name     = "${var.box_name}"
  communicator = "ssh"
  insert_key   = true
  output_dir   = "${var.output_directory}/application-vagrant"
  provider     = "${var.vagrant_provider}"
  skip_add     = true
  source_path  = "${var.source_box_uri}"
  template     = "${var.vendor_path}/scripts/vagrant/Vagrantfile"
}

# Not built by CI/CD; local-build-only.
# Intention: VirtualBox emulator for metal artifacts.
source "virtualbox-ovf" "application" {
  source_path      = "${var.vbox_source_path}"
  format           = "${var.vbox_format}"
  checksum         = "none"
  headless         = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|/sbin/halt -h -p"
  ssh_password     = "${var.ssh_password}"
  ssh_username     = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/application-virtualbox-ovf"
  output_filename  = "${var.image_name}"
  vboxmanage       = [
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
  guest_additions_mode    = "disable"
}

build {
  sources = [
    "source.googlecompute.application",
    "source.qemu.application",
    "source.vagrant.application",
    "source.virtualbox-ovf.application"
  ]

  provisioner "file" {
    direction   = "upload"
    source      = "${var.vendor_path}/vendor/github.com/Cray-HPE/csm-rpms"
    destination = "/tmp"
  }

  provisioner "file" {
    direction   = "upload"
    source      = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/ansible.cfg"
    destination = "/tmp/ansible.cfg"
  }

  provisioner "file" {
    direction   = "upload"
    source      = "boxes/application/files"
    destination = "/tmp"
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "mkdir -pv /etc/ansible /srv/cray",
      "cp -pv /tmp/ansible.cfg /etc/ansible/",
      "cp -rpv /tmp/csm-rpms /srv/cray/",
      "cp -rpv /tmp/files /srv/cray/"
    ]
  }
  
  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    environment_vars = [
      "COS_CN_REPO=https://arti.hpc.amslabs.hpecorp.net/artifactory/cos-rpm-stable-local/release/cos-2.4/sle15_sp3_cn/ cray-cos-sle-15sp3-SHASTA-OS-cos-cn --no-gpgcheck -p 89 cray/cos/sle-15sp3-cn",
    ]
    inline        = [
      "bash -c 'echo $COS_CN_REPO >> /srv/cray/csm-rpms/repos/cray.template.repos'",
      "bash -c 'cp /srv/cray/files/cmdline-perm.service /usr/lib/systemd/system/cmdline-perm.service'",
      "bash -c 'systemctl enable cmdline-perm'"
    ]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    environment_vars = [
      "ARTIFACTORY_USER=${var.artifactory_user}",
      "ARTIFACTORY_TOKEN=${var.artifactory_token}"
    ]
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; setup-package-repos'"
    ]
    valid_exit_codes = [0, 123]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.packages explicit'",
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.deps.packages deps'"
    ]
    only = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-common/base.packages'"
    ]
    valid_exit_codes = [0, 123]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-common/google.packages'"
    ]
    valid_exit_codes = [0, 123]
    only             = ["googlecompute.application"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-common/metal.packages'"
    ]
    valid_exit_codes = [0, 123]
    only             = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-common/vagrant.packages'"
    ]
    valid_exit_codes = [0, 123]
    only             = ["vagrant.application"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/files/application.packages'"
    ]
    valid_exit_codes = [0, 123]
    only             = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/common/setup.sh"
  }

  provisioner "ansible-local" {
    inventory_file = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/packer.yml"
    playbook_dir   = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision"
    playbook_file  = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/pb_ncn_common.yml"
    command        = "source /etc/ansible/csm_ansible/bin/activate && ANSIBLE_STDOUT_CALLBACK=debug PYTHONUNBUFFERED=1 /etc/ansible/csm_ansible/bin/ansible-playbook --tags common"
  }

  provisioner "ansible-local" {
    inventory_file = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/packer.yml"
    playbook_dir   = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision"
    playbook_file  = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/pb_ncn_common.yml"
    command        = "source /etc/ansible/csm_ansible/bin/activate && ANSIBLE_STDOUT_CALLBACK=debug PYTHONUNBUFFERED=1 /etc/ansible/csm_ansible/bin/ansible-playbook --tags google"
    only           = ["googlecompute.application"]
  }

  provisioner "ansible-local" {
    inventory_file = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/packer.yml"
    playbook_dir   = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision"
    playbook_file  = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/pb_ncn_common.yml"
    command        = "source /etc/ansible/csm_ansible/bin/activate && ANSIBLE_STDOUT_CALLBACK=debug PYTHONUNBUFFERED=1 /etc/ansible/csm_ansible/bin/ansible-playbook --tags metal"
    only           = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "ansible-local" {
    inventory_file = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/packer.yml"
    playbook_dir   = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision"
    playbook_file  = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/pb_ncn_common.yml"
    command        = "source /etc/ansible/csm_ansible/bin/activate && ANSIBLE_STDOUT_CALLBACK=debug PYTHONUNBUFFERED=1 /etc/ansible/csm_ansible/bin/ansible-playbook --tags vagrant"
    only           = ["vagrant.application"]
  }

  // Creates a virtualenv for GCP
  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/google/install.sh"
    only            = ["googlecompute.application"]

  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/metal/install.sh"
    only            = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "ansible-local" {
    inventory_file = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/packer.yml"
    playbook_dir   = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision"
    playbook_file  = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/pb_ncn_common_team.yml"
    command        = "source /etc/ansible/csm_ansible/bin/activate && ANSIBLE_STDOUT_CALLBACK=debug PYTHONUNBUFFERED=1 /etc/ansible/csm_ansible/bin/ansible-playbook --tags common"
  }

  provisioner "ansible-local" {
    inventory_file = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/packer.yml"
    playbook_dir   = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision"
    playbook_file  = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/pb_ncn_common_team.yml"
    command        = "source /etc/ansible/csm_ansible/bin/activate && ANSIBLE_STDOUT_CALLBACK=debug PYTHONUNBUFFERED=1 /etc/ansible/csm_ansible/bin/ansible-playbook --tags google"
    only           = ["googlecompute.application"]
  }

  provisioner "ansible-local" {
    inventory_file = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/packer.yml"
    playbook_dir   = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision"
    playbook_file  = "${var.vendor_path}/vendor/github.com/Cray-HPE/metal-provision/pb_ncn_common_team.yml"
    command        = "source /etc/ansible/csm_ansible/bin/activate && ANSIBLE_STDOUT_CALLBACK=debug PYTHONUNBUFFERED=1 /etc/ansible/csm_ansible/bin/ansible-playbook --tags metal"
    only           = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.packages explicit'",
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.deps.packages deps'",
      "zypper lr -e /tmp/installed.repos"
    ]
    only = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "file" {
    direction = "download"
    sources   = [
      "/tmp/initial.deps.packages",
      "/tmp/initial.packages",
      "/tmp/installed.deps.packages",
      "/tmp/installed.packages",
      "/tmp/installed.repos"
    ]
    destination = "${var.output_directory}/${source.name}-qemu/"
    only        = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-package-repos'"
    ]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-all-repos'"
    ]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["/srv/cray/scripts/common/openscap.sh"]
    only = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/oval-results.xml"
    destination = "${var.output_directory}/${source.type}-${source.type}/oval-results-${source.type}.${source.name}.xml"
    only = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/oval-patch-results.xml"
    destination = "${var.output_directory}/${source.type}-${source.type}/oval-patch-results-${source.type}.${source.name}.xml"
    only = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/oval-report.html"
    destination = "${var.output_directory}/${source.type}-${source.type}/oval-report-${source.type}.${source.name}.html"
    only = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/oval-patch-report.html"
    destination = "${var.output_directory}/${source.type}-${source.type}/oval-patch-report-${source.type}.${source.name}.html"
    only = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/common/cleanup.sh"
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script = "${path.root}/files/cleanup.sh"
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '/srv/cray/scripts/common/create-kis-artifacts.sh'"
    ]
    only = ["qemu.application", "virtualbox-ovf.application"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/squashfs/"
    destination = "${var.output_directory}/${source.name}-${source.type}/"
    only        = ["qemu.application"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '/srv/cray/scripts/common/cleanup-kis-artifacts.sh'"
    ]
    only = ["qemu.application", "virtualbox-ovf.application"]
  }

  post-processors {
    #post-processor "shell-local" {
    #  # Packer will always make a package.box file from its vagrant builder (https://github.com/hashicorp/packer-plugin-vagrant/issues/16).
    #  # This renames package.box to ${source.name}.box, and removes the Vagrantfile since it contains sensitive information (e.g. the root password).
    #  inline = [
    #    "mv -v ${var.output_directory}/${source.type}-${source.type}/package.box ${var.output_directory}/${source.type}-${source.type}/${var.image_name}.box",
    #    "ls -l ${var.output_directory}/${source.type}-${source.type}/"
    #  ]
    #  only = ["vagrant.application"]
    #}

    # Commented out as no subsequent  layer exists yet 
    #post-processor "shell-local" {
    #  # Create a volume for the next layer to auto-resolve, preventing race conditions during parallel builds.
    #  inline = [
    #    "vagrant box add --name ${source.name} --provider ${var.vagrant_provider} ${var.output_directory}-${source.type}/${var.image_name}.box",
    #    "echo export name=\"${source.name}_vagrant_box_image_0_$(stat -c %Y ~/.vagrant.d/boxes/${source.name}/0/${var.vagrant_provider}/box.img )_box.img\" > ./scripts/vagrant/.variables",
    #    "echo export libvirt_uid=\"$(id -u libvirt-qemu)\" >> ./scripts/vagrant/.variables",
    #    "echo export libvirt_gid=\"$(getent group libvirt-qemu | awk -F : '{print $3}')\" >> ./scripts/vagrant/.variables",
    #    "echo export allocation=\"$(stat -c %s ~/.vagrant.d/boxes/${source.name}/0/${var.vagrant_provider}/box.img)\" >> ./scripts/vagrant/.variables",
    #    "echo export capacity=\"$(cat ~/.vagrant.d/boxes/${source.name}/0/${var.vagrant_provider}/metadata.json | jq .virtual_size | awk '{print $1*1024*1024*1024}')\" >> ./scripts/vagrant/.variables",
    #    "cat ./scripts/vagrant/.variables",
    #    "bash -c '. ./scripts/vagrant/.variables; envsubst < ./scripts/vagrant/volume.template.xml > ./${var.output_directory}-${source.type}/volume.xml'",
    #    "sudo virsh vol-create default ./${var.output_directory}-${source.type}/volume.xml",
    #    "bash -c '. ./scripts/vagrant/.variables; sudo virsh vol-upload $name ~/.vagrant.d/boxes/${source.name}/0/${var.vagrant_provider}/box.img --pool default'"
    #  ]
    #  only = ["vagrant.application"]
    #}

    post-processor "shell-local" {
      inline = [
        "echo 'Rename filesystem.squashfs and move remaining files to receive the image ID'",
        "ls -lR ./${var.output_directory}/${source.name}-${source.type}",
        "mv ${var.output_directory}/${source.name}-${source.type}/squashfs/filesystem.squashfs ${var.output_directory}/${source.name}-${source.type}/${source.name}.squashfs",
        "mv ${var.output_directory}/${source.name}-${source.type}/squashfs/*.kernel ${var.output_directory}/${source.name}-${source.type}",
        "mv ${var.output_directory}/${source.name}-${source.type}/squashfs/initrd.img.xz ${var.output_directory}/${source.name}-${source.type}",
        "rm -rf ${var.output_directory}/${source.name}-${source.type}/squashfs",
        "ls -lR ./${var.output_directory}/${source.name}-${source.type}"
      ]
      only = ["qemu.application"]
    }
  }
}
