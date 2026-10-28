# CodeShark

Infrastructure as code and CI/CD pipelines that deploy [DeskShark](https://github.com/Henryyy-R/DeskShark), a help desk web app, to Azure.

Everything in Azure that the app runs on is defined in Terraform. Changes go through pull requests, and a push to `main` applies them.

## Environments

| | Staging | Production |
|---|---|---|
| URL | https://staging.desksharkproject.me | https://app.desksharkproject.me |
| Container App | `ca-deskshark-staging` | `ca-deskshark-prod` |
| Replicas | 0 to 1 (scales to zero when idle) | 1 (always on) |
| Resource group | `rg-dsk-staging` | `rg-dsk-prod` |
| Key Vault | `kv-dsk-staging-f2500b` | `kv-dsk-prod-f2500b` |
| Uploads | Azure Files share, mounted at `/app/backend/uploads` | Separate storage account and share, same mount path |
| Database | `deskshark_staging` (MongoDB Atlas) | `deskshark_prod` (MongoDB Atlas) |

Production is always on because the app's ticket monitor runs as a background job inside the app process.

Both apps run inside **one shared Container App Environment**, `cae-dsk-staging-std`, which the staging stack owns. See [Design decisions](#design-decisions).

## Repository layout

```
terraform/
  shared/          Resources both environments use, such as the container registry
  envs/staging/    Staging stack: app, identity, logs, uploads storage, domain and certificate
  envs/prod/       Production stack: app, identity, uploads storage, domain and certificate
.github/workflows/
  plan.yml         Runs on every pull request
  apply.yml        Runs on pushes to main that change terraform/**, or manually
```

## How changes reach Azure

1. **Pull request.** `plan.yml` runs for `shared`, `envs/staging` and `envs/prod`: format check, `init`, `validate`, then `plan`. The plan is posted as a comment on the pull request. The three plan checks are required to merge.
2. **Merge to `main`.** `apply.yml` runs the `staging` job, then the `production` job. The `production` job uses a GitHub Environment with a required reviewer, so it waits for a manual approval before it changes anything.
3. **Applies run one at a time** and are never cancelled halfway through.

A change that touches only `.github/**` does not trigger `apply.yml`, because it only watches `terraform/**`. Use **Run workflow** on the `apply` workflow to start it by hand.

### Deploying a new version of DeskShark

1. Merge the change in the DeskShark repository. Its release workflow builds an image and pushes it to the registry, tagged with the commit.
2. Open a pull request in this repository that changes `image_tag` in `terraform/envs/staging/image.tf`. Read the plan comment: only the container image should change. Merge it, and check staging.
3. Repeat in `terraform/envs/prod/image.tf` to promote the same tag to production, and approve the production job.

To roll back, change `image_tag` back to the previous tag.

## Design decisions

- **One Container App Environment for the whole subscription.** The Azure for Students subscription allows only one, so production runs as a second app inside the staging-owned environment. The apps have separate identities, Key Vaults, storage accounts, secrets and databases, and they share the environment and its log workspace. The production stack must never manage or destroy the environment itself.
- **Standard (consumption-only) environment, requested explicitly.** In this subscription the default turned out to be the Express mode, which has no Key Vault secret references, custom domains or Azure Files, so the environment is created through the `azapi` provider with `environmentMode = "ConsumptionOnly"`.
- **No long-lived credentials.** GitHub Actions logs in to Azure with OIDC. Separate identities handle planning (read-only) and applying (scoped to the resource groups), and the production apply identity login is tied to the `production` GitHub Environment.
- **Secrets never pass through Terraform.** Secret values live in Key Vault, are added by hand, and the apps read them through their own managed identity via Key Vault references. The app pulls images from the registry with the same managed identity, with no registry password.
- **Custom domains in stages.** Azure can only validate a managed certificate after the hostname is registered on the app, so each domain is built in order: DNS records, the hostname on the app, the managed certificate, and the binding. The binding uses a raw `azapi` request because the `azurerm` provider can't bind a managed certificate.
- **Logs** for the environment (console, system and HTTP) are sent to a Log Analytics workspace with a daily ingestion cap.
- **Uploads persist** on an Azure Files share. The mount sets the file owner to the container's `node` user (uid and gid 1000), and `/uploads` requires a logged-in user.
- **Region** is East Asia. The subscription's policy only allows a few regions.

## Known limitations

- **The uploads storage account keys are in Terraform state.** Container Apps can only mount an Azure Files share with a key. State is in a private storage account and accessed with Azure AD.
- **The plan identity can read storage account keys.** Refreshing a storage account requires `listKeys`, so a custom role grants that single action on each uploads account. Anything that can trigger a plan on a pull request can therefore read those keys. Fork pull requests don't receive an OIDC token.
- **Production uses Clerk development keys**, the same instance as staging. A Clerk production instance is a separate step.
- **Staging and production share one MongoDB Atlas cluster**, with a separate user and database for each. The network access list is open to all addresses.
- **`/uploads` has no per-ticket permission check.** Any logged-in user who knows a filename can fetch the file. Filenames are random, and the upload filter checks extension and the client-supplied type only.
- **No alerting.** Nothing notifies anyone if production goes down.
- **The DeskShark repository has no pull request checks**, so releases rely on manual testing.
- **Shared fate.** Because the apps share an environment, an environment-level problem affects both.

## Set up by hand, outside the stacks

These were created during setup and are not managed by the Terraform stacks:

- the Terraform state storage account, and the plan and apply identities with their federated credentials and role assignments
- the custom role that lets the plan identity read storage keys, and its per-account assignments
- the Key Vaults and every secret in them
- the DNS zone, delegated from the domain registrar, and the MongoDB Atlas users
- the GitHub Environments and the branch ruleset that requires the plan checks