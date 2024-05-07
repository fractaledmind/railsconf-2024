## SQLite Extensions

Beyond simply spinning up separate SQLite databases for IO-bound Rails components, there are a number of ways that we can enhance working with SQLite itself. One of the most powerful features of SQLite is its support for [loadable extensions](https://www.sqlite.org/loadext.html). These extensions allow you to add new functionality to SQLite, such as full-text search, JSON support, or even custom functions.

There is an unofficial SQLite extension package manager called [sqlpkg](https://sqlpkg.org/). We can use sqlpkg to install a number of useful SQLite extensions. View all 97 extensions available in sqlpkg [here](https://sqlpkg.org/all/).

We can install the [Ruby gem](https://github.com/fractaledmind/sqlpkg-ruby) that ships with precompiled executables like so:

```sh
bundle add sqlpkg
```

And then we can install it into our Rails application like so:

```sh
bin/rails generate sqlpkg:install
```

This will create 2 files in our application:

1. `.sqlpkg`, which ensures that sqlpkg will run in "project scope"
2. `sqlpkg.lock`, where sqlpkg will store information about the installed packages

The gem provides the `sqlpkg` executable, which we can use to install SQLite extensions. For example, to install the [`uuid` extension](https://github.com/nalgeon/sqlean/blob/main/docs/uuid.md), we can run:

```sh
bundle exec sqlpkg install nalgeon/uuid
```

Or, to install the [`ulid` extension](https://github.com/asg017/sqlite-ulid), we can run:

```sh
bundle exec sqlpkg install asg017/ulid
```

As you will see on the [sqlpkg website](https://sqlpkg.org/all/), each extension has an identifier made up of a namespace and a name. There are many more extensions available.

When you do install an extension, you will see logs like:

```
(project scope)
> installing asg017/ulid...
✓ installed package asg017/ulid to .sqlpkg/asg017/ulid
```

In order to make use of these extensions in our Rails application, we need to load them when the database is opened. The enhanced adapter gem can load any extensions installed via `sqlpkg` by listing them in the `database.yml` file. For example, to load the `uuid` and `ulid` extensions, we would add the following to our `config/database.yml` file:

```yaml
extensions:
  - nalgeon/uuid
  - asg017/ulid
```

If you want an extension to be loaded for each database (`primary`, `queue`, and `cache`), add this section to the `default` section of the `database.yml` file. If there are some extensions that you only want to load for a specific database, you can add this section to the specific database configuration.

For example, if we only want to load the `uuid` extension for the `primary` database, we would add this section to the `primary` section of the `database.yml` file:

```yaml
primary: &primary
  <<: *default
  database: storage/<%= Rails.env %>.sqlite3
  extensions:
    - nalgeon/uuid
```

But, if we wanted to load the `ulid` extension for all databases, we would add this section to the `default` section of the `database.yml` file:

```yaml
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
  extensions:
    - asg017/ulid
```

We can confirm that the extensions are loaded by opening the Rails console and running a query that uses the extension. For example, to generate a UUID, we can run:

```ruby
ActiveRecord::Base.connection.execute 'select uuid4();'
```

If you see a return value something like:

```ruby
[{"uuid4()"=>"abf3946d-5e04-4da0-8452-158cd983bd21"}]
```

then you know that the extension is loaded and working correctly.

In order to ensure that your extensions are downloaded and installed in your production environment, you need to ensure that the `.sqlpkg` directory is present in your application's repository, but doesn't contain any files. Then, you need to call the `sqlpkg install` command as a part of your deployment process:

```sh
bundle exec sqlpkg install
```

To do this, let's first create a `.keep` file in the `.sqlpkg` directory:

```sh
touch .sqlpkg/.keep
```

Then, we can add the following to the `.gitignore` file:

```
/.sqlpkg/*
!/.sqlpkg/.keep
```

This ignores all files in the `.sqlpkg` directory except for the `.keep` file. This way, the `.sqlpkg` directory will be present in the repository, but will not contain any files. This allows us to run the `sqlpkg install` command as a part of our deployment process.

When you run the `sqlpkg install` command without specifying a package, it will install all packages listed in the `sqlpkg.lock` file. So, you can install SQLite extensions locally, commit the `sqlpkg.lock` file to your repository, and then run the `sqlpkg install` command as a part of your deployment process to ensure that the extensions are installed in your production environment.

- - -

With SQLite extensions integrated, the next step is to control how the SQLite executable is compiled. You will find that step's instructions when you checkout the `step-9` tag.

```sh
git checkout step-9
```

and then open the `workshop/09-controlling-sqlite-compilation.md` file to begin.

- - -

You can find the final solution for this step by checking out the `step-8-solution` tag

```sh
git checkout step-8-solution
```
