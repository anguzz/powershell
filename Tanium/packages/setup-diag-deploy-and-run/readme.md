# Endpoint Diagnostic – SetupDiag setup and execution

## Overview

This Tanium package deploys and executes **Microsoft SetupDiag** to analyze Windows Feature Update failures (e.g., 23H2 to 24H2).

The utility parses Windows setup logs and identifies upgrade blocking conditions.

---

## Package Name

**Endpoint Diagnostic – SetupDiag Execution**

---

## Deployment Behavior

* Creates folder:

  ```
  C:\SetupDiag\
  ```
* Downloads latest SetupDiag from Microsoft:

  ```
  https://go.microsoft.com/fwlink/?linkid=870142
  ```
* Executes SetupDiag
* Generates:

  ```
  C:\SetupDiag\setupdiagresults.log
  C:\SetupDiag\Logs.zip
  ```

---

## Tanium Configuration

**Run Command:**
`cmd.exe /c powershell.exe -ExecutionPolicy bypass -WindowStyle Hidden -NonInteractive -NoProfile -File setupDiag.ps1`

**Verification Query:**

```
File Exists["C:\SetupDiag\SetupDiag.exe"] contains "C:\SetupDiag\SetupDiag.exe"
```

**Command Timeout:**

```
5 minutes (300 seconds)
```

This is required because SetupDiag can take several minutes to process Panther and Rollback logs.

---

## Output Files

| File                   | Purpose                |
| ---------------------- | ---------------------- |
| `SetupDiag.exe`        | Diagnostic utility     |
| `SetupDiag.exe.config` | Runtime configuration  |
| `setupdiagresults.log` | Rule match results     |
| `Logs.zip`             | Collected upgrade logs |

---

## Operational Workflow

1. Deploy package to target endpoint.
2. Wait for action completion.
3. Direct connect to endpoint.
4. Retrieve:

   ```
   C:\SetupDiag\setupdiagresults.log
   C:\SetupDiag\Logs.zip
   ```
5. Review rule output and identified failure reason.

---

# Important Behavior Notes

##  Empty setupdiagresults.log

If the log is empty or near 0 KB:

This typically means one of the following:

* No upgrade failure logs were found.
* No blocking rules matched.
* The machine has not experienced a recent feature update failure.
* SetupDiag completed but no actionable rule triggered.

This is **not necessarily a failure**

---


## Improvement Considerations

This package combines download and execution into a single workflow for simplicity and speed of deployment. While separating the binary deployment and execution into two distinct package and a software deployment would provide more granular control, reusability, and cleaner operational separation, the current single-package design allows for rapid, one-step diagnostics without additional orchestration. This makes it practical for targeted troubleshooting scenarios where speed and ease of deployment are prioritized over modular design.
