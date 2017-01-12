resource "openstack_compute_secgroup_v2" "sg_secgroup" {
  region = "${var.region}"
  name = "sg_secgroup"
  description = "sg_secgroup"
  rule {
    from_port = "22"
    to_port = "22"
    ip_protocol = "tcp"
    cidr = "0.0.0.0/0"
    from_group_id = ""
  }
}
