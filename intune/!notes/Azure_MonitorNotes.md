
# Setup azure VM monitoring + notes
- Goal: we want to make dashboards with azure monitoring that monitor azure vm processes, cpu util, etc.


##  Azure Monitoring Services
| Layer                            | What It Does                                                                        | Example in Your Project                                    |
| -------------------------------- | ----------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| **Azure Monitor**                | The umbrella service that collects, analyzes, and acts on telemetry from resources. | The foundation of all dashboards/alerts.                   |
| **Log Analytics Workspace**      | Central store for logs and performance data.                                        | Where VM metrics, event logs, and custom data are sent.    |
| **Azure Metrics**                | Lightweight performance counters (CPU, memory, etc.) collected at 1-min intervals.  | Used for CPU/disk utilization charts.                      |
| **Azure Alerts**                 | Rules that trigger actions (emails, SMS, Logic App) when thresholds are hit.        | “If CPU > 90% for 10 mins, send email.”                    |
| **Azure Dashboards / Workbooks** | Visualization layer.                                                                | Graphs and tiles showing resource health, CPU trends, etc. |
| **Azure Monitor Agent (AMA)**    | The modern data collection agent installed on VMs.                                  | Needed to send data (event logs, performance metrics).     |
| **Action Groups**                | Define *who* or *what* to notify (email, Teams, SMS, webhook, etc.).                | Send alerts to IT             |


## Azure resource hierachy
- Subscription -> resource group -> Resource (vm/storage/etc)
- We setup scope tied to each of these levels (per sub, per resource)

## VM monitoring pipeline
- vm sends metrics -> goes to analytics workspace ->alerts/dashboards visualize it
- without the ama agent no metrics


## KQL 
Kusto Query Language (KQL) is used to log analystics in query logs
- like sql for monitoring dashboards and workbooks.

```sql
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize avg(CounterValue) by bin(TimeGenerated, 5m), Computer
```


# Setup Monitoring on VMs.
My notes/process on setting up azure monitoring on vms.

*Optional: go to azure portal: search vms and skip to step 3*

 1) Go to  https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/virtualMachines

 2) Go to `monitor -> virtual machines -> configure insights`
 - Here we can see VMS that are `not monitored` and their corresponding resource group

3) Go to on one of the VMs

4) Under the `virtual machines | Insights page`  configure `enhanced monitoring`.

Here you should have two metric types that report differently. Add the one you need or both, both install the AMA monitoring agent.
- `OpenTelemetry metrics` go to `Azure monitor workspaces`  AMA sends data to a Log Analytics workspace
- `Log-based metrics` go to `Log Analytics workspace`: AMA additionally streams a subset of telemetry to the Azure Monitor Metrics backend
- Either can be added to a dashboard/workgroup once its setup

### Important note:
Going to a VMs insights page will automatically generate azure monitoring and create a default data collection rule following `MSVMI-region-vm-name` format.

It will actually now show up as a monitored vm under https://portal.azure.com/#view/Microsoft_Azure_Monitoring/AzureMonitoringBrowseBlade/~/virtualMachines and if we click under our performance tab.

I found some more info on this at https://learn.microsoft.com/en-us/azure/azure-monitor/vm/vminsights-enable?tabs=portal#prerequisites, if no agents are onboarded this area will not populate.


### Dashboards vs workbooks

| Tool                | Use Case                                        | Description                                                       |
| ------------------- | ----------------------------------------------- | ----------------------------------------------------------------- |
| **Azure Dashboard** | Quick visual overview across multiple resources | Tiles you can pin from anywhere in the portal                     |
| **Azure Workbook**  | Rich, interactive visualization & queries       | Uses KQL (Log Analytics queries) for charts, filters, time ranges |

I personally setup dashboards for my use case since since I just want basic info.

### Github community kql queries
- https://github.com/microsoft/AzureMonitorCommunity


### Note: Export queries easily

1) Go to Log analytics workspace 
2) Go to logs
3) Queries hub opens automatically or Click New query
5) Choose a query
6) Hit run
7) Save as function to seee the code block, copy paste it and export it for re-use
*optionally, Pin to a custom dashboard*
