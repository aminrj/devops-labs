# Deploying Linkding with PostgresQL Cluster on Kubernetes with ArgoCD

This repository contains the Kubernetes manifests and ArgoCD configuration for deploying **Linkding**—a self-hosted bookmark manager—on a **Rancher Desktop** Kubernetes cluster using GitOps principles.

## 🚀 Features

- 🧠 **GitOps-powered deployment** using ArgoCD
- 🔐 Secure secrets management via [External Secrets Operator](https://external-secrets.io/)
- 🗄️ PostgreSQL backend powered by [CloudNativePG](https://cloudnative-pg.io/)
- 🏗️ Designed for **local development and testing**, with clear structure for staging and production environments
- 🔄 Automatic backup support with Azure Blob Storage + Barman

---

## 📦 Project Structure

```
.
├── apps/                         # ArgoCD Application manifests
│   └── linkding-dev.yaml
├── databases/
│   └── linkding/
│       ├── base/                # Common CNPG config
│       └── overlays/
│           └── dev/            # Env-specific config and bootstrap
├── secrets/                     # ExternalSecret manifests
│   └── linkding-db-creds.yaml
├── .github/                     # GitHub workflows (if used)
└── README.md
```

---

## 🧑‍💻 Local Development

### Prerequisites

- Rancher Desktop or local Kubernetes cluster
- `kubectl`, `argocd`, and `helm` installed
- Port forwarding for ArgoCD:

  ```bash
  kubectl port-forward svc/argocd-server -n argocd 50778:443
  ```

### Login to ArgoCD

```bash
argocd login localhost:50778 --username admin --password <your-password> --insecure
```

### Sync Applications

```bash
argocd app sync linkding-dev
```

---

## Secrets Management

Secrets are managed with **External Secrets Operator (ESO)** and fetched from **Azure Key Vault**.

Each app defines its own `ExternalSecret` manifest under `secrets/`, e.g.:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: linkding-db-creds
spec:
  secretStoreRef:
    name: azure-kv-store-dev
    kind: ClusterSecretStore
  data:
    - secretKey: username
      remoteRef:
        key: linkding-db-username
    - secretKey: password
      remoteRef:
        key: linkding-db-password
```

---

## Database

CloudNativePG is used for PostgreSQL. Bootstrap and backup are configured via Azure Blob Storage using SAS tokens.

To bootstrap a fresh cluster:

1. Disable recovery mode in the CNPG manifest (`bootstrap.recovery`)
2. Apply the ArgoCD app or sync via CLI

To restore from backup:

1. Re-enable `bootstrap.recovery`
2. Make sure backup is present in the Azure Blob container
3. Trigger a sync via ArgoCD

---

## ⚠️ Tips & Troubleshooting

- Disable auto-sync temporarily in ArgoCD if testing:

  ```bash
  argocd app set linkding-dev --sync-policy none
  ```

- Enable again:

  ```bash
  argocd app set linkding-dev --sync-policy automated
  ```

---

## 🤝 Contributions

Feel free to fork this and adapt for your own app deployments. PRs and issues welcome!
Start ⭐️ if you like what you see.

---

## 📜 License

[MIT License](LICENSE)

---

Would you like a `CONTRIBUTING.md` or `.env.example` template to go with it?
