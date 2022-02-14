tags: master, kube-apiserver, kube-scheduler, kube-controller-manager

# 05-1. 部署 master 节点

<!-- TOC -->

- [安装及配置kubectl](#安装及配置kubectl)
- [安装及配置kube-apiserver](#安装及配置kube-apiserver)
- [安装及配置kube-controller-manager](#安装及配置kube-controller-manager)
- [安装及配置kube-scheduler](#安装及配置kube-scheduler)
- [安装及配置nginx](#安装及配置nginx)
- [安装及配置keepalived](#安装及配置keepalived)
- [all in one 脚本](#安装及配置all in one 脚本)


<!-- /TOC -->

kubernetes master 节点运行如下组件：
+ kubectl
+ kube-apiserver
+ kube-controller-manager
+ kube-scheduler
+ nginx
+ keepalived

kube-apiserver、kube-scheduler 和 kube-controller-manager 均以多实例模式运行：
1. kube-scheduler 和 kube-controller-manager 会自动选举产生一个 leader 实例，其它实例处于阻塞模式，当 leader 挂了后，重新选举产生新的 leader，从而保证服务可用性；
2. kube-apiserver 是无状态的，可以通过nginx实现上游三台kube-apiserver服务器代理，在三台服务器安装keepalived实现VRRP从而保证apiserver的高可用性。


## Master节点所需二进制文件
所有二进制文件都在此路径下
``` bash
cd /opt/k8s/work/
```
解压已经准备好的二进制文件，kubernetes-server-linux-amd64.tar。
``` bash
tar -xzvf /opt/k8s/work/cluster/kubernetes-server-linux-amd64.tar.gz -C /opt/k8s/work/cluster/
```
解压完成后将二进制文件拷贝至所有Master节点
``` bash
   for node_ip in ${Master_NODE_IPS[@]}
   do
      echo "scp apiextensions-apiserver,kube-apiserver,kube-controller-manager,kube-scheduler,kubeadm,kubectl,mounter ----> master node:${node_ip}"
      ssh root@${node_ip} "mkdir -p /opt/k8s/bin/"
      scp /opt/k8s/work/cluster/kubernetes/server/bin/{apiextensions-apiserver,kube-apiserver,kube-controller-manager,kube-scheduler,kubeadm,kubectl,mounter} root@${node_ip}:/opt/k8s/bin/
      ssh root@${node_ip} "chmod +x /opt/k8s/bin/*"
   done
```

## Master节点所需证书

+ kubectl访问apiserver所需证书 admin.pem 及其私钥 admin-key.pem
+ kube-apiserver对外提供服务及访问etcd所需证书 kubernetes.pem 及其私钥 kubernetes-key.pem
+ kube-controller对外提供服务所需证书 kube-controller-manager.pem 及其私钥 kube-controller-manager-key.pem
+ kube-scheduler对外提供服务所需证书 kube-scheduler.pem 及其私钥 kube-scheduler-key.pem

根据步骤[初始化集群证书]]所有证书都在此路径下
``` bash
cd /etc/kubernetes/cert/
```

准备好所有证书及二进制文件后，可以开始逐个安装Master节点组件

