# !!! change the below IPs to your VMs public IPs. !!!
# ssh-keygen -t rsa to all nodes will be convenient
Master_NODE_IPS=(39.101.166.22 39.98.114.92 39.101.182.149)
#WORKER_NODE_IPS=(39.105.193.128 39.105.183.241 39.106.16.18)
WORKER_NODE_IPS=(39.105.183.241 39.106.16.18)

UBlue='\033[4;34m'      
Color_Off='\033[0m'

echoInfo(){   
   [ -n "$1" ] && echo -e "---> ${UBlue} $1 ${Color_Off}" && echo
}

download_and_distribute_kubernetes_binary(){
   mkdir -p /opt/k8s/work/cluster
  
   if [ -f /opt/k8s/work/cluster/kubernetes-server-linux-amd64.tar.gz ];then 
      echoInfo "kubernetes-server-linux-amd64.tar.gz already exists, skip downloading"
   else
      echoInfo "download kubernetes-server-linux-amd64.tar.gz v16.6"
      wget -P /opt/k8s/work/cluster https://dl.k8s.io/v1.16.6/kubernetes-server-linux-amd64.tar.gz
   fi

   if [ -d /opt/k8s/work/cluster/kubernetes ];then 
      echoInfo "kubernetes directory already exists, skip taping kubernetes-server-linux-amd64.tar.gz"
   else
      echoInfo "taping archive kubernetes-server-linux-amd64.tar.gz v16.6"
      tar -xzvf /opt/k8s/work/cluster/kubernetes-server-linux-amd64.tar.gz -C /opt/k8s/work/cluster/
   fi

   if [ -d /opt/k8s/work/cluster/kubernetes/plugin ];then 
      echoInfo "plugin directory already exists, skip taping kubernetes-src.tar.gz"
   else
      echoInfo "taping archive kubernetes-src.tar.gz"
      tar -xzvf  /opt/k8s/work/cluster/kubernetes/kubernetes-src.tar.gz -C /opt/k8s/work/cluster/kubernetes/
   fi

   # for node_ip in ${Master_NODE_IPS[@]}
   # do
   #    # GF:Q - does master node needs kubelet or kube-proxy ??
   #    # GF:Q - what does mounter do ??
   #    echoInfo "scp apiextensions-apiserver,kube-apiserver,kube-controller-manager,kube-scheduler,kubeadm,kubectl,mounter ----> master node:${node_ip}"
   #    ssh root@${node_ip} "mkdir -p /opt/k8s/bin/"
   #    scp /opt/k8s/work/cluster/kubernetes/server/bin/{apiextensions-apiserver,kube-apiserver,kube-controller-manager,kube-scheduler,kubeadm,kubectl,mounter} root@${node_ip}:/opt/k8s/bin/
   #    ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
   # done

   for node_ip in ${WORKER_NODE_IPS[@]}
   do
      echoInfo "scp kubelet,kube-proxy,kubeadm,kubectl ----> ${node_ip}"
      ssh root@${node_ip} "mkdir -p /opt/k8s/bin/"
      scp /opt/k8s/work/cluster/kubernetes/server/bin/{kubelet,kube-proxy,kubeadm,kubectl} root@${node_ip}:/opt/k8s/bin/
      ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
   done
}

download_and_distribute_kubernetes_binary