#!/bin/bash

# Set up HugePages
sudo sed -i 's/selinux=1/& default_hugepagesz=1GB hugepagesz=1G hugepages=32/g' /etc/default/grub
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# Configure HugePages via sysctl
echo "vm.nr_hugepages=32" >> /etc/sysctl.conf
sysctl -w vm.nr_hugepages=32

# Install required packages
yum update -y
yum install -y lshw net-tools tcpdump vim iperf3 ethtool git

# Create script to set up Multus interfaces
cat << 'EOF' > /bin/create-virtual-function.sh
#!/bin/bash
yum install -y lshw

INTERFACES=$(lshw -class network -json | jq '.[] | select(.product=="MT2910 Family [ConnectX-7]").logicalname' | tr -d '"')
# max NUMBER_VFS for Mellanox CX-7 is 127
NUMBER_VFS=10

for interface in ${INTERFACES[@]}
do
    echo Updating Virtual Functions for interface: ${interface}
    echo ifconfig ${interface} up
    echo ${NUMBER_VFS} > /sys/class/net/${interface}/device/sriov_numvfs
done
EOF

chmod +x /bin/create-virtual-function.sh

# Create systemd service to ensure VFs are created on boot
cat << 'EOF' > /etc/systemd/system/createvf.service
[Unit]
Description=Create Virtual Functions for SR-IOV
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/create-virtual-function.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable createvf.service
systemctl start createvf.service

# Set kubelet extra args for CPU manager policy
echo 'KUBELET_EXTRA_ARGS="--cpu-manager-policy=static"' > /etc/eks/kubelet/kubelet-extra-args

# Load GTP kernel module
modprobe gtp

# Ensure GTP module is loaded on boot
echo "gtp" > /etc/modules-load.d/gtp.conf

# Set up Multus ENIs
# This will be handled by the Multus CNI plugin and SRIOV device plugin after cluster setup
