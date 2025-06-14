#!/bin/bash

# Enable strict error handling
set -euo pipefail

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a /var/log/user-data.log
}

log "Starting Free5GC EKS node initialization for cluster: ${cluster_name}"
log "Region: ${region}"

# Set up HugePages
log "Configuring HugePages..."
if grep -q "hugepages" /etc/default/grub; then
    log "HugePages already configured in GRUB"
else
    sudo sed -i 's/selinux=1/& default_hugepagesz=1GB hugepagesz=1G hugepages=32/g' /etc/default/grub || {
        log "ERROR: Failed to configure HugePages in GRUB"
        exit 1
    }
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg || {
        log "ERROR: Failed to update GRUB configuration"
        exit 1
    }
fi

# Configure HugePages via sysctl
log "Setting up HugePages via sysctl..."
if ! grep -q "vm.nr_hugepages=32" /etc/sysctl.conf; then
    echo "vm.nr_hugepages=32" >> /etc/sysctl.conf
fi
sysctl -w vm.nr_hugepages=32 || log "WARNING: Failed to set hugepages immediately"

# Install required packages
log "Installing required packages..."
yum update -y || {
    log "ERROR: Failed to update packages"
    exit 1
}

yum install -y lshw net-tools tcpdump vim iperf3 ethtool git jq || {
    log "ERROR: Failed to install required packages"
    exit 1
}

# Create script to set up Multus interfaces
log "Creating SR-IOV virtual function setup script..."
cat << 'EOF' > /bin/create-virtual-function.sh
#!/bin/bash
set -euo pipefail

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a /var/log/sriov-setup.log
}

log "Starting SR-IOV virtual function setup..."

# Ensure jq is available
if ! command -v jq &> /dev/null; then
    log "ERROR: jq is not installed"
    exit 1
fi

# Ensure lshw is available
if ! command -v lshw &> /dev/null; then
    yum install -y lshw || {
        log "ERROR: Failed to install lshw"
        exit 1
    }
fi

# Get Mellanox ConnectX-7 interfaces
INTERFACES=$(lshw -class network -json 2>/dev/null | jq -r '.[] | select(.product=="MT2910 Family [ConnectX-7]").logicalname // empty' 2>/dev/null || echo "")

if [ -z "$INTERFACES" ]; then
    log "WARNING: No Mellanox ConnectX-7 interfaces found"
    exit 0
fi

# Maximum NUMBER_VFS for Mellanox CX-7 is 127
NUMBER_VFS=10

for interface in $INTERFACES; do
    if [ -n "$interface" ] && [ -d "/sys/class/net/$interface" ]; then
        log "Setting up Virtual Functions for interface: $interface"
        
        # Bring interface up
        ip link set "$interface" up || {
            log "WARNING: Failed to bring up interface $interface"
            continue
        }
        
        # Check if SR-IOV is supported
        if [ ! -f "/sys/class/net/$interface/device/sriov_numvfs" ]; then
            log "WARNING: SR-IOV not supported on interface $interface"
            continue
        fi
        
        # Set number of VFs
        echo "$NUMBER_VFS" > "/sys/class/net/$interface/device/sriov_numvfs" || {
            log "ERROR: Failed to create VFs for interface $interface"
            continue
        }
        
        log "Successfully created $NUMBER_VFS VFs for interface $interface"
    else
        log "WARNING: Interface $interface not found or invalid"
    fi
done

log "SR-IOV virtual function setup completed"
EOF

chmod +x /bin/create-virtual-function.sh || {
    log "ERROR: Failed to make SR-IOV script executable"
    exit 1
}

# Create systemd service to ensure VFs are created on boot
log "Creating systemd service for SR-IOV setup..."
cat << 'EOF' > /etc/systemd/system/createvf.service
[Unit]
Description=Create Virtual Functions for SR-IOV
After=network.target
Wants=network.target

[Service]
Type=oneshot
ExecStart=/bin/create-virtual-function.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
log "Enabling and starting SR-IOV service..."
systemctl daemon-reload || {
    log "ERROR: Failed to reload systemd daemon"
    exit 1
}

systemctl enable createvf.service || {
    log "ERROR: Failed to enable createvf service"
    exit 1
}

systemctl start createvf.service || {
    log "WARNING: Failed to start createvf service immediately"
}

# Set kubelet extra args for CPU manager policy
log "Configuring kubelet CPU manager policy..."
mkdir -p /etc/eks/kubelet
echo 'KUBELET_EXTRA_ARGS="--cpu-manager-policy=static"' > /etc/eks/kubelet/kubelet-extra-args || {
    log "ERROR: Failed to configure kubelet extra args"
    exit 1
}

# Load GTP kernel module
log "Loading GTP kernel module..."
if ! modprobe gtp; then
    log "WARNING: Failed to load GTP kernel module"
else
    log "GTP kernel module loaded successfully"
fi

# Ensure GTP module is loaded on boot
log "Configuring GTP module to load on boot..."
echo "gtp" > /etc/modules-load.d/gtp.conf || {
    log "WARNING: Failed to configure GTP module for boot loading"
}

# Configure Multus networking (using template variables)
log "Configuring Multus networking..."
log "Multus subnet IDs: ${multus_subnet_ids}"
log "Multus security group ID: ${multus_sg_id}"

# Create a configuration file for Multus setup
cat << EOF > /etc/free5gc-multus-config.json
{
    "cluster_name": "${cluster_name}",
    "region": "${region}",
    "multus_subnet_ids": "${multus_subnet_ids}",
    "multus_sg_id": "${multus_sg_id}"
}
EOF

log "Free5GC EKS node initialization completed successfully"
log "Node is ready for Free5GC workloads with Multus networking support"

# Signal completion
touch /var/log/user-data-completed
