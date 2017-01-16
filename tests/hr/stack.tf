resource "openstack_compute_secgroup_v2" "hr_secgroup_icmp_ssh" {
  region = "${var.region}"
  name = "hr_secgroup_icmp_ssh"
  description = "hr_secgroup_icmp_ssh"
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

resource "openstack_networking_network_v2" "hr_net_bastion" {
  name = "hr_net_bastion"
  admin_state_up = "true"
  region = "${var.region}"
}

resource "openstack_networking_subnet_v2" "hr_subnet_bastion" {
  name = "hr_subnet_bastion"
  network_id = "${openstack_networking_network_v2.hr_net_bastion.id}"
  cidr = "10.48.48.0/24"
  ip_version = 4
  region = "${var.region}"
}

resource "openstack_networking_network_v2" "hr_net_backend" {
  name = "hr_net_backend"
  admin_state_up = "true"
  region = "${var.region}"
}

resource "openstack_networking_subnet_v2" "hr_subnet_backend" {
  name = "hr_subnet_backend"
  network_id = "${openstack_networking_network_v2.hr_net_backend.id}"
  cidr = "10.88.88.0/24"
  ip_version = 4
  region = "${var.region}"
}

resource "openstack_networking_port_v2" "hr_bastion_port" {
  name = "hr_bastion_port"
  network_id = "${openstack_networking_network_v2.hr_net_bastion.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.hr_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.hr_subnet_bastion.id}"
  }
}

resource "openstack_networking_floatingip_v2" "hr_bastion_fip" {
  region = "${var.region}"
  pool = "public"
  port_id = "${openstack_networking_port_v2.hr_bastion_port.id}"
}

resource "openstack_compute_instance_v2" "hr_bastion" {
  depends_on = ["null_resource.add_host_routes"]
  region = "${var.region}"
  name = "hr_bastion"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network { 
    port = "${openstack_networking_port_v2.hr_bastion_port.id}"
  }
  key_pair = "${var.key_pair}"
  user_data = "#!/bin/bash\n\nscreen -d -m ping ${openstack_networking_port_v2.hr_backend_port.fixed_ip.0.ip_address}"
}

resource "openstack_networking_port_v2" "hr_router_port_bastion" {
  name = "hr_router_port_bastion"
  network_id = "${openstack_networking_network_v2.hr_net_bastion.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.hr_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.hr_subnet_bastion.id}"
  }
}

resource "openstack_networking_port_v2" "hr_router_port_backend" {
  name = "hr_router_port_backend"
  network_id = "${openstack_networking_network_v2.hr_net_backend.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.hr_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.hr_subnet_backend.id}"
  }
}

resource "openstack_compute_instance_v2" "hr_router" {
  depends_on = ["null_resource.add_host_routes"]
  region = "${var.region}"
  name = "hr_router"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network = {
    port = "${openstack_networking_port_v2.hr_router_port_bastion.id}"
  }
  network = {
    port = "${openstack_networking_port_v2.hr_router_port_backend.id}"
  }
  key_pair = "${var.key_pair}"
}

resource "openstack_networking_port_v2" "hr_backend_port" {
  name = "hr_backend_port"
  network_id = "${openstack_networking_network_v2.hr_net_backend.id}"
  admin_state_up = "true"
  security_group_ids = ["${openstack_compute_secgroup_v2.hr_secgroup_icmp_ssh.id}"]
  region = "${var.region}"
  fixed_ip {
    subnet_id = "${openstack_networking_subnet_v2.hr_subnet_backend.id}"
  }
}

resource "openstack_compute_instance_v2" "hr_backend" {
  depends_on = ["null_resource.add_host_routes"]
  region = "${var.region}"
  name = "hr_backend"
  image_id = "${var.image_id}"
  flavor_id = "${var.flavor_id}"
  network = {
    port = "${openstack_networking_port_v2.hr_backend_port.id}"
  }
  key_pair = "${var.key_pair}"
}

resource "null_resource" "add_host_routes" {
  triggers {
    backend = "openstack_networking_subnet_v2.hr_subnet_backend"
    bastion = "openstack_networking_subnet_v2.hr_subnet_bastion"
  }
  provisioner "local-exec" {
    command = "neutron --os-region-name ${var.region} subnet-update ${openstack_networking_subnet_v2.hr_subnet_bastion.id} --host_routes type=dict list=true destination=10.88.88.0/24,nexthop=${openstack_networking_port_v2.hr_router_port_bastion.fixed_ip.0.ip_address} destination=0.0.0.0/0,nexthop=10.48.48.1"
  }
  provisioner "local-exec" {
    command = "neutron --os-region-name ${var.region} subnet-update ${openstack_networking_subnet_v2.hr_subnet_backend.id} --host_routes type=dict list=true destination=10.48.48.0/24,nexthop=${openstack_networking_port_v2.hr_router_port_backend.fixed_ip.0.ip_address} destination=0.0.0.0/0,nexthop=10.88.88.1"
  }
}
