#!/bin/bash

##############################################################################
#Author: Koushik                                                             #
#Date: 26-10-2026                                                            #
#Description: This script is for installing the "kubernetes the kubeadm way".#
##############################################################################

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="/home/ubuntu/setup_${TIMESTAMP}.log"

# 1. Open File Descriptor 3 to talk directly to the screen (stdout before redirection)
exec 3>&1

# 2. Redirect all future standard output and errors from this script into the logfile
exec >> "$LOGFILE" 2>&1

# Helper function to check execution status
# Call this immediately after any command you want to verify
check_step() {
    local exit_code=$? # Captures the status of the command that ran right before this function
    if [ $exit_code -eq 0 ]; then
        echo "Successful, proceeding to next step..." >&3
    else
        echo "❌ Step failed! Exiting script. Check $LOGFILE for details." >&3
        exit 1
    fi
}

echo "Starting the commands execution..." >&3

#Update apt packages
sudo apt-get update
check_step

#Load modules:
sudo modprobe overlay && sudo modprobe br_netfilter
check_step

#set system configuration for kubernetes networking:
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
check_step

#Apply new settings:
sudo sysctl --system
check_step

#Install containerd:
sudo apt-get update && sudo apt-get install -y containerd
check_step

#Create default configuration file for containerd:
sudo mkdir -p /etc/containerd
check_step

#Generate default containerd configuration and save to the newly created default file:
sudo containerd config default | sudo tee /etc/containerd/config.toml
check_step

#Restart containerd to ensure new configuration file usage:
sudo systemctl restart containerd
check_step

#Verify that containerd is running (optional)
sudo systemctl status containerd
check_step

#Disable swap:
sudo swapoff -a
check_step

#Install dependency packages:
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gpg
check_step

#Download the public signing key for the Kubernetes package repositories:
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
check_step

#Add the appropriate Kubernetes apt repository:
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
check_step

#Update package listings:
sudo apt-get update
check_step

#Install Kubernetes packages:
sudo apt-get install -y kubelet kubeadm kubectl kubernetes-cni nfs-common
check_step

#Turn off automatic updates:
sudo apt-mark hold kubelet kubeadm kubectl kubernetes-cni nfs-common
check_step

echo " All steps successfully executed! Cluster pre-requisites setup complete!..............." >&3

