source "virtualbox-ovf" "application" {
  source_path = "${var.vbox_source_path}"
  format = "${var.vbox_format}"
  checksum = "none"
  headless = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|/sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}"
  output_filename = "${var.image_name}"
  vboxmanage = [
    [
      "modifyvm",
      "{{ .Name }}",
      "--memory",
      "${var.memory}"],
    [
      "modifyvm",
      "{{ .Name }}",
      "--cpus",
      "${var.cpus}"]
  ]
  virtualbox_version_file = ".vbox_version"
  guest_additions_mode = "disable"
}

source "qemu" "application" {
  accelerator = "${var.qemu_accelerator}"
  cpus = "${var.cpus}"
  disk_cache = "${var.disk_cache}"
  disk_discard = "unmap"
  disk_detect_zeroes = "unmap"
  disk_compression = "${var.qemu_disk_compression}"
  skip_compaction = "${var.qemu_skip_compaction}"
  disk_image = true
  disk_size = "${var.disk_size}"
  display = "${var.qemu_display}"
  use_default_display = "${var.qemu_default_display}"
  memory = "${var.memory}"
  headless = "${var.headless}"
  iso_checksum = "${var.source_iso_checksum}"
  iso_url = "${var.source_iso_uri}"
  shutdown_command = "echo '${var.ssh_password}'|/sbin/halt -h -p"
  ssh_password = "${var.ssh_password}"
  ssh_username = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}"
  vnc_bind_address = "${var.vnc_bind_address}"
  vm_name = "${var.image_name}.${var.qemu_format}"
  format = "${var.qemu_format}"
}

source "googlecompute" "application" {
  instance_name = "vshasta-${var.image_name}-builder-${var.artifact_version}"
  project_id = "${var.google_destination_project_id}"
  network_project_id = "${var.google_network_project_id}"
  source_image_project_id = "${var.google_source_image_project_id}"
  source_image_family = "${var.google_source_image_family}"
  source_image = "${var.google_source_image_name}"
  service_account_email = "${var.google_service_account_email}"
  ssh_username = "root"
  zone = "${var.google_zone}"
  image_family = "${var.google_destination_image_family}"
  image_name = "vshasta-${var.image_name}-${var.artifact_version}"
  image_description = "build.source-artifact = ${var.google_source_image_url}, build.url = ${var.build_url}"
  machine_type = "n2-standard-32"
  subnetwork = "${var.google_subnetwork}"
  disk_size = "${var.google_disk_size_gb}"
  use_internal_ip = "${var.google_use_internal_ip}"
  omit_external_ip = "${var.google_use_internal_ip}"
}

build {
  sources = [
    "source.virtualbox-ovf.application",
    "source.qemu.application",
    "source.googlecompute.application"]

  provisioner "file" {
    source = "${path.root}/files"
    destination = "/tmp/"
  }

  provisioner "file" {
    source = "vendor/github.com/Cray-HPE/node-images/vendor/github.com/Cray-HPE/csm-rpms"
    destination = "/tmp/files/"
  }

  provisioner "file" {
    source = "vendor/github.com/Cray-HPE/node-images/custom"
    destination = "/tmp/files/"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/setup.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/google/setup.sh"
    only = ["googlecompute.application"]
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/metal/setup.sh"
    only = [
      "qemu.application",
      "virtualbox-ovf.application"
    ]
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/disk_resize.sh"
  }

  provisioner "shell" {
    inline = [
      "bash -c 'rpm --import https://arti.dev.cray.com/artifactory/dst-misc-stable-local/SigningKeys/HPE-SHASTA-RPM-PROD.asc'"]
  }

  provisioner "shell" {
    environment_vars = [
      "CUSTOM_REPOS_FILE=${var.custom_repos_file}",
      "ARTIFACTORY_USER=${var.artifactory_user}",
      "ARTIFACTORY_TOKEN=${var.artifactory_token}"
    ]
    inline = ["bash -c /srv/cray/custom/repos.sh"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.packages explicit'",
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.deps.packages deps'"
    ]
    only = [
      "qemu.application",
      "virtualbox-ovf.application"
    ]
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/metal/hpc.sh"
    only = [
      "qemu.application",
      "virtualbox-ovf.application"
    ]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-non-compute-common/base.packages'"]
    valid_exit_codes = [0, 123]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-non-compute-common/metal.packages'"]
    valid_exit_codes = [0, 123]
    only = [
      "qemu.application",
      "virtualbox-ovf.application"
    ]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/node-image-non-compute-common/cms.packages'"]
    valid_exit_codes = [0, 123]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/application/application.packages'"]
    valid_exit_codes = [0, 123]
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/csm/ansible.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/python_symlink.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/cms/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/metal/install.sh"
    only = [
      "qemu.application",
      "virtualbox-ovf.application"
    ]
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/cos/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/cos/rsyslog.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/common/kernel/modules.sh"
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.packages explicit'",
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.deps.packages deps'",
      "bash -c 'zypper lr -e /tmp/installed.repos'"
    ]
    only = [
      "qemu.application",
      "virtualbox-ovf.application"
    ]
  }

  provisioner "file" {
    direction = "download"
    sources = [
      "/tmp/initial.deps.packages",
      "/tmp/initial.packages",
      "/tmp/installed.deps.packages",
      "/tmp/installed.packages"
    ]
    destination = "${var.output_directory}/"
    only = [
      "qemu.application",
      "virtualbox-ovf.application"
    ]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/installed.repos"
    destination = "${var.output_directory}/installed.repos"
    only = [
      "qemu.application",
      "virtualbox-ovf.application"
    ]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-package-repos'"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-all-repos'"]
  }

  provisioner "shell" {
    script = "${path.root}/files/scripts/common/cleanup.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/metal/cleanup.sh"
  }

  provisioner "shell" {
    inline = [
      "bash -c '/srv/cray/scripts/common/create-kis-artifacts.sh'"]
    only = ["qemu.application"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/kis.tar.gz"
    destination = "${var.output_directory}/"
    only = ["qemu.application"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '/srv/cray/scripts/common/cleanup-kis-artifacts.sh'"]
    only = ["qemu.application"]
  }

  provisioner "shell" {
    inline = [
      "bash -c 'goss -g /srv/cray/tests/common/goss-image-common.yaml validate -f junit | tee /tmp/goss_out.xml'"]
    only = [
      "qemu.application",
      "virtualbox-ovf.application"
    ]
  }

  provisioner "shell" {
    inline = [
      "bash -c 'goss -g /srv/cray/tests/metal/goss-image-common.yaml validate -f junit | tee /tmp/goss_metal_out.xml'"]
    only = [
      "qemu.application",
      "virtualbox-ovf.application"
    ]
  }

  provisioner "shell" {
    inline = [
      "bash -c 'goss -g /srv/cray/tests/google/goss-image-common.yaml validate -f junit | tee /tmp/goss_google_out.xml'"]
    only = ["googlecompute.application"]
  }

  provisioner "file" {
    direction = "download"
    source = "/tmp/goss_out.xml"
    destination = "${var.output_directory}/test-results.xml"
    only = [
      "qemu.application",
      "virtualbox-ovf.application"
    ]
  }

  post-processors {
    post-processor "shell-local" {
      inline = [
        "echo 'Extracting KIS artifacts package'",
        "echo 'Putting image name into the squashFS filename.'",
        "ls -lR ./${var.output_directory}",
        "tar -xzvf ${var.output_directory}/kis.tar.gz -C ${var.output_directory}",
        "rm ${var.output_directory}/kis.tar.gz"
      ]
      only   = ["qemu.application"]
    }
    post-processor "shell-local" {
      inline = [
        "if cat ${var.output_directory}/test-results.xml | grep '<failure>'; then echo 'Error: goss test failures found! See build output for details'; exit 1; fi"]
      only   = ["qemu.application"]
    }
  }
}
