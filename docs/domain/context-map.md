# Context map

```
                 ┌────────────────────────────┐
   observations  │        ingestion           │  reads: itam (Observation API)
  ──────────────▶│  discovery · monitoring ·  │
                 │  csv adapters → observations│
                 └─────────────┬──────────────┘
                               ▼
                 ┌────────────────────────────┐
                 │           itam             │  reads: metadata, query, rule
                 │ Asset ↔ CI · lifecycle ·   │
                 │ identification · reconcile │
                 └───────┬───────┬────────────┘
                         ▼       ▼
     ┌────────────┐  ┌────────┐  ┌──────────┐  ┌──────────────┐
     │  metadata  │◀─│ query  │◀─│   rule   │  │   layering   │─▶ metadata
     │ tables ·   │  │ jOOQ · │  │ scripts ·│  └──────────────┘
     │ fields ·   │  │ ACL    │  │ ACL defs │
     │ scope      │  └────────┘  └──────────┘
     └────────────┘
```

Arrows point from the module that depends to the module it depends on. `allowedDependencies` in each
`package-info.java` mirrors this map, and both change in the same PR. `ModularityTest` fails when code
crosses a boundary that `allowedDependencies` does not allow; it does not compare this document.
The control plane (instance provisioning) is a separate deployable and is out of scope until Phase 5.
