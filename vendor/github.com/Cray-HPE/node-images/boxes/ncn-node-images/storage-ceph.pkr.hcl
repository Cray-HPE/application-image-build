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
source "googlecompute" "storage-ceph" {
  instance_name           = "vshasta-${var.image_name_ceph}-builder-${var.artifact_version}"
  project_id              = "${var.google_destination_project_id}"
  network_project_id      = "${var.google_network_project_id}"
  source_image_project_id = "${var.google_source_image_project_id}"
  source_image_family     = "${var.google_source_image_family}"
  source_image            = "${var.google_source_image_name}"
  service_account_email   = "${var.google_service_account_email}"
  ssh_username            = "root"
  zone                    = "${var.google_zone}"
  image_family            = "vshasta-storage-ceph-rc"
  image_name              = "vshasta-${var.image_name_ceph}-${var.artifact_version}"
  image_description       = "build_source-artifact = ${var.google_source_image_url}, build_url = ${var.build_url}"
  machine_type            = "${var.google_machine_type}"
  subnetwork              = "${var.google_subnetwork}"
  disk_size               = "${var.google_disk_size_gb}"
  use_internal_ip         = "${var.google_use_internal_ip}"
  omit_external_ip        = "${var.google_use_internal_ip}"
}

# Metal artifacts are published to Artifactory and intended for running on real hardware.
# These are shipped to customers.
source "qemu" "storage-ceph" {
  accelerator         = "${var.qemu_accelerator}"
  use_default_display = "${var.qemu_default_display}"
  display             = "${var.qemu_display}"
  cpus                = "${var.cpus}"
  disk_cache          = "${var.disk_cache}"
  disk_size           = "${var.disk_size}"
  memory              = "${var.memory}"
  iso_url             = "${var.source_iso_uri}"
  iso_checksum        = "none"
  headless            = "${var.headless}"
  shutdown_command    = "echo '${var.ssh_password}'|/sbin/halt -h -p"
  ssh_password        = "${var.ssh_password}"
  ssh_username        = "${var.ssh_username}"
  ssh_wait_timeout    = "${var.ssh_wait_timeout}"
  output_directory    = "${var.output_directory}/storage-ceph-qemu"
  vm_name             = "${var.image_name_ceph}.${var.qemu_format}"
  disk_image          = true
  disk_discard        = "unmap"
  disk_detect_zeroes  = "unmap"
  disk_compression    = true
  skip_compaction     = false
  vnc_bind_address    = "${var.vnc_bind_address}"
}

# Vagrant artifacts are published to Artifactory and intended for developer/internal-user use.
source "vagrant" "storage-ceph" {
  add_force    = false
  box_name     = "${var.box_name}"
  communicator = "ssh"
  insert_key   = true
  output_dir   = "${var.output_directory}/storage-ceph-vagrant"
  provider     = "${var.vagrant_provider}"
  skip_add     = true
  source_path  = "${var.source_box_uri}"
  template     = "./scripts/vagrant/Vagrantfile"
}

# Not built by CI/CD; local-build-only.
# Intention: VirtualBox emulator for metal artifacts.
source "virtualbox-ovf" "storage-ceph" {
  source_path      = "${var.vbox_source_path}"
  format           = "${var.vbox_format}"
  checksum         = "none"
  headless         = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|/sbin/halt -h -p"
  ssh_password     = "${var.ssh_password}"
  ssh_username     = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/storage-ceph-virtualbox-ovf"
  output_filename  = "${var.image_name_ceph}"
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
    "source.googlecompute.storage-ceph",
    "source.qemu.storage-ceph",
    "source.vagrant.storage-ceph",
    "source.virtualbox-ovf.storage-ceph"
  ]

  provisioner "file" {
    direction   = "upload"
    source      = "./vendor/github.com/Cray-HPE/csm-rpms"
    destination = "/tmp"
  }

  provisioner "file" {
    direction   = "upload"
    source      = "${path.root}/${source.name}/files"
    destination = "/tmp"
  }

  provisioner "file" {
    direction   = "upload"
    source      = "./vendor/github.com/Cray-HPE/metal-provision/ansible.cfg"
    destination = "/tmp/ansible.cfg"
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "mkdir -pv /etc/ansible /srv/cray",
      "cp -pv /tmp/ansible.cfg /etc/ansible/",
      "cp -rpv /tmp/files/* /srv/cray/",
      "cp -rpv /tmp/csm-rpms /srv/cray/"
    ]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/common/setup.sh"
  }

  # setup.sh only exists for storage-ceph at this time.
  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/${source.name}/provisioners/common/setup.sh"
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.packages explicit'",
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.deps.packages deps'"
    ]
    only = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
  }

  // Install packages by context (e.g. base (a.k.a. common), google, or metal)
  provisioner "shell" {
    environment_vars = [
      "ARTIFACTORY_USER=${var.artifactory_user}",
      "ARTIFACTORY_TOKEN=${var.artifactory_token}"
    ]
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; setup-package-repos'"
    ]
    valid_exit_codes = [0, 123]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-storage-ceph/base.packages'"
    ]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-storage-ceph/metal.packages'"
    ]
    only = ["virtualbox-ovf.storage-ceph", "qemu.storage-ceph"]
  }

  provisioner "shell" {
    environment_vars = [
      "DOCKER_IMAGE_REGISTRY=${var.docker_image_registry}",
      "K8S_IMAGE_REGISTRY=${var.k8s_image_registry}",
      "QUAY_IMAGE_REGISTRY=${var.quay_image_registry}"
    ]
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/${source.name}/provisioners/common/install.sh"
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/${source.name}/provisioners/google/install.sh"
    only            = ["googlecompute.storage-ceph"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/${source.name}/provisioners/metal/install.sh"
    only            = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.packages explicit'",
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.deps.packages deps'",
      "zypper lr -e /tmp/installed.repos"
    ]
    only = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
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
    only        = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
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
    only = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/oval-results.xml"
    destination = "${var.output_directory}/${source.name}-${source.type}/oval-results-${source.type}.${source.name}.xml"
    only = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/oval-patch-results.xml"
    destination = "${var.output_directory}/${source.name}-${source.type}/oval-patch-results-${source.type}.${source.name}.xml"
    only = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/oval-report.html"
    destination = "${var.output_directory}/${source.name}-${source.type}/oval-report-${source.type}.${source.name}.html"
    only = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/oval-patch-report.html"
    destination = "${var.output_directory}/${source.name}-${source.type}/oval-patch-report-${source.type}.${source.name}.html"
    only = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/common/cleanup.sh"
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/google/cleanup.sh"
    only            = ["googlecompute.storage-ceph"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/metal/cleanup.sh"
    only            = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "goss -g /srv/cray/tests/common/ncn-common-tests.yml validate -f junit | tee /tmp/goss_${source.name}_ncn_common_out.xml",
      "goss -g /srv/cray/tests/common/${source.name}-tests.yml validate -f junit | tee /tmp/goss_${source.name}_out.xml"
    ]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "goss -g /srv/cray/tests/google/ncn-common-tests.yml validate -f junit | tee /tmp/goss_${source.name}_ncn_google_out.xml"
    ]
    only = ["googlecompute.storage-ceph"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "goss -g /srv/cray/tests/metal/ncn-common-tests.yml validate -f junit | tee /tmp/goss_${source.name}_ncn_metal_out.xml",
      "goss -g /srv/cray/tests/metal/${source.name}-tests.yml validate -f junit | tee /tmp/goss_${source.name}_metal_out.xml"
    ]
    only = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/goss_${source.name}_ncn_common_out.xml"
    destination = "${var.output_directory}/${source.name}-${source.type}/test-results-${source.type}.${source.name}-ncn-common.xml"
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/goss_${source.name}_out.xml"
    destination = "${var.output_directory}/${source.name}-${source.type}/test-results-${source.type}.${source.name}.xml"
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/goss_${source.name}_ncn_google_out.xml"
    destination = "${var.output_directory}/${source.name}-${source.type}/test-results-${source.type}.${source.name}-ncn-google.xml"
    only        = ["googlecompute.storage-ceph"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/goss_${source.name}_ncn_metal_out.xml"
    destination = "${var.output_directory}/${source.name}-${source.type}/test-results-${source.type}.${source.name}-ncn-metal.xml"
    only        = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/goss_${source.name}_metal_out.xml"
    destination = "${var.output_directory}/${source.name}-${source.type}/test-results-${source.type}.${source.name}-metal.xml"
    only        = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "/srv/cray/scripts/common/create-kis-artifacts.sh"
    ]
    only = ["qemu.storage-ceph"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/squashfs/"
    destination = "${var.output_directory}/${source.name}-${source.type}/"
    only        = ["qemu.storage-ceph"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "/srv/cray/scripts/common/cleanup-kis-artifacts.sh"
    ]
    only = ["qemu.storage-ceph"]
  }

  post-processors {
    post-processor "shell-local" {
      inline = [
        "if ! grep ' failures=.0. ' ${var.output_directory}/${source.name}-${source.type}/test-results-${source.type}.${source.name}-ncn-common.xml; then echo >&2 'Error: goss test failures found! See build output for details'; exit 1; fi",
        "if ! grep ' failures=.0. ' ${var.output_directory}/${source.name}-${source.type}/test-results-${source.type}.${source.name}.xml; then echo >&2 'Error: goss test failures found! See build output for details'; exit 1; fi"
      ]
    }

    post-processor "shell-local" {
      inline = [
        "if ! grep ' failures=.0. ' ${var.output_directory}/${source.name}-${source.type}/test-results-${source.type}.${source.name}-ncn-google.xml; then echo >&2 'Error: goss test failures found! See build output for details'; exit 1; fi"
      ]
      only = ["googlecompute.storage-ceph"]
    }

    post-processor "shell-local" {
      inline = [
        "if ! grep ' failures=.0. ' ${var.output_directory}/${source.name}-${source.type}/test-results-${source.type}.${source.name}-ncn-metal.xml; then echo >&2 'Error: goss test failures found! See build output for details'; exit 1; fi",
        "if ! grep ' failures=.0. ' ${var.output_directory}/${source.name}-${source.type}/test-results-${source.type}.${source.name}-metal.xml; then echo >&2 'Error: goss test failures found! See build output for details'; exit 1; fi"
      ]
      only = ["qemu.storage-ceph", "virtualbox-ovf.storage-ceph"]
    }

    post-processor "shell-local" {
      inline = [
        "echo 'Rename filesystem.squashfs and move remaining files to receive the image ID'",
        "ls -lR ./${var.output_directory}/${source.name}-${source.type}",
        "mv ${var.output_directory}/${source.name}-${source.type}/squashfs/filesystem.squashfs ${var.output_directory}/${source.name}-${source.type}/${source.name}.squashfs",
        "mv ${var.output_directory}/${source.name}-${source.type}/squashfs/*.kernel ${var.output_directory}/${source.name}-${source.type}",
        "mv ${var.output_directory}/${source.name}-${source.type}/squashfs/initrd.img.xz ${var.output_directory}/${source.name}-${source.type}",
        "rm -rf ${var.output_directory}/${source.name}-${source.type}/squashfs",
      ]
      only = ["qemu.storage-ceph"]
    }

    post-processor "shell-local" {
      # Packer will always make a package.box file from its vagrant builder (https://github.com/hashicorp/packer-plugin-vagrant/issues/16).
      # This renames package.box to ${var.image_name}.box.
      inline = [
        "mv -v ${var.output_directory}/${source.name}-${source.type}/package.box ${var.output_directory}/${source.name}-${source.type}/${var.image_name_ceph}.box",
        "ls -l ${var.output_directory}/${source.name}-${source.type}"
      ]
      only = ["vagrant.storage-ceph"]
    }
  }
}
