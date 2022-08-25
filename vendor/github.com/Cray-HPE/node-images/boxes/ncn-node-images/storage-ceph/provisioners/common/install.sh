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

set -ex

ansible_version='2.9.21'

# usage: cmd_retry <cmd> <arg1> ...
#
# Run the specified command until it passes or until it fails too many times
function cmd_retry
{
    local -i attempt
    # For now I'm hard coding these values, but it would be easy to make them into function
    # arguments in the future, if desired
    local -i max_attempts=10
    local -i sleep_time=12
    attempt=1
    while [ true ]; do
        # We redirect to stderr just in case the output of this command is being piped
        echo "Attempt #$attempt to run: $*" 1>&2
        if "$@" ; then
            return 0
        elif [ $attempt -lt $max_attempts ]; then
           echo "Sleeping ${sleep_time} seconds before retry" 1>&2
           sleep ${sleep_time}
           attempt=$(($attempt + 1))
           continue
        fi
        echo "ERROR: Unable to get $url even after retries" 1>&2
        return 1
    done
    echo "PROGRAMMING LOGIC ERROR: This line should never be reached" 1>&2
    exit 1
}

mkdir -p /etc/kubernetes
echo "export KUBECONFIG=\"/etc/kubernetes/admin.conf\"" >> /etc/profile.d/cray.sh

echo "Moving ceph operations files into place"
mkdir -p /srv/cray/tmp
mkdir -p /srv/cray/tmp/storage_classes

echo "Creating directory for caching podman images"
image_dir="/srv/cray/resources/common/images/"
mkdir -p $image_dir

sed  '/pull_policy/s/^# //' -i /usr/share/containers/containers.conf

cat > /etc/systemd/system/registry.container.service <<'EOF'
[Unit]
Description=Container Registry

[Service]
Restart=always
ExecStart=/usr/bin/podman start -a registry
ExecStop=/usr/bin/podman stop -t2 registry
RestartSec=30s
TimeoutStartSec=120
TimeoutStopSec=120
StartLimitInterval=30min
StartLimitBurst=5
ExecStartPre=/usr/bin/podman create --replace --privileged  --name registry -p 5000:5000 -v /var/lib/registry:/var/lib/registry --restart=always registry:2.8.1

[Install]
WantedBy=default.target

EOF

cat > /etc/containers/registries.conf <<'EOF'
# For more information on this configuration file, see containers-registries.conf(5).
#
# Registries to search for images that are not fully-qualified.
# i.e. foobar.com/my_image:latest vs my_image:latest
[registries.search]
registries = []
unqualified-search-registries = ["registry.local", "localhost"]

# Registries that do not use TLS when pulling images or uses self-signed
# certificates.
[registries.insecure]
registries = []
unqualified-search-registries = ["localhost", "registry.local"]

# Blocked Registries, blocks the  from pulling from the blocked registry.  If you specify
# "*", then the docker daemon will only be allowed to pull from registries listed above in the search
# registries.  Blocked Registries is deprecated because other container runtimes and tools will not use it.
# It is recommended that you use the trust policy file /etc/containers/policy.json to control which
# registries you want to allow users to pull and push from.  policy.json gives greater flexibility, and
# supports all container runtimes and tools including the docker daemon, cri-o, buildah ...
[registries.block]
registries = []

## ADD BELOW
[[registry]]
prefix = "registry.local"
location = "registry.local"
insecure = true

[[registry.mirror]]
prefix = "registry.local"
location = "localhost:5000"
insecure = true

[[registry]]
prefix = "localhost"
location = "localhost:5000"
insecure = true

[[registry]]
prefix = "localhost/quay.io"
location = "localhost:5000"
insecure = true

[[registry]]
prefix = "artifactory.algol60.net/csm-docker/stable"
location = "artifactory.algol60.net/csm-docker/stable"
insecure = true

[[registry.mirror]]
prefix = "artifactory.algol60.net/csm-docker/stable"
location = "localhost:5000"
insecure = true

[[registry]]
prefix = "artifactory.algol60.net/csm-docker/stable/quay.io"
location = "artifactory.algol60.net/csm-docker/stable/quay.io"
insecure = true

[[registry.mirror]]
prefix = "artifactory.algol60.net/csm-docker/stable/quay.io"
location = "localhost:5000"
insecure = true

[[registry]]
location = "docker.io"
insecure = true

EOF

mkdir -p /var/lib/registry
systemctl disable registry.container.service

echo "Pulling the ceph container image"
systemctl start podman

# Note to clean this up.  CASMINST-2148
ceph_current="$(rpm -q --queryformat '%{VERSION}' cephadm | awk -F '.' '{print $1"."$2"."$3}')"
cmd_retry podman pull artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v${ceph_current}
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v${ceph_current} registry.local/ceph/ceph:v${ceph_current}
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v${ceph_current} registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v${ceph_current}
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v${ceph_current}
cmd_retry podman pull artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v16.2.7
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v16.2.7 registry.local/ceph/ceph:v16.2.7
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v16.2.7 registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v16.2.7
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v16.2.7
cmd_retry podman pull artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15 registry.local/ceph/ceph:v15.2.15
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15 registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.15
cmd_retry podman pull artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.16
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.16 registry.local/ceph/ceph:v15.2.16
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.16 registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.16
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph:v15.2.16
cmd_retry podman pull artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.20.0
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.20.0 registry.local/prometheus/alertmanager:v0.20.0
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.20.0
cmd_retry podman pull artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.21.0
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.21.0 registry.local/prometheus/alertmanager:v0.21.0
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/alertmanager:v0.21.0
cmd_retry podman pull artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/node-exporter:v1.2.2
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/node-exporter:v1.2.2 registry.local/prometheus/node-exporter:v1.2.2
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/node-exporter:v1.2.2 registry.local/quay.io/prometheus/node-exporter:v1.2.2
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/prometheus/node-exporter:v1.2.2
cmd_retry podman pull artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph-grafana:8.3.5
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph-grafana:8.3.5 registry.local/ceph/ceph-grafana:8.3.5
podman tag  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph-grafana:8.3.5 registry.local/artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph-grafana:8.3.5
podman rmi  artifactory.algol60.net/csm-docker/stable/quay.io/ceph/ceph-grafana:8.3.5
cmd_retry podman pull artifactory.algol60.net/csm-docker/stable/ceph/ceph-grafana:6.7.4
podman tag  artifactory.algol60.net/csm-docker/stable/ceph/ceph-grafana:6.7.4 registry.local/ceph/ceph-grafana:6.7.4
podman rmi  artifactory.algol60.net/csm-docker/stable/ceph/ceph-grafana:6.7.4
cmd_retry podman pull artifactory.algol60.net/csm-docker/stable/prometheus:v2.18.1
podman tag  artifactory.algol60.net/csm-docker/stable/prometheus:v2.18.1 registry.local/prometheus/prometheus:v2.18.1
podman tag  artifactory.algol60.net/csm-docker/stable/prometheus:v2.18.1 registry.local/quay.io/prometheus/prometheus:v2.18.1
podman rmi  artifactory.algol60.net/csm-docker/stable/prometheus:v2.18.1
cmd_retry podman pull artifactory.algol60.net/csm-docker/stable/docker.io/registry:2.8.1
podman tag  artifactory.algol60.net/csm-docker/stable/docker.io/registry:2.8.1 localhost/registry:2.8.1

echo "Image pull complete"

echo "Saving ceph image to tar file as backup"
# Commenting out for troubleshooting.  will do a manual save per image for now.
#for image in $(podman images --format "{{.Repository}}")
# do
#  read -r name vers <<<$(podman images --format "{{.Repository}} {{.Tag}}" $image|grep registry)
#  read -r image_name <<<$(echo "$name"|awk -F"/" '{print $NF}')
#  echo "saving image $image_dir$image_name $vers"
#  podman save $name":"$vers -o "$image_dir$image_name"_$vers".tar"
# done

podman save registry.local/ceph/ceph:v${ceph_current} -o /srv/cray/resources/common/images/ceph_v${ceph_current}.tar
podman save registry.local/ceph/ceph:v16.2.7 -o /srv/cray/resources/common/images/ceph_v16.2.7.tar
podman save registry.local/ceph/ceph:v15.2.15 -o /srv/cray/resources/common/images/ceph_v15.2.15.tar
podman save registry.local/ceph/ceph:v15.2.16 -o /srv/cray/resources/common/images/ceph_v15.2.16.tar
podman save registry.local/prometheus/alertmanager:v0.20.0 -o /srv/cray/resources/common/images/alertmanager_v0.20.0.tar
podman save registry.local/prometheus/alertmanager:v0.21.0 -o /srv/cray/resources/common/images/alertmanager_v0.21.0.tar
podman save registry.local/prometheus/node-exporter:v1.2.2 -o /srv/cray/resources/common/images/node-exporter_v1.2.2.tar
podman save registry.local/ceph/ceph-grafana:8.3.5 -o /srv/cray/resources/common/images/ceph-grafana_8.3.5.tar
podman save registry.local/ceph/ceph-grafana:6.7.4 -o /srv/cray/resources/common/images/ceph-grafana_6.7.4.tar
podman save registry.local/prometheus/prometheus:v2.18.1 -o /srv/cray/resources/common/images/prometheus_v2.18.1.tar
podman save localhost/registry:2.8.1 -o /srv/cray/resources/common/images/registry_2.8.1.tar

podman rmi --all
# We may want to put a check in here for the files.

echo "Images have been saved for re-import post build"

echo "Stopping podman"
systemctl stop podman
systemctl disable podman

echo "Disabling spire-agent.service"
systemctl disable spire-agent.service && systemctl stop spire-agent.service
