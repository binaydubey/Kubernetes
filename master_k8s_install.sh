echo "######### This script will install Kubernetes #############"
echo "############### This Script Will Install Kubernetes Master ###########"
sleep 5 
echo "Please Enter the Master IP Address"
read mip
echo "$mip      master" | sudo tee -a /etc/hosts

###Enable br_netfilter kernel module
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo sysctl --system

###Disable Swap 
sudo swapoff -a
###remove swap entry from /etc/fstab
sudo sed -i '/swap/d' /etc/fstab

###Install containerd runtime 
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install containerd.io -y
sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo systemctl status containerd &> /dev/null

#1. Update the apt package index and install packages needed to use the Kubernetes apt repository:

sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

#2. Download the public signing key
# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg


#3 Add the appropriate Kubernetes apt repository.
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list


#4.Update the apt package index, install kubelet, kubeadm and kubectl, and pin their version:
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

#5. Enable the kubelet service before running kubeadm:
sudo systemctl enable --now kubelet

echo "#######Installation completed successfully #####"
echo "#### Performing Master Specific Configuration ########"
sleep 5

echo "######Start cluster initialization on master node#####"
sudo kubeadm init --pod-network-cidr=10.244.0.0/16  --apiserver-advertise-address=$mip
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
sleep 5
echo "#########Installing the Flannel Network Add-on#############"
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
echo "######### Installation completed Successfully ###########"
echo "############ WAIT FOR PODS to GET READY #############"
sleep 30
kubectl get pods --all-namespaces
kubeadm token create --print-join-command > kube-join.txt
sleep 5
echo "A kube-join.txt file is created in the current directory. This contains Join token for the node."
echo "Execute this join token on node after running node installation Script"
echo "############Installation Finished#################"
