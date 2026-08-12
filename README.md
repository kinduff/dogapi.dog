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

Breed pictures are imported from [Wikimedia Commons](https://commons.wikimedia.org)
into Active Storage, resized to WebP, and served with the attribution their
licence requires. `libvips` must be installed locally for the variants.

```bash
rails "images:import[Akita]"     # one breed
rails images:import_all          # every breed that has none yet
rails images:stats               # coverage so far
rails images:reprocess           # rebuild missing variants
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
