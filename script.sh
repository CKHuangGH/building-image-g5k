# Update the package index and upgrade installed packages.
apt-get update
apt-get upgrade -y


# Install basic utilities used during installation and troubleshooting.
apt-get install -y \
  wget \
  git \
  net-tools \
  jq

# Kubernetes normally expects swap to be disabled.
# Disable it now and prevent it from being enabled again after reboot.
swapoff -a

sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab


# Install packages required to access HTTPS repositories
# and manage repository signing keys.
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release


# Add the Kubernetes v1.37 package repository.
# Kubernetes uses a separate package repository for each minor release.
mkdir -p /etc/apt/keyrings

curl -fsSL \
  https://pkgs.k8s.io/core:/stable:/v1.37/deb/Release.key \
  | gpg --dearmor \
  -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.37/deb/ /' \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update


# Install the Kubernetes node components.
#
# kubelet:
#   Runs on every node and manages Pods on that node.
#
# kubeadm:
#   Initializes the control plane and joins nodes to the cluster.
#
# kubectl:
#   Command-line client used to communicate with the Kubernetes API.
apt-get install -y \
  kubelet=1.37.1-1.1 \
  kubeadm=1.37.1-1.1 \
  kubectl=1.37.1-1.1


# Prevent normal package upgrades from unexpectedly changing
# the Kubernetes version.
apt-mark hold kubelet kubeadm kubectl


# Enable kubelet at boot.
# kubelet may restart until kubeadm initializes or joins the node.
systemctl enable --now kubelet

# Install runc.
#
# containerd manages containers at a higher level,
# while runc is the OCI runtime that creates and starts
# the actual Linux containers.
wget \
  https://github.com/opencontainers/runc/releases/download/v1.5.2/runc.amd64

install -m 755 runc.amd64 /usr/local/sbin/runc

# Download and install containerd.
#
# kubelet communicates with containerd through the
# Container Runtime Interface (CRI).
wget \
  https://github.com/containerd/containerd/releases/download/v2.4.2/containerd-2.4.2-linux-amd64.tar.gz

tar xvf containerd-2.4.2-linux-amd64.tar.gz

cp bin/* /usr/local/bin/



# Generate the default containerd configuration.
mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml


# kubeadm configures kubelet to use the systemd cgroup driver.
# Configure containerd to use the same cgroup driver.
sed -i \
  's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml


# Create the systemd service for containerd.
cat <<EOF > /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target dbus.service

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity

# Comment out TasksMax if your systemd version does not support it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd after adding the containerd service.
systemctl daemon-reload


# Start containerd now and automatically after reboot.
systemctl enable --now containerd

# Configure Linux networking for Kubernetes.
#
# IPv4 forwarding allows packets to be forwarded between
# network interfaces, which is required by most Kubernetes
# cluster networking implementations.
cat <<EOF > /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

sysctl --system


# Install Helm.
#
# Helm is not required by kubeadm itself, but will be used later
# to install Kubernetes applications and add-ons.
wget \
  https://get.helm.sh/helm-v4.3.1-linux-amd64.tar.gz

tar -zxvf helm-v4.3.1-linux-amd64.tar.gz

mv linux-amd64/helm /usr/local/bin/helm

rm -rf linux-amd64/
rm -f helm-v4.3.1-linux-amd64.tar.gz


# Check the installed versions.
containerd --version
runc --version
kubelet --version
kubeadm version
kubectl version --client
helm version


# Verify that containerd is running.
systemctl status containerd --no-pager


# Remove downloaded installation files.
rm -rf bin
rm -f containerd-2.4.2-linux-amd64.tar.gz
rm -f runc.amd64