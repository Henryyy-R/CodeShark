resource "azurerm_monitor_diagnostic_setting" "env_logs" {
  name                       = "diag-cae-dsk-staging"
  target_resource_id         = azapi_resource.env.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category = "ContainerAppConsoleLogs"
  }

  enabled_log {
    category = "ContainerAppSystemLogs"
  }

  enabled_log {
    category = "ContainerAppHTTPLogs"
  }
}