source "googlecompute" "pit" {
  instance_name           = "vshasta-${var.image_name}-builder-${var.artifact_version}"
  project_id              = "${var.google_destination_project_id}"
  network_project_id      = "${var.google_network_project_id}"
  source_image_project_id = "${var.google_source_image_project_id}"
  source_image_family     = "${var.google_source_image_family}"
  source_image            = "${var.google_source_image_name}"
  service_account_email   = "${var.google_service_account_email}"
  ssh_username            = "root"
  zone                    = "${var.google_zone}"
  image_guest_os_features = "${var.image_guest_os_features}"
  image_family            = "${var.google_destination_image_family}"
  image_name              = "vshasta-${var.image_name}-${var.artifact_version}"
  image_description       = "build.source-artifact = ${var.google_source_image_url}, build.url = ${var.build_url}"
  machine_type            = "${var.google_machine_type}"
  subnetwork              = "${var.google_subnetwork}"
  disk_size               = "${var.google_disk_size_gb}"
  use_internal_ip         = "${var.google_use_internal_ip}"
  omit_external_ip        = "${var.google_use_internal_ip}"
}

source "qemu" "pit" {
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
  output_directory    = "${var.output_directory}"
  vnc_bind_address    = "${var.vnc_bind_address}"
  vm_name             = "${var.image_name}.${var.qemu_format}"
  format              = "${var.qemu_format}"
}

source "virtualbox-ovf" "pit" {
  source_path      = "${var.vbox_source_path}"
  format           = "${var.vbox_format}"
  checksum         = "none"
  headless         = "${var.headless}"
  shutdown_command = "echo '${var.ssh_password}'|/sbin/halt -h -p"
  ssh_password     = "${var.ssh_password}"
  ssh_username     = "${var.ssh_username}"
  ssh_wait_timeout = "${var.ssh_wait_timeout}"
  output_directory = "${var.output_directory}"
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
    "source.googlecompute.pit",
    "source.qemu.pit",
    "source.virtualbox-ovf.pit"
  ]

  provisioner "shell" {
    inline = [
      "mkdir -pv /srv/cray"
    ]
  }

  provisioner "file" {
    sources = [
      "./vendor/github.com/Cray-HPE/csm-rpms",
      "${path.root}/files/"
    ]
    destination = "/srv/cray"
  }

  // Setup each context (e.g. common, google, and metal)
  provisioner "shell" {
    environment_vars = [
      "PIT_SLUG=${var.pit_slug}"
    ]
    script = "${path.root}/provisioners/common/setup.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/google/setup.sh"
    only   = ["googlecompute.pit"]
  }

  # Placeholder: if/when Metal needs a setup.sh (e.g. actions before RPMs are installed).
  #  provisioner "shell" {
  #    script = "${path.root}/provisioners/metal/setup.sh"
  #    only = ["qemu.pit", "virtualbox-ovf.pit"]
  #  }

  provisioner "shell" {
    environment_vars = [
      "CUSTOM_REPOS_FILE=${var.custom_repos_file}",
      "ARTIFACTORY_USER=${var.artifactory_user}",
      "ARTIFACTORY_TOKEN=${var.artifactory_token}"
    ]
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; setup-package-repos'"
    ]
    valid_exit_codes = [0, 123]
  }

  provisioner "shell" {
    inline = [
      "bash -c 'rpm --import https://arti.dev.cray.com/artifactory/dst-misc-stable-local/SigningKeys/HPE-SHASTA-RPM-PROD.asc'"
    ]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.packages explicit'",
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/initial.deps.packages deps'"
    ]
    only = ["qemu.pit", "virtualbox-ovf.pit"]
  }

  // Install packages by context (e.g. base (a.k.a. common), google, or metal)
  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/cray-pre-install-toolkit/base.packages'"
    ]
    valid_exit_codes = [0, 123]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; install-packages /srv/cray/csm-rpms/packages/cray-pre-install-toolkit/metal.packages'"
    ]
    valid_exit_codes = [0, 123]
    only             = ["qemu.pit", "virtualbox-ovf.pit"]
  }

  // Install all generic installers first by context (e.g. common, google, and metal).
  provisioner "shell" {
    script = "${path.root}/provisioners/common/install.sh"
  }

  provisioner "shell" {
    script = "${path.root}/provisioners/metal/install.sh"
    only   = ["qemu.pit", "virtualbox-ovf.pit"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.packages explicit'",
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; get-current-package-list /tmp/installed.deps.packages deps'",
      "bash -c 'zypper lr -e /tmp/installed.repos'"
    ]
    only = ["qemu.pit", "virtualbox-ovf.pit"]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-package-repos'"
    ]
  }

  provisioner "shell" {
    inline = [
      "bash -c '. /srv/cray/csm-rpms/scripts/rpm-functions.sh; cleanup-all-repos'"
    ]
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
    destination = "${var.output_directory}/"
    only        = ["qemu.pit", "virtualbox-ovf.pit"]
  }

  provisioner "shell" {
    script = "${path.root}/files/scripts/common/cleanup.sh"
  }

  provisioner "shell" {
    inline = [
      "bash -c 'goss -g /srv/cray/tests/common/pit-tests.yml validate -f junit | tee /tmp/goss_${source.name}_out.xml'"
    ]
  }

  provisioner "shell" {
    inline = [
      "bash -c 'goss -g /srv/cray/tests/google/pit-tests.yml validate -f junit | tee /tmp/goss_${source.name}_google_out.xml'"
    ]
    only = ["googlecompute.pit"]
  }

  provisioner "shell" {
    inline = [
      "bash -c 'goss -g /srv/cray/tests/metal/pit-tests.yml validate -f junit | tee /tmp/goss_${source.name}_metal_out.xml'"
    ]
    only = ["qemu.pit", "virtualbox-ovf.pit"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/goss_${source.name}_out.xml"
    destination = "${var.output_directory}/test-results-${source.type}.${source.name}.xml"
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/goss_${source.name}_google_out.xml"
    destination = "${var.output_directory}/test-results-${source.type}.${source.name}-google.xml"
    only        = ["googlecompute.pit"]
  }

  provisioner "file" {
    direction   = "download"
    source      = "/tmp/goss_${source.name}_metal_out.xml"
    destination = "${var.output_directory}/test-results-${source.type}.${source.name}-metal.xml"
    only        = ["qemu.pit", "virtualbox-ovf.pit"]
  }

  post-processors {
    post-processor "shell-local" {
      inline = [
        "if ! grep ' failures=.0. ' ${var.output_directory}/test-results-${source.type}.${source.name}.xml; then echo >&2 'Error: goss test failures found! See build output for details'; exit 1; fi"
      ]
    }
    post-processor "shell-local" {
      inline = [
        "if ! grep ' failures=.0. ' ${var.output_directory}/test-results-${source.type}.${source.name}-google.xml; then echo >&2 'Error: goss test failures found! See build output for details'; exit 1; fi"
      ]
      only = ["googlecompute.pit"]
    }
    post-processor "shell-local" {
      inline = [
        "if ! grep ' failures=.0. ' ${var.output_directory}/test-results-${source.type}.${source.name}-metal.xml; then echo >&2 'Error: goss test failures found! See build output for details'; exit 1; fi"
      ]
      only = ["qemu.pit", "virtualbox-ovf.pit"]
    }
  }
}
