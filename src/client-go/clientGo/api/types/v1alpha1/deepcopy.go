package crontabv1

import "k8s.io/apimachinery/pkg/runtime"

func (in *Crontab) DeepCopyInto(out *Crontab) {
	out.TypeMeta = in.TypeMeta
	out.ObjectMeta = in.ObjectMeta
	out.Spec = CrontabSpec{
		Replica: in.Spec.Replica,
	}
}

func (in *Crontab) DeepCopyObject() runtime.Object {
	out := Crontab{}
	in.DeepCopyInto(&out)

	return &out
}

func (in *CrontabList) DeepCopyObject() runtime.Object {
	out := CrontabList{}
	out.TypeMeta = in.TypeMeta
	out.ListMeta = in.ListMeta

	if in.Items != nil {
		out.Items = make([]Crontab, len(in.Items))
		for i := range in.Items {
			in.Items[i].DeepCopyInto(&out.Items[i])
		}
	}

	return &out
}
