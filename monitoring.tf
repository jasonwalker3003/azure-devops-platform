variable "alert_email" {
  description = "Email address for monitoring alerts"
  type        = string
}

resource "azurerm_log_analytics_workspace" "law" {
  name                = "log-${local.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_application_insights" "appi" {
  name                = "appi-${local.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "web"
}

resource "azurerm_application_insights_standard_web_test" "site" {
  name                    = "webtest-${local.prefix}"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  application_insights_id = azurerm_application_insights.appi.id
  geo_locations           = ["emea-gb-db3-azr", "emea-se-sto-edge", "emea-nl-ams-azr"]
  frequency               = 300
  timeout                 = 30
  enabled                 = true

  request {
    url = "http://${azurerm_public_ip.pip.ip_address}"
  }

  validation_rules {
    expected_status_code = 200
  }

  tags = {
    "hidden-link:${azurerm_application_insights.appi.id}" = "Resource"
  }
}

resource "azurerm_monitor_action_group" "email" {
  name                = "ag-${local.prefix}"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "dpalerts"

  email_receiver {
    name                    = "me"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_metric_alert" "site_down" {
  name                = "alert-site-down-${local.prefix}"
  resource_group_name = azurerm_resource_group.rg.name
  scopes = [
    azurerm_application_insights_standard_web_test.site.id,
    azurerm_application_insights.appi.id,
  ]
  description = "Website failed availability checks from 2 or more locations"
  severity    = 1
  frequency   = "PT1M"
  window_size = "PT5M"

  application_insights_web_test_location_availability_criteria {
    web_test_id           = azurerm_application_insights_standard_web_test.site.id
    component_id          = azurerm_application_insights.appi.id
    failed_location_count = 2
  }

  action {
    action_group_id = azurerm_monitor_action_group.email.id
  }
}
