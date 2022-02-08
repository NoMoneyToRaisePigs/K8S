package main

import (
	"flag"
	"fmt"
	"net"
	"os"
	"strings"

	gfCSI "gf.com/csi/Service"
	"github.com/container-storage-interface/spec/lib/go/csi"
	"github.com/golang/glog"
	"google.golang.org/grpc"
)

func main() {
	endpoint := flag.String("endpoint", "unix://tmp/csi.sock", "CSI endpoint")
	flag.Parse()

	proto, addr, err := ParseEndpoint(*endpoint)
	if err != nil {
		glog.Fatal(err.Error())
	}

	if proto == "unix" {
		addr = "/" + addr
		if err := os.Remove(addr); err != nil && !os.IsNotExist(err) {
			glog.Fatalf("Failed to remove %s, error: %s", addr, err.Error())
		}
	}

	fmt.Println("hello csi")

	// listener, err := net.Listen(proto, "../unixsock_test.sock")
	listener, err := net.Listen(proto, addr)
	if err != nil {
		glog.Fatalf("Failed to listen: %v", err)
	}

	server := grpc.NewServer()
	identityServer := gfCSI.IdentityServer{}
	controllerServer := gfCSI.ControllerServer{
		ServiceCapabilities: []csi.ControllerServiceCapability_RPC_Type{
			csi.ControllerServiceCapability_RPC_CREATE_DELETE_VOLUME,
		},
	}
	nodeServer := gfCSI.NodeServer{}

	csi.RegisterIdentityServer(server, &identityServer)
	csi.RegisterControllerServer(server, &controllerServer)
	csi.RegisterNodeServer(server, &nodeServer)

	glog.Infof("Listening for connections on address: %#v", listener.Addr())

	server.Serve(listener)
}

func ParseEndpoint(ep string) (string, string, error) {
	if strings.HasPrefix(strings.ToLower(ep), "unix://") || strings.HasPrefix(strings.ToLower(ep), "tcp://") {
		s := strings.SplitN(ep, "://", 2)
		if s[1] != "" {
			return s[0], s[1], nil
		}
	}
	return "", "", fmt.Errorf("Invalid endpoint: %v", ep)
}
