resource "openstack_compute_servergroup_v2" "aap_fw_group" {
  name = "aap_fw_group"
  policies = ["anti-affinity"]
  region = "${var.region}"
} 

resource "openstack_compute_secgroup_v2" "aap_fw_secgroup_icmp_ssh" {
  region = "${var.region}"
  name = "aap_fw_secgroup_icmp_ssh"
  description = "aap_fw_secgroup_icmp_ssh"
  rule {
    from_port = 22
    to_port = 22
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
    from_group_id = ""
  }
  rule {
    from_port = "-1"
    to_port = "-1"
    ip_protocol = "icmp"
    cidr = "0.0.0.0/0"
    from_group_id = ""
  }
}

resource "openstack_networking_network_v2" "aap_fw_net_admin" {
  name = "aap_fw_net_admin"
  admin_state_up = "true"
  region = "${var.region}"
}

resource "openstack_networking_subnet_v2" "aap_fw_subnet_admin" {
  name = "aap_fw_subnet_admin"
  network_id = "${openstack_networking_network_v2.aap_fw_net_admin.id}"
  cidr = "10.44.0.0/24"
  ip_version = 4
  region = "${var.region}"
/*
  host_routes {
    destination_cidr = "10.66.0.0/24"
    next_hop = "10.44.0.200"
  }
  host_routes {
    destination_cidr = "0.0.0.0/0"
    next_hop = "10.44.0.1"
  }
*/
}

resource "openstack_networking_router_v2" "aap_fw_router" {
  region = "${var.region}"
  name = "aap_fw_router"
  external_gateway = "${var.public_pool_id}"
}

resource "openstack_networking_router_interface_v2" "aap_fw_router_interface" {
  region = "${var.region}"
  router_id = "${openstack_networking_router_v2.aap_fw_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.aap_fw_subnet_admin.id}"
}

resource "openstack_networking_network_v2" "aap_fw_net_backend" {
  name = "aap_fw_net_backend"
  admin_state_up = "true"
  region = "${var.region}"
}

resource "openstack_networking_subnet_v2" "aap_fw_subnet_backend" {
  name = "aap_fw_subnet_backend"
  network_id = "${openstack_networking_network_v2.aap_fw_net_backend.id}"
  cidr = "10.66.0.0/24"
  ip_version = 4
  region = "${var.region}"
/*
  host_routes {
    destination_cidr = "10.44.0.0/24"
    next_hop = "10.66.0.200"
  }
  host_routes {
    destination_cidr = "0.0.0.0/0"
    next_hop = "10.66.0.200"
  }
*/
}

resource "openstack_networking_port_v2" "aap_fw_bastion_port" {
  name = "aap_fw_bastion_port"
  network_id = "${openstack_networking_network_v2.aap_fw_net_admin.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.aap_fw_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.aap_fw_subnet_admin.id}"
  }
}

resource "openstack_networking_floatingip_v2" "aap_fw_bastion_fip" {
  region = "${var.region}"
  pool = "public"
  port_id = "${openstack_networking_port_v2.aap_fw_bastion_port.id}"
}

resource "openstack_compute_instance_v2" "aap_fw_bastion" {
  region = "${var.region}"
  name = "aap_fw_bastion"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network { 
    port = "${openstack_networking_port_v2.aap_fw_bastion_port.id}"
  }
  key_pair = "${var.key_pair}"
  user_data = "#!/bin/bash\n\nscreen -d -m ping ${openstack_networking_port_v2.aap_fw_vm1_port.fixed_ip.0.ip_address}"
}

resource "openstack_networking_port_v2" "aap_fw_fw1_port_backend" {
  name = "aap_fw_fw1_port_backend"
  network_id = "${openstack_networking_network_v2.aap_fw_net_backend.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.aap_fw_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.aap_fw_subnet_backend.id}"
  }
  allowed_address_pairs {
    ip_address = "10.66.0.200"
    mac_address = "00:00:5e:00:01:42"
  }
}

resource "openstack_networking_port_v2" "aap_fw_fw1_port_admin" {
  name = "aap_fw_fw1_port_admin"
  network_id = "${openstack_networking_network_v2.aap_fw_net_admin.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.aap_fw_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.aap_fw_subnet_admin.id}"
  }
  allowed_address_pairs {
    ip_address = "10.44.0.200"
    mac_address = "00:00:5e:00:01:2c"
  }
}

resource "openstack_compute_instance_v2" "aap_fw_fw1" {
  name = "aap_fw_fw1"
  region = "${var.region}"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network = {
    port = "${openstack_networking_port_v2.aap_fw_fw1_port_admin.id}"
  }
  network = {
    port = "${openstack_networking_port_v2.aap_fw_fw1_port_backend.id}"
  }
  key_pair = "${var.key_pair}"
  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.aap_fw_group.id}"
  }
  user_data = "${file("userdata-master.yml")}"
}

resource "openstack_networking_port_v2" "aap_fw_fw2_port_backend" {
  name = "aap_fw_fw2_port_backend"
  network_id = "${openstack_networking_network_v2.aap_fw_net_backend.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.aap_fw_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.aap_fw_subnet_backend.id}"
  }
  allowed_address_pairs {
    ip_address = "10.66.0.200"
    mac_address = "00:00:5e:00:01:42"
  }
}

resource "openstack_networking_port_v2" "aap_fw_fw2_port_admin" {
  name = "aap_fw_fw2_port_admin"
  network_id = "${openstack_networking_network_v2.aap_fw_net_admin.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.aap_fw_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.aap_fw_subnet_admin.id}"
  }
  allowed_address_pairs {
    ip_address = "10.44.0.200"
    mac_address = "00:00:5e:00:01:2c"
  }
}

resource "openstack_compute_instance_v2" "aap_fw_fw2" {
  name = "aap_fw_fw2"
  region = "${var.region}"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network = {
    port = "${openstack_networking_port_v2.aap_fw_fw2_port_admin.id}"
  }
  network = {
    port = "${openstack_networking_port_v2.aap_fw_fw2_port_backend.id}"
  }
  key_pair = "${var.key_pair}"
  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.aap_fw_group.id}"
  }
  user_data = "${file("userdata-slave.yml")}"
}

resource "openstack_networking_port_v2" "aap_fw_vm1_port" {
  name = "aap_fw_vm1_port"
  network_id = "${openstack_networking_network_v2.aap_fw_net_backend.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.aap_fw_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.aap_fw_subnet_backend.id}"
  }
}

resource "openstack_compute_instance_v2" "aap_fw_vm1" {
  name = "aap_fw_vm1"
  region = "${var.region}"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network = {
    port = "${openstack_networking_port_v2.aap_fw_vm1_port.id}"
  }
  key_pair = "${var.key_pair}"
  user_data = "#!/bin/bash\n\nscreen -d -m ping 8.8.8.8"
}

resource "null_resource" "add_host_route_backend" {
  triggers {
    backend = "openstack_networking_subnet_v2.aap_fw_subnet_backend.id"
  }
  provisioner "local-exec" {
    command = "neutron --os-region-name ${var.region} subnet-update ${openstack_networking_subnet_v2.aap_fw_subnet_backend.id} --host_routes type=dict list=true destination=10.44.0.0/24,nexthop=10.66.0.200 destination=0.0.0.0/0,nexthop=10.66.0.200"
  }
}

resource "null_resource" "add_host_route_admin" {
  triggers {
    admin = "openstack_networking_subnet_v2.aap_fw_subnet_admin.id"
  }
  provisioner "local-exec" {
    command = "neutron --os-region-name ${var.region} subnet-update ${openstack_networking_subnet_v2.aap_fw_subnet_admin.id} --host_routes type=dict list=true destination=10.66.0.0/24,nexthop=10.44.0.200 destination=0.0.0.0/0,nexthop=10.44.0.1"
  }
}

output "aap_fw_bastion_ip" {
  value = "${openstack_networking_floatingip_v2.aap_fw_bastion_fip.address}"
}
