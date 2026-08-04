# Day 1 - Linux & Networking

> **Daig chapter:** Before Daig runs anywhere, it runs on a machine, and that
> machine has to talk to other machines.

The least glamorous day and the highest-leverage one. Nobody puts "good at
Linux" on a CV any more. Everybody notices when you are not.

## Morning - orientation on a real box

```bash
docker compose up -d
docker compose exec orders sh
```

Find your way around from inside a running container:

| Question | Command | Why it matters later |
|---|---|---|
| What is running? | `ps aux` | Friday: why is this pod using 400m CPU? |
| What is listening? | `ss -tlnp` | Demo Day scenario 4 is a probe on the wrong port |
| Where does the time go? | `top`, `htop` | Day 4: is it CPU or is it waiting? |
| What is this process doing? | `strace -p <pid>` | The tool of last resort, and it works |
| How much disk? | `df -h`, `du -sh *` | The most common cause of a 3am page |
| What did it say? | `journalctl -u docker`, `docker logs` | Every diagnosis starts here |

## Afternoon - follow one request all the way down

Trace a single HTTP call through every layer:

```bash
getent hosts postgres          # 1. name  -> address
nc -zv postgres 5432           # 2. can we open a TCP connection?
curl -v localhost:3001/readyz  # 3. does the application layer answer?
tcpdump -i any -n port 5432    # 4. what actually goes over the wire?
```

The point to land: **four different layers, four different failure modes, four
different tools.** "The database is down" is not a diagnosis, it is a symptom
with at least four possible causes.

## Chaos Hour - 16:00

```bash
./chaos/day1-network.sh break <1|2|3>
```

Orders cannot reach the database. Three teams, three different planted causes.
Nobody is told which variant they have, so nobody can copy.

The correct method, in order:

1. `curl localhost:3001/readyz` - confirm the symptom
2. `docker compose logs orders` - what does it say?
3. `getent hosts postgres` - is it a name problem?
4. `nc -zv postgres 5432` - is it a reachability problem?
5. `ss -tlnp` on the database - is anything listening at all?

Fifteen minutes to diagnose, then compare notes across teams. That comparison
is where the day lands: three teams saw the identical symptom and found three
different causes.

## Deliverable

A written diagnosis: what you observed, what you ruled out and how, what the
cause was. Three paragraphs. This is a postmortem in miniature and it is the
skill Demo Day scores at 40%.

## Skip this day and

80% of the "Kubernetes problems" you hit on Friday are Linux and networking
problems wearing a costume.
