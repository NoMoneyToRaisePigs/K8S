package gfCSI

import (
	"github.com/container-storage-interface/spec/lib/go/csi"
	"github.com/golang/glog"
	"golang.org/x/net/context"
)

const driverName string = "com.testlocal.gf"
const driverVersion string = "0.1.0"

type IdentityServer struct {
	Name string
}

// func (hp IdentitySrv) GetPluginInfo(ctx context.Context, req *csi.GetPluginInfoRequest) (*csi.GetPluginInfoResponse, error) {
// 	return nil, nil
// }

// func (hp IdentitySrv) GetPluginCapabilities(ctx context.Context, req *csi.GetPluginCapabilitiesRequest) (*csi.GetPluginCapabilitiesResponse, error) {
// 	caps := []*csi.PluginCapability{
// 		{
// 			Type: &csi.PluginCapability_Service_{
// 				Service: &csi.PluginCapability_Service{
// 					Type: csi.PluginCapability_Service_CONTROLLER_SERVICE,
// 				},
// 			},
// 		},
// 	}

// 	return &csi.GetPluginCapabilitiesResponse{Capabilities: caps}, nil
// }

// func (hp IdentitySrv) Probe(ctx context.Context, req *csi.ProbeRequest) (*csi.ProbeResponse, error) {
// 	return nil, nil
// }

func (ids *IdentityServer) GetPluginInfo(ctx context.Context, req *csi.GetPluginInfoRequest) (*csi.GetPluginInfoResponse, error) {
	glog.V(5).Infof("Using default GetPluginInfo")

	return &csi.GetPluginInfoResponse{
		Name:          driverName,
		VendorVersion: driverVersion,
	}, nil
}

func (ids *IdentityServer) Probe(ctx context.Context, req *csi.ProbeRequest) (*csi.ProbeResponse, error) {
	return &csi.ProbeResponse{}, nil
}

func (ids *IdentityServer) GetPluginCapabilities(ctx context.Context, req *csi.GetPluginCapabilitiesRequest) (*csi.GetPluginCapabilitiesResponse, error) {
	glog.V(5).Infof("Using default capabilities")
	return &csi.GetPluginCapabilitiesResponse{
		Capabilities: []*csi.PluginCapability{
			{
				Type: &csi.PluginCapability_Service_{
					Service: &csi.PluginCapability_Service{
						Type: csi.PluginCapability_Service_CONTROLLER_SERVICE,
					},
				},
			},
		},
	}, nil
}
