# Dog API

[![CI](https://github.com/kinduff/dogapi.dog/actions/workflows/ci.yml/badge.svg)](https://github.com/kinduff/dogapi.dog/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A free JSON API about dogs: 283 breeds, 9 breed groups, 483 facts and about
2,350 openly licensed breed photos. No API key, no sign-up, CORS open.
Running at [dogapi.dog](https://dogapi.dog) since 2016.

## Quick start

```bash
curl "https://dogapi.dog/api/v2/facts?limit=2"
curl "https://dogapi.dog/api/v2/breeds?page[size]=5"
curl "https://dogapi.dog/api/v2/groups"
```

Responses follow [JSON:API](https://jsonapi.org). `fetch()` works straight from
a browser, a CodePen, a notebook or `localhost`; no proxy needed. The limit is
300 requests per minute per IP.

## A random dog in one tag

```html
<img src="https://dogapi.dog/api/v2/breeds/image" alt="A random dog">
```

The URL redirects to a picture. Add `?size=thumb|medium|large|full`, or use
`/api/v2/breeds/{id}/image` for a specific breed. Photos come from Wikimedia
Commons and Openverse; each breed's attribution is in the API response.

## Use it from an AI assistant (MCP)

A remote [MCP](https://modelcontextprotocol.io) server lives at
`https://dogapi.dog/mcp`, no key needed. Tools: `random_dog_facts`,
`search_breeds`, `get_breed`, `list_groups`, `get_group`, `random_dog_image`.

```bash
claude mcp add --transport http dogapi https://dogapi.dog/mcp
```

Or in any client that takes JSON config:

```json
{ "mcpServers": { "dogapi": { "type": "http", "url": "https://dogapi.dog/mcp" } } }
```

## Docs

- [API v2 reference](https://dogapi.dog/docs/api-v2), with an
  [OpenAPI document](https://dogapi.dog/api-docs/v2/swagger.json) for Postman,
  Insomnia or code generators
- [API v1](https://dogapi.dog/docs/api-v1) still answers, so old tutorials keep working

## Used in classrooms

A lot of the traffic comes from students: assignments on Canvas, Google
Classroom, Moodle and Schoology, Colab notebooks and The Odin Project. If you
teach, [dogapi.dog/teach](https://dogapi.dog/teach) has ready-made exercises
with starter code in JavaScript, Python and curl. Free for classes,
workshops, tutorials and videos, paid or not.

## Running it locally

You need Ruby, PostgreSQL and `libvips` (for image variants).

1. Clone this repository
2. `bundle install`
3. `rails db:setup`
4. `rails server`

### Breed images

Breed pictures are imported into Active Storage, resized to WebP, and served
with the attribution their licence requires. `libvips` must be installed
locally for the variants.

Five sources are tried in turn, in order of how much human judgement went into
what they return: the photo a breed's Wikipedia article leads with, then every
other picture that article and its translations use, then the files in its
Wikimedia Commons category, then a Commons search, then the openly licensed
photographs [Openverse](https://openverse.org) indexes.

```bash
rails "images:backfill[10]"      # walk every source until each breed has ten
rails "images:import[Akita]"     # one breed, one source
rails images:stats               # coverage so far
rails images:reprocess           # rebuild missing variants
```

Both the importing and the scoring are mostly spent waiting on somebody else's
API, so long runs belong on Sidekiq rather than in a terminal:

```bash
rails "images:backfill_async[10]"   # a job per breed, chained through the sources
rails images:rerank_async           # a job per unscored picture
```

Two workers handle them, because Wikimedia's patience and the model's rate
limit are nothing alike — see `docker-compose.yml`:

```bash
bundle exec sidekiq -q images -c 2
bundle exec sidekiq -q reviews -q default -c 8
```

A breed's first image is the one the API and the site show on their own, so a
review pass looks at each picture and scores it as the one photograph a breed
page leads with: one adult dog, sharp, filling the frame, nothing else in it.
The best scoring picture is moved to the front, and the score and the sentence
behind it are kept on the record. A score of 0 means the wrong picture rather
than a poor one: no dog in it, or several photographs arranged into a grid.
This needs `ANTHROPIC_API_KEY`.

```bash
rails "images:rerank[Akita]"     # score one breed's pictures and reorder them
rails images:rerank_all          # every breed, skipping pictures already scored
rails images:scores              # how the scores came out
rails "images:prune_reviewed[4]" # delete everything that scored below 4/10
```

Hand picked images can be listed in `db/seeds/breed_images.yml` and imported
with `rails "images:import[Akita,manual]"`.

In production set `ACTIVE_STORAGE_SERVICE` to `amazon` or `cloudflare` and fill
in the `S3_*` values from `.env.example`; without them files stay on local disk.

## Contributing

We welcome contributions to this project! If you have an idea for a new feature or find a bug, please open an issue in this repository.

To contribute code to the project, follow these steps:

1. Fork this repository
2. Create a new branch for your changes
3. Make the necessary changes and commit them to your branch
4. Push your branch to your forked repository
5. Open a pull request from your branch to this repository

We will review your changes and merge them into the project if they are approved.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
