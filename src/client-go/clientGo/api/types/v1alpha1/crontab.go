package crontabv1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

type CrontabSpec struct {
	CronSpec string `json:"cronSpec"`
	Image    string `json:"image"`
	Replica  string `json:"replicas"`
}

type Crontab struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec CrontabSpec `json:"spec"`
}

type CrontabList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`

	Items []Crontab `json:"items"`
}
