## Adding Solid Queue

To schedule the `Litestream::VerificationJob` to run at regular intervals and also to generally be able to run background jobs for our application, we can use the [Solid Queue gem](https://github.com/rails/solid_queue). Solid Queue is a DB-based queuing backend for Active Job, designed with simplicity and performance in mind. And it works great with SQLite.

Adding the gem is straight-forward:

```sh
bundle add solid_queue
```

But, the currently released version of Solid Queue (v0.3.0) does not work with Rails 7.2.0.alpha. So, we need to manually update the `Gemfile` to use the main branch of the gem:

```ruby
gem "solid_queue", github: "rails/solid_queue", branch: "main"
```

After updating the `Gemfile`, ensure that Bundler installs the new version:

```sh
bundle install
```

Because Solid Queue is constantly polling the database and making frequent updates, it is recommended to use a separate database for the queue when using Solid Queue with SQLite. This will prevent the queue from interfering with the main database and vice versa. To do this, we can create a new SQLite database for the queue. In the `config/database.yml` file, we can add a new configuration for the queue:

```yaml
queue: &queue
  <<: *default
  migrations_paths: db/queue_migrate
  database: storage/<%= Rails.env %>-queue.sqlite3
```

This configuration sets up a new database that will have a separate schema and separate migrations.

However, adding a new database configuration is not sufficient. We also need to ensure that every environment that needs this new `queue` database uses it alongside our primary database. As [the Rails Guides](https://guides.rubyonrails.org/active_record_multiple_databases.html) say, we need to "change our database.yml from a 2-tier to a 3-tier config."

This means that we need to define each of our databases and then specify which database each environment should use. For this app, I think we can call the database that backs our application `primary` and the database that backs our queue `queue`. We will then ensure that all 3 environments (`development`, `test`, and `production`) are configured to use both.

Our `primary` database simply uses our existing `default` configuration and specifies that the database file lives in the `storage/` directory and is named the same as our Rails environment:

```yaml
primary: &primary
  <<: *default
  database: storage/<%= Rails.env %>.sqlite3
```

Each of our environments can then simply list the databases they need to use, like:

```yaml
development:
  primary: *primary
  queue: *queue
```

We can replicate this structure for each environment.

With our databases configured, we can now run the Solid Queue installer, but we need to tell the installer to use the `queue` database. We can do this by setting the `DATABASE` environment variable:

```sh
DATABASE=queue bin/rails generate solid_queue:install
```

This will create the necessary files for Solid Queue to work with the `queue` database in the `db/queue_migrate` directory. Now, we need to run the migrations for the `queue` database:

```sh
bin/rails db:migrate:queue
```

With our `storage/queue.sqlite3` database prepared, we now need to tell Rails to use Solid Queue as the Active Job backend and then tell Solid Queue to use the `queue` database.

The installation generator should have added the configuration to the `config/environments/production.rb` file, but we want our app to use Solid Queue in all environments. So, we can move this configuration to the `config/application.rb` file:

```ruby
# config/application.rb
config.active_job.queue_adapter = :solid_queue
```

Then, immediately below that, we can tell Solid Queue to use the `queue` database:

```ruby
config.solid_queue.connects_to = { database: { writing: :queue } }
```

With all of that in place, we should be able to start the Solid Queue process successfully:

```sh
bin/rails solid_queue:start
```

and see something like:

```
[SolidQueue] Starting Dispatcher(pid=48982, hostname=local, metadata={:polling_interval=>1, :batch_size=>500, :concurrency_maintenance_interval=>600, :recurring_schedule=>nil})
[SolidQueue] Starting Worker(pid=48983, hostname=local, metadata={:polling_interval=>0.1, :queues=>"*", :thread_pool_size=>3})
```

Like our Litestream replication process, we need to ensure that the Solid Queue supervisor process is running alongside our Rails application. Luckily, also like the Litestream gem, Solid Queue provides a Puma plugin as well. We can add the Solid Queue Puma plugin to our `config/puma.rb` file right below our Litestream plugin:

```ruby
plugin :solid_queue
```

With Solid Queue now fully integrated into our application, we can schedule the `Litestream::VerificationJob` to run at regular intervals. We can do this by defining a recurring task in the `config/solid_queue.yml` file. By default, this file is commented out, so we need to uncomment it and add our recurring task. As detailed in the [Solid Queue documentation](https://github.com/rails/solid_queue?tab=readme-ov-file#recurring-tasks), we add recurring tasks under the `dispatchers` key in the configuration file like so

```yaml
dispatchers:
  - polling_interval: 1
    batch_size: 500
    recurring_tasks:
      my_periodic_job:
        class: MyJob
        args: [ 42, { status: "custom_status" } ]
        schedule: every second
```

We need to add a task to run the `Litestream::VerificationJob` every day at 1am, so let's replace the `my_periodic_job` task with the `periodic_litestream_backup_verfication_job` task:

```yaml
periodic_litestream_backup_verfication_job:
  class: Litestream::VerificationJob
  args: []
  schedule: every day at 1am EST
```

We can verify that the recurring task is scheduled by restarting the Solid Queue process and checking the logs:

```sh
bin/rails solid_queue:start
```

should now output something like:

```
[SolidQueue] Starting Dispatcher(pid=55226, hostname=local, metadata={:polling_interval=>1, :batch_size=>500, :concurrency_maintenance_interval=>600, :recurring_schedule=>{:periodic_litestream_backup_verfication_job=>{:schedule=>"every day at 1am EST", :class_name=>"Litestream::VerificationJob", :arguments=>[]}}})
[SolidQueue] Starting Worker(pid=55227, hostname=local, metadata={:polling_interval=>0.1, :queues=>"*", :thread_pool_size=>3})
```

If you see the `periodic_litestream_backup_verfication_job` in the Dispatcher configuration, then the recurring task is scheduled correctly!

The final detail we need is a web interface to monitor the Solid Queue process. Solid Queue provides a web interface that we can mount in our Rails application. We can do this by adding Rails' new [`mission_control-jobs` gem](https://github.com/rails/mission_control-jobs):

```sh
bundle add mission_control-jobs
```

With the gem installed, we simply need to mount the engine in our `config/routes.rb` file, and let's be sure to mount it _within_ our `AuthenticatedConstraint` block to only allow authenticated users to access the interface:

```ruby
mount MissionControl::Jobs::Engine, at: "/jobs"
```

Of course, in a real-world application, you would want to ensure that only specifically authorized users can access the Solid Queue web interface. You could do this by creating a new constraint and wrapping the `mount` call in that constraint.

- - -

With Solid Queue installed and setup, the next step is to add Solid Cache. You will find that step's instructions when you checkout the `step-7` tag.

```sh
git checkout step-7
```

and then open the `workshop/07-adding-solid-cache.md` file to begin.

- - -

You can find the final solution for this step by checking out the `step-6-solution` tag

```sh
git checkout step-6-solution
```
