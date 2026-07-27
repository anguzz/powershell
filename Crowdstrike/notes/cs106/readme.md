# Falcon 106 Dashboards

Falcon Dashboards are interactive visual workspaces within the CrowdStrike Falcon platform that help security teams monitor, analyze, and respond to security data in real time.

Dashboards use built-in visualization tools to display charts and metrics through widgets. These visualizations are managed through the Falcon interface you do not configure chart libraries directly.

---

## Widgets

Widgets are the building blocks of Falcon dashboards.

Each widget represents a chart or visual element that displays data and helps visualize trends, events, or security metrics.

When you add a widget to a dashboard, you are essentially adding a chart that presents data in a specific format.

### Custom Widgets

Custom widgets support a limited set of predefined chart types.

- Fully custom visualizations are not supported.
- If a desired visualization is unavailable, you must select from the supported widget types or use an existing preset widget.

### Choosing the Right Widget

Selecting the appropriate widget type helps ensure that data is presented clearly and supports faster decision-making.

---

## Dashboard Types

### Single-Source Dashboards

Single source dashboards are limited to one data source and cannot display widgets from other Falcon data sources.

### Multi-Source Dashboards

Multi source dashboards allow multiple Falcon data sources to be combined into a single dashboard view.

This provides broader visibility by displaying different security metrics and datasets together.

### Private Dashboards

- Visible only to the dashboard creator.
- Useful for personal analysis and investigations.

### Shared Dashboards

- Accessible to other users within the organization.
- Useful for team collaboration and operational reporting.

### Preset Dashboards

- Provided by CrowdStrike Falcon.
- Cannot be modified.
- Serve as useful starting points for monitoring and reporting.

### Legacy Dashboards

- Original Falcon dashboard framework.
- Provides basic customization using widgets from single or multiple data sources.

### Foundry Dashboards

- Falcon's newer and more advanced dashboard platform.
- Designed for deeper data analysis and custom reporting capabilities.
- Recommended for advanced reporting and insights.

---

## Scheduled Reporting

Dashboards can be scheduled for delivery as recurring reports.

Scheduled reporting is useful for:

- Delivering regular updates to stakeholders
- Maintaining visibility into key metrics
- Reducing the need to manually log into Falcon to review dashboards

### Accessing Scheduled Reports

Navigate to:

**Dashboards and Reports → Scheduled Reporting**