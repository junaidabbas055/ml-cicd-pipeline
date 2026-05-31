"""
Pulumi program — OpenStack private cloud provisioning.
Equivalent to the Terraform stack but using Pulumi Python SDK.
Demonstrates IaC flexibility: same infrastructure, different toolchain.

Deploy:
    pulumi stack init dev
    pulumi config set openstack:cloud devcloud
    pulumi up
"""

import pulumi
import pulumi_openstack as openstack

config  = pulumi.Config()
env     = config.get("environment") or "dev"
prefix  = f"infra-{env}"
key_pair = config.require("keyPair")

# ── Network ──────────────────────────────────────────────────────────────────
network = openstack.networking.Network(
    f"{prefix}-network",
    admin_state_up=True,
    port_security_enabled=True,
)

subnet = openstack.networking.Subnet(
    f"{prefix}-subnet",
    network_id=network.id,
    cidr="192.168.10.0/24",
    ip_version=4,
    dns_nameservers=["8.8.8.8", "8.8.4.4"],
    allocation_pools=[openstack.networking.SubnetAllocationPoolArgs(
        start="192.168.10.10",
        end="192.168.10.200",
    )],
)

external_network = openstack.networking.get_network(external=True, name="public")

router = openstack.networking.Router(
    f"{prefix}-router",
    admin_state_up=True,
    external_network_id=external_network.id,
)

openstack.networking.RouterInterface(
    f"{prefix}-router-iface",
    router_id=router.id,
    subnet_id=subnet.id,
)

# ── Security Groups ───────────────────────────────────────────────────────────
base_sg = openstack.networking.SecGroup(
    f"{prefix}-base-sg",
    description="Base SG — deny all inbound except SSH from bastion",
)

openstack.networking.SecGroupRule(
    f"{prefix}-egress-all",
    direction="egress",
    ethertype="IPv4",
    security_group_id=base_sg.id,
)

openstack.networking.SecGroupRule(
    f"{prefix}-ssh-bastion",
    direction="ingress",
    ethertype="IPv4",
    protocol="tcp",
    port_range_min=22,
    port_range_max=22,
    remote_ip_prefix="10.0.0.0/8",
    security_group_id=base_sg.id,
)

web_sg = openstack.networking.SecGroup(f"{prefix}-web-sg")

for port, name in [(80, "http"), (443, "https")]:
    openstack.networking.SecGroupRule(
        f"{prefix}-{name}",
        direction="ingress",
        ethertype="IPv4",
        protocol="tcp",
        port_range_min=port,
        port_range_max=port,
        remote_ip_prefix="0.0.0.0/0",
        security_group_id=web_sg.id,
    )

# ── Compute Instances ─────────────────────────────────────────────────────────
anti_affinity_group = openstack.compute.ServerGroup(
    f"{prefix}-anti-affinity",
    policies=["anti-affinity"],
)

app_instances = []
for i in range(2):
    inst = openstack.compute.Instance(
        f"{prefix}-app-{i+1}",
        flavor_name="m1.medium",
        image_name="Ubuntu-22.04",
        key_pair=key_pair,
        security_groups=[base_sg.name, web_sg.name],
        networks=[openstack.compute.InstanceNetworkArgs(name=network.name)],
        scheduler_hints=[openstack.compute.InstanceSchedulerHintArgs(
            group=anti_affinity_group.id,
        )],
        metadata={
            "environment": env,
            "managed-by": "pulumi",
            "role": "app",
        },
    )
    app_instances.append(inst)

    volume = openstack.blockstorage.Volume(
        f"{prefix}-app-{i+1}-data",
        size=50,
        volume_type="ceph-ssd",
    )
    openstack.compute.VolumeAttach(
        f"{prefix}-app-{i+1}-vol-attach",
        instance_id=inst.id,
        volume_id=volume.id,
    )

# ── Exports ───────────────────────────────────────────────────────────────────
pulumi.export("network_id",   network.id)
pulumi.export("subnet_id",    subnet.id)
pulumi.export("router_id",    router.id)
pulumi.export("app_instance_ids", [i.id for i in app_instances])
pulumi.export("app_instance_ips", [i.access_ip_v4 for i in app_instances])
