# **Tanium Gateway & GraphQL API – notes**

This folder will contain Gateway and GraphQL api scripts. Below are my notes on the docs and some trainings I did.


# docs: 
- https://help.tanium.com/bundle/ug_gateway_cloud/page/gateway/gateway_examples.html

- https://fbm.cloud.tanium.com/ui/gateway/


# **1. Overview: What Tanium Gateway Does**

Tanium Gateway acts as a **bridge between external scripts/applications** and the Tanium platform.

### **Key capabilities**

| Capability              | Description                                                           |
| -- |  |
| **Endpoint Data**       | GraphQL queries for online + offline endpoints using TDS-cached data. |
| **Deploy Actions**      | Run scripts, install software, add/remove tags, execute commands.     |
| **Patch Deployment**    | Push patch actions programmatically.                                  |
| **Interface Discovery** | See what API capabilities exist from introspection.                   |
| **Custom Integrations** | Build automation (Python/PowerShell/Go/etc.) to interact with Tanium. |



# **2. Tanium Data Service (TDS)**

TDS stores **registered sensor data** centrally so API queries do NOT need to request fresh sensor evaluation.

This means:

* Queries return **cached**, near-real-time data.
* Large dataset queries (e.g., "all missing patches") run **instantly**.
* Only sensors marked as **registered** are collected for TDS.

**Examples of automatically registered sensors:**

* Computer Name
* IP Address
* Installed Applications
* Drive Space

If you don't see a field in GraphQL, you may need to **register the sensor** in the Console.



# **3. GraphQL Basics (Gateway Query Syntax)**

GraphQL is structured like **JSON without values**, and the API returns **JSON matching the shape of your query**.

### **Minimal Query Example**


```
query {
  endpoints {
    edges {
      node {
        id
        name
        ipAddress
        os {
          name
          platform
        }
      }
    }
  }
}
```

The structure always follows:

```
object -> edges -> node -> fields
```

### **Get all fields from a device**

- Good for visibility on what exists on a type to help us write further queries.

```
{
  __type(name: "Endpoint") {
    fields { name }
  }
}
```


# **4. Filtering Endpoints**

Filters allow you to target specific machines **before retrieving data**.

### **Example: Filter by OS platform (Linux)**

```
query filteredEndpoints($filter: EndpointFieldFilter) {
  endpoints(filter: $filter) {
    edges {
      node {
        name
        os {
          platform
        }
      }
    }
  }
}


```


# **5. Filtering Linked Objects (Installed Applications, Tags, etc.)**

"Left-side filters" apply to **nested objects** inside an endpoint.

### **Example: Endpoints where Installed Applications contain "Python"**



```
{
  endpoints {
    edges {
      node {
        name
        installedApplications(
          filter: {
            path: "name"
            op: CONTAINS
            value: "Python"
          }
        ) {
          name
          version
        }
      }
    }
  }
}


```



# **6. Pagination (FIRST / LAST / AFTER / BEFORE / CURSOR)**

Large datasets require pagination.

### **Get first 10 endpoints**

```
query {
  endpoints(first: 10) {
    edges {
      node { name id }
    }
    pageInfo {
      startCursor
      endCursor
      hasNextPage
      hasPreviousPage
    }
  }
}
```


# **7. Example Query Library (Copy & Paste)**


### **Get hostname + IP**

```
{
  endpoints {
    edges {
      node {
        name
        ipAddress
      }
    }
  }
}
```

### **Get Installed Software List**

```
{
  endpoints {
    edges {
      node {
        name
        installedApplications {
          name
          version
        }
      }
    }
  }
}
```

### **Get Tags for a Device**

```
{
  endpoints {
    edges {
      node {
        name
        CustomTags { name }
      }
    }
  }
}
```





# **8. REST Call Format (curl)**

### **Generic curl example**

```bash
curl -X POST "https://<gateway>/api/v2/graphql" \
 -H "Authorization: Bearer $TOKEN" \
 -H "Content-Type: application/json" \
 -d "{\"query\":\"{ endpoints { edges { node { name } } } }\"}"
```



# **9. Understanding the Workflow**

### **To automate anything in Tanium Gateway:**

1. **Write a GraphQL query**
   (retrieve endpoint IDs, tags, apps, OS, etc.)

2. **Feed input into a mutation**
   (`createAction → addTags`, `deployAction`, etc.)

3. **(Optional)** Poll via cursor pagination to monitor action progress.

4. **Integrate into PowerShell/Python**
   → Loop hosts from CSV
   → Apply actions at scale



# **10. Common Mutations You Will Use**

| Mutation             | Purpose                                            |
| -- | -- |
| **createAction**     | Execute scripts, add/remove tags, install software |
| **cancelAction**     | Stop an action                                     |
| **createSavedQuery** | Save reusable queries                              |
| **deleteSavedQuery** | Remove saved queries                               |

### **Add Tag Mutation (quick template)**

```graphql
mutation AddTag($id: String!, $tag: String!) {
  createAction(input: {
    name: "Tagging Task",
    targetGroup: { endpoints: [$id] },
    addTags: [$tag]
  }) {
    id
  }
}
```



# **13. Notes & Gotchas**

* **Cursors expire every 5 minutes** → never store them.
* TDS only includes **registered sensors**.
* Nested filters require **FieldFilter** types.
* Every response is wrapped in:

  ```
  data → endpoints → edges → node
  ```
* Calling GraphQL is **always** a `POST` to `/api/v2/graphql`.



# More queries

Using this to discover all types and better visualize the data i can reach.
```
query findAllTypes {
  __schema {
    types {
      name
      kind
      fields {
        name
        type {
          name
          kind
        }
      }
    }
  }
}
```

This discovers all the types in taniums graphQL. 
