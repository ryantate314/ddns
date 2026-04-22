resource "aws_resourcegroups_group" "ddns" {
  name        = "ddns"
  description = "All resources tagged Project=ddns (the DDNS provider stack)."

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
