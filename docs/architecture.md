# Architecture

## Generic pattern

```mermaid
flowchart LR
    A[Source API] --> B[Ingest compute]
    B --> C[(Object storage - raw)]
    C --> D[Transform compute]
    D --> E[(Data warehouse)]
    E --> F[Dashboard / front end]
```

## GCP

```mermaid
flowchart LR
    A[Open-Meteo API] -->|Cloud Scheduler| B[Cloud Function: ingest]
    B --> C[(Cloud Storage - raw/)]
    C -->|Eventarc trigger| D[Cloud Function: transform]
    D --> E[(BigQuery)]
    E --> F[Front end / Looker Studio]
```

This repo is one leg of a multi-cloud pattern — see also `aws-data-pipeline`,
`azure-data-pipeline`, and `k8s-airflow-data-platform`. Same `shared/` ingest
+ transform logic, GCP-native wiring.
