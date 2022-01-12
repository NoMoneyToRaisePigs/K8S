package main

import (
	"flag"
	"fmt"
	"path/filepath"
	clientv1 "test/api/types/clientset"
	crontabv1 "test/api/types/v1alpha1"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
	//
	// Uncomment to load all auth plugins
	// _ "k8s.io/client-go/plugin/pkg/client/auth"
	//
	// Or uncomment to load specific auth plugins
	// _ "k8s.io/client-go/plugin/pkg/client/auth/azure"
	// _ "k8s.io/client-go/plugin/pkg/client/auth/gcp"
	// _ "k8s.io/client-go/plugin/pkg/client/auth/oidc"
	// _ "k8s.io/client-go/plugin/pkg/client/auth/openstack"
)

func init() {}

func main() {

	var kubeconfig *string
	if home := homedir.HomeDir(); home != "" {
		kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "(optional) absolute path to the kubeconfig file")
	} else {
		kubeconfig = flag.String("kubeconfig", "", "absolute path to the kubeconfig file")
	}
	flag.Parse()

	// use the current context in kubeconfig
	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	if err != nil {
		panic(err.Error())
	}

	crontabv1.AddToScheme(scheme.Scheme)

	clientSet, err := clientv1.NewForConfig(config)
	if err != nil {
		panic(err)
	}

	crontabs, err := clientSet.CronTabs("default").List(metav1.ListOptions{})

	for _, v := range crontabs.Items {
		fmt.Println(v.Name)
	}

	//the manual way of doing things--------------------------------------------------------------------------------------------------------
	// crdConfig := *config
	// crdConfig.ContentConfig.GroupVersion = &pkgS.GroupVersion{Group: crontabv1.GroupName, Version: crontabv1.GroupVersion}
	// crdConfig.APIPath = "/apis"
	// crdConfig.NegotiatedSerializer = serializer.NewCodecFactory(scheme.Scheme)
	// crdConfig.UserAgent = rest.DefaultKubernetesUserAgent()

	// exampleRestClient, err := rest.UnversionedRESTClientFor(&crdConfig)
	// if err != nil {
	// 	panic(err)
	// }

	// result := crontabv1.CronTabList{}
	// if err := exampleRestClient.Get().Resource("crontabs").Do(context.TODO()).Into(&result); err != nil {
	// 	panic(err)
	// }

	// for _, val := range result.Items {
	// 	println(val.Name)
	// }

	// err := exampleRestClient.
	// 	 Get().
	// 	 Resource("projects").
	// 	 Do().
	// 	 Into(&result)
	//--------------------------------------------------------------------------------------------------------------------------------

	time.Sleep(5 * time.Second)
}

func int32ptr(i int32) *int32 { return &i }
