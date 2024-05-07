## Adding Solid Cache

In addition to a job backend, a full-featured Rails application often needs a cache backend. Modern Rails provides a database-backed default cache store named [Solid Cache](https://github.com/rails/solid_cache). We install it like any other gem:

```sh
bundle add solid_cache
```

Like with Solid Queue, we need to configure Solid Cache to use a separate database. We can do this by adding a new database configuration to our `config/database.yml` file:

```yaml
cache: &cache
  <<: *default
  migrations_paths: db/cache_migrate
  database: storage/<%= Rails.env %>-cache.sqlite3
```

We need need to ensure that each environment uses this `cache` database, like so:

```yaml
development:
  primary: *primary
  queue: *queue
  cache: *cache
```

With the new cache database configured, we can install Solid Cache into our application with that database

```sh
DATABASE=cache bin/rails solid_cache:install
```

This will create the migration files in the `db/cache_migrate` directory. We can then run the migrations like so:

```sh
bin/rails db:migrate:cache
```

Finally, if you want to use the cache in the `development` environment, make sure you run the `dev:cache` task:

```sh
bin/rails dev:cache
```

You want to see the following output:

```
Development mode is now being cached.
```

With Solid Cache enabled for the `development` environment, we can finally configure Solid Cache itself to use our new cache database. By default, Solid cache expects you to use a single database named after the environment. We need to point Solid Cache to our new `cache` database. We can do this in the configuration file at `config/solid_cache.yml`:

```yaml
default: &default
  database: cache
  store_options:
    max_age: <%= 1.week.to_i %>
    max_size: <%= 256.megabytes %>
    namespace: <%= Rails.env %>
```

With Solid Cache now fully integrated into our application, we can use it like any other Rails cache store. Let's confirm that everything is working as expecting by opening the Rails console:

```sh
bin/rails console
```

write to the `Rails.cache` object:

```ruby
Rails.cache.write(:key, "value")
```

You should see logging output like:

```
SolidCache::Entry Upsert (0.6ms)  INSERT INTO "solid_cache_entries" ("key","value","key_hash","byte_size","created_at") VALUES (x'646576656c6f706d656e743a6b6579', x'001102000000000000f0bfffffffff76616c7565', -7049334240734188906, 175, STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')) ON CONFLICT ("key_hash") DO UPDATE SET "key"=excluded."key","value"=excluded."value","byte_size"=excluded."byte_size" RETURNING "id"
```

This output confirms that Solid Cache is working as expected!

If we then read that key back from the cache:

```ruby
Rails.cache.read(:key)
```

You should see the value `"value"` returned.

With caching now enabled in our application, we can use Solid Cache to cache expensive operations, such as database queries, API calls, or view partials, to improve the performance of our application.

We can cache the rendering of the posts partial in the `posts/index.html.erb` view like so:

```erb
<td>
  <% cache post do %>
    <%= render post %>
  <% end %>
</td>
```

- - -

With Solid Cache installed and setup, the next step is to consider how to enhance SQLite with extensions. You will find that step's instructions when you checkout the `step-8` tag.

```sh
git checkout step-8
```

and then open the `workshop/08-sqlite-extensions.md` file to begin.

- - -

You can find the final solution for this step by checking out the `step-7-solution` tag

```sh
git checkout step-7-solution
```
