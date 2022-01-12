package crontabv1

import "k8s.io/apimachinery/pkg/runtime"

func (in *CronTab) DeepCopyInto(out *CronTab) {
	out.TypeMeta = in.TypeMeta
	out.ObjectMeta = in.ObjectMeta
	out.Spec = CronTabSpec{
		Replica: in.Spec.Replica,
	}
}

func (in *CronTab) DeepCopyObject() runtime.Object {
	out := CronTab{}
	in.DeepCopyInto(&out)

	return &out
}

func (in *CronTabList) DeepCopyObject() runtime.Object {
	out := CronTabList{}
	out.TypeMeta = in.TypeMeta
	out.ListMeta = in.ListMeta

	if in.Items != nil {
		out.Items = make([]CronTab, len(in.Items))
		for i := range in.Items {
			in.Items[i].DeepCopyInto(&out.Items[i])
		}
	}

	return &out
}
