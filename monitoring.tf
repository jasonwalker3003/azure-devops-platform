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

resource "azurerm_monitor_data_collection_rule" "vm" {
  name                = "dcr-${local.prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "Linux"

  destinations {
    log_analytics {
      name                  = "law"
      workspace_resource_id = azurerm_log_analytics_workspace.law.id
    }
  }

  data_flow {
    streams      = ["Microsoft-Syslog", "Microsoft-Perf"]
    destinations = ["law"]
  }

  data_sources {
    syslog {
      name           = "syslog"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "daemon", "syslog", "user"]
      log_levels     = ["Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
    }

    performance_counter {
      name                          = "perf"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "Processor(*)\\% Processor Time",
        "Memory(*)\\% Used Memory",
        "Logical Disk(*)\\% Used Space",
      ]
    }
  }
}

resource "azurerm_virtual_machine_extension" "ama" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = true
}

resource "azurerm_monitor_data_collection_rule_association" "vm" {
  name                    = "dcra-${local.prefix}"
  target_resource_id      = azurerm_linux_virtual_machine.vm.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.vm.id
}
