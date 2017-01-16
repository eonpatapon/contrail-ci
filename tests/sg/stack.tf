resource "openstack_compute_secgroup_v2" "sg_secgroup" {
  region = "${var.region}"
  name = "sg_secgroup"
  description = "sg_secgroup"
  rule {
    from_port = "-1"
    to_port = "-1"
    ip_protocol = "icmp"
    cidr = "0.0.0.0/0"
    from_group_id = ""
  }
  rule {
    from_port = "22"
    to_port = "22"
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
    from_group_id = ""
  }
}

resource "openstack_networking_network_v2" "sg_net" {
  name = "sg_net"
  admin_state_up = "true"
  region = "${var.region}"
}

resource "openstack_networking_subnet_v2" "sg_subnet" {
  name = "sg_subnet"
  network_id = "${openstack_networking_network_v2.sg_net.id}"
  cidr = "10.33.44.0/24"
  ip_version = 4
  region = "${var.region}"
}

resource "openstack_compute_instance_v2" "sg_vm1" {
  region = "${var.region}"
  name = "sg_vm1"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network {
    port = "${openstack_networking_port_v2.sg_vm1_port.id}"
  }
  key_pair = "${var.key_pair}"
  user_data = "#!/bin/bash\n\nscreen -d -m ping ${openstack_networking_port_v2.sg_vm2_port.fixed_ip.0.ip_address}"
}

resource "openstack_networking_port_v2" "sg_vm1_port" {
  network_id = "${openstack_networking_network_v2.sg_net.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.sg_secgroup.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.sg_subnet.id}"
  }
}

resource "openstack_networking_floatingip_v2" "sg_vm1_fip" {
  region = "${var.region}"
  pool = "public"
  port_id = "${openstack_networking_port_v2.sg_vm1_port.id}"
}

resource "openstack_compute_instance_v2" "sg_vm2" {
  region = "${var.region}"
  name = "sg_vm2"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network {
    port = "${openstack_networking_port_v2.sg_vm2_port.id}"
  }
  key_pair = "${var.key_pair}"
}

resource "openstack_networking_port_v2" "sg_vm2_port" {
  network_id = "${openstack_networking_network_v2.sg_net.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.sg_secgroup.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.sg_subnet.id}"
  }
}
