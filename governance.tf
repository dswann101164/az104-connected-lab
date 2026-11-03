# Layer 2: governance and cost

# Policy
#
# The built-in "Require a tag on resources" (871b6d14-...) hardcodes effect = deny,
# so it cannot be used for an Audit assignment. This custom definition is the same
# rule with the effect as a parameter, assigned twice below with different effects.
resource "azurerm_policy_definition" "require_tag" {
  name         = "require-tag-on-resources"
  policy_type  = "Custom"
  mode         = "Indexed" # only resource types that support tags and location
  display_name = "Require a tag on resources (effect parameterized)"
  description  = "Flags or blocks resources missing the named tag. Does not apply to resource groups."

  metadata = jsonencode({ category = "Tags" })

  parameters = jsonencode({
    tagName = {
      type     = "String"
      metadata = { displayName = "Tag name", description = "Name of the tag, such as 'cost_center'." }
    }
    effect = {
      type          = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
      metadata      = { displayName = "Effect" }
    }
  })

  policy_rule = jsonencode({
    if   = { field = "[concat('tags[', parameters('tagName'), ']')]", exists = "false" }
    then = { effect = "[parameters('effect')]" }
  })
}

resource "azurerm_resource_group_policy_assignment" "require_cost_center" {
  name                 = "require-tag-cost-center"
  display_name         = "Require cost_center tag (Deny)"
  resource_group_id    = azurerm_resource_group.lab.id
  policy_definition_id = azurerm_policy_definition.require_tag.id

  parameters = jsonencode({
    tagName = { value = "cost_center" }
    effect  = { value = "Deny" }
  })

  non_compliance_message {
    content = "Every resource in this resource group needs a cost_center tag."
  }
}

resource "azurerm_resource_group_policy_assignment" "require_project" {
  name                 = "require-tag-project"
  display_name         = "Require project tag (Audit)"
  resource_group_id    = azurerm_resource_group.lab.id
  policy_definition_id = azurerm_policy_definition.require_tag.id

  parameters = jsonencode({
    tagName = { value = "project" }
    effect  = { value = "Audit" }
  })

  non_compliance_message {
    content = "Resources in this resource group should carry a project tag."
  }
}

data "azurerm_policy_definition" "allowed_locations" {
  name = "e56962a6-4747-49cd-b67b-bf8b01975c4c" # built-in "Allowed locations"
}

resource "azurerm_resource_group_policy_assignment" "allowed_locations" {
  name                 = "allowed-locations"
  display_name         = "Allowed locations: ${join(", ", var.allowed_locations)} (Deny)"
  resource_group_id    = azurerm_resource_group.lab.id
  policy_definition_id = data.azurerm_policy_definition.allowed_locations.id

  parameters = jsonencode({
    listOfAllowedLocations = { value = var.allowed_locations }
    effect                 = { value = "Deny" }
  })

  non_compliance_message {
    content = "Resources in this resource group may only be deployed to: ${join(", ", var.allowed_locations)}."
  }
}

# Budget

resource "azurerm_consumption_budget_resource_group" "lab" {
  name              = "budget-${var.resource_group_name}"
  resource_group_id = azurerm_resource_group.lab.id
  amount            = var.budget_amount
  time_grain        = "Monthly"

  # Budgets must start on the first of a month. Computed once at create time;
  # ignore_changes stops timestamp() from forcing a new budget on every plan.
  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  dynamic "notification" {
    for_each = toset(var.budget_alert_thresholds)

    content {
      enabled        = true
      threshold      = notification.value
      threshold_type = "Actual"
      operator       = "GreaterThanOrEqualTo"
      contact_emails = var.budget_alert_emails
    }
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}

# Lock
#
# ReadOnly blocks every write and every POST on the storage account, including
# listKeys. Set enable_lock = false and apply before running terraform destroy.
resource "azurerm_management_lock" "storage" {
  count = var.enable_lock ? 1 : 0

  name       = "lock-readonly-${azurerm_storage_account.lab.name}"
  scope      = azurerm_storage_account.lab.id
  lock_level = "ReadOnly"
  notes      = "Layer 2 lab lock. Remove (enable_lock = false) before destroy."

  # Updating the private endpoint writes a privateEndpointConnectionProxy under the
  # storage account, which the lock blocks. Create the lock only after the endpoint.
  depends_on = [azurerm_private_endpoint.blob]
}
