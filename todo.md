# TODO

Findings from code review. Work through sequentially, top to bottom.

Once done with an item, commit and dont co-author, do only titles, and keep it simple. One commit per TODO item.

## 1. Bugs (live 500s, unauthenticated)

- [x] **Negative limit returns 500.** `app/controllers/api/v1/facts_controller.rb:19`, `app/controllers/api/v2/facts_controller.rb:14`. `limit.to_i` of `-1` is neither zero nor `> 5`, so it reaches the query and emits `LIMIT -1`, which Postgres rejects (`ActiveRecord::StatementInvalid`). Replace with `limit.to_i.clamp(1, 5)`.
- [x] **`raw=true` on empty facts table raises NoMethodError.** `app/controllers/api/v1/facts_controller.rb:12` calls `@facts.first.body` without a nil guard. Now returns 404.
- [x] **Clamp semantics are surprising.** `?limit=10` currently returns 1 fact instead of 5. Fixed by the `clamp(1, 5)` change above; `swagger/` already documented min 1 / max 5, so no doc change was needed.
- [x] Add request specs covering all three cases (see item 23). Added `spec/requests/api/v{1,2}/facts_behavior_spec.rb`, separate from the rswag doc files.

## 2. Security and config

- [ ] **Restrict CORS.** `config/initializers/cors.rb` allows `post patch put` from `origins "*"` on every resource. The API is read-only — allow `get` and `options` only.
- [ ] **Add `/.env` to `.gitignore`.** It is currently untracked but holds `UMAMI_PASSWORD`; one `git add -A` leaks it. Commit a `.env.example` with the four `UMAMI_*` keys and no values.
- [ ] **Enable production hardening.** `config/environments/production.rb` has `assume_ssl`, `force_ssl`, and `config.hosts` all commented out. App sits behind Traefik TLS — enable `assume_ssl` and `force_ssl`, and set `config.hosts` to `dogapi.dog` for Host-header / DNS-rebinding protection.
- [ ] **Bump framework defaults.** `config/application.rb` pins `config.load_defaults 7.0` while running Rails 8.1. Step up using `config/initializers/new_framework_defaults_8_1.rb`.
- [ ] **Define a CSP.** `config/initializers/content_security_policy.rb` is entirely commented out, and the public pages carry inline JS.

## 3. Docker

- [ ] **Add `.dockerignore`.** Build context currently ships `.git/`, `log/`, and hundreds of `tmp/miniprofiler/` files.
- [ ] **Run as non-root.** `Dockerfile` has no `USER`.
- [ ] **Multi-stage build.** Single stage leaves `build-essential` and `git` in the runtime image.
- [ ] **Delete `entrypoint.sh`.** It runs `bundle install` at container start and is referenced by neither the Dockerfile nor `docker-compose.yml`.

## 4. Performance

- [ ] **Fix N+1 in v2 index actions.** `GroupSerializer` declares `has_many :breeds` and `BreedSerializer` declares `belongs_to :group`, but neither index preloads. `breeds#index` permits `page[size]=1000`, so that is up to 1000 group lookups. Add `.includes(:group)` / `.includes(:breeds)`.
- [ ] **Move rack-attack off MemoryStore.** `config/initializers/rack_attack.rb:6` uses an in-process store, so the real limit is 300/min *per puma worker* and resets on restart. Redis is already running in `docker-compose.yml`.
- [ ] **Replace `ORDER BY RANDOM()`.** Used in v1 facts, v2 facts, and `pages#index` (homepage, every hit). Full sort per request, no usable index. Use `TABLESAMPLE`, a random offset, or a cached id list.
- [ ] **Move Umami tracking off raw threads.** `app/controllers/concerns/umami_trackable.rb:19` spawns an unbounded `Thread.new` per API response, with no pool, killed mid-flight on shutdown. Sidekiq is already in the Gemfile. Also drop the per-request `Rails.logger.debug` interpolation on line 14.
- [ ] **Add HTTP caching.** No ETag or Cache-Control on breeds/groups, which are effectively static. Cheap CDN win.
- [ ] **Add missing indexes.** `facts.uuid` (public-facing id, currently unindexed), `breeds.name` and `groups.name` (both ordered on).

## 5. Dead code and dependencies

- [ ] **Drop unused gems.** No references anywhere in the codebase: `redis`, `sidekiq`, `groupdate`, `ransack`, `jbuilder`, `image_processing`, `aws-sdk-s3`, and `sqlite3` (in the test group, but the suite runs on Postgres). Keep `redis`/`sidekiq` only if the rack-attack and Umami items above are done first. Each unused gem is CVE surface and image weight.
- [ ] **Remove the `User` model and `users` table.** No auth, no routes, no `has_secure_password` (bcrypt is not even a dependency), yet `password_digest` and `remember_token` columns exist.
- [ ] **Resolve `pg_search`.** Scopes are defined on all three models and called nowhere; there is no search endpoint. Ship search or drop the gem.
- [ ] **Resolve `JSONAPI::Filtering`.** Included in `Api::V2::BaseController` but `jsonapi_filter` is never called, so clients sending `filter[...]` silently get unfiltered results. Implement it or remove the include.
- [ ] **Mount or delete rswag UI.** `config/initializers/rswag_ui.rb` configures endpoints, but `Rswag::Ui::Engine` is never mounted in `config/routes.rb` — the docs UI is unreachable.
- [ ] **De-duplicate pagination.** `jsonapi_page_size` is identical in `breeds_controller.rb` and `groups_controller.rb`. Move it to `Api::V2::BaseController`.

## 6. Ops and testing

- [ ] **Add `/up` health endpoint.** `config/environments/production.rb:47` silences `/up`, but no such route exists and `docker-compose.yml` has no healthcheck. Add `get "up" => "rails/health#show"`.
- [ ] **Write real request specs.** Everything under `spec/requests/` is an rswag doc-generator block asserting only a `200`. Nothing covers limit clamping, `raw=true`, 404 paths, or pagination bounds — which is why the bugs in section 1 exist. Keep the rswag blocks for doc generation, add separate specs for behavior.
- [ ] **Set a simplecov minimum threshold.** Installed, but currently enforces nothing.
- [ ] **Fill in the near-empty model specs.** `spec/models/fact_spec.rb` and `spec/models/user_spec.rb` are 3 lines each (the latter goes away if `User` is removed).
- [ ] **Bump Postgres off 13.** EOL as of November 2025. Pinned in both `.github/workflows/ci.yml` and `docker-compose.yml`.
