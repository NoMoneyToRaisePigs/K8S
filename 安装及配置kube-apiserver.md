tags: master, kube-apiserver

# 05-2. 安装及配置 kube-apiserver

<!-- TOC -->

- [安装及配置 kube-apiserver](#安装及配置-kube-apiserver)
    - [检查 kube-apiserver 二进制文件](#检查-kube-apiserver-二进制文件)
    - [检查 kube-apiserver 所需证书](#检查-kube-apiserver-所需证书)
    - [创建kube-apiserver.service - system unit 模板文件](#创建kube-apiserver.service-system-unit-模板文件)
    - [启动 kube-apiserver 服务](#启动-kube-apiserver-服务)
    - [创建 kube-apiserver systemd unit 模板文件](#创建-kube-apiserver-systemd-unit-模板文件)
    - [启动 kube-apiserver 服务](#启动-kube-apiserver-服务)
    - [检查 kube-apiserver 运行状态](#检查-kube-apiserver-运行状态)
    - [检查集群状态](#检查集群状态)
    - [检查 kube-apiserver 监听的端口](#检查-kube-apiserver-监听的端口)

<!-- /TOC -->

本文档讲解部署一个三实例 kube-apiserver 集群的步骤.

注意：如果没有特殊指明，本文档的所有操作**均在 zhangjun-k8s-01 节点上执行**。

## 检查 kube-apiserver 二进制文件

在[安装MasterNode](#安装MasterNode)中已经解压并拷贝了kube-apiserver二进制文件，检查kube-apiserver是否存在
``` bash
cd /opt/k8s/bin/
[ ! -f /opt/k8s/bin/kube-apiserver ] && echo "there is no kube-apiserver binary in /opt/k8s/bin/" || "kube-apiserver binary exists in /opt/k8s/bin/"
```

## 检查 kube-apiserver 所需证书

``` bash
   [ ! -f /etc/kubernetes/cert/ca.pem ] && echo "ca.pem needed" || "ca.pem exists"
   [ ! -f /etc/kubernetes/cert/proxy-client.pem ] && echo "proxy-client.pem needed" || "proxy-client.pem exists"
   [ ! -f /etc/kubernetes/cert/kubernetes.pem ] && echo "kubernetes CA needed" || "kubernetes.pem exists"
```

## 创建kube-apiserver.service system unit 模板文件

``` bash
   echo "creating kube-apiserver.service"
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
  --max-mutating-requests-inflight=2000 \\
  --max-requests-inflight=4000 \\
  --delete-collection-workers=2 \\
  --etcd-cafile=/etc/kubernetes/cert/ca.pem \\
  --etcd-certfile=/etc/kubernetes/cert/kubernetes.pem \\
  --etcd-keyfile=/etc/kubernetes/cert/kubernetes-key.pem \\
  --etcd-servers=${ETCD_ENDPOINTS} \\
  --bind-address=${NODE_IP} \\
  --secure-port=6443 \\
  --tls-cert-file=/etc/kubernetes/cert/kubernetes.pem \\
  --tls-private-key-file=/etc/kubernetes/cert/kubernetes-key.pem \\
  --insecure-port=0 \\
  --audit-log-maxage=15 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-truncate-enabled \\
  --audit-log-path=${K8S_DIR}/kube-apiserver/audit.log \\
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
```

+ `--advertise-address`：apiserver 对外通告的 IP（kubernetes 服务后端节点 IP）；
+ `--default-*-toleration-seconds`：设置节点异常相关的阈值；
+ `--max-*-requests-inflight`：请求相关的最大阈值；
+ `--etcd-*`：访问 etcd 的证书和 etcd 服务器地址；
+ `--bind-address`： https 监听的 IP，不能为 `127.0.0.1`，否则外界不能访问它的安全端口 6443；
+ `--secret-port`：https 监听端口；
+ `--insecure-port=0`：关闭监听 http 非安全端口(8080)；
+ `--tls-*-file`：指定 apiserver 使用的证书、私钥和 CA 文件；
+ `--audit-*`：配置审计策略和审计日志文件相关的参数；
+ `--client-ca-file`：验证 client (kue-controller-manager、kube-scheduler、kubelet、kube-proxy 等)请求所带的证书；
+ `--enable-bootstrap-token-auth`：启用 kubelet bootstrap 的 token 认证；
+ `--requestheader-*`：kube-apiserver 的 aggregator layer 相关的配置参数，proxy-client & HPA 需要使用；
+ `--requestheader-client-ca-file`：用于签名 `--proxy-client-cert-file` 和 `--proxy-client-key-file` 指定的证书；在启用了 metric aggregator 时使用；
+ `--requestheader-allowed-names`：不能为空，值为逗号分割的 `--proxy-client-cert-file` 证书的 CN 名称，这里设置为 "aggregator"；
+ `--service-account-key-file`：签名 ServiceAccount Token 的公钥文件，kube-controller-manager 的 `--service-account-private-key-file` 指定私钥文件，两者配对使用；
+ `--runtime-config=api/all=true`： 启用所有版本的 APIs，如 autoscaling/v2alpha1；
+ `--authorization-mode=Node,RBAC`、`--anonymous-auth=false`： 开启 Node 和 RBAC 授权模式，拒绝未授权的请求；
+ `--enable-admission-plugins`：启用一些默认关闭的 plugins；
+ `--allow-privileged`：运行执行 privileged 权限的容器；
+ `--apiserver-count=3`：指定 apiserver 实例的数量；
+ `--event-ttl`：指定 events 的保存时间；
+ `--kubelet-*`：如果指定，则使用 https 访问 kubelet APIs；需要为证书对应的用户(上面 kubernetes*.pem 证书的用户为 kubernetes) 用户定义 RBAC 规则，否则访问 kubelet API 时提示未授权；
+ `--proxy-client-*`：apiserver 访问 metrics-server 使用的证书；
+ `--service-cluster-ip-range`： 指定 Service Cluster IP 地址段；
+ `--service-node-port-range`： 指定 NodePort 的端口范围；

如果 kube-apiserver 机器**没有**运行 kube-proxy，则还需要添加 `--enable-aggregator-routing=true` 参数；

关于 `--requestheader-XXX` 相关参数，参考：

+ https://v1-21.docs.kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/

注意：
1. `--requestheader-client-ca-file` 指定的 CA 证书，必须具有 `client auth and server auth`；
2. 如果 `--requestheader-allowed-names` 不为空,且 `--proxy-client-cert-file` 证书的 CN 名称不在 allowed-names 中，则后续查看 node 或 pods 的 metrics 失败，提示：
  ``` bash
  $ kubectl top nodes
  Error from server (Forbidden): nodes.metrics.k8s.io is forbidden: User "aggregator" cannot list resource "nodes" in API group "metrics.k8s.io" at the cluster scope
  ```

启动kube-apiserver：

``` bash
systemctl daemon-reload && systemctl enable kube-apiserver && systemctl restart kube-apiserver
```

## 启动 kube-apiserver 服务

``` bash
systemctl daemon-reload && systemctl enable kube-apiserver && systemctl restart kube-apiserver
```

## 检查 kube-apiserver 运行状态

``` bash
systemctl status kube-apiserver |grep 'Active:'
```

确保状态为 `active (running)`，否则查看日志，确认原因：

``` bash
systemctl status kube-apiserver
journalctl -xefu kube-apiserver
```

## 检查集群状态

``` bash
$ kubectl cluster-info
Kubernetes master is running at https://172.27.138.251:6443

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

$ kubectl get all --all-namespaces
NAMESPACE   NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
default     service/kubernetes   ClusterIP   10.254.0.1   <none>        443/TCP   3m53s

$ kubectl get componentstatuses
NAME                 AGE
controller-manager   <unknown>
scheduler            <unknown>
etcd-0               <unknown>
etcd-2               <unknown>
etcd-1               <unknown>
```
+ Kubernetes 1.21.8 存在 Bugs 导致返回结果一直为 `<unknown>`，但 `kubectl get cs -o yaml` 可以返回正确结果；

## 检查 kube-apiserver 监听的端口

``` bash
$ sudo netstat -lnpt|grep kube
tcp        0      0 172.27.138.251:6443     0.0.0.0:*               LISTEN      101442/kube-apiserv
```
+ 6443: 接收 https 请求的安全端口，对所有请求做认证和授权；
+ 由于关闭了非安全端口，故没有监听 8080；