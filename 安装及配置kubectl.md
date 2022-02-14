# 安装和配置 kubectl

<!-- TOC -->

- [安装和配置 kubectl](#安装和配置-kubectl)
    - [检查 kubectl 二进制文件](#下载和分发-kubectl-二进制文件)
    - [检查 kubectl 所需证书](#检查-kubectl-所需证书)
    - [创建 kubectl.kubeconfig 文件](#创建-kubectl.kubeconfig-文件)

<!-- /TOC -->

本文档介绍安装和配置 kubernetes 命令行管理工具 kubectl 的步骤。

注意：
1. 生成的 kubeconfig 文件是**通用的**，可以拷贝到需要执行 kubectl 命令的机器的 `~/.kube/config` 位置；
2. 生成 kubectl.kubeconfig 的脚本依赖${NODE_IP}参数，此参数可以为Master节点任意IP，或者keepalived VIP。

## 检查 kubectl 二进制文件
在[安装MasterNode](#安装MasterNode)中已经解压并拷贝了kubectl二进制文件，检查kubectl是否存在
``` bash
cd /opt/k8s/bin/
[ ! -f /opt/k8s/bin/kubectl ] && echoFailure "there is no kubectl binary in /opt/k8s/bin/" || echo "kubectl binary existss"
```

## 检查 kubectl 所需证书
在[集群CA证书创建及部署](#[集群CA证书创建及部署)中已经生成kubectl证书，检查证书是否存在
``` bash
cd /etc/kubernetes/cert/
   [ ! -f /etc/kubernetes/cert/ca.pem ] && echo "ca.pem needed" || echo "ca.pem exists"
   [ ! -f /etc/kubernetes/cert/admin.pem ] && echo "admin.pem needed" || echo "admin.pem exists"
   [ ! -f /etc/kubernetes/cert/admin-key.pem ] && echo "admin-key.pem needed" || echo "admin-key.pem exists"
```

## 创建 kubectl.kubeconfig 文件

kubectl 使用 https 协议与 kube-apiserver 进行安全通信，kube-apiserver 对 kubectl 请求包含的证书进行认证和授权。

kubectl 后续用于集群管理，所以这里创建具有**最高权限**的 admin 证书。

检查kubeconfig是否存在，存在将其删除并重新创建:

``` bash
[ -f /opt/k8s/work/kubectl/kubectl.kubeconfig ] && echo "remove existing kubectl.kubeconfig" && rm -rf /opt/k8s/work/kubectl/kubectl.kubeconfig
```
创建kubectl.kubeconfig:

``` bash
   echo "create kubectl.kubeconfig"
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

   echo "copy /opt/k8s/work/kubectl/kubectl.kubeconfig to /root/.kube/config"
   cp /opt/k8s/work/kubectl/kubectl.kubeconfig ~/.kube/config
```
