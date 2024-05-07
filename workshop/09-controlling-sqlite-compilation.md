## Controling SQLite Compilation

Because SQLite is simply a single executable, it is easy to control the actual compilation of SQLite. The `sqlite3-ruby` gem allows us to control the compilation flags used to compile the SQLite executable. We can set the compilation flags via the `BUNDLE_BUILD__SQLITE3` environment variable set in the `.bundle/config` file. Bundler allows you set set such configuration via the `bundle config set` command. To control SQLite compilation, you use the `bundle config set build.sqlite3` command passing the `--with-sqlite-cflags` argument.

The [SQLite docs recommend 12 flags](https://www.sqlite.org/compile.html#recommended_compile_time_options) for a 5% improvement. The `sqlite3-ruby` gem needs some of the features recommended to be omitted, and some are useful for Rails apps. These 7 flags are my recommendation for a Rails app, and can be set using the following command:

```sh
bundle config set build.sqlite3 \
  "--with-sqlite-cflags='
      -DSQLITE_DQS=0
      -DSQLITE_THREADSAFE=0
      -DSQLITE_DEFAULT_MEMSTATUS=0
      -DSQLITE_LIKE_DOESNT_MATCH_BLOBS
      -DSQLITE_MAX_EXPR_DEPTH=0
      -DSQLITE_OMIT_SHARED_CACHE
      -DSQLITE_USE_ALLOCA'"
```

Typically, the `.bundle/config` file is removed from source control, but we add it back to make this app more portable. Note, however, that this does restrict individual configuration of Bundler. This requires a change to the `.gitignore` file.

Finally, in order to ensure that SQLite is compiled from source, we need to specify in the `Gemfile` that the SQLite gem should use the `ruby` platform version.

```ruby
gem "sqlite3", ">= 2.0", force_ruby_platform: true
```

- - -

With SQLite custom compiled, the next step is to setup the repository to work with branch-specific databases. You will find that step's instructions when you checkout the `step-10` tag.

```sh
git checkout step-10
```

and then open the `workshop/10-branch-specific-databases.md` file to begin.

- - -

You can find the final solution for this step by checking out the `step-9-solution` tag

```sh
git checkout step-9-solution
```
