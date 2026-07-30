include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "${get_repo_root()}//modules/kms"
}

inputs = {
  key_deletion_window_days = include.root.locals.env_vars.locals.key_deletion_window_days
  enable_key_rotation      = true
}
