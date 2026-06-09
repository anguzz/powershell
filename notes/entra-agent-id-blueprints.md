
# Agent identity blueprints in Microsoft Entra Agent ID 

I read an article on agent blueprints and thought it was interesting. To better understand them and how they compare to service principals/app registrations, I created these notes which also include sum up of the security/risk considerations.


First it's important to just quickly note the enterprise app model.

```shell
Normal App Model
----------------
App Registration
    ↓
Service Principal (Enterprise App)
 ├─ Identity
    ├─ Permissions
    └─ Credentials
```
In the traditional Entra ID model:
- The app registration acts as the application definition/template.
- The service principal (enterprise application) is the tenant-side identity.
- The service principal directly authenticates and receives permissions/tokens.

This helps us visualize the difference in the agent ID model.


```shell
Agent ID Model
---------------
Agent Blueprint
    ├─ defines allowed/inheritable permissions
    ├─ stores credentials
    └─ acts like the master template

        ↓ instantiated into tenant

Blueprint Principal
    ├─ tenant-local representation
    ├─ stores consented permissions
    ├─ manages child agent identities
    └─ can create new agents

        ↓ creates/manages

Agent Identity A
    ├─ receives inherited perms
    ├─ authenticates via blueprint token exchange
    └─ acts as actual AI runtime identity

Agent Identity B
Agent Identity C
```


This model can roughly be understood as:
- Blueprint says: "these permissions are ALLOWED to be inherited"
- Blueprint Principal says: "these permissions are CONSENTED in this tenant (similar to a service principal used for agent id)"
- Agent Identity says: "ok now I actually RECEIVE them in my token"



## Risk 
Inherited permissions are hard to enumerate directly because you can only inspect the agent identity object, which does not show all the permissions.

Instead these would be under the blueprint, and blueprint principal, which shows us inheritance rules and consent grants. This makes permission analysis more complex than traditional enterprise applications.

This makes blueprints a high value target, if an attacker compromises a blueprint credential, it controls many agents.The blueprint itself becomes an attack vector (as well as the blueprint principal it creates)

The blueprint becomes a major attack surface because it is effectively the “root trust object” for all child agent identities This makes the blueprint credential is more important than the child identities themselves.

## References: 

https://learn.microsoft.com/en-us/entra/agent-id/agent-blueprint

https://blog.compass-security.com/2026/06/entra-agent-id-from-a-security-perspective/
