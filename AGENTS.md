# Repository execution rules

## Start here

- For any non-trivial change, read [`docs/agent_guide.md`](docs/agent_guide.md) before editing. It maps the application boundaries, authorization/tenancy rules, test strategy, and task-specific verification.
- Treat the existing working tree as user-owned. Inspect `git status --short` before edits; do not revert, reformat, or fold unrelated changes into your work.
- Keep changes narrowly scoped. For a behavioral change, update the closest RSpec coverage and run the focused command from the agent guide.

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
