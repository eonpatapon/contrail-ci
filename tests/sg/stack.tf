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
    uuid = "${openstack_networking_network_v2.sg_net.id}"
  }
  key_pair = "${var.key_pair}"
  security_groups = ["${openstack_compute_secgroup_v2.sg_secgroup.id}"]

  connection {
    host = "${self.network.0.fixed_ip_v4}"
    type = "ssh"
    user = "cloud"
    private_key = "${file(var.private_key)}"
    bastion_host = "${openstack_networking_floatingip_v2.sg_vm2_fip.address}"
    bastion_user = "cloud"
    bastion_private_key = "${file(var.private_key)}"
  }

  provisioner "remote-exec" {
    inline = [
      "ip a",
      "ip r",
      "ping -c 2 ${openstack_networking_port_v2.sg_vm2_port.fixed_ip.0.ip_address}",
      "screen -d -m ping ${openstack_networking_port_v2.sg_vm2_port.fixed_ip.0.ip_address}",
      // http://stackoverflow.com/questions/36207752/how-can-i-start-a-remote-service-using-terraform-provisioning
      "sleep 1",
    ]
  }
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

  connection {
    host = "${openstack_networking_floatingip_v2.sg_vm2_fip.address}"
    type = "ssh"
    user = "cloud"
    private_key = "${file(var.private_key)}"
  }

  provisioner "remote-exec" {
    inline = [
      "ip a",
      "ip r",
    ]
  }
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

resource "openstack_networking_floatingip_v2" "sg_vm2_fip" {
  region = "${var.region}"
  pool = "public"
  port_id = "${openstack_networking_port_v2.sg_vm2_port.id}"
}
