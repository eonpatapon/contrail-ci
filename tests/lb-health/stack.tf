variable instances {
  default = "2"
}

variable cloudinit {
  default = "cloudinit.yml"
}

##################
# Template Files #
##################

data "template_file" "bastion_cinit" {
    template = "${file("userdata-bastion.yml")}"

    vars {
        vip = "${openstack_lb_vip_v1.lb_vip.address}"
    }
}

###########
# Network #
###########

resource "openstack_networking_network_v2" "lb_net_backend" {
  name = "lb_net_backend"
  admin_state_up = "true"
  region = "${var.region}"
}

resource "openstack_networking_network_v2" "lb_net_bastion" {
  name = "lb_net_bastion"
  admin_state_up = "true"
  region = "${var.region}"
}

##########
# Subnet #
##########

resource "openstack_networking_subnet_v2" "lb_subnet_backend" {
  name = "lb_subnet_backend"
  network_id = "${openstack_networking_network_v2.lb_net_backend.id}"
  cidr = "10.65.65.0/24"
  ip_version = 4
  region = "${var.region}"
}


resource "openstack_networking_subnet_v2" "lb_subnet_bastion" {
  name = "lb_subnet_bastion"
  network_id = "${openstack_networking_network_v2.lb_net_bastion.id}"
  cidr = "10.35.35.0/24"
  ip_version = 4
  region = "${var.region}"
}

########
# Port #
########

resource "openstack_networking_port_v2" "lb_port_bastion" {
  network_id = "${openstack_networking_network_v2.lb_net_bastion.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.lb_secgroup_bastion.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.lb_subnet_bastion.id}"
  }
}

resource "openstack_networking_port_v2" "lb_port_backend_0" {
  network_id = "${openstack_networking_network_v2.lb_net_backend.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.lb_secgroup_backend_0.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.lb_subnet_backend.id}"
  }
}

resource "openstack_networking_port_v2" "lb_port_backend_1" {
  network_id = "${openstack_networking_network_v2.lb_net_backend.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.lb_secgroup_backend_1.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.lb_subnet_backend.id}"
  }
}

##################
# Security Group #
##################

resource "openstack_compute_secgroup_v2" "lb_secgroup_bastion" {
  region = "${var.region}"
  name = "lb_secgroup_bastion"
  description = "lb_secgroup_bastion"
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

resource "openstack_compute_secgroup_v2" "lb_secgroup_backend_0" {
  region = "${var.region}"
  name = "lb_secgroup_backend_0"
  description = "lb_secgroup_backend_0"
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

resource "openstack_compute_secgroup_v2" "lb_secgroup_backend_1" {
  region = "${var.region}"
  name = "lb_secgroup_backend_1"
  description = "lb_secgroup_backend_1"
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

##########
# Router #
##########

resource "openstack_networking_router_v2" "lb_router" {
  region = "${var.region}"
  name = "lb_router"
}

#####################
# Router Interfaces #
#####################

resource "openstack_networking_router_interface_v2" "lb_router_bastion_itf" {
  region = "${var.region}"
  router_id = "${openstack_networking_router_v2.lb_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.lb_subnet_bastion.id}"
}

resource "openstack_networking_router_interface_v2" "lb_router_backend_itf" {
  region = "${var.region}"
  router_id = "${openstack_networking_router_v2.lb_router.id}"
  subnet_id = "${openstack_networking_subnet_v2.lb_subnet_backend.id}"
}

###########
# LB Pool #
###########

resource "openstack_lb_pool_v1" "lb_pool_backend" {
  name = "lb_pool_backend"
  #protocol = "TCP"
  protocol = "HTTP"
  subnet_id = "${openstack_networking_subnet_v2.lb_subnet_backend.id}"
  lb_method = "ROUND_ROBIN"
  #lb_method = "LEAST_CONNECTIONS"
  region = "${var.region}"
  #monitor_ids = ["${openstack_lb_monitor_v1.lb_monitor.id}"]
}

##############
# LB Monitor #
##############

resource "openstack_lb_monitor_v1" "lb_monitor" {
  region = "${var.region}"
  type = "HTTP"
  delay = 10
  timeout = 5
  max_retries = 3
  admin_state_up = "true"
  url_path = "/index.html"
  http_method = "GET"
  expected_codes = "200"
}

##########
# LB VIP #
##########

resource "openstack_lb_vip_v1" "lb_vip" {
  name = "lb_vip"
  subnet_id = "${openstack_networking_subnet_v2.lb_subnet_backend.id}"
  protocol = "HTTP"
  port = 80
  pool_id = "${openstack_lb_pool_v1.lb_pool_backend.id}"
  region = "${var.region}"
  admin_state_up = "true"
}


#############
# LB Member #
#############

resource "openstack_lb_member_v1" "lb_member_backend_0" {
  pool_id = "${openstack_lb_pool_v1.lb_pool_backend.id}"
  address = "${openstack_networking_port_v2.lb_port_backend_0.fixed_ip.0.ip_address}"
  port = 80
  region = "${var.region}"
  admin_state_up = "true"
}

resource "openstack_lb_member_v1" "lb_member_backend_1" {
  pool_id = "${openstack_lb_pool_v1.lb_pool_backend.id}"
  address = "${openstack_networking_port_v2.lb_port_backend_1.fixed_ip.0.ip_address}"
  port = 80
  region = "${var.region}"
  admin_state_up = "true"
}

################
# Server Group #
################

resource "openstack_compute_servergroup_v2" "lb_group_backend" {
  name = "lb_group_backend"
  policies = ["anti-affinity"]
  region = "${var.region}"
}

###########
# Backend #
###########

resource "openstack_compute_instance_v2" "lb_backend_0" {
  region = "${var.region}"
  name = "lb_backend_0"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network {
    port = "${openstack_networking_port_v2.lb_port_backend_0.id}"
  }
  metadata {
    groups = "lb_backend"
  }
  key_pair = "${var.key_pair}"
  security_groups = ["lb_secgroup_backend_0"]
  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.lb_group_backend.id}"
  }
  user_data = "${file("userdata-backend.yml")}"
}

resource "openstack_compute_instance_v2" "lb_backend_1" {
  region = "${var.region}"
  name = "lb_backend_1"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network {
    port = "${openstack_networking_port_v2.lb_port_backend_1.id}"
  }
  metadata {
    groups = "lb_backend"
  }
  key_pair = "${var.key_pair}"
  security_groups = ["lb_secgroup_backend_1"]
  scheduler_hints {
    group = "${openstack_compute_servergroup_v2.lb_group_backend.id}"
  }
  user_data = "${file("userdata-backend.yml")}"
}

###########
# Bastion #
###########

resource "openstack_compute_instance_v2" "bastion" {
  region = "${var.region}"
  name = "lb_bastion"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network {
    port = "${openstack_networking_port_v2.lb_port_bastion.id}"
  }
  metadata {
    groups = "lb_secgroup_bastion"
  }
  key_pair = "${var.key_pair}"
  security_groups = ["lb_secgroup_bastion"]
  user_data = "${data.template_file.bastion_cinit.rendered}"
}

###############
# Floating IP #
###############

resource "openstack_networking_floatingip_v2" "lb_fip_vip" {
  region = "${var.region}"
  pool = "public"
  port_id = "${openstack_lb_vip_v1.lb_vip.port_id}"
}

resource "openstack_networking_floatingip_v2" "lb_fip_bastion" {
  region = "${var.region}"
  pool = "public"
  port_id = "${openstack_networking_port_v2.lb_port_bastion.id}"
}

##########
# Output #
##########

output "lb_vip_ip" {
  value = "${openstack_networking_floatingip_v2.lb_fip_vip.address}"
}

output "lb_bastion_ip" {
  value = "${openstack_networking_floatingip_v2.lb_fip_bastion.address}"
}

output "lb_backends_ip" {
  value = ["${openstack_networking_port_v2.lb_port_backend_0.fixed_ip.0.ip_address}",
"${openstack_networking_port_v2.lb_port_backend_1.fixed_ip.0.ip_address}"] 
}
