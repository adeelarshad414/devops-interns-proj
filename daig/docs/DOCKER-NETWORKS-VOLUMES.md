# Docker networks and volumes - Day 3 afternoon

The two Docker subjects that get skipped and then cause every subsequent
problem. Both are best taught by breaking something.

## Networks

### The lab

```bash
docker network ls
docker network inspect daig_default | head -40
```

Then take the network away and watch what happens:

```bash
docker network disconnect daig_default daig-orders-1
curl localhost:3001/readyz          # 503 - cannot reach the database
docker network connect daig_default daig-orders-1
curl localhost:3001/readyz          # healthy again
```

### The four things they must be able to say afterwards

**1. Container names are DNS names.** `postgres:5432` works inside the network
because Docker runs a DNS resolver, not because of any configuration. Prove it:

```bash
docker compose exec orders getent hosts postgres
docker compose exec orders getent hosts kitchen
```

Direct callback to Day 1's `getent`. Same tool, new context.

**2. `localhost` inside a container is that container.** The single most common
beginner error. `DATABASE_URL=postgresql://...@localhost:5432` fails inside a
container and works on the host, which is maddening until you understand why.

**3. Networks are isolation, not just plumbing.** Build the three-tier
separation by hand:

```bash
docker network create daig-frontend
docker network create --internal daig-data     # no external egress at all

docker network connect daig-frontend daig-web-1
docker network connect daig-data    daig-postgres-1
# web is NOT on daig-data, so web cannot reach the database. By construction.
```

That last comment is the point. The three-tier model stops being a diagram and
becomes something the network enforces whether or not anyone remembers it.

**4. Published ports are a hole you punched deliberately.** `5432:5432` in the
compose file exposes the database to the whole host. Fine on a laptop,
catastrophic on a server. Ask them which ports in `docker-compose.yml` they
would remove before deploying it anywhere real. The answer is most of them.

## Volumes

### The lab that teaches it in one minute

```bash
docker compose exec postgres psql -U daig -d daig \
  -c "INSERT INTO restaurants (name, area) VALUES ('Volume Test', 'Nowhere');"

docker compose down          # containers destroyed
docker compose up -d
docker compose exec postgres psql -U daig -d daig \
  -c "SELECT name FROM restaurants WHERE name='Volume Test';"   # STILL THERE

docker compose down -v       # -v destroys the volume
docker compose up -d
# ...gone. Along with everything else.
```

Two commands, one letter apart, and one of them deletes your database. Let them
run both. Nobody forgets the `-v` after doing that themselves.

### The three mount types

| Type | Syntax | Use it for |
|---|---|---|
| Named volume | `pgdata:/var/lib/postgresql/data` | Data you intend to keep. Docker manages the location. |
| Bind mount | `./db/init:/docker-entrypoint-initdb.d` | Host files you want visible inside. Local dev, config. |
| tmpfs | `emptyDir` / `--tmpfs /tmp` | Scratch space that should vanish. Required when the root filesystem is read-only. |

Find one of each in `docker-compose.yml` and `k8s/base/orders.yaml`. The
`readOnlyRootFilesystem: true` plus `/tmp` emptyDir pairing in the Kubernetes
manifest is the clearest example of why tmpfs exists.

### Things that will actually bite them

- **Bind-mount permissions.** The container runs as uid 1000; if the host
  directory is owned by root, writes fail with a permission error that names
  neither Docker nor the mount.
- **A volume outlives every container that used it.** `docker volume ls` after
  a week of experimenting is a genuinely startling amount of disk.
- **`docker system prune -a --volumes`** reclaims it and will also delete
  things you wanted. Read the prompt.
- **Volumes are node-local.** A pod that reschedules to another node cannot see
  its volume. This is precisely why `k8s/base/postgres.yaml` is a StatefulSet
  with a PVC — and why production uses managed RDS/Cloud SQL/Flexible Server
  instead, which is what `infra/` provisions.

That last point is the bridge from Wednesday to Tuesday's cloud work and to
Friday's Kubernetes. Draw it explicitly.
