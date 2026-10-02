# Glossary

Words used in code, tickets and ADRs. If a word is missing, add it in the same PR that introduces it.

| Term | Meaning | Not to be confused with |
|---|---|---|
| **Platform** | The engines every app runs on: metadata, query, rule, layering, (later) provisioning | App |
| **App** | A domain package on the platform (ITAM first, rack later) that defines tables, rules and UI via metadata | Module |
| **Module** | A Spring Modulith module = a direct sub-package of `com.brokenfinger.vera` | Gradle project |
| **Table definition** | Metadata record describing a customer-visible table: name, label, parent, scope | Physical table (`u_*`) |
| **Field definition** | Metadata record describing a column: name, type, reference target, indexed, scope | Column |
| **Scope** | Who owns a metadata record: `BASE` (shipped by the platform) or `CUSTOMER` (created/modified by a customer) | Tenant |
| **Instance** | One customer's deployment: application + database (multi-instance, not multi-tenant) | Scope |
| **Layering** | Tracking whether a `BASE` record was modified by the customer, so upgrades can skip and report it | Versioning |
| **Rule** | Customer logic executed by the rule engine on events (before insert, after update…) in the sandbox | ACL |
| **ACL** | Row/field level access rule injected into every query by the query engine | Rule |
| **Asset** | ITAM: the financial/contractual view of a thing (cost, contract, owner, lifecycle) | CI |
| **CI (Configuration Item)** | ITAM: the operational/technical view (IP, OS, relationships). 1:1 with an Asset when in operation | Asset |
| **Observation** | One report about a CI from a source (discovery, monitoring, CSV, manual) at a time | CI |
| **Identification** | Matching an observation to an existing CI by ordered identifiers (serial → MAC → hostname+IP) | Reconciliation |
| **Reconciliation** | Choosing which source's value wins per attribute when observations disagree | Identification |
| **Ghost asset** | A CI no source has confirmed for longer than its threshold (`last_seen` per source) | Retired asset |
