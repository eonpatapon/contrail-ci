resource "openstack_networking_network_v2" "lb_vip_sg_net_backend" {
  name = "lb_vip_sg_net_backend"
  admin_state_up = "true"
  region = "${var.region}"
}

resource "openstack_networking_subnet_v2" "lb_vip_sg_subnet_backend" {
  name = "lb_vip_sg_subnet_backend"
  network_id = "${openstack_networking_network_v2.lb_vip_sg_net_backend.id}"
  cidr = "10.65.65.0/24"
  ip_version = 4
  region = "${var.region}"
}

resource "openstack_networking_port_v2" "lb_vip_sg_port_backend_0" {
  network_id = "${openstack_networking_network_v2.lb_vip_sg_net_backend.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.lb_vip_sg_secgroup_backend.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.lb_vip_sg_subnet_backend.id}"
  }
}

resource "openstack_networking_port_v2" "lb_vip_sg_port_backend_1" {
  network_id = "${openstack_networking_network_v2.lb_vip_sg_net_backend.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.lb_vip_sg_secgroup_backend.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.lb_vip_sg_subnet_backend.id}"
  }
}

resource "openstack_compute_secgroup_v2" "lb_vip_sg_secgroup_backend" {
  region = "${var.region}"
  name = "lb_vip_sg_secgroup_backend"
  description = "lb_vip_sg_secgroup_backend"
  rule {
    from_port = 80
    to_port = 80
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
    from_group_id = ""
  }
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

resource "openstack_lb_pool_v1" "lb_vip_sg_pool_backend" {
  name = "lb_vip_sg_pool_backend"
  protocol = "HTTP"
  subnet_id = "${openstack_networking_subnet_v2.lb_vip_sg_subnet_backend.id}"
  lb_method = "ROUND_ROBIN"
  region = "${var.region}"
}

resource "openstack_lb_vip_v1" "lb_vip_sg_vip" {
  name = "lb_vip_sg_vip"
  subnet_id = "${openstack_networking_subnet_v2.lb_vip_sg_subnet_backend.id}"
  protocol = "HTTP"
  port = 80
  pool_id = "${openstack_lb_pool_v1.lb_vip_sg_pool_backend.id}"
  region = "${var.region}"
  admin_state_up = "true"
}

resource "openstack_lb_member_v1" "lb_vip_sg_member_backend_0" {
  pool_id = "${openstack_lb_pool_v1.lb_vip_sg_pool_backend.id}"
  address = "${openstack_networking_port_v2.lb_vip_sg_port_backend_0.fixed_ip.0.ip_address}"
  port = 80
  region = "${var.region}"
  admin_state_up = "true"
}

resource "openstack_lb_member_v1" "lb_vip_sg_member_backend_1" {
  pool_id = "${openstack_lb_pool_v1.lb_vip_sg_pool_backend.id}"
  address = "${openstack_networking_port_v2.lb_vip_sg_port_backend_1.fixed_ip.0.ip_address}"
  port = 80
  region = "${var.region}"
  admin_state_up = "true"
}

resource "openstack_compute_instance_v2" "lb_vip_sg_backend_0" {
  region = "${var.region}"
  name = "lb_vip_sg_backend_0"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network {
    port = "${openstack_networking_port_v2.lb_vip_sg_port_backend_0.id}"
  }
  key_pair = "${var.key_pair}"
  user_data = "${file("userdata-backend.yml")}"
}

resource "openstack_compute_instance_v2" "lb_vip_sg_backend_1" {
  region = "${var.region}"
  name = "lb_vip_sg_backend_1"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network {
    port = "${openstack_networking_port_v2.lb_vip_sg_port_backend_1.id}"
  }
  key_pair = "${var.key_pair}"
  user_data = "${file("userdata-backend.yml")}"
}

resource "openstack_networking_floatingip_v2" "lb_vip_sg_fip_vip" {
  region = "${var.region}"
  pool = "public"
  port_id = "${openstack_lb_vip_v1.lb_vip_sg_vip.port_id}"
}

resource "openstack_networking_floatingip_v2" "lb_vip_sg_fip_backend_0" {
  region = "${var.region}"
  pool = "public"
  port_id = "${openstack_networking_port_v2.lb_vip_sg_port_backend_0.id}"
}

resource "openstack_compute_secgroup_v2" "lb_vip_sg_secgroup" {
  region = "${var.region}"
  name = "lb_vip_sg_secgroup"
  description = "lb_vip_sg_secgroup"
  rule {
    from_port = "-1"
    to_port = "-1"
    ip_protocol = "icmp"
    cidr = "0.0.0.0/0"
    from_group_id = ""
  }
}

output "lb_vip_sg_vip_ip" {
  value = "${openstack_networking_floatingip_v2.lb_vip_sg_fip_vip.address}"
}

output "lb_vip_sg_backends_ip" {
  value = ["${openstack_networking_port_v2.lb_vip_sg_port_backend_0.fixed_ip.0.ip_address}",
           "${openstack_networking_port_v2.lb_vip_sg_port_backend_1.fixed_ip.0.ip_address}"] 
}
