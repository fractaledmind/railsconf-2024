## Restoring from a Backup

With Litestream streaming updates to your MinIO bucket, you can now restore your database from a backup. To do this, you can use the `litestream:restore` Rake task:

```sh
bin/rails litestream:restore -- --database=storage/production.sqlite3 -o=storage/restored.sqlite3
```

This task will download the latest snapshot and WAL files from your MinIO bucket and restore them to your local database.

When you run this task, you should see output like:

```
time=YYYY-MM-DDTHH:MM:SS.000+00:00 level=INFO msg="restoring snapshot" db=~/path/to/railsconf-2024/storage/production.sqlite3 replica=s3 generation=e9885230835eaf8b index=0 path=storage/restored.sqlite3.tmp
time=YYYY-MM-DDTHH:MM:SS.000+00:00 level=INFO msg="restoring wal files" db=~/path/to/railsconf-2024/storage/production.sqlite3 replica=s3 generation=e9885230835eaf8b index_min=0 index_max=0
time=YYYY-MM-DDTHH:MM:SS.000+00:00 level=INFO msg="downloaded wal" db=~/path/to/railsconf-2024/storage/production.sqlite3 replica=s3 generation=e9885230835eaf8b index=0 elapsed=2.622459ms
time=YYYY-MM-DDTHH:MM:SS.000+00:00 level=INFO msg="applied wal" db=~/path/to/railsconf-2024/storage/production.sqlite3 replica=s3 generation=e9885230835eaf8b index=0 elapsed=913.333µs
time=YYYY-MM-DDTHH:MM:SS.000+00:00 level=INFO msg="renaming database from temporary location" db=~/path/to/railsconf-2024/storage/production.sqlite3 replica=s3
```

You can inspect the contents of the `restored` database with the `sqlite3` console:

```sh
sqlite3 storage/restored.sqlite3
```

Check how many records are in the `posts` table:

```sql
SELECT COUNT(*) FROM posts;
```

and the same for the `comments` table:

```sql
SELECT COUNT(*) FROM comments;
```

You should see the same number of records in the `restored` database as in the `production` database.

Running a single restoration like this is useful for testing, but in a real-world scenario, you would likely want to ensure that your backups are both fresh and restorable. In order to ensure that you consistently have a resilient backup strategy, the Litestream gem provides a `Litestream.verify!` method to, well, verify your backups. It is worth noting, to be clear, that this is not a feature of the underlying Litestream utility, but only a feature of the Litestream gem itself.

The method takes the path to a database file that you have configured Litestream to backup; that is, it takes one of the `path` values under the `dbs` key in your `litestream.yml` configuration file. In order to verify that the backup for that database is both restorable and fresh, the method will add a new row to that database under the `_litestream_verification` table. It will then wait 10 seconds to give the Litestream utility time to replicate that change to whatever storage providers you have configured. After that, it will download the latest backup from that storage provider and ensure that this verification row is present in the backup. If the verification row is _not_ present, the method will raise a `Litestream::VerificationFailure` exception.

We can force a verification failure by simply stopping the Litestream replication process and then running the verify method. To stop the Litestream replication process, you can press `Ctrl+C` in the terminal tab where you started the replication process. Then, open the Rails console:

```sh
bin/rails console
```

and run:

```ruby
Litestream.verify!("storage/production.sqlite3")
```

After 10 seconds, you will see an error message like:

```
Verification failed for `storage/production.sqlite3` (Litestream::VerificationFailure)
```

To confirm that the verification method works as expected, you can restart the Litestream replication process by going back to the terminal tab where it had been running and start it again:

```sh
bin/rails litestream:replicate
```

Once it is booted, go back to the Rails console and run the verification method again:

```ruby
Litestream.verify!("storage/production.sqlite3")
```

This time, no exception should be raised, indicating that the verification was successful.

Even better than manually verifying your backups is to automate the process. We can create a recurring job to verify our backups for us. To do this, you can generate a new job with the Rails generator:

```sh
bin/rails generate job litestream/verification
```

This will create a new job file in the `app/jobs/litestream` directory. You can then implement the job to run the verification task:

```ruby
class Litestream::VerificationJob < ApplicationJob
  queue_as :default

  def perform
    Litestream::Commands.databases.each do |database_hash|
      Litestream.verify!(database_hash["path"])
    end
  end
end
```

This job will allow us to verify our backup strategy for all databases we have configured Litestream to replicate. If any database fails verification, the job will raise an exception, which will be caught by Rails and logged.

All we need now is a job backend that will allow us to schedule this job to run at regular intervals.

- - -

With backup verification setup, the next step is to add a background job adapter. You will find that step's instructions when you checkout the `step-6` tag.

```sh
git checkout step-6
```

and then open the `workshop/06-adding-solid-queue.md` file to begin.

- - -

You can find the final solution for this step by checking out the `step-5-solution` tag

```sh
git checkout step-5-solution
```
