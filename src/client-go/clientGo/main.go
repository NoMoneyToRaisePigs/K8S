package main

import (
	"bufio"
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"

	// crontabv1 "test/api/types/v1alpha1"
	"time"

	appsv1 "k8s.io/api/apps/v1"
	apiv1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	v1 "k8s.io/client-go/kubernetes/typed/apps/v1"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
	retry "k8s.io/client-go/util/retry"
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

	// crontabv1.AddToScheme(scheme.Scheme)

	// create the clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}

	//get pods
	pods, err := clientset.CoreV1().Pods("").List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		panic(err.Error())
	}
	fmt.Printf("There are %d pods in the cluster\n", len(pods.Items))

	for _, item := range pods.Items {
		fmt.Println(item.Namespace, item.Name)
	}

	// get deployments
	deployments, err := clientset.AppsV1().Deployments("default").List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		fmt.Println(err)
		return
	}

	fmt.Printf("There are %d pods in the cluster\n", len(pods.Items))
	for _, dpl := range deployments.Items {
		fmt.Println(dpl.Name)
	}

	result, err := create_nginx_deployment(clientset)
	if err != nil {
		panic(err)
	}

	fmt.Printf("created deployment %q.\n", result.GetObjectMeta().GetName())

	time.Sleep(10 * time.Second)
}

func create_nginx_deployment(clientset *kubernetes.Clientset) (*appsv1.Deployment, error) {
	deploymentClient := clientset.AppsV1().Deployments("default")

	//create nginx deployment.---------------------------------------------------------------
	helper := int32(1)

	nginxSpec := appsv1.DeploymentSpec{
		Replicas: &helper,
		Selector: &metav1.LabelSelector{
			MatchLabels: map[string]string{"app": "nginx"},
		},
		Template: apiv1.PodTemplateSpec{
			ObjectMeta: metav1.ObjectMeta{
				Labels: map[string]string{
					"app": "nginx",
				},
			},
			Spec: apiv1.PodSpec{
				Containers: []apiv1.Container{
					{
						Name:  "nginx",
						Image: "nginx",
						Ports: []apiv1.ContainerPort{
							{
								ContainerPort: 80,
							},
						},
					},
				},
			},
		},
	}

	nginxDeployemnt := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:   "nginx-deployment",
			Labels: map[string]string{"app": "nginx"},
		},
		Spec: nginxSpec,
	}

	result, err := deploymentClient.Create(context.TODO(), nginxDeployemnt, metav1.CreateOptions{})

	return result, err
}

func delete_nginx_deployment(client v1.DeploymentInterface) error {
	deletepolicy := metav1.DeletePropagationForeground
	err := client.Delete(context.TODO(), "nginx-deployment", metav1.DeleteOptions{
		PropagationPolicy: &deletepolicy,
	})

	return err
}

func update_nginx_deployment(client v1.DeploymentInterface) error {
	err := retry.RetryOnConflict(retry.DefaultRetry, func() error {
		// retrieve the latest version of deployment before attempting update
		// retryonconflict uses exponential backoff to avoid exhausting the apiserver
		result, geterr := client.Get(context.TODO(), "nginx-deployment", metav1.GetOptions{})
		if geterr != nil {
			panic(fmt.Errorf("failed to get latest version of deployment: %v", geterr))
		}

		helper := int32(1)
		result.Spec.Replicas = &helper                               // reduce replica count
		result.Spec.Template.Spec.Containers[0].Image = "nginx:1.16" // change nginx version
		_, updateerr := client.Update(context.TODO(), result, metav1.UpdateOptions{})
		return updateerr
	})

	return err
}

func prompt() {
	fmt.Println("-> press return key to continue, will delete!")
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		fmt.Println(scanner.Text())
		break
	}
	if err := scanner.Err(); err != nil {
		panic(err)
	}
	fmt.Println()
}

func int32ptr(i int32) *int32 { return &i }
