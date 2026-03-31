import {
  to = aws_controltower_landing_zone.root
  id = "253SSA9Y0WZPC0ZN"
}

resource "aws_controltower_landing_zone" "root" {
  manifest_json = file("${path.module}/files/LandingZoneManifest.json")
  version       = "3.3"
}
