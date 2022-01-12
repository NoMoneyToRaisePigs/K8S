NODE_IP=39.106.16.18
NODE_INTERNAL_IP=172.22.76.53
NODE_NAME=gf-worker-03
MASTER_NODE_IP=39.101.166.22


KUBE_APISERVER="https://39.101.166.22:6443"
CLUSTER_DNS_SVC_IP="10.254.0.2"
CLUSTER_DNS_DOMAIN="cluster.local"
CLUSTER_CIDR="172.30.0.0/16"
K8S_DIR="/data/k8s/k8s"


UBlue='\033[4;34m'      
URed='\033[4;31m'  
Color_Off='\033[0m'



echoInfo(){   
   [ -n "$1" ] && echo -e "---> ${UBlue} $1 ${Color_Off}" && echo
}

echoFailure(){   
   [ -n "$1" ] && echo -e "${URed} $1 ${Color_Off}" && echo
}

pre_check(){
   local HOSTNAME=$(hostname)
   [ "${HOSTNAME}" != "${NODE_NAME}" ] && echoFailure "variable NODE_NAME does not equal host name" && exit 1
}

install_docker(){

  echoInfo "---> installing Docker 19.03.15 ..."

  yum install -y yum-utils
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

  local Docker_Version="docker-ce-19.03.15"
  local Docker_Cli_Version="docker-ce-cli-19.03.15"
  local  Docker_Unit=$(systemctl list-unit-files | egrep "enabled" | egrep "docker")

  [ -n "$Docker_Unit" ] && echo "docker service exists, disable and remove current docker service" && systemctl stop docker && systemctl disable docker
  rpm -qa | egrep "docker" && echo "dockerd installed, remove current version" && yum remove docker-ce docker-ce-cli -y

  yum install "$Docker_Version" "$Docker_Cli_Version" -y || exit 1

  if [ $? -eq 0 ];then #is docker installed successfully
    systemctl daemon-reload && systemctl enable docker && systemctl start docker  && echo "docker 配置重载&服务启动成功&enabled"
  else
    echoFailure "docker install failed"
  fi
   
  local  Docker_Installed_Version=$(docker -v | awk '{print $3}')

  if [ "${Docker_Installed_Version%,*}" == "${Docker_Version#*ce-}" ];then
    echoInfo "---> docker insatlled with correct version !"
  else
    echoWarning "---> docker failure with incorrect version" && yum remove remove docker-ce docker-ce-cli
  fi
}

setup_kubectl(){
   echoInfo "setup kubectl"
   mkdir -p /opt/k8s/work/kubectl

   [ ! -f /opt/k8s/bin/kubectl ] && echoFailure "there is no kubectl binary in /opt/k8s/bin/" && exit 1
   [ ! -f /etc/kubernetes/cert/ca.pem ] && echoFailure "root CA needed" && exit 1
   [ ! -f /etc/kubernetes/cert/admin.pem ] && echoFailure "admin CA needed" && exit 1

   [ -f /opt/k8s/work/kubectl/kubectl.kubeconfig ] && echoInfo "remove existing kubectl.kubeconfig" && rm -rf /opt/k8s/work/kubectl/kubectl.kubeconfig
   
   echoInfo "create kubectl.kubeconfig"
   kubectl config set-cluster kubernetes \
      --certificate-authority=/etc/kubernetes/cert/ca.pem \
      --embed-certs=true \
      --server=https://${MASTER_NODE_IP}:6443 \
      --kubeconfig=/opt/k8s/work/kubectl/kubectl.kubeconfig

   kubectl config set-credentials admin \
      --client-certificate=/etc/kubernetes/cert/admin.pem \
      --client-key=/etc/kubernetes/cert/admin-key.pem \
      --embed-certs=true \
      --kubeconfig=/opt/k8s/work/kubectl/kubectl.kubeconfig

   kubectl config set-context kubernetes \
      --cluster=kubernetes \
      --user=admin \
      --kubeconfig=/opt/k8s/work/kubectl/kubectl.kubeconfig

   kubectl config use-context kubernetes \
      --kubeconfig=/opt/k8s/work/kubectl/kubectl.kubeconfig

   echoInfo "copy /opt/k8s/work/kubectl/kubectl.kubeconfig to /root/.kube/config"
   cp /opt/k8s/work/kubectl/kubectl.kubeconfig ~/.kube/config
}

setup_kubelet(){
  echoInfo "---> creating kubelet bootstrap config ..."
  mkdir -p /opt/k8s/work/kubelet/

  [ ! -f /opt/k8s/bin/kubelet ] && echoFailure "there is no kubelet binary in /opt/k8s/bin/" && exit 1
  [ ! -f /etc/kubernetes/cert/ca.pem ] && echoFailure "root CA needed" && exit 1

  [ -f /opt/k8s/work/kubelet/kubelet-bootstrap.kubeconfig ] && echoInfo "remove existing kubelet-bootstrap.kubeconfig" && rm -rf /opt/k8s/work/kubelet/kubelet-bootstrap.kubeconfig


  local BOOTSTRAP_TOKEN=$(kubeadm token create --description kubelet-bootstrap-token --groups system:bootstrappers:${NODE_NAME} --kubeconfig ~/.kube/config)

  kubectl config set-cluster kubernetes \
    --certificate-authority=/etc/kubernetes/cert/ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=/opt/k8s/work/kubelet/kubelet-bootstrap.kubeconfig

  kubectl config set-credentials kubelet-bootstrap \
    --token=${BOOTSTRAP_TOKEN} \
    --kubeconfig=/opt/k8s/work/kubelet/kubelet-bootstrap.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes \
    --user=kubelet-bootstrap \
    --kubeconfig=/opt/k8s/work/kubelet/kubelet-bootstrap.kubeconfig

  kubectl config use-context default \
    --kubeconfig=/opt/k8s/work/kubelet/kubelet-bootstrap.kubeconfig

  # kubeadm token list --kubeconfig ~/.kube/config

  scp /opt/k8s/work/kubelet/kubelet-bootstrap.kubeconfig /etc/kubernetes/kubelet-bootstrap.kubeconfig


  echoInfo "---> creating kubelet-config.yaml"

  cat > /opt/k8s/work/kubelet/kubelet-config.yaml <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: "${NODE_INTERNAL_IP}"
staticPodPath: ""
syncFrequency: 1m
fileCheckFrequency: 20s
httpCheckFrequency: 20s
staticPodURL: ""
port: 10250
readOnlyPort: 0
rotateCertificates: true
serverTLSBootstrap: true
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/etc/kubernetes/cert/ca.pem"
authorization:
  mode: Webhook
registryPullQPS: 0
registryBurst: 20
eventRecordQPS: 0
eventBurst: 20
enableDebuggingHandlers: true
enableContentionProfiling: true
healthzPort: 10248
healthzBindAddress: "${NODE_INTERNAL_IP}"
clusterDomain: "${CLUSTER_DNS_DOMAIN}"
clusterDNS:
  - "${CLUSTER_DNS_SVC_IP}"
nodeStatusUpdateFrequency: 10s
nodeStatusReportFrequency: 1m
imageMinimumGCAge: 2m
imageGCHighThresholdPercent: 85
imageGCLowThresholdPercent: 80
volumeStatsAggPeriod: 1m
kubeletCgroups: ""
systemCgroups: ""
cgroupRoot: ""
cgroupsPerQOS: true
cgroupDriver: cgroupfs
runtimeRequestTimeout: 10m
hairpinMode: promiscuous-bridge
maxPods: 220
podCIDR: "${CLUSTER_CIDR}"
podPidsLimit: -1
resolvConf: /etc/resolv.conf
maxOpenFiles: 1000000
kubeAPIQPS: 1000
kubeAPIBurst: 2000
serializeImagePulls: false
evictionHard:
  memory.available:  "100Mi"
  nodefs.available:  "10%"
  nodefs.inodesFree: "5%"
  imagefs.available: "15%"
evictionSoft: {}
enableControllerAttachDetach: true
failSwapOn: true
containerLogMaxSize: 20Mi
containerLogMaxFiles: 10
systemReserved: {}
kubeReserved: {}
systemReservedCgroup: ""
kubeReservedCgroup: ""
enforceNodeAllocatable: ["pods"]
EOF

  cp /opt/k8s/work/kubelet/kubelet-config.yaml /etc/kubernetes/kubelet-config.yaml



  echoInfo "---> creating kubelet systemd unit file"
  cat > /opt/k8s/work/kubelet/kubelet.service.template <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
WorkingDirectory=${K8S_DIR}/kubelet
ExecStart=/opt/k8s/bin/kubelet \\
  --bootstrap-kubeconfig=/etc/kubernetes/kubelet-bootstrap.kubeconfig \\
  --cert-dir=/etc/kubernetes/cert \\
  --root-dir=${K8S_DIR}/kubelet \\
  --kubeconfig=/etc/kubernetes/kubelet.kubeconfig \\
  --config=/etc/kubernetes/kubelet-config.yaml \\
  --hostname-override=${NODE_NAME} \\
  --image-pull-progress-deadline=15m \\
  --volume-plugin-dir=${K8S_DIR}/kubelet/kubelet-plugins/volume/exec/ \\
  --logtostderr=true \\
  --v=2
Restart=always
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF

  mkdir -p ${K8S_DIR}/kubelet

  cp /opt/k8s/work/kubelet/kubelet.service.template /etc/systemd/system/kubelet.service

  # echoInfo "creating clusterrolebinding for api server to access kubelet"
  # kubectl create clusterrolebinding kube-apiserver:kubelet-apis --clusterrole=system:kubelet-api-admin --user kubernetes-master

  # echoInfo "creating clusterrolebinding for CSR"
  # kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --group=system:bootstrappers

  # kubectl get csr | grep Pending | awk '{print $1}' | xargs kubectl certificate approve

  mkdir -p ${K8S_DIR}/kubelet/kubelet-plugins/volume/exec/
  # systemctl daemon-reload && systemctl enable kubelet && systemctl restart kubelet
}


setup_kube_proxy(){
  echoInfo "set up kube-proxy"
  mkdir -p /opt/k8s/work/kube-proxy/

  [ ! -f /opt/k8s/bin/kube-proxy ] && echoFailure "there is no kube-proxy binary in /opt/k8s/bin/" && exit 1
  [ ! -f /etc/kubernetes/cert/ca.pem ] && echoFailure "root CA needed" && exit 1
  [ ! -f /etc/kubernetes/cert/kube-proxy.pem ] && echoFailure "kube-proxy CA needed" && exit 1

  echoInfo "create kube-proxy.kubeconfig"
  [ -f /opt/k8s/work/kube-proxy/kube-proxy.kubeconfig ] && echoInfo "remove existing kube-proxy.kubeconfig" && rm -rf /opt/k8s/work/kube-proxy/kube-proxy.kubeconfig

  kubectl config set-cluster kubernetes \
    --certificate-authority=/etc/kubernetes/cert/ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=/opt/k8s/work/kube-proxy/kube-proxy.kubeconfig

  kubectl config set-credentials kube-proxy \
    --client-certificate=/etc/kubernetes/cert/kube-proxy.pem \
    --client-key=/etc/kubernetes/cert/kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=/opt/k8s/work/kube-proxy/kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes \
    --user=kube-proxy \
    --kubeconfig=/opt/k8s/work/kube-proxy/kube-proxy.kubeconfig

  kubectl config use-context default \
    --kubeconfig=/opt/k8s/work/kube-proxy/kube-proxy.kubeconfig

  cp /opt/k8s/work/kube-proxy/kube-proxy.kubeconfig /etc/kubernetes/

  echoInfo "create kube-proxy-config.yaml"

  cat > /opt/k8s/work/kube-proxy/kube-proxy-config.yaml <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  burst: 200
  kubeconfig: "/etc/kubernetes/kube-proxy.kubeconfig"
  qps: 100
bindAddress: ${NODE_INTERNAL_IP}
healthzBindAddress: ${NODE_INTERNAL_IP}:10256
metricsBindAddress: ${NODE_INTERNAL_IP}:10249
enableProfiling: true
clusterCIDR: ${CLUSTER_CIDR}
hostnameOverride: ${NODE_NAME}
mode: "ipvs"
portRange: ""
iptables:
  masqueradeAll: false
ipvs:
  scheduler: rr
  excludeCIDRs: []
EOF

  cp /opt/k8s/work/kube-proxy/kube-proxy-config.yaml /etc/kubernetes/kube-proxy-config.yaml


  echoInfo "create kube-proxy systemd unit file"
  cat > /opt/k8s/work/kube-proxy/kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
WorkingDirectory=${K8S_DIR}/kube-proxy
ExecStart=/opt/k8s/bin/kube-proxy \\
  --config=/etc/kubernetes/kube-proxy-config.yaml \\
  --logtostderr=true \\
  --v=2
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  cp /opt/k8s/work/kube-proxy/kube-proxy.service /etc/systemd/system/

  mkdir -p ${K8S_DIR}/kube-proxy
  modprobe ip_vs_rr
  # systemctl daemon-reload && systemctl enable kube-proxy && systemctl restart kube-proxy
}

get_pause3_1(){
  local PauseImage=$(docker images | grep pause)

  if [ -z "${PauseImage}" ];then 
    echoInfo "pulling pause:3.1"
    docker pull mirrorgooglecontainers/pause:3.1
    docker tag mirrorgooglecontainers/pause:3.1  k8s.gcr.io/pause:3.1
  else
    echoInfo "pause 3.1 image already exists"
  fi
}

add_cni_kubelet(){

  # add this two flag options to kubelet system unit file.
  # --network-plugin=cni \\
  # --cni-conf-dir=/etc/cni/net.d \\
}


main(){
  pre_check
  install_docker
  setup_kubectl
  setup_kubelet
  setup_kube_proxy
  get_pause3_1
}

main