# 🐶 Dog API

The **Dog API** provides information on over 340 dog breeds, 20 breed groups, and fun facts. Our data is accurate and constantly updated. Easily integrate this information into your own website or application with our user-friendly API. Get started today and discover more about the world of dogs.

## Getting Started

To get started with this API, you will need to have Ruby and Rails installed on your system. You will also need to have a PostgreSQL database set up and running.

Once you have these prerequisites installed, follow these steps:

1. Clone this repository to your local machine
2. Navigate to the project directory and run `bundle install` to install all necessary dependencies
3. Set up the database by running `rails db:setup`
4. Start the API server by running `rails server`

## Breed images

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
