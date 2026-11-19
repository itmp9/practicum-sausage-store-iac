package terratest

import (
	"context"
	"net"
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	compute "github.com/yandex-cloud/go-genproto/yandex/cloud/compute/v1"
	ycsdk "github.com/yandex-cloud/go-sdk/v2"
	"github.com/yandex-cloud/go-sdk/v2/credentials"
	"github.com/yandex-cloud/go-sdk/v2/pkg/options"
)

var state = &terraform.Options{TerraformDir: "..", TerraformBinary: "terraform"}

func cloud(t *testing.T) (context.Context, *ycsdk.SDK) {
	t.Helper()

	keyFile := os.Getenv("TF_VAR_yc_service_account_key_file")
	if keyFile == "" {
		t.Fatal("set TF_VAR_yc_service_account_key_file to the authorized key path")
	}
	creds, err := credentials.ServiceAccountKeyFile(keyFile)
	if err != nil {
		t.Fatalf("load service account: %v", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Minute)
	t.Cleanup(cancel)
	sdk, err := ycsdk.Build(ctx, options.WithCredentials(creds))
	if err != nil {
		t.Fatalf("initialize Yandex Cloud SDK: %v", err)
	}
	t.Cleanup(func() {
		if err := sdk.Shutdown(ctx); err != nil {
			t.Errorf("close Yandex Cloud SDK: %v", err)
		}
	})
	return ctx, sdk
}

func getInstance(t *testing.T, ctx context.Context, sdk *ycsdk.SDK, id string) *compute.Instance {
	t.Helper()

	conn, err := sdk.GetConnection(ctx, "yandex.cloud.compute.v1.InstanceService.Get")
	if err != nil {
		t.Fatalf("connect to Compute API: %v", err)
	}
	instance, err := compute.NewInstanceServiceClient(conn).Get(ctx, &compute.GetInstanceRequest{InstanceId: id})
	if err != nil {
		t.Fatalf("get instance %s: %v", id, err)
	}
	return instance
}

func TestVirtualMachineAvailability(t *testing.T) {
	ctx, sdk := cloud(t)
	for _, environment := range []string{"dev", "prod"} {
		t.Run(environment, func(t *testing.T) {
			prefix := "vm_" + environment
			id := terraform.Output(t, state, prefix+"_id")
			name := terraform.Output(t, state, prefix+"_name")
			address := terraform.Output(t, state, prefix+"_address")

			instance := getInstance(t, ctx, sdk, id)
			if name != "vm-"+environment || instance.GetName() != name {
				t.Fatalf("unexpected name: state=%q, API=%q", name, instance.GetName())
			}
			if instance.GetStatus() != compute.Instance_RUNNING {
				t.Fatalf("instance %s status: %s", name, instance.GetStatus())
			}
			if net.ParseIP(address) == nil || len(instance.GetNetworkInterfaces()) != 1 {
				t.Fatalf("unexpected network configuration for %s", name)
			}
			nat := instance.GetNetworkInterfaces()[0].GetPrimaryV4Address().GetOneToOneNat()
			if nat.GetAddress() != address {
				t.Fatalf("external IP for %s differs between state and Cloud API", name)
			}

			endpoint := net.JoinHostPort(address, "22")
			deadline := time.Now().Add(2 * time.Minute)
			for {
				conn, err := net.DialTimeout("tcp", endpoint, 5*time.Second)
				if err == nil {
					conn.Close()
					return
				}
				if time.Now().After(deadline) {
					t.Fatalf("SSH on %s unavailable: %v", endpoint, err)
				}
				time.Sleep(3 * time.Second)
			}
		})
	}
}
