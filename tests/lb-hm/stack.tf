variable instances {
  default = "2"
}

resource "openstack_networking_network_v2" "lb_hm_net" {
  name = "lb_hm_net"
  admin_state_up = "true"
  region = "${var.region}"
}

resource "openstack_networking_subnet_v2" "lb_hm_subnet" {
  name = "lb_hm_subnet"
  network_id = "${openstack_networking_network_v2.lb_hm_net.id}"
  cidr = "10.47.47.0/24"
  ip_version = 4
  region = "${var.region}"
}

resource "openstack_networking_port_v2" "lb_hm_port" {
  network_id = "${openstack_networking_network_v2.lb_hm_net.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.lb_hm_secgroup.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.lb_hm_subnet.id}"
  }
  count = "${var.instances}"
}

resource "openstack_compute_secgroup_v2" "lb_hm_secgroup" {
  region = "${var.region}"
  name = "lb_hm_secgroup"
  description = "lb_hm_secgroup"
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

resource "openstack_compute_secgroup_v2" "lb_hm_secgroup_no_http" {
  region = "${var.region}"
  name = "lb_hm_secgroup_no_http"
  description = "lb_hm_secgroup_no_http"
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

resource "openstack_lb_pool_v1" "lb_hm_pool" {
  name = "lb_pool"
  protocol = "HTTP"
  subnet_id = "${openstack_networking_subnet_v2.lb_hm_subnet.id}"
  lb_method = "ROUND_ROBIN"
  region = "${var.region}"
  monitor_ids = ["${openstack_lb_monitor_v1.lb_hm_monitor.id}"]
}

resource "openstack_lb_monitor_v1" "lb_hm_monitor" {
  region = "${var.region}"
  type = "HTTP"
  delay = 1
  timeout = 1
  max_retries = 3
  admin_state_up = "true"
  url_path = "/"
  http_method = "GET"
  expected_codes = "200"
}

resource "openstack_lb_vip_v1" "lb_hm_vip" {
  name = "lb_hm_vip"
  subnet_id = "${openstack_networking_subnet_v2.lb_hm_subnet.id}"
  protocol = "HTTP"
  port = 80
  pool_id = "${openstack_lb_pool_v1.lb_hm_pool.id}"
  region = "${var.region}"
  admin_state_up = "true"
}

resource "openstack_lb_member_v1" "lb_hm_member" {
  pool_id = "${openstack_lb_pool_v1.lb_hm_pool.id}"
  address = "${openstack_networking_port_v2.lb_hm_port.*.fixed_ip.0.ip_address[count.index]}"
  port = 80
  region = "${var.region}"
  admin_state_up = "true"
  count = "${var.instances}"
}

resource "openstack_compute_instance_v2" "lb_hm_backend" {
  region = "${var.region}"
  name = "lb_hm_backend_${count.index}"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network {
    port = "${openstack_networking_port_v2.lb_hm_port.*.id[count.index]}"
  }
  key_pair = "${var.key_pair}"
  user_data = "${file("userdata-backend.yml")}"
  count = "${var.instances}"
}

resource "openstack_networking_floatingip_v2" "lb_hm_fip_vip" {
  region = "${var.region}"
  pool = "public"
  port_id = "${openstack_lb_vip_v1.lb_hm_vip.port_id}"
}

output "lb_hm_vip_ip" {
  value = "${openstack_networking_floatingip_v2.lb_hm_fip_vip.address}"
}
