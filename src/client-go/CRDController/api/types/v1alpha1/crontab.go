package crontabv1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

type CronTabSpec struct {
	CronSpec string `json:"cronSpec"`
	Image    string `json:"image"`
	Replica  string `json:"replicas"`
}

type CronTab struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec CronTabSpec `json:"spec"`
}

type CronTabList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`

	Items []CronTab `json:"items"`
}
