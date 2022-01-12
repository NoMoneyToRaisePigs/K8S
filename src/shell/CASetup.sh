CLUSTER_DNS_DOMAIN="cluster.local"
CLUSTER_KUBERNETES_SVC_IP="10.254.0.1"

Master_NODE_IPS=(39.101.166.22 39.98.114.92 39.101.182.149)
# WORKER_NODE_IPS=(39.105.193.128 39.105.183.241 39.106.16.18)
WORKER_NODE_IPS=(39.105.183.241 39.106.16.18)
Master_NODE_Internal_IPS=(172.21.52.145 172.21.52.144 172.29.8.152)
WORKER_NODE_Internal_IPS=(172.22.76.54 172.22.76.52 172.22.76.53)

UBlue='\033[4;34m'      
Color_Off='\033[0m'

echoInfo(){   
   [ -n "$1" ] && echo -e "---> ${UBlue} $1 ${Color_Off}" && echo
}

dowload_cfssl_binary(){
   mkdir -p /opt/k8s/cert/
   mkdir -p /opt/k8s/bin/
   mkdir -p /opt/k8s/work/cfssl/

   if [ -f cfssl_1.4.1_linux_amd64 ];then  
      echoInfo "cfssl_1.4.1_linux_amd64 already exists, skip downloading"
   else
      echoInfo "download cfssl_1.4.1_linux_amd64" 
      wget -O /opt/k8s/work/cfssl https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssl_1.4.1_linux_amd64
   fi

   if [ -f cfssljson_1.4.1_linux_amd64 ];then  
      echoInfo "cfssljson_1.4.1_linux_amd64 already exists, skip downloading"
   else
      echoInfo "download cfssljson_1.4.1_linux_amd64"
      wget -O /opt/k8s/bin/cfssljson https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssljson_1.4.1_linux_amd64
   fi

      if [ -f cfssl-certinfo_1.4.1_linux_amd64 ];then  
      echoInfo "cfssl-certinfo_1.4.1_linux_amd64 already exists, skip downloading"
   else
      echoInfo "download cfssl-certinfo_1.4.1_linux_amd64"
      wget -O /opt/k8s/bin/cfssl-certinfo https://github.com/cloudflare/cfssl/releases/download/v1.4.1/cfssl-certinfo_1.4.1_linux_amd64
   fi

   chmod +x /opt/k8s/bin/*
}

generate_root_ca(){

   echoInfo "generating root ca"
   # 87600h is 100 years, which never expire.
   cat > /opt/k8s/work/cfssl/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "876000h"
      }
    }
  }
}
EOF

   cat > /opt/k8s/work/cfssl/ca-csr.json <<EOF
{
  "CN": "kubernetes-ca",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "ChangChun",
      "L": "ChangChun",
      "O": "k8s",
      "OU": "gf"
    }
  ],
  "ca": {
    "expiry": "876000h"
 }
}
EOF

   cd /opt/k8s/work/cfssl/
   cfssl gencert -initca ca-csr.json | cfssljson -bare ca

   cp /opt/k8s/work/cfssl/ca.pem /opt/k8s/cert/
   cp /opt/k8s/work/cfssl/ca-key.pem /opt/k8s/cert/
}

generate_kubectl_client_cert(){
   
   echoInfo "generating admin ca for kubectl"
   
   cat > /opt/k8s/work/cfssl/admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "ChangChun",
      "L": "ChangChun",
      "O": "system:masters",
      "OU": "gf"
    }
  ]
}
EOF

   cd /opt/k8s/work/cfssl/

   cfssl gencert \
      -ca=/opt/k8s/work/cfssl/ca.pem \
      -ca-key=/opt/k8s/work/cfssl/ca-key.pem \
      -config=/opt/k8s/work/cfssl/ca-config.json \
      -profile=kubernetes admin-csr.json | cfssljson -bare admin

   cp /opt/k8s/work/cfssl/admin.pem /opt/k8s/cert/
   cp /opt/k8s/work/cfssl/admin-key.pem /opt/k8s/cert/
}

generate_etcd_cert(){
   
   echoInfo "generating etcd ca for etcd"
   cat > /opt/k8s/work/cfssl/etcd-csr.json <<EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "${Master_NODE_IPS[0]}",
    "${Master_NODE_IPS[1]}",
    "${Master_NODE_IPS[2]}",
    "${Master_NODE_Internal_IPS[0]}",
    "${Master_NODE_Internal_IPS[1]}",
    "${Master_NODE_Internal_IPS[2]}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "ChangChun",
      "L": "ChangChun",
      "O": "k8s",
      "OU": "gf"
    }
  ]
}
EOF

   cd /opt/k8s/work/cfssl/
   cfssl gencert \
      -ca=/opt/k8s/work/cfssl/ca.pem \
      -ca-key=/opt/k8s/work/cfssl/ca-key.pem \
      -config=/opt/k8s/work/cfssl/ca-config.json \
      -profile=kubernetes etcd-csr.json | cfssljson -bare etcd

   cp /opt/k8s/work/cfssl/etcd.pem /opt/k8s/cert/
   cp /opt/k8s/work/cfssl/etcd-key.pem /opt/k8s/cert/
}

generate_kube_apiserver_cert(){
   
   echoInfo "generating kubernetes ca for api server"
   cat > /opt/k8s/work/cfssl/kubernetes-csr.json <<EOF
{
  "CN": "kubernetes-master",
  "hosts": [
    "127.0.0.1",
    "${Master_NODE_IPS[0]}",
    "${Master_NODE_IPS[1]}",
    "${Master_NODE_IPS[2]}",
    "${Master_NODE_Internal_IPS[0]}",
    "${Master_NODE_Internal_IPS[1]}",
    "${Master_NODE_Internal_IPS[2]}",
    "${WORKER_NODE_IPS[0]}",
    "${WORKER_NODE_IPS[1]}",
    "${WORKER_NODE_IPS[2]}",
    "${WORKER_NODE_Internal_IPS[0]}",
    "${WORKER_NODE_Internal_IPS[1]}",
    "${WORKER_NODE_Internal_IPS[2]}",
    "${CLUSTER_KUBERNETES_SVC_IP}",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local.",
    "kubernetes.default.svc.${CLUSTER_DNS_DOMAIN}."
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "ChangChun",
      "L": "ChangChun",
      "O": "k8s",
      "OU": "gf"
    }
  ]
}
EOF

   cd /opt/k8s/work/cfssl/
   cfssl gencert \
      -ca=/opt/k8s/work/cfssl/ca.pem \
      -ca-key=/opt/k8s/work/cfssl/ca-key.pem \
      -config=/opt/k8s/work/cfssl/ca-config.json \
      -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes

   cp /opt/k8s/work/cfssl/kubernetes.pem /opt/k8s/cert/
   cp /opt/k8s/work/cfssl/kubernetes-key.pem /opt/k8s/cert/ 
}

generate_proxy_client_cert(){
   echoInfo "generating kubernetes ca for api server"

   cat > /opt/k8s/work/cfssl/proxy-client-csr.json <<EOF
{
  "CN": "aggregator",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "ChangChun",
      "L": "ChangChun",
      "O": "k8s",
      "OU": "gf"
    }
  ]
}
EOF 

   cd /opt/k8s/work/cfssl/
   cfssl gencert -ca=/opt/k8s/work/cfssl/ca.pem \
      -ca-key=/opt/k8s/work/cfssl/ca-key.pem  \
      -config=/opt/k8s/work/cfssl/ca-config.json  \
      -profile=kubernetes proxy-client-csr.json | cfssljson -bare proxy-client

   cp /opt/k8s/work/cfssl/proxy-client*.pem /etc/kubernetes/cert/
}

generate_kube_controller_manager_cert(){

   echoInfo "generating kube-controller-manager ca for kube controller manager"
   cat > /opt/k8s/work/cfssl/kube-controller-manager-csr.json <<EOF
{
    "CN": "system:kube-controller-manager",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
      "127.0.0.1",
      "${Master_NODE_IPS[0]}",
      "${Master_NODE_IPS[1]}",
      "${Master_NODE_IPS[2]}",
      "${Master_NODE_Internal_IPS[0]}",
      "${Master_NODE_Internal_IPS[1]}",
      "${Master_NODE_Internal_IPS[2]}"
    ],
    "names": [
      {
        "C": "CN",
        "ST": "ChangChun",
        "L": "ChangChun",
        "O": "system:kube-controller-manager",
        "OU": "gf"
      }
    ]
}
EOF

   cd /opt/k8s/work/cfssl/
   cfssl gencert \
      -ca=/opt/k8s/work/cfssl/ca.pem \
      -ca-key=/opt/k8s/work/cfssl/ca-key.pem \
      -config=/opt/k8s/work/cfssl/ca-config.json \
      -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

   cp /opt/k8s/work/cfssl/kube-controller-manager.pem /opt/k8s/cert/
   cp /opt/k8s/work/cfssl/kube-controller-manager-key.pem /opt/k8s/cert/
}

generate_kube_scheduler_cert(){

   echoInfo "generating kube-scheduler ca for kube kube scheduler"
   cat > /opt/k8s/work/cfssl/kube-scheduler-csr.json <<EOF
{
    "CN": "system:kube-scheduler",
    "hosts": [
      "127.0.0.1",
      "${Master_NODE_IPS[0]}",
      "${Master_NODE_IPS[1]}",
      "${Master_NODE_IPS[2]}",
      "${Master_NODE_Internal_IPS[0]}",
      "${Master_NODE_Internal_IPS[1]}",
      "${Master_NODE_Internal_IPS[2]}"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
      {
        "C": "CN",
        "ST": "ChangChun",
        "L": "ChangChun",
        "O": "system:kube-scheduler",
        "OU": "gf"
      }
    ]
}
EOF

   cd /opt/k8s/work/cfssl/
   cfssl gencert \
      -ca=/opt/k8s/work/cfssl/ca.pem \
      -ca-key=/opt/k8s/work/cfssl/ca-key.pem \
      -config=/opt/k8s/work/cfssl/ca-config.json \
      -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler

   cp /opt/k8s/work/cfssl/kube-scheduler.pem /opt/k8s/cert/
   cp /opt/k8s/work/cfssl/kube-scheduler-key.pem /opt/k8s/cert/
}


generate_kube_proxy_client_cert(){

   echoInfo "generating kube-proxy ca for kube proxy"
   cat > /opt/k8s/work/cfssl/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "ChangChun",
      "L": "ChangChun",
      "O": "k8s",
      "OU": "gf"
    }
  ]
}
EOF

   cd /opt/k8s/work/cfssl/
   cfssl gencert \
      -ca=/opt/k8s/work/cfssl/ca.pem \
      -ca-key=/opt/k8s/work/cfssl/ca-key.pem \
      -config=/opt/k8s/work/cfssl/ca-config.json \
      -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy

   cp /opt/k8s/work/cfssl/kube-proxy.pem /opt/k8s/cert/
   cp /opt/k8s/work/cfssl/kube-proxy-key.pem /opt/k8s/cert/
}


distribute_cert_master(){
   for node_ip in ${Master_NODE_IPS[@]}
   do
      echoInfo "---> copy ca.pem ca-key.pem admin.pem admin-key.pem etcd.pem etcd-key.pem kubernetes.pem kubernetes-key.pem kube-controller-manager.pem kube-controller-manager-key.pem kube-scheduler.pem kube-scheduler-key.pem --->  master node ${node_ip}:/etc/kubernetes/cert/"
      ssh root@${node_ip} "mkdir -p /etc/kubernetes/cert/"
      scp /opt/k8s/cert/{ca.pem,ca-key.pem,admin.pem,admin-key.pem,etcd.pem,etcd-key.pem,kubernetes.pem,kubernetes-key.pem,kube-controller-manager.pem,kube-controller-manager-key.pem,kube-scheduler.pem,kube-scheduler-key.pem, } root@${node_ip}:/etc/kubernetes/cert/
   done
}

distribute_cert_worker(){
   for node_ip in ${WORKER_NODE_IPS[@]}
   do
      echoInfo "---> ca.pem ca-key.pem admin.pem admin-key.pem kube-proxy.pem kube-proxy-key.pem --->  worker node ${node_ip}:/etc/kubernetes/cert/"
      ssh root@${node_ip} "mkdir -p /etc/kubernetes/cert/"
      scp /opt/k8s/cert/{ca.pem,ca-key.pem,admin.pem,admin-key.pem,kube-proxy.pem,kube-proxy-key.pem} root@${node_ip}:/etc/kubernetes/cert/
   done
}


#dowload_cfssl_binary

# generate_root_ca
# generate_kubectl_client_cert
# generate_etcd_cert
# generate_kube_apiserver_cert
# generate_kube_controller_manager_cert
# generate_kube_scheduler_cert
# generate_kube_proxy_client_cert

# distribute_cert_master
distribute_cert_worker