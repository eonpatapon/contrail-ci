variable instances {
  default = "2"
}

resource "openstack_compute_servergroup_v2" "snat_group" {
  name = "snat_group"
  policies = ["anti-affinity"]
  region = "${var.region}"
}

resource "openstack_networking_network_v2" "snat_net" {
  name = "snat_net_${count.index}"
  admin_state_up = "true"
  region = "${var.region}"
  count = "${var.instances}"
}

resource "openstack_networking_subnet_v2" "snat_subnet_net" {
  name = "snat_subnet_net_${count.index}"
  network_id = "${element(openstack_networking_network_v2.snat_net.*.id, count.index)}"
  cidr = "${cidrsubnet("10.22.0.0/16", 8, count.index)}"
  ip_version = 4
  region = "${var.region}"
  count = "${var.instances}"
}

resource "openstack_networking_router_v2" "snat_router" {
  name = "snat_router_${count.index}"
  region = "${var.region}"
  external_gateway = "${var.public_pool_id}"
  count = "${var.instances}"
}

resource "openstack_networking_router_interface_v2" "snat_router_net_itf" {
  region = "${var.region}"
  router_id = "${element(openstack_networking_router_v2.snat_router.*.id, count.index)}"
  subnet_id = "${element(openstack_networking_subnet_v2.snat_subnet_net.*.id, count.index)}"
  count = "${var.instances}"
}

resource "openstack_networking_port_v2" "snat_client_port" {
  network_id = "${element(openstack_networking_network_v2.snat_net.*.id, count.index)}"
  admin_state_up = "true"
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${element(openstack_networking_subnet_v2.snat_subnet_net.*.id, count.index)}"
  }
  count = "${var.instances}"
}

resource "openstack_compute_instance_v2" "snat_client_vm" {
  name = "snat_client_vm_${count.index}"
  region = "${var.region}"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network { 
    port = "${element(openstack_networking_port_v2.snat_client_port.*.id, count.index)}"
  }
  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.snat_group.id}"
  }
  count = "${var.instances}"
  key_pair = "${var.key_pair}"
  user_data = "#!/bin/bash\n\nscreen -d -m ping 8.8.8.8"
}
