terraform {
  backend "gcs" {
    bucket = "<your-project-id>-terraform-state"
    prefix = "terraform/state"
  }
}
