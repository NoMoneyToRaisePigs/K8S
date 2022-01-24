# NODE_IP=39.98.114.92
NODE_IP=172.21.52.145
NODE_NAME=gf-master-01

K8S_DIR="/data/k8s/k8s"
# ETCD_ENDPOINTS="https://39.101.166.22:2379,https://39.98.114.92:2379,https://39.101.182.149:2379"
ETCD_ENDPOINTS="https://172.21.52.145:2379,https://172.21.52.144:2379,https://172.29.8.152:2379"
SERVICE_CIDR="10.254.0.0/16"
NODE_PORT_RANGE="30000-32767"
Encryption_Key="lvYO3Qi5EVBpSAHh0yG1j1QnTT2zh+fQXrpGuMUn8og="

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
      --server=https://${NODE_IP}:6443 \
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


install_setup_etcd(){
   echoInfo "install and setup etcd..."
   mkdir -p /opt/k8s/work/etcd/ 


   if [ ! -f /opt/k8s/work/etcd/etcd-v3.4.3-linux-amd64.tar.gz ]; then
      echoInfo "dowload etcd archive..."
      wget -P /opt/k8s/work/etcd/ https://github.com/coreos/etcd/releases/download/v3.4.3/etcd-v3.4.3-linux-amd64.tar.gz
   else
      echoInfo "etcd binary already downloaded"
   fi

   if [ ! -d /opt/k8s/work/etcd/etcd-v3.4.3-linux-amd64 ]; then
      echoInfo "taping etcd archive..."
      tar -xvf /opt/k8s/work/etcd/etcd-v3.4.3-linux-amd64.tar.gz -C /opt/k8s/work/etcd/
   else
      echoInfo "etcd binary already taped"
   fi

   cp /opt/k8s/work/etcd/etcd-v3.4.3-linux-amd64/etcd* /opt/k8s/bin
   chmod +x /opt/k8s/bin/*

   [ ! -f /etc/kubernetes/cert/etcd.pem ] && echoFailure "ectd CA needed" && exit 1
   [ ! -f /etc/kubernetes/cert/ca.pem ] && echoFailure "root CA needed" && exit 1

   echoInfo "creating etcd.service"
   local ETCD_DATA_DIR="/data/k8s/etcd/data"
   local ETCD_WAL_DIR="/data/k8s/etcd/wal"
   local ETCD_NODES="gf-master-01=https://172.21.52.145:2380,gf-master-02=https://172.21.52.144:2380,gf-master-03=https://172.29.8.152:2380" 
   mkdir -p ${ETCD_DATA_DIR} ${ETCD_WAL_DIR}

   cat > /opt/k8s/work/etcd/etcd.service.template << EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=${ETCD_DATA_DIR}
ExecStart=/opt/k8s/bin/etcd \\
  --data-dir=${ETCD_DATA_DIR} \\
  --wal-dir=${ETCD_WAL_DIR} \\
  --name=${NODE_NAME} \\
  --cert-file=/etc/kubernetes/cert/etcd.pem \\
  --key-file=/etc/kubernetes/cert/etcd-key.pem \\
  --trusted-ca-file=/etc/kubernetes/cert/ca.pem \\
  --peer-cert-file=/etc/kubernetes/cert/etcd.pem \\
  --peer-key-file=/etc/kubernetes/cert/etcd-key.pem \\
  --peer-trusted-ca-file=/etc/kubernetes/cert/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --listen-peer-urls=https://${NODE_IP}:2380 \\
  --initial-advertise-peer-urls=https://${NODE_IP}:2380 \\
  --listen-client-urls=https://${NODE_IP}:2379,http://127.0.0.1:2379 \\
  --advertise-client-urls=https://${NODE_IP}:2379 \\
  --initial-cluster-token=etcd-cluster-0 \\
  --initial-cluster=${ETCD_NODES} \\
  --initial-cluster-state=new \\
  --auto-compaction-mode=periodic \\
  --auto-compaction-retention=1 \\
  --max-request-bytes=33554432 \\
  --quota-backend-bytes=6442450944 \\
  --heartbeat-interval=250 \\
  --election-timeout=2000
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

   cp /opt/k8s/work/etcd/etcd.service.template /etc/systemd/system/etcd.service

   systemctl daemon-reload && systemctl enable etcd && systemctl restart etcd 
}



setup_kube_apiserver(){
   echoInfo "setup kube-apiserver..."

   [ ! -f /opt/k8s/bin/kube-apiserver ] && echo "there is no kube-apiserver binary in /opt/k8s/bin/" && exit 1
   [ ! -f /etc/kubernetes/cert/ca.pem ] && echo "root CA needed" && exit 1
   [ ! -f /etc/kubernetes/cert/proxy-client.pem ] && echo "proxy-client CA needed" && exit 1
   [ ! -f /etc/kubernetes/cert/kubernetes.pem ] && echo "kubernetes CA needed" && exit 1

   mkdir -p /opt/k8s/work/kube-apiserver/

   echoInfo "creating encryption-config.yaml "

   cat > /opt/k8s/work/kube-apiserver/encryption-config.yaml << EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${Encryption_Key}
      - identity: {}
EOF

   cp /opt/k8s/work/kube-apiserver/encryption-config.yaml /etc/kubernetes/encryption-config.yaml

   echoInfo "creating audit-policy.yaml"

   cat > /opt/k8s/work/kube-apiserver/audit-policy.yaml << EOF
apiVersion: audit.k8s.io/v1beta1
kind: Policy
rules:
  # The following requests were manually identified as high-volume and low-risk, so drop them.
  - level: None
    resources:
      - group: ""
        resources:
          - endpoints
          - services
          - services/status
    users:
      - 'system:kube-proxy'
    verbs:
      - watch

  - level: None
    resources:
      - group: ""
        resources:
          - nodes
          - nodes/status
    userGroups:
      - 'system:nodes'
    verbs:
      - get

  - level: None
    namespaces:
      - kube-system
    resources:
      - group: ""
        resources:
          - endpoints
    users:
      - 'system:kube-controller-manager'
      - 'system:kube-scheduler'
      - 'system:serviceaccount:kube-system:endpoint-controller'
    verbs:
      - get
      - update

  - level: None
    resources:
      - group: ""
        resources:
          - namespaces
          - namespaces/status
          - namespaces/finalize
    users:
      - 'system:apiserver'
    verbs:
      - get

  # Don't log HPA fetching metrics.
  - level: None
    resources:
      - group: metrics.k8s.io
    users:
      - 'system:kube-controller-manager'
    verbs:
      - get
      - list

  # Don't log these read-only URLs.
  - level: None
    nonResourceURLs:
      - '/healthz*'
      - /version
      - '/swagger*'

  # Don't log events requests.
  - level: None
    resources:
      - group: ""
        resources:
          - events

  # node and pod status calls from nodes are high-volume and can be large, don't log responses
  # for expected updates from nodes
  - level: Request
    omitStages:
      - RequestReceived
    resources:
      - group: ""
        resources:
          - nodes/status
          - pods/status
    users:
      - kubelet
      - 'system:node-problem-detector'
      - 'system:serviceaccount:kube-system:node-problem-detector'
    verbs:
      - update
      - patch

  - level: Request
    omitStages:
      - RequestReceived
    resources:
      - group: ""
        resources:
          - nodes/status
          - pods/status
    userGroups:
      - 'system:nodes'
    verbs:
      - update
      - patch

  # deletecollection calls can be large, don't log responses for expected namespace deletions
  - level: Request
    omitStages:
      - RequestReceived
    users:
      - 'system:serviceaccount:kube-system:namespace-controller'
    verbs:
      - deletecollection

  # Secrets, ConfigMaps, and TokenReviews can contain sensitive & binary data,
  # so only log at the Metadata level.
  - level: Metadata
    omitStages:
      - RequestReceived
    resources:
      - group: ""
        resources:
          - secrets
          - configmaps
      - group: authentication.k8s.io
        resources:
          - tokenreviews
  # Get repsonses can be large; skip them.
  - level: Request
    omitStages:
      - RequestReceived
    resources:
      - group: ""
      - group: admissionregistration.k8s.io
      - group: apiextensions.k8s.io
      - group: apiregistration.k8s.io
      - group: apps
      - group: authentication.k8s.io
      - group: authorization.k8s.io
      - group: autoscaling
      - group: batch
      - group: certificates.k8s.io
      - group: extensions
      - group: metrics.k8s.io
      - group: networking.k8s.io
      - group: policy
      - group: rbac.authorization.k8s.io
      - group: scheduling.k8s.io
      - group: settings.k8s.io
      - group: storage.k8s.io
    verbs:
      - get
      - list
      - watch

  # Default level for known APIs
  - level: RequestResponse
    omitStages:
      - RequestReceived
    resources:
      - group: ""
      - group: admissionregistration.k8s.io
      - group: apiextensions.k8s.io
      - group: apiregistration.k8s.io
      - group: apps
      - group: authentication.k8s.io
      - group: authorization.k8s.io
      - group: autoscaling
      - group: batch
      - group: certificates.k8s.io
      - group: extensions
      - group: metrics.k8s.io
      - group: networking.k8s.io
      - group: policy
      - group: rbac.authorization.k8s.io
      - group: scheduling.k8s.io
      - group: settings.k8s.io
      - group: storage.k8s.io
      
  # Default level for all other requests.
  - level: Metadata
    omitStages:
      - RequestReceived
EOF

   echoInfo "copying /opt/k8s/work/kube-apiserver/audit-policy.yaml ---> /etc/kubernetes/audit-policy.yaml"
   cp /opt/k8s/work/kube-apiserver/audit-policy.yaml /etc/kubernetes/audit-policy.yaml


   echoInfo "creating kube-apiserver.service"
   mkdir -p ${K8S_DIR}
   mkdir -p /data/k8s/k8s/kube-apiserver
   cat > /opt/k8s/work/kube-apiserver/kube-apiserver.service << EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
WorkingDirectory=${K8S_DIR}/kube-apiserver
ExecStart=/opt/k8s/bin/kube-apiserver \\
  --advertise-address=${NODE_IP} \\
  --default-not-ready-toleration-seconds=360 \\
  --default-unreachable-toleration-seconds=360 \\
  --feature-gates=DynamicAuditing=true \\
  --max-mutating-requests-inflight=2000 \\
  --max-requests-inflight=4000 \\
  --default-watch-cache-size=200 \\
  --delete-collection-workers=2 \\
  --encryption-provider-config=/etc/kubernetes/encryption-config.yaml \\
  --etcd-cafile=/etc/kubernetes/cert/ca.pem \\
  --etcd-certfile=/etc/kubernetes/cert/kubernetes.pem \\
  --etcd-keyfile=/etc/kubernetes/cert/kubernetes-key.pem \\
  --etcd-servers=${ETCD_ENDPOINTS} \\
  --bind-address=${NODE_IP} \\
  --secure-port=6443 \\
  --tls-cert-file=/etc/kubernetes/cert/kubernetes.pem \\
  --tls-private-key-file=/etc/kubernetes/cert/kubernetes-key.pem \\
  --insecure-port=0 \\
  --audit-dynamic-configuration \\
  --audit-log-maxage=15 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-truncate-enabled \\
  --audit-log-path=${K8S_DIR}/kube-apiserver/audit.log \\
  --audit-policy-file=/etc/kubernetes/audit-policy.yaml \\
  --profiling \\
  --anonymous-auth=false \\
  --client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --enable-bootstrap-token-auth \\
  --requestheader-allowed-names="aggregator" \\
  --requestheader-client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-extra-headers-prefix="X-Remote-Extra-" \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --service-account-key-file=/etc/kubernetes/cert/ca.pem \\
  --authorization-mode=Node,RBAC \\
  --runtime-config=api/all=true \\
  --enable-admission-plugins=NodeRestriction \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --event-ttl=168h \\
  --kubelet-certificate-authority=/etc/kubernetes/cert/ca.pem \\
  --kubelet-client-certificate=/etc/kubernetes/cert/kubernetes.pem \\
  --kubelet-client-key=/etc/kubernetes/cert/kubernetes-key.pem \\
  --kubelet-https=true \\
  --kubelet-timeout=10s \\
  --proxy-client-cert-file=/etc/kubernetes/cert/proxy-client.pem \\
  --proxy-client-key-file=/etc/kubernetes/cert/proxy-client-key.pem \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --service-node-port-range=${NODE_PORT_RANGE} \\
  --logtostderr=true \\
  --v=2
Restart=on-failure
RestartSec=10
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

  cp /opt/k8s/work/kube-apiserver/kube-apiserver.service /etc/systemd/system/kube-apiserver.service
  systemctl daemon-reload && systemctl enable kube-apiserver && systemctl restart kube-apiserver
}



setup_kube_controller_manager(){
   echoInfo "setup kube-controller-manager..."

   mkdir -p /opt/k8s/work/kube-controller-manager/

  
   [ ! -f /opt/k8s/bin/kube-controller-manager ] && echoFailure "there is no kube-controller-manager binary in /opt/k8s/bin/" && exit 1
   [ ! -f /etc/kubernetes/cert/ca.pem ] && echoFailure "root CA needed" && exit 1
   [ ! -f /etc/kubernetes/cert/kube-controller-manager.pem ] && echoFailure "kube-controller-manager CA needed" && exit 1


   echoInfo "creating kube-controller-manager.kubeconfig for controller-manager to access cluster api"
   [ -f /opt/k8s/work/kube-controller-manager/kube-controller-manager.kubeconfig ] && echoInfo "remove existing kube-controller-manager.kubeconfig" && rm -rf /opt/k8s/work/kube-controller-manager/kube-controller-manager.kubeconfig

   kubectl config set-cluster kubernetes \
   --certificate-authority=/etc/kubernetes/cert/ca.pem \
   --embed-certs=true \
   --server="https://${NODE_IP}:6443" \
   --kubeconfig=/opt/k8s/work/kube-controller-manager/kube-controller-manager.kubeconfig

   kubectl config set-credentials system:kube-controller-manager \
      --client-certificate=/etc/kubernetes/cert/kube-controller-manager.pem \
      --client-key=/etc/kubernetes/cert/kube-controller-manager-key.pem \
      --embed-certs=true \
      --kubeconfig=/opt/k8s/work/kube-controller-manager/kube-controller-manager.kubeconfig

   kubectl config set-context system:kube-controller-manager \
      --cluster=kubernetes \
      --user=system:kube-controller-manager \
      --kubeconfig=/opt/k8s/work/kube-controller-manager/kube-controller-manager.kubeconfig

   kubectl config use-context system:kube-controller-manager \
      --kubeconfig=/opt/k8s/work/kube-controller-manager/kube-controller-manager.kubeconfig

   cp /opt/k8s/work/kube-controller-manager/kube-controller-manager.kubeconfig /etc/kubernetes/kube-controller-manager.kubeconfig

   echo "creating kube-controller-mananger systemd unit file"
   mkdir -p ${K8S_DIR}/kube-controller-manager

   cat > /opt/k8s/work/kube-controller-manager/kube-controller-manager.service.template << EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
WorkingDirectory=${K8S_DIR}/kube-controller-manager
ExecStart=/opt/k8s/bin/kube-controller-manager \\
  --profiling \\
  --cluster-name=kubernetes \\
  --controllers=*,bootstrapsigner,tokencleaner \\
  --kube-api-qps=1000 \\
  --kube-api-burst=2000 \\
  --leader-elect \\
  --use-service-account-credentials\\
  --concurrent-service-syncs=2 \\
  --bind-address=${NODE_IP} \\
  --secure-port=10252 \\
  --tls-cert-file=/etc/kubernetes/cert/kube-controller-manager.pem \\
  --tls-private-key-file=/etc/kubernetes/cert/kube-controller-manager-key.pem \\
  --port=0 \\
  --authentication-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-allowed-names="aggregator" \\
  --requestheader-client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-extra-headers-prefix="X-Remote-Extra-" \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --authorization-kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --cluster-signing-cert-file=/etc/kubernetes/cert/ca.pem \\
  --cluster-signing-key-file=/etc/kubernetes/cert/ca-key.pem \\
  --experimental-cluster-signing-duration=876000h \\
  --horizontal-pod-autoscaler-sync-period=10s \\
  --concurrent-deployment-syncs=10 \\
  --concurrent-gc-syncs=30 \\
  --node-cidr-mask-size=24 \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --pod-eviction-timeout=6m \\
  --terminated-pod-gc-threshold=10000 \\
  --root-ca-file=/etc/kubernetes/cert/ca.pem \\
  --service-account-private-key-file=/etc/kubernetes/cert/ca-key.pem \\
  --kubeconfig=/etc/kubernetes/kube-controller-manager.kubeconfig \\
  --logtostderr=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  cp /opt/k8s/work/kube-controller-manager/kube-controller-manager.service.template /etc/systemd/system/kube-controller-manager.service
  systemctl daemon-reload && systemctl enable kube-controller-manager && systemctl restart kube-controller-manager
}



setup_kube_scheduler(){
   echoInfo "---> try setup kube-scheduler..."

   [ ! -f /opt/k8s/bin/kube-scheduler ] && echoFailure "there is no kube-scheduler binary in /opt/k8s/bin/" && exit 1
   [ ! -f /etc/kubernetes/cert/ca.pem ] && echoFailure "root CA needed" && exit 1
   [ ! -f /etc/kubernetes/cert/kube-scheduler.pem ] && echoFailure "kube-scheduler CA needed" && exit 1

   mkdir -p /opt/k8s/work/kube-scheduler/

   [ -f /opt/k8s/work/kube-scheduler/kube-scheduler.kubeconfig ] && echoInfo "remove existing kube-scheduler.kubeconfig" && rm -rf /opt/k8s/work/kube-scheduler/kube-scheduler.kubeconfig

   echoInfo "creating kube-scheduler.kubeconfig"
   kubectl config set-cluster kubernetes \
      --certificate-authority=/etc/kubernetes/cert/ca.pem \
      --embed-certs=true \
      --server="https://${NODE_IP}:6443" \
      --kubeconfig=/opt/k8s/work/kube-scheduler/kube-scheduler.kubeconfig

   kubectl config set-credentials system:kube-scheduler \
      --client-certificate=/etc/kubernetes/cert/kube-scheduler.pem \
      --client-key=/etc/kubernetes/cert/kube-scheduler-key.pem \
      --embed-certs=true \
      --kubeconfig=/opt/k8s/work/kube-scheduler/kube-scheduler.kubeconfig

   kubectl config set-context system:kube-scheduler \
      --cluster=kubernetes \
      --user=system:kube-scheduler \
      --kubeconfig=/opt/k8s/work/kube-scheduler/kube-scheduler.kubeconfig

   kubectl config use-context system:kube-scheduler \
      --kubeconfig=/opt/k8s/work/kube-scheduler/kube-scheduler.kubeconfig

   cp /opt/k8s/work/kube-scheduler/kube-scheduler.kubeconfig /etc/kubernetes/kube-scheduler.kubeconfig

 
   echoInfo "creating kube-scheduler.yaml"
   cat > /opt/k8s/work/kube-scheduler/kube-scheduler.yaml << EOF
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
bindTimeoutSeconds: 600
clientConnection:
  burst: 200
  kubeconfig: "/etc/kubernetes/kube-scheduler.kubeconfig"
  qps: 100
enableContentionProfiling: false
enableProfiling: true
hardPodAffinitySymmetricWeight: 1
healthzBindAddress: ${NODE_IP}:10251
leaderElection:
  leaderElect: true
metricsBindAddress: ${NODE_IP}:10251
EOF

   cp /opt/k8s/work/kube-scheduler/kube-scheduler.yaml /etc/kubernetes/kube-scheduler.yaml


   echoInfo "creating kube-scheduler.service"
   mkdir -p ${K8S_DIR}/kube-scheduler
   cat > /opt/k8s/work/kube-scheduler/kube-scheduler.service.template << EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
WorkingDirectory=${K8S_DIR}/kube-scheduler
ExecStart=/opt/k8s/bin/kube-scheduler \\
  --config=/etc/kubernetes/kube-scheduler.yaml \\
  --bind-address=${NODE_IP} \\
  --secure-port=10259 \\
  --port=0 \\
  --tls-cert-file=/etc/kubernetes/cert/kube-scheduler.pem \\
  --tls-private-key-file=/etc/kubernetes/cert/kube-scheduler-key.pem \\
  --authentication-kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \\
  --client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-allowed-names="" \\
  --requestheader-client-ca-file=/etc/kubernetes/cert/ca.pem \\
  --requestheader-extra-headers-prefix="X-Remote-Extra-" \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --authorization-kubeconfig=/etc/kubernetes/kube-scheduler.kubeconfig \\
  --logtostderr=true \\
  --v=2
Restart=always
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF

  cp /opt/k8s/work/kube-scheduler/kube-scheduler.service.template /etc/systemd/system/kube-scheduler.service
  systemctl daemon-reload && systemctl enable kube-scheduler && systemctl restart kube-scheduler

}


main(){
   pre_check
   setup_kubectl
   install_setup_etcd
   setup_kube_apiserver
   setup_kube_controller_manager
   setup_kube_scheduler
}

main