## Deploying to Many Machines by Hostname

* Queries used to deploy to multiple machines with **specific hostnames** should follow the patterns below.
* Replace the example hostnames with the machines you want to target.


### Package Deployment (Interact)

For **package deployments**, ask the following question in **Interact**.
Once results load, select all machines using the **Select All** checkbox, then choose
**Deploy Action → Continue** with your package deployment.

```sql
Get Computer Name
from all entities
with Computer Name matches ".*(desktop-1|desktop-2|server-1|server-2).*"
```


### Software Deployment (Question Builder)

For **software deployments**, use the following in the **Question Builder**:

Path:
**Software > Deploy > Create Deployment > Endpoints to Target > Question Criteria**

```sql
Computer Name matches ".*(desktop-1|desktop-2|server-1|server-2).*"
```


**Notes**

* `matches` with a regex pattern is used instead of `OR`
* The `.*` ensures partial matches are included
* This approach works whether hostnames include prefixes or suffixes
- This can be scaled up with however many specific machines you need as long as you continue to add | operators in between.

