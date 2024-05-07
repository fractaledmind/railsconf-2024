## Branch-specific Databases

Another enhancement that SQLite affords is a nice developer experience — branch-specific databases. If you have ever worked in team on a single codebase, you very likely have experienced the situation where you are working on a longer running feature branch, but then a colleague asks you to review or help on a feature branch that they had been working on. What happens when you had some migrations in your branch and they had some migrations in their branch? Because your database typically has no awareness of you changing git branches, your database ends up in a mixed state with both sets of migrations applied. When you return to your branch, your database is in an altered state than you left it.

Because SQLite stores your entire database in literal files on disk and only runs embedded in your application process, databases are very cheap to create. So, what if we simply spun up a completely new database for each and every git branch you use in your application? Not only would this solve the mixed migrations issue, but it also opens up the ability to prepare branch-specific data that can then be shared with collegues or used in manual testing for that branch.

So, what all is entailed in getting such a setup for your Rails application? Well, the basic implementation is literally only 2 lines of code in 2 files!

Firstly, in your `database.yml` file, we need to update how we set the database name for the `primary` database. Of course, if we wanted or needed to, we could do the same for our `queue` and `cache` databases as well, but I personally haven't yet needed that level of isolation. Instead of setting the name of the `primary` database to the current Rails environment, we want to set the name to the current git branch. Since we can execute shell commands easily in Ruby, this is nothing more than `git branch --show-current`. Because we can be in a detached state in git, we also need a fallback. You can either use `"development"` or `"detached"` or whatever else you'd like. In the end, our new configuration will look something like:

```yaml
primary: &primary
  <<: *default
  database: storage/<%= `git branch --show-current`.chomp || "detached" %>.sqlite3
```

This ensures that whenever Rails loads the database configuration, it will simply introspect the current git branch and use that as the database name. The second requirement is that this database file be properly prepared; that is, have the schema set and seeds ran.

Rails provides a Rake task for precisely this use: `db:prepare`. More importantly for us, though, is that Rails provides a corresponding Ruby method as well: `ActiveRecord::Tasks::DatabaseTasks.prepare_all`. We simply need to ensure that this is run whenever Rails boots, and this is just what the `config.after_initialize` hook is for. Since this is only a development feature, we can simply add this to our `config/environments/development.rb` file:

```ruby
config.after_initialize do
  ActiveRecord::Tasks::DatabaseTasks.prepare_all
end
```

This hook ensures that whenever Rails boots, our database will definitely be prepared. This means when you open a console session, start the application server, or run a `rails runner` task. This is a very powerful feature that can save you a lot of time and headache when working on multiple branches simultaneously.

But, what if you want to copy the table data from one branch to another? Well, that's a bit more involved, but it's still quite doable. The core piece of the implementation puzzle is SQLite's [`ATTACH` functionality](https://www.sqlite.org/lang_attach.html), which allows you to, well, attach another database to the current database connection. This allows you to run queries that span multiple databases. The basic idea is to attach the source database to the target database, and then copy the data from the source to the target. Mixin a bit of dynamic string generation, and you can craft a shell function that merges all table data from a source database into a target database

```sh
db_merge() {
  target="$1"
  source="$2"

  # Attach merging database to base database
  merge_sql="ATTACH DATABASE '$source' AS merging; BEGIN TRANSACTION;"
  # Loop through each table in merging database
  for table_name in $(sqlite3 $source "SELECT name FROM sqlite_master WHERE type = 'table';")
  do
    columns=$(sqlite3 $source "SELECT name FROM pragma_table_info('$table_name');" | tr '\n' ',' | sed 's/.$//')
    # Merge table data into target database, ignoring any duplicate entries
    merge_sql+=" INSERT OR IGNORE INTO $table_name ($columns) SELECT $columns FROM merging.$table_name;"
  done
  merge_sql+=" COMMIT TRANSACTION; DETACH DATABASE merging;"

  sqlite3 "$target" "$merge_sql"
}
```

What I like to do is add a script to the `bin/` directory that provides the ability to branch or merge databases easily. Let's create a `bin/sqlite` script and make it executable:

```sh
touch bin/sqlite
chmod u+x bin/sqlite
```

In addition to merging table data, we can provide the ability to clone a database's schema into a new database as well:

```sh
db_branch() {
  target="$1"
  source="$2"

  sqlite3 "$source" ".schema --nosys" | sqlite3 "$target"
}
```

All our `bin/sqlite` script will do is provided structured access to these functions. We want it to support both a `branch` and a `merge` command, and the `branch` command should default to copying both the schema and the table data, but you can specify to only copy the schema. The `merge` command should only copy the table data.

The file is relatively long (~175 lines), so I won't copy it here, but you can find it in the repository at this commit. In addition to our `after_initialize` automated hook, we now have the ability to branch and merge whatever SQLite databases we like, whenever we like.

To give one example of how we could use this script to automate branching and copying table data, we could create a post-checkout git hook:


```sh
touch .git/hooks/post-checkout
chmod u+x .git/hooks/post-checkout
```

And then write some shell to ensure that we have checked out a new branch and call our `bin/sqlite branch` command with the new branch and previous branch:

```sh
# If this is a file checkout, do nothing
if [ "$3" == "0" ]; then exit; fi

# If the prev and curr refs don't match, do nothing
if [ "$1" != "$2" ]; then exit; fi

reflog=$(git reflog)
prev_branch=$(echo $reflog | awk 'NR==1{ print $6; exit }')
curr_branch=$(echo $reflog | awk 'NR==1{ print $8; exit }')
num_checkouts=$(echo $reflog | grep -o $curr_branch | wc -l)

# If the number of checkouts equals one, a new branch has been created
if [ ${num_checkouts} -eq 1 ]; then
  bin/sqlite branch "storage/$curr_branch.sqlite3" "storage/$prev_branch.sqlite3" --with-data
fi
```

With this in place, we wouldn't really need the `after_initialize` Rails hook as our new branch database would be created in this post-checkout git hook. Moreover, in this example that database would include all of the data from the original branch database as well.

Depending on how your team works, this kind of automation may be a bit too heavy handed. I personally prefer to simply have the `bin/sqlite` script and run `bin/sqlite merge` whenever I want to populate a new database with table data from a pre-existing database. But, I wanted to at least demonstrate the power and flexibility possible with these tools.

Regardless of how precisely you wire everything together, working with branch-specific databases has been a solid developer experience improvement for me.

- - -

With the repository working with branch-specific databases, the final step is to setup error monitoring. You will find that step's instructions when you checkout the `step-11` tag.

```sh
git checkout step-11
```

and then open the `workshop/11-error-monitoring.md` file to begin.

- - -

You can find the final solution for this step by checking out the `step-10-solution` tag

```sh
git checkout step-10-solution
```
