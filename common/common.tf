variable private_key {
  default = "../../common/test-key"
}

variable key_pair {
  default = "test-key"
}

variable public_pool_id {
}

variable image_id {
}

variable flavor_id {
}

variable region {
}

resource "openstack_compute_keypair_v2" "test-key" {
  name = "test-key"
  public_key = "${file("../../common/test-key.pub")}"
}
