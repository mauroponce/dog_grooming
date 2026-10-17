# Repository execution rules

## Start here

- `AGENTS.md` is the repository instruction entry point. Global Dev Skills define the working method selected for the task; the Markdown files in this repository define durable project facts. Project documentation never replaces an invoked global skill or creates a new skill by itself.
- For a non-trivial change, select the applicable global Dev Skill first: use `dev-discovery` to understand an unclear initiative, `dev-plan` to design a defined initiative, `dev-implement` to make an approved change, `dev-review` for independent review, and `dev-release` only for release work. Follow the selected skill together with these repository rules.
- For any non-trivial change, read [`docs/agent_guide.md`](docs/agent_guide.md), [`docs/product_context.md`](docs/product_context.md), and [`docs/architecture.md`](docs/architecture.md) before editing. Then read only the relevant entries from [`docs/decisions/README.md`](docs/decisions/README.md). These are the project-owned sources for stable functional and architectural decisions.
- Use those documents to avoid broad repository archaeology. Verify only the code, schema, tests, and history near the requested change. Documentation does not replace targeted verification.
- If current code and project documentation conflict, do not silently choose one. Establish the intended behavior from tests, recent history, and the user's instruction, then update the affected documentation in the same change.
- Treat the existing working tree as user-owned. Inspect `git status --short` before edits; do not revert, reformat, or fold unrelated changes into your work.
- Keep changes narrowly scoped. For a behavioral change, update the closest RSpec coverage and run the focused command from the agent guide.

## Keep project knowledge current

- Update [`docs/product_context.md`](docs/product_context.md) when externally visible behavior, roles, lifecycle, billing rules, onboarding, or domain terminology changes.
- Update [`docs/architecture.md`](docs/architecture.md) when ownership boundaries, data invariants, tenancy, integrations, persistence, async flows, or important implementation seams change.
- Add or supersede a record under [`docs/decisions`](docs/decisions/README.md) only for durable, non-obvious decisions that affect future implementation. Do not create an ADR for routine local implementation details.
- Update [`docs/production_operations.md`](docs/production_operations.md) when deployment, backups, runtime configuration, monitoring, or recovery procedures change.
- Keep temporary discovery notes, implementation plans, debugging notes, progress logs, and personal Codex memory outside the repository according to the global skills. Do not add repository `PLAN.md`, `SPEC.md`, workflow-state files, or secrets.
- Before finishing a non-trivial implementation, explicitly check whether product, architecture, decision, and operations documentation remains accurate. Documentation updates are part of the definition of done when one of those contracts changed.

## Docker is mandatory

- Run every project command inside Docker. Do not run Rails, Ruby, Bundler, RSpec, Rake, database clients, linters, asset builders, or application scripts on the host.
- Use the Compose `web` service for application commands. The repository is mounted at `/rails` in that container.
- Preferred form when the stack is running:

  ```sh
  docker compose exec -T web bash -lc '<command>'
  ```

- If a one-off application container is genuinely required, use:

  ```sh
  docker compose run --rm web bash -lc '<command>'
  ```

- Run all Rails database creation, preparation, migration, rollback, schema, seed, and test-database commands from the `web` container. Its database host must remain the Compose service `db`; never create or migrate a `dog_grooming_*` database on the host PostgreSQL instance.
- If direct PostgreSQL access is required, run `psql` inside the Compose `db` service, never on the host:

  ```sh
  docker compose exec -T db psql -U dog_grooming -d dog_grooming_development
  ```

- Host-side commands are limited to Docker/Compose lifecycle commands needed to start, inspect, enter, or stop containers. File edits through Codex editing tools are allowed because they operate on the bind-mounted workspace.
- Before running a project command, verify that it is wrapped in `docker compose exec`, `docker compose run`, or another command executed inside the appropriate Compose service.

- The local web port is `3003`; PostgreSQL is exposed only for diagnostics on `5435`, and Mailpit on `8028`.
