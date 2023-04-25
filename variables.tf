variable "tags" {
  default = {Env="Demo",CreatedBy="TF",App="MyApp" }
  type = map(any)
}