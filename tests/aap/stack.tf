variable vip_ip {
  default = "15.15.15.15"
}

resource "openstack_compute_servergroup_v2" "aap_group" {
  name = "aap_group"
  policies = ["anti-affinity"]
  region = "${var.region}"
} 

resource "openstack_compute_secgroup_v2" "aap_secgroup_icmp_ssh" {
  region = "${var.region}"
  name = "aap_secgroup_icmp_ssh"
  description = "aap_secgroup_icmp_ssh"
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

resource "openstack_networking_network_v2" "aap_net" {
  name = "aap_net"
  admin_state_up = "true"
  region = "${var.region}"
}

resource "openstack_networking_subnet_v2" "aap_subnet" {
  name = "aap_subnet"
  network_id = "${openstack_networking_network_v2.aap_net.id}"
  cidr = "15.15.15.0/24"
  ip_version = 4
  region = "${var.region}"
}

resource "openstack_networking_router_v2" "aap_router" {
  region = "${var.region}"
  name = "aap_router"
}

resource "openstack_networking_router_interface_v2" "aap_router_interface" {
  region = "${var.region}"
  router_id = "${openstack_networking_router_v2.aap_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.aap_subnet.id}"
}

resource "openstack_networking_port_v2" "aap_vip_port" {
  name = "aap_vip_port"
  network_id = "${openstack_networking_network_v2.aap_net.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.aap_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.aap_subnet.id}"
    ip_address = "${var.vip_ip}"
  }
}

resource "openstack_networking_port_v2" "aap_vm1_port" {
  name = "aap_vm1_port"
  network_id = "${openstack_networking_network_v2.aap_net.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.aap_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.aap_subnet.id}"
  }
}

resource "openstack_networking_floatingip_v2" "aap_vm1_fip" {
  region = "${var.region}"
  pool = "public"
  port_id = "${openstack_networking_port_v2.aap_vm1_port.id}"
}

resource "openstack_networking_port_v2" "aap_vm2_port" {
  name = "aap_vm2_port"
  network_id = "${openstack_networking_network_v2.aap_net.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.aap_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.aap_subnet.id}"
  }
}

resource "openstack_networking_floatingip_v2" "aap_vm2_fip" {
  region = "${var.region}"
  pool = "public"
  port_id = "${openstack_networking_port_v2.aap_vm2_port.id}"
}

resource "openstack_networking_port_v2" "aap_bastion_port" {
  name = "aap_bastion_port"
  network_id = "${openstack_networking_network_v2.aap_net.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.aap_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.aap_subnet.id}"
  }
}

resource "openstack_networking_floatingip_v2" "aap_bastion_fip" {
  region = "${var.region}"
  pool = "public"
  port_id = "${openstack_networking_port_v2.aap_bastion_port.id}"
}

resource "openstack_compute_instance_v2" "aap_bastion" {
  depends_on = ["null_resource.add_aap"]
  region = "${var.region}"
  name = "aap_bastion"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network { 
    port = "${openstack_networking_port_v2.aap_bastion_port.id}"
  }
  metadata {
    groups = "aap_secgroup_icmp_ssh"
  }
  key_pair = "${var.key_pair}"
  security_groups = ["aap_secgroup_icmp_ssh"]
  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.aap_group.id}"
  }
  user_data = "${file("userdata-bastion.yml")}"
}

resource "openstack_compute_instance_v2" "aap_vm1" {
  depends_on = ["null_resource.add_aap"]
  name = "aap_vm1"
  region = "${var.region}"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network = {
    port = "${openstack_networking_port_v2.aap_vm1_port.id}"
  }
  metadata {
    groups = "aap_secgroup_icmp_ssh"
  }
  key_pair = "${var.key_pair}"
  security_groups = ["aap_secgroup_icmp_ssh"]
  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.aap_group.id}"
  }
  user_data = "${file("userdata-master.yml")}"
}

resource "openstack_compute_instance_v2" "aap_vm2" {
  depends_on = ["null_resource.add_aap"]
  name = "aap_vm2"
  region = "${var.region}"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network = {
    port = "${openstack_networking_port_v2.aap_vm2_port.id}"
  }
  metadata {
    groups = "aap_secgroup_icmp_ssh"
  }
  key_pair = "${var.key_pair}"
  security_groups = ["aap_secgroup_icmp_ssh"]
  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.aap_group.id}"
  }
  user_data = "${file("userdata-backup.yml")}"
}

resource "null_resource" "add_aap" {
  triggers {
    vm1 = "openstack_networking_port_v2.aap_vm1_port"
    vm2 = "openstack_networking_port_v2.aap_vm2_port"
  }
  provisioner "local-exec" {
    command = "neutron port-update ${openstack_networking_port_v2.aap_vm1_port.id} --allowed_address_pairs list=true type=dict ip_address=${openstack_networking_port_v2.aap_vip_port.fixed_ip.0.ip_address},mac_address=00:00:5e:00:01:33"
  }
  provisioner "local-exec" {
    command = "neutron port-update ${openstack_networking_port_v2.aap_vm2_port.id} --allowed_address_pairs list=true type=dict ip_address=${openstack_networking_port_v2.aap_vip_port.fixed_ip.0.ip_address},mac_address=00:00:5e:00:01:33"
  }
}

output "aap_bastion_ip" {
  value = "${openstack_networking_floatingip_v2.aap_bastion_fip.address}"
}

output "aap_vm1_ip" {
  value = "${openstack_networking_port_v2.aap_vm1_port.fixed_ip.0.ip_address}"
}

output "aap_vm2_ip" {
  value = "${openstack_networking_port_v2.aap_vm2_port.fixed_ip.0.ip_address}"
}

output "aap_vip_ip" {
  value = "${var.vip_ip}"
}
