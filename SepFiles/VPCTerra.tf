resource "aws_default_vpc" "default_vpc" {}

resource "aws_default_network_acl" "default_network_acl" {
    default_network_acl_id = "${aws_default_vpc.default_vpc.default_network_acl_id}"

    // No egress or ingress rules defined, therefore no traffic allowed
}

resource "aws_default_security_group" "default_sg" {
    vpc_id = "${aws_default_vpc.default_vpc.id}"
    // No egress or ingress rules defined, therefore no traffic allowed
}
resource "aws_default_route_table" "default_route" {
    default_route_table_id = "${aws_default_vpc.default_vpc.default_route_table_id}"
    route = []
}