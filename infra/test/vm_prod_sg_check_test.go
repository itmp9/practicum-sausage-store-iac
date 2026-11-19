package terratest

import (
	"slices"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	vpc "github.com/yandex-cloud/go-genproto/yandex/cloud/vpc/v1"
)

func TestProdSecurityGroup(t *testing.T) {
	ctx, sdk := cloud(t)
	instanceID := terraform.Output(t, state, "vm_prod_id")
	groupID := terraform.Output(t, state, "prod_security_group_id")
	groupName := terraform.Output(t, state, "prod_security_group_name")

	instance := getInstance(t, ctx, sdk, instanceID)
	interfaces := instance.GetNetworkInterfaces()
	if len(interfaces) != 1 || !slices.Equal(interfaces[0].GetSecurityGroupIds(), []string{groupID}) {
		t.Fatalf("prod instance must use only security group %s", groupID)
	}
	conn, err := sdk.GetConnection(ctx, "yandex.cloud.vpc.v1.SecurityGroupService.Get")
	if err != nil {
		t.Fatalf("connect to VPC API: %v", err)
	}
	group, err := vpc.NewSecurityGroupServiceClient(conn).Get(ctx, &vpc.GetSecurityGroupRequest{SecurityGroupId: groupID})
	if err != nil {
		t.Fatalf("get prod security group: %v", err)
	}
	if group.GetName() != groupName || groupName != "sausage-store-prod" {
		t.Fatalf("unexpected group name: state=%q, API=%q", groupName, group.GetName())
	}

	ports := map[int64]bool{22: false, 8200: false}
	var outbound bool
	for _, rule := range group.GetRules() {
		switch rule.GetDirection() {
		case vpc.SecurityGroupRule_INGRESS:
			port := rule.GetPorts().GetFromPort()
			if _, expected := ports[port]; !expected || rule.GetPorts().GetToPort() != port || rule.GetProtocolName() != "TCP" {
				t.Fatalf("unexpected inbound rule %s", rule.GetId())
			}
			ports[port] = true
		case vpc.SecurityGroupRule_EGRESS:
			if rule.GetProtocolName() == "ANY" && slices.Contains(rule.GetCidrBlocks().GetV4CidrBlocks(), "0.0.0.0/0") {
				outbound = true
			}
		}
	}
	if !ports[22] || !ports[8200] || !outbound {
		t.Fatal("expected inbound TCP 22 and 8200 and outbound access")
	}
}
