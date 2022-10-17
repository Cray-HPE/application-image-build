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
source "googlecompute" "pre-install-toolkit" {
  instance_name           = "vshasta-${var.image_name_pit}-builder-${var.artifact_version}"
  project_id              = "${var.google_destination_project_id}"
  network_project_id      = "${var.google_network_project_id}"
  source_image_project_id = "${var.google_source_image_project_id}"
  source_image_family     = "${var.google_source_image_family}"
  source_image            = "${var.google_source_image_name}"
  service_account_email   = "${var.google_service_account_email}"
  ssh_username            = "root"
  zone                    = "${var.google_zone}"
  image_guest_os_features = "${var.image_guest_os_features}"
  image_family            = "vshasta-pre-install-toolkit-rc"
  image_name              = "vshasta-${var.image_name_pit}-${var.artifact_version}"
  image_description       = "build_source-artifact = ${var.google_source_image_url}, build_url = ${var.build_url}"
  machine_type            = "${var.google_machine_type}"
  subnetwork              = "${var.google_subnetwork}"
  disk_size               = "${var.google_disk_size_gb}"
  use_internal_ip         = "${var.google_use_internal_ip}"
  omit_external_ip        = "${var.google_use_internal_ip}"
}

# Metal artifacts are published to Artifactory and intended for running on real hardware.
# These are shipped to customers.
# NOTE: Until an ISO is created, the ISO we ship comes from https://github.com/Cray-HPE/cray-pre-install-toolkit.
source "qemu" "pre-install-toolkit" {
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
  output_directory    = "${var.output_directory}/pre-install-toolkit-qemu"
  vnc_bind_address    = "${var.vnc_bind_address}"
  vm_name             = "${var.image_name_pit}.${var.qemu_format}"
  format              = "${var.qemu_format}"
}

# Vagrant artifacts are published to Artifactory and intended for developer/internal-user use.
source "vagrant" "pre-install-toolkit" {
  add_force    = false
  box_name     = "${var.box_name}"
  communicator = "ssh"
  insert_key   = true
  output_dir   = "${var.output_directory}/pre-install-toolkit-vagrant"
  provider     = "${var.vagrant_provider}"
  skip_add     = true
  source_path  = "${var.source_box_uri}"
  template     = "./scripts/vagrant/Vagrantfile"
}

# Not built by CI/CD; local-build-only.
# Intention: VirtualBox emulator for metal artifacts.
source "virtualbox-ovf" "pre-install-toolkit" {
  source_path      = "${var.vbox_source_path}"
  format           = "${var.vbox_format}"
  checksum         = "none"
  headless         = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|/sbin/halt -h -p"
  ssh_password     = "${var.ssh_password}"
  ssh_username     = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}/pre-install-toolkit-virtualbox-ovf"
  output_filename  = "${var.image_name_pit}"
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
    "source.googlecompute.pre-install-toolkit",
    "source.qemu.pre-install-toolkit",
    "source.vagrant.pre-install-toolkit",
    "source.virtualbox-ovf.pre-install-toolkit"
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
    environment_vars = [
      "PIT_SLUG=${var.pit_slug}"
    ]
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/common/setup.sh"
  }

  provisioner "shell" {
    environment_vars = [
      "PIT_SLUG=${var.pit_slug}"
    ]
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/${source.name}/provisioners/common/setup.sh"
  }

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
      "rpm --import https://arti.dev.cray.com/artifactory/dst-misc-stable-local/SigningKeys/HPE-SHASTA-RPM-PROD.asc"
    ]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.packages explicit'",
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.deps.packages deps'"
    ]
    only = ["qemu.pre-install-toolkit", "virtualbox-ovf.pre-install-toolkit"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-pre-install-toolkit/base.packages'"
    ]
    valid_exit_codes = [0, 123]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-pre-install-toolkit/metal.packages'"
    ]
    valid_exit_codes = [0, 123]
    only             = ["qemu.pre-install-toolkit", "virtualbox-ovf.pre-install-toolkit"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/${source.name}/provisioners/common/install.sh"
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.packages explicit'",
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.deps.packages deps'",
      "zypper lr -e /tmp/installed.repos"
    ]
    only = ["qemu.pre-install-toolkit", "virtualbox-ovf.pre-install-toolkit"]
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
    only = ["qemu.pre-install-toolkit", "virtualbox-ovf.pre-install-toolkit"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/oval-results.xml"
    destination = "${var.output_directory}/${source.name}-${source.type}/oval-results-${source.type}.${source.name}.xml"
    only = ["qemu.pre-install-toolkit", "virtualbox-ovf.pre-install-toolkit"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/oval-patch-results.xml"
    destination = "${var.output_directory}/${source.name}-${source.type}/oval-patch-results-${source.type}.${source.name}.xml"
    only = ["qemu.pre-install-toolkit", "virtualbox-ovf.pre-install-toolkit"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/oval-report.html"
    destination = "${var.output_directory}/${source.name}-${source.type}/oval-report-${source.type}.${source.name}.html"
    only = ["qemu.pre-install-toolkit", "virtualbox-ovf.pre-install-toolkit"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/oval-patch-report.html"
    destination = "${var.output_directory}/${source.name}-${source.type}/oval-patch-report-${source.type}.${source.name}.html"
    only = ["qemu.pre-install-toolkit", "virtualbox-ovf.pre-install-toolkit"]
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
    only        = ["qemu.pre-install-toolkit", "virtualbox-ovf.pre-install-toolkit"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/common/cleanup.sh"
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/google/cleanup.sh"
    only            = ["googlecompute.pre-install-toolkit"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    script          = "${path.root}/provisioners/metal/cleanup.sh"
    only            = ["qemu.pre-install-toolkit", "virtualbox-ovf.pre-install-toolkit"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-all-repos'"
    ]
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
    only = ["googlecompute.pre-install-toolkit"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = [
      "goss -g /srv/cray/tests/metal/ncn-common-tests.yml validate -f junit | tee /tmp/goss_${source.name}_ncn_metal_out.xml"
    ]
    only = ["qemu.pre-install-toolkit", "virtualbox-ovf.pre-install-toolkit"]
  }

  provisioner "shell" {
    execute_command = "sudo bash -c '{{ .Vars }} {{ .Path }}'"
    inline          = ["chage -d 0 root"]
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
    only        = ["googlecompute.pre-install-toolkit"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/goss_${source.name}_ncn_metal_out.xml"
    destination = "${var.output_directory}/${source.name}-${source.type}/test-results-${source.type}.${source.name}-ncn-metal.xml"
    only        = ["qemu.pre-install-toolkit", "virtualbox-ovf.pre-install-toolkit"]
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
      only = ["googlecompute.pre-install-toolkit"]
    }

    post-processor "shell-local" {
      inline = [
        "if ! grep ' failures=.0. ' ${var.output_directory}/${source.name}-${source.type}/test-results-${source.type}.${source.name}-ncn-metal.xml; then echo >&2 'Error: goss test failures found! See build output for details'; exit 1; fi"
      ]
      only = ["qemu.pre-install-toolkit", "virtualbox-ovf.pre-install-toolkit"]
    }

    post-processor "shell-local" {
      # Packer will always make a package.box file from its vagrant builder (https://github.com/hashicorp/packer-plugin-vagrant/issues/16).
      # This renames package.box to ${var.image_name}.box.
      inline = [
        "mv -v ${var.output_directory}/${source.name}-${source.type}/package.box ${var.output_directory}/${source.name}-${source.type}/${var.image_name_pit}.box",
        "ls -l ${var.output_directory}/${source.name}-${source.type}/"
      ]
      only = ["vagrant.pre-install-toolkit"]
    }
  }
}
