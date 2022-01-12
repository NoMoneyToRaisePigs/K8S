package crontabv1

import (
	"context"
	crontabv1 "test/api/types/v1alpha1"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/rest"
)

const ResourceName = "crontabs"

type CronTabInterface interface {
	List(opts metav1.ListOptions) (*crontabv1.CronTabList, error)
	Get(name string, options metav1.GetOptions) (*crontabv1.CronTab, error)
	Create(*crontabv1.CronTab) (*crontabv1.CronTab, error)
	Watch(opts metav1.ListOptions) (watch.Interface, error)
	Delete(name string, option metav1.DeleteOptions) (*crontabv1.CronTab, error)
}

type cronTabClient struct {
	restClient rest.Interface
	ns         string
}

func (client *cronTabClient) List(opts metav1.ListOptions) (*crontabv1.CronTabList, error) {
	result := crontabv1.CronTabList{}
	err := client.restClient.Get().Namespace(client.ns).Resource(ResourceName).VersionedParams(&opts, scheme.ParameterCodec).Do(context.TODO()).Into(&result)

	if err != nil {
		panic(err)
	}

	return &result, err
}

func (client *cronTabClient) Get(name string, opts metav1.GetOptions) (*crontabv1.CronTab, error) {
	result := crontabv1.CronTab{}
	err := client.restClient.Get().Namespace(client.ns).Resource(ResourceName).Name(name).VersionedParams(&opts, scheme.ParameterCodec).Do(context.TODO()).Into(&result)

	if err != nil {
		panic(err)
	}

	return &result, err
}

func (client *cronTabClient) Create(crontab *crontabv1.CronTab) (*crontabv1.CronTab, error) {
	result := crontabv1.CronTab{}

	err := client.restClient.Post().Name(client.ns).Resource(ResourceName).Body(crontab).Do(context.TODO()).Into(&result)

	if err != nil {
		panic(err)
	}

	return &result, err
}

func (client *cronTabClient) Delete(name string, opts metav1.DeleteOptions) (*crontabv1.CronTab, error) {
	result := crontabv1.CronTab{}

	err := client.restClient.Delete().Name(client.ns).Resource(ResourceName).Name(name).VersionedParams(&opts, scheme.ParameterCodec).Do(context.TODO()).Into(&result)
	if err != nil {
		panic(err)
	}

	return &result, err
}

func (client *cronTabClient) Watch(opts metav1.ListOptions) (watch.Interface, error) {
	opts.Watch = true

	return client.restClient.Get().Namespace(client.ns).Resource(ResourceName).VersionedParams(&opts, scheme.ParameterCodec).Watch(context.TODO())
}
