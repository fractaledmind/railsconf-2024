## Error Monitoring

After working with Solid Queue and Solid Cache, you might get curious how else one might leverage this pattern of spinning up separate SQLite databases to drive additional services for our Rails application. I personally got curious and explored this how this pattern could compliment Rails' error reporter interface. You might come up with other great ideas.

Let's walk through how we can add integrated error monitoring into our application by using the [Solid Errors](https://github.com/fractaledmind/solid_errors) gem.

Step one, as often, is to install the gem:

```sh
bundle add solid_errors
```

Following the pattern of setting up a new SQLite database to back this service, let's create an `errors` database:

```yaml
errors: &errors
  <<: *default
  migrations_paths: db/errors_migrate
  database: storage/<%= Rails.env %>-errors.sqlite3
```

And configure each of our environments to use this database:

```yaml
development:
  primary: *primary
  queue: *queue
  cache: *cache
  errors: *errors
```

With our new `errors` database configured, we can generate the Solid Errors migrations for this database:

```sh
bin/rails generate solid_errors:install --database errors
```

And then run those migrations:

```sh
bin/rails db:migrate:errors
```

Finally, we need to tell Solid Errors to use this dedicated database in our `config/application.rb` file:

```ruby
# Use a separate database for error monitoring
config.solid_errors.connects_to = { database: { writing: :errors } }
```

Like Mission Control Jobs, Solid Errors comes with a web dashboard that allows us to view our application's unresolved errors. You can mount that in your `config/routes.rb` file under our `AuthenticatedConstraint` block:

```ruby
mount SolidErrors::Engine, at: "/errors"
```

In addition to the web UI, Solid Errors also supports sending email notifications when an error is raised. This is opt-in behavior though, so you need to configure the from and to email addresses:

```ruby
# config/application.rb
config.solid_errors.send_emails = true
config.solid_errors.email_from = "errors@railsconf-2024.com"
config.solid_errors.email_to = "devs@railsconf-2024.com"
```

This provides a pretty solid foundation for error monitoring. Certainly not as robust as a 3rd party service like Honeybadger or AppSignal, but a great place to start for a new application where you need to keep initial costs to a minimum.

Test how it works by restarting your Rails server process and causing an error. I find the simplest way to generate an error is to sign out and then try to access an authorized route like `/posts/:id/edit` as a guest. Once you have caused the exception, sign back in and visit the `/errors` dashboard to see what Solid Errors provides.

- - -

With error monitoring setup, you have now completed this workshop!

You can find the final solution for this step by checking out the `step-11-solution` tag

```sh
git checkout step-11-solution
```
