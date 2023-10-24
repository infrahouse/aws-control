locals {
  me_arn       = "arn:aws:iam::990466748045:user/aleks"
  instance_arn = tolist(data.aws_ssoadmin_instances.sso.arns)[0]
}
