variable public_pool_id {
}

variable image_id {
}

variable flavor_id {
}

variable region {
}

variable key_pair {
  type = "string"
}

variable key_path {
  type = "string"
}

resource "openstack_compute_keypair_v2" "test-key" {
  name = "${var.key_pair}"
  public_key = "${file("${var.key_path}")}"
}
