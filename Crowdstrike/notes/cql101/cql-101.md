# CrowdStrike Webinar CQL & Event Model Notes

Notes from CQL 101 Webinar 


## What Are Events

In Falcon Next-Gen SIEM (LogScale), **events** are the core unit of data.

* Raw log data is **ingested and parsed**
* Parsers convert raw text into **field-value pairs**
* Each event contains structured data used for querying

### Guaranteed Fields

Every event includes some built-in metadata fields:

```
#repo
#type
@id
@ingesttimestamp
@rawstring
@timestamp
```

These exist on all events and can be used for filtering and analysis.

***

## Field Types

CQL uses different field types based on prefixes. Understanding these is key for writing efficient queries.

### Tags (`#fields`)

* Prefixed with `#`
* Example: `#vendor`, `#repo`
* Indexed heavily on the backend

**Why they matter:**

* Very fast to filter on
* Reduce how much data needs to be decompressed

```
#vendor="CrowdStrike"
```

***

### Metadata Fields (`@fields`)

* Prefixed with `@`
* Describe the event itself (not the content)

Examples:

* `@timestamp`
* `@rawstring`
* `@id`

***

### User Fields (Standard Fields)

* No prefix
* Most commonly used fields in queries

Examples:

* `user.email`
* `source.address`
* `event.action`

**Key point:**

* Still performant, especially when used early in filtering
* Most day-to-day work happens here

***

## Query Execution Model (Best Practices)

Efficient queries generally follow this order:

```
1. Filter
2. Transform
3. Aggregate
4. Post-process
```

You won’t always hit every step, but this is the **ideal pattern**.

***

### 1. Filtering (Most Important Step)

Filtering reduces the amount of data that must be processed.

**Why it matters:**

* Data is stored compressed
* Decompression is expensive
* Less data = faster query

Example:

```
#vendor="CrowdStrike"
user.name="tyler"
```

**Rule:**

> More filtering = less decompression = faster query

***

### 2. Transform

Transforms make data easier to read or compute.

Common use cases:

* Convert timestamps
* Perform math
* Clean or format fields

Examples:

```
total := end - start
ratings := round(ratings)
```

***

### 3. Aggregate

Aggregation summarizes data to tell a story.

Most common function: `groupBy()`

Example:

```
| groupBy([source.ip])
```

Advanced example:

```
| groupBy(
    [source.address],
    function=[count(field=user.email, as="Unique Users", distinct=true)]
)
```

What this does:

* Groups by source address
* Counts distinct users per address

***

### 4. Post-Processing

Refinement after aggregation.

Examples:

```
failed_logins > 5
| sort(total)
```

***

## Performance Principles

### Data Processing

* Data is stored **compressed**
* Queries must decompress data to inspect it
* Decompression is the most expensive operation

**Key takeaway:**

> Filter as early as possible to reduce work

***

### Measuring Efficiency

Use the **Work** metric.

* Lower work = more efficient query
* Compare similar queries to optimize

```
Lower work + same result = better query
```

> Small differences (\~4–5%) usually aren’t worth optimizing

***

### Optimization Strategy

* First: make the query work
* Then: optimize only if reused frequently

***

## Wildcards

Used for partial matching.

Examples:

```
user.email = john*
user.email = *@example.co
user.email != *example.co
```

### Notes

* Case sensitive by default
* Can ignore case with function:

```
wildcard(field=user.email, pattern="Angel*", ignoreCase=true)
```

***

## Regex

CQL uses a regex engine similar to PCRE (based on JITREX).

***

### Basic Usage

```
user.email=/carla/
source.address=/vuln/i
```

* `/pattern/` = regex
* `i` = case insensitive

***

### Capture Groups (Field Extraction)

Extract values into new fields:

```
user.email=/(?<user.name>\w+)@/
user.email=/@(?<user.domain>.*)/
```

Combined:

```
user.email=/^(?<user.name>\w+)@(?<user.domain>.*)/
```

***

### Pattern Matching

```
source.address=/^(vuln|host)\-0[234]/i
```

Matches:

* vuln-02, host-03, etc.

***

### Escaping

There is no shortcut for escaping entire strings.

You must escape manually:

```
john\@
```

***

## Eval (`:=`)

Primary way to assign values.

### Syntax

```
field := value
```

Equivalent to:

```
eval(field=value)
```

***

### Examples

```
result := 5 + 7
address := lower(source.address)
```

***

### Important Gotcha

```
field := value   // references field "value"
field := "value" // assigns string
```

***

## In Function

Simplifies multiple OR conditions.

### Example

```
event.action="login" OR event.action="logout"
```

Becomes:

```
in(field=event.action, values=["login", "logout"])
```

***

### Exclusion

```
!in(field=user.email, values=["*@example.co"])
```

***

## Case Statements (Conditionals)

Used for branching logic.

```
| case {
    condition1 | result1;
    condition2 | result2;
    * | default;
}
```

### Key Behavior

* Evaluated top → bottom
* Only first match runs
* `*` = catch-all

***

## GroupBy (Core Concept)

Most important function in CQL.

### Basic

```
| groupBy([user.email])
```

***

### Advanced

```
| groupBy(
    [source.address],
    function=[collect([user.email])]
)
```

***

### Nested Example

```
| groupBy(
    [source.address],
    function=[
        groupBy(
            [user.email],
            function=[collect([event.outcome])]
        )
    ]
)
```

***

## Match Function (Lookup Enrichment)

Adds external data from lookup files.

### Basic

```
| match(file="cql101.csv", field=[source.address], column=[host])
```

***

### Options

* `strict=false` → keep non-matching events (left join)
* `include=[field]` → select fields from lookup
* `mode=glob` → wildcard matching

***

## Additional Notes

### createEvents()

* Used to generate test data
* **Does NOT count toward ingestion limits**
* Data never enters pipeline

***

### Renaming Fields

```
field2 := rename(field="field1")  // renames
field2 := field1                 // clones
```

***

### Quotes

* Double quotes (`"`) used for string values
* Important in functions like `in()`

***

## Practical Tips

* Use filtering first to improve performance
* Use user fields for most logic
* Use tags when possible for speed
* Use `groupBy()` frequently
* Hover over functions in UI for help
* Use documentation:


# References

- https://library.humio.com

- https://community.crowdstrike.com/cql-cps-user-group-111/cql-101-webinar-material-3704 

- https://library.humio.com/data-analysis/dashboards-create.html

- https://library.humio.com/data-analysis/repositories-files-ui-create.html#repositories-files-ui-loading-files

- https://falconpy.io/


## summary

* Events = parsed field-value data
* Filtering early is the biggest performance win
* Tags (`#`) = fastest filters
* `groupBy()` = most important function
* Use Work metric to validate efficiency
* Regex and wildcard help with flexible matching
* Build query first, optimize later



# CQL 101 Lab Setup

This setup provides a **practice dashboard and lookup file** for learning CrowdStrike CQL (Next-Gen SIEM / LogScale).

## Files Included

* `cql101_webinar.yaml` — Dashboard with example queries
* `cql101.csv` — Lookup file used in `match()` examples

***

## Dashboard Import

1. Download and unzip the `cql101.zip` file
2. Go to:
   ```
   Falcon → Next-Gen SIEM → Log Management → Dashboards
   ```
3. Click **Create dashboard**
4. Select **Import dashboard**
5. Upload:
   ```
   cql101_webinar.yaml
   ```
6. (Optional) Rename the dashboard
7. Keep **Repository/View = All**
8. Click **Import**

***

## Lookup File Import

1. Go to:
   ```
   Falcon → Next-Gen SIEM → Log Management → Lookup files
   ```
2. Click **Create file**
3. Select **Import file**
4. Upload:
   ```
   cql101.csv
   ```
5. **Do NOT rename the file** (required by dashboard queries)
6. Keep **Repository/View = All**
7. Click **Import**

***

## Usage Notes

* The dashboard uses `createEvents()` to generate sample data
* You can modify queries freely — this is meant for practice
* Lookup file is used in `match()` examples for enrichment

