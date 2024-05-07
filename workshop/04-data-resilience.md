## Data Resilience

With our application now running smoothly, we can focus on the second most important foundational aspect of our application: data resilience. We need to ensure that our data is safe and secure, and that we can recover it in case of a disaster.

While the fact that SQLite is an embedded database is central to its simplicity and speed, it also does make it more important to ensure that you have a solid backup strategy in place. You don't want anything to go wrong with your production machine and lose all your data.

In my opinion, the best tool for backing up SQLite databases [Litestream](https://litestream.io); however, there are [alternatives](https://oldmoe.blog/2024/04/30/backup-strategies-for-sqlite-in-production/). We will use Litestream though. It is a tool that continuously streams SQLite changes to a remote S3-compatible storage provider. It is simple to set up and use, and like SQLite itself it is free.

Since Litestream is a single Go executable, it can be provided as a precompiled Ruby gem, and that is precisely what the `litestream` gem does. To install it, simply:

```sh
bundle add litestream
```

Then,

```sh
bin/rails generate litestream:install
```

The installer will create 2 files in your project:

1. `config/litestream.yml` - the configuration file for the Litestream utility
2. `config/initializers/litestream.rb` - an initializer that sets up the Litestream gem

In order to use Litestream, you need to have an S3-compatible storage provider. You can use AWS S3, DigitalOcean Spaces, or any other provider that is compatible with the S3 API. For this workshop, we will use a local instance of [MinIO](https://github.com/minio/minio), which is an open-source S3-compatible storage provider.

There is also a Ruby gem providing the precompiled executable for MinIO, so you can install it with:

```sh
bundle add minio
```

The gem provides a Rake task to start the MinIO server, so you can run it with:

```sh
bin/rails minio:server -- --console-address=:9001
```

Run that in a new terminal window, and you will see the MinIO server starting up. You can now access the MinIO web interface at [http://127.0.0.1:9001](http://127.0.0.1:9001). Before we can use Litestream, we need to create a bucket in MinIO. You can do that on the ["Create Bucket" page](http://127.0.0.1:9001/buckets/add-bucket). Visit that link and sign in with the default credentials:

```
Username: minioadmin
Password: minioadmin
```

Then, fill in the "Bucket Name" field with `railsconf-2024` and click the "Create Bucket" button.

Now that we have our S3-compatible storage provider set up, we can configure Litestream to use it. If you open the `config/litestream.yml` file, you will notice that it references some environment variables:

```yaml
type: s3
bucket: $LITESTREAM_REPLICA_BUCKET
path: storage/production.sqlite3
access-key-id: $LITESTREAM_ACCESS_KEY_ID
secret-access-key: $LITESTREAM_SECRET_ACCESS_KEY
```

In order to ensure that these environment variables are set with the correct values, we need to configure the Litestream gem. The Litestream gem provides Rake tasks for all of the Litestream CLI commands, and each Rake task will take the gem's configuration and use it to set the corresponding environment variables. The gem configuration lives in the `config/initializers/litestream.rb` file. By default that file is commented out. Let's uncomment the Ruby code in that file (and save the file) and see what the default configuration setup looks like:

```ruby
Litestream.configure do |config|
  litestream_credentials = Rails.application.credentials.litestream

  config.replica_bucket = litestream_credentials.replica_bucket
  config.replica_key_id = litestream_credentials.replica_key_id
  config.replica_access_key = litestream_credentials.replica_access_key
end
```

The gem suggests using [Rails' credentials](https://edgeguides.rubyonrails.org/security.html#custom-credentials) to store our bucket details. So, let's do that. We can edit the Rails credentials with:

```sh
EDITOR=vim bin/rails credentials:edit
```

In that `vim` window, we can add the bucket details (use `i` to enter `INSERT` mode, then paste the following at the top of the file):

```yaml
litestream:
  replica_bucket: railsconf-2024
  replica_key_id: minioadmin
  replica_access_key: minioadmin
```

Save and close the file/that Vim session with `:wq` (use `Escape` first to exit `INSERT` mode). Now, if we run the `litestream:env` Rake task, we should see the environment variables set:

```sh
bin/rails litestream:env
```

should ouput:

```
LITESTREAM_REPLICA_BUCKET=railsconf-2024
LITESTREAM_ACCESS_KEY_ID=minioadmin
LITESTREAM_SECRET_ACCESS_KEY=minioadmin
```

There is one final step to get Litestream configured to use our local MinIO bucket. We need to actually add one value to the `config/litestream.yml` file so that Litestream knows the endpoint where our MinIO server is running. So, update the `replicas` list item with:

```yaml
type: s3
bucket: $LITESTREAM_REPLICA_BUCKET
path: production.sqlite3
endpoint: http://localhost:9000
access-key-id: $LITESTREAM_ACCESS_KEY_ID
secret-access-key: $LITESTREAM_SECRET_ACCESS_KEY
```

With our configuration files set up and our credentials securely stored, we can now start the Litestream replication process. To start, let's run it in another terminal tab:

```sh
bin/rails litestream:replicate
```

Running this Rake task should output something generally like:

```
time=YYYY-MM-DDTHH:MM:SS.000+00:00 level=INFO msg=litestream version=v0.3.13
time=YYYY-MM-DDTHH:MM:SS.000+00:00 level=INFO msg="initialized db" path=~/path/to/railsconf-2024/storage/production.sqlite3
time=YYYY-MM-DDTHH:MM:SS.000+00:00 level=INFO msg="replicating to" name=s3 type=s3 sync-interval=1s bucket=railsconf-2024 path=production.sqlite3 region="" endpoint=http://localhost:9000
time=YYYY-MM-DDTHH:MM:SS.000+00:00 level=INFO msg="write snapshot" db=~/path/to/railsconf-2024/storage/production.sqlite3 replica=s3 position=89dac524869a943d/00000001:4152
time=YYYY-MM-DDTHH:MM:SS.000+00:00 level=INFO msg="snapshot written" db=~/path/to/railsconf-2024/storage/production.sqlite3 replica=s3 position=89dac524869a943d/00000001:4152 elapsed=47.469667ms sz=2082195
time=YYYY-MM-DDTHH:MM:SS.000+00:00 level=INFO msg="write wal segment" db=~/path/to/railsconf-2024/storage/production.sqlite3 replica=s3 position=89dac524869a943d/00000001:0
time=YYYY-MM-DDTHH:MM:SS.000+00:00 level=INFO msg="wal segment written" db=~/path/to/railsconf-2024/storage/production.sqlite3 replica=s3 position=89dac524869a943d/00000001:0 elapsed=2.253875ms sz=4152
```

If you see logs like this, congratulations, you have successfully set up Litestream to replicate your SQLite database to MinIO! But, how do we ensure that the replication process runs continuously while our application is running?

The Litestream gem provides a Puma plugin that makes this easy. To use the plugin, we need to add it to our `config/puma.rb` file. Open that file and add the following line after the `plugin :tmp_restart` bit:

```ruby
# Allow puma to manage the Litestream replication process
plugin :litestream
```

Now, whenever you start your Rails server with `bin/rails server`, the Litestream replication process will start automatically.

You can now test the replication by making changes to your database and seeing them reflected in the MinIO bucket.

- - -

With Litestream and MinIO installed and setup, the next step is to ensure that the backup strategy is consistently working and you can restore from a bacup. You will find that step's instructions when you checkout the `step-5` tag.

```sh
git checkout step-5
```

and then open the `workshop/05-restoring-from-a-backup.md` file to begin.

- - -

You can find the final solution for this step by checking out the `step-4-solution` tag

```sh
git checkout step-4-solution
```
