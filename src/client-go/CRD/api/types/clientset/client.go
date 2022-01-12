package crontabv1

import (
	crontabv1 "test/api/types/v1alpha1"

	"k8s.io/apimachinery/pkg/runtime/schema"

	// "k8s.io/apimachinery/pkg/runtime/serializer"
	"k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/rest"
)

type ExampleV1Alpha1Interface interface {
	CronTabs(namespace string) CronTabInterface
}

type ExampleV1Alpha1Client struct {
	restClient rest.Interface
}

func NewForConfig(c *rest.Config) (*ExampleV1Alpha1Client, error) {
	config := *c
	config.ContentConfig.GroupVersion = &schema.GroupVersion{Group: crontabv1.GroupName, Version: crontabv1.GroupVersion}
	config.APIPath = "/apis"
	config.NegotiatedSerializer = scheme.Codecs.WithoutConversion()
	config.UserAgent = rest.DefaultKubernetesUserAgent()

	client, err := rest.RESTClientFor(&config)
	if err != nil {
		return nil, err
	}

	return &ExampleV1Alpha1Client{restClient: client}, nil
}

func (client *ExampleV1Alpha1Client) CronTabs(namespace string) CronTabInterface {
	return &cronTabClient{
		restClient: client.restClient,
		ns:         namespace,
	}
}
