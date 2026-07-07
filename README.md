# Install Dynatrace OneAgent on an ECS Cluster (Automated)

This project installs **Dynatrace OneAgent** — a monitoring tool — onto an **Amazon ECS cluster** automatically, using Terraform and GitHub Actions.

You give it a cluster name and your Dynatrace login details. It does the rest: installs the agent on every server in that cluster, so Dynatrace can watch your applications (performance, errors, traffic, CPU/memory, etc.).

> **New to the team? Start here.** You don't need to know Terraform or ECS deeply to use this. Read the "What it does" section, then follow "Setup" step by step.

---

## What it does (in plain English)

Imagine your applications run on a group of servers in AWS. You want Dynatrace to monitor them. Dynatrace's agent (called **OneAgent**) has to sit **on each server** to see everything happening there.

Doing that by hand on every server is slow and error-prone. This project automates it:

1. You store a few secrets in GitHub (cluster name, Dynatrace token, AWS keys).
2. You trigger the pipeline (it runs automatically when code is pushed to `main`).
3. The pipeline installs OneAgent on **every server in your cluster**, then optionally restarts your app so monitoring starts immediately.

That's it. No manual server access needed.

---

## Where does OneAgent get installed?

On **every EC2 server** (called a "container instance") inside the cluster you name — **one agent per server**.

```
ECS Cluster: "prod-cluster"   ← the name you provide
│
├── Server 1  →  🟢 OneAgent   (watches this whole server + all its containers)
├── Server 2  →  🟢 OneAgent
└── Server 3  →  🟢 OneAgent
```

- **One agent per server** — not one per app. Each agent monitors the entire server and every container on it.
- **Only that named cluster** is touched. Nothing else in your AWS account is affected.
- **New servers are covered automatically.** If AWS adds a server later (autoscaling), ECS installs OneAgent on it with no action from you.

---

## How it works under the hood

Dynatrace can't monitor from *inside* a normal app container — it's locked in its own box. So OneAgent runs with special host-level access and installs itself onto the **server's operating system**, where it can see everything.

```mermaid
graph TD
    subgraph Server [One EC2 Server in the Cluster]
        OA[🟢 OneAgent<br/>host-level access]
        A1[App Container 1]
        A2[App Container 2]
        OA -- monitors --> A1
        OA -- monitors --> A2
        OA -- monitors --> Server
    end
```

Two more things worth knowing:

- **DAEMON mode:** ECS is told "run exactly one OneAgent on every server, always." This is what makes it self-maintaining — new servers get it, removed servers clean up automatically.
- **App restart (optional):** Dynatrace only monitors an app if the app started *after* the agent was already there. So if you give it your app's service name, the pipeline restarts your app once at the end so it comes up monitored. If you skip this, the agent is still installed — your app just gets monitored the next time it restarts.

---

## What you need before starting

1. An **EC2-based ECS cluster** that already exists and is running.
   ⚠️ It must be **EC2-backed, not Fargate** — Fargate has no servers to install an agent on.
2. A **Dynatrace account**, from which you need:
   - Your environment URL (e.g. `https://abc12345.live.dynatrace.com`)
   - A **PaaS/API token** (Dynatrace → Access Tokens → create one with installer download permission)
3. **AWS access keys** for an account that can manage ECS.

---

## Setup (one-time)

### Step 1 — Add secrets in GitHub

Go to your repo → **Settings → Secrets and variables → Actions → New repository secret**, and add:

**Required:**

| Secret | What to put |
| --- | --- |
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `ECS_CLUSTER_NAME` | The cluster to install onto, e.g. `prod-cluster` |
| `DYNATRACE_ENVIRONMENT_URL` | Your Dynatrace URL |
| `DYNATRACE_API_TOKEN` | Your Dynatrace token |

**Optional:**

| Secret | Default if you skip it |
| --- | --- |
| `AWS_REGION` | `us-east-1` |
| `APPLICATION_SERVICE_NAME` | (empty) — app restart is skipped |

### Step 2 — Run the pipeline

Either **push any change to the `main` branch**, or go to the **Actions** tab → *Dynatrace OneAgent ECS Deployment* → **Run workflow**.

The pipeline runs 8 steps and prints a clear summary at the end:

```
Step 1  Authenticate with AWS
Step 2  Validate your inputs & check the cluster exists
Step 3  Initialize Terraform
Step 4  Register the OneAgent configuration
Step 5  Install OneAgent on every server (DAEMON) and wait until it's running
Step 6  Restart your app (only if you set APPLICATION_SERVICE_NAME)
Step 7  Verify everything is running
Step 8  Print a summary report
```

That's the whole process. ✅

---

## How to check it worked

**In AWS:** ECS → your cluster → Services → you'll see a service called **`dynatrace-oneagent`**. Its "Running tasks" number should equal your number of servers.

**In Dynatrace:** go to **Infrastructure → Hosts**. Your ECS servers should appear and start reporting data within a few minutes.

---

## Common questions

**Do I have to run this every time?**
No. Once installed, it keeps itself running and covers new servers automatically. Re-run it only if you change the configuration.

**My servers are ARM/Graviton (t4g, m6g, c7g...).**
Open `terraform/main.tf`, find `arch=x86` in the installer URL, and change it to `arch=arm`.

**Nothing shows up in Dynatrace.**
Check the pipeline logs (Actions tab) for the failing step. Most often it's a wrong Dynatrace URL/token, or the cluster is Fargate (not supported), or the cluster has no running servers yet.

**Can I run it from my own laptop instead of GitHub?**
Yes — see [`terraform/README.md`](terraform/README.md) for the local `terraform` commands.

---

## Where things live

```
.github/workflows/deploy.yml   ← the automated pipeline (8 steps)
terraform/main.tf              ← what gets installed (the OneAgent config)
terraform/variables.tf         ← the inputs you can set
terraform/README.md            ← details + how to run locally
```

For deeper technical details, see [`terraform/README.md`](terraform/README.md).
