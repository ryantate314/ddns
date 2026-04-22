resource "aws_resourcegroups_group" "ddns" {
  name        = "ddns"
  description = "Dynamic DNS for Home Lab Wireguard"

  resource_query {
    type = "TAG_FILTERS_1_0"

    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Project"
          Values = ["ddns"]
        }
      ]
    })
  }
}
