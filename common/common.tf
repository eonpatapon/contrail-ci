variable private_key {
  default = "../../common/test-key"
}

variable key_pair {
  default = "test-key"
}

variable public_pool_id {
  default = "ec92b9e1-6d07-4a8d-901c-ebd992c31af3"
}

variable image_id {
  default = "3dc0ed38-943a-47c9-aa11-acde51bdad3f"
}

variable flavor_id {
  default = "1"
}

variable region {
  default = "lab2"
}

resource "openstack_compute_keypair_v2" "test-key" {
  name = "test-key"
  public_key = "${file("../../common/test-key.pub")}"
}
