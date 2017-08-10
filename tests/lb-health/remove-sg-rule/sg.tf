resource "openstack_compute_secgroup_v2" "lb_secgroup_backend_0" {
  region = "${var.region}"
  name = "lb_secgroup_backend_0"
  description = "lb_secgroup_backend"
  rule {
    from_port = 22
    to_port = 22
    ip_protocol = "tcp"
    #from_group_id = "${openstack_compute_secgroup_v2.lb_secgroup_bastion.id}"
    cidr = "0.0.0.0/0"
  }
  rule {
    from_port = "-1"
    to_port = "-1"
    ip_protocol = "icmp"
    #from_group_id = "${openstack_compute_secgroup_v2.lb_secgroup_bastion.id}"
    cidr = "0.0.0.0/0"
  }
}
