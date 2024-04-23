# README

This is an app built for demonstration purposes for the [RailsConf 2024 conference](https://railsconf.org) held in Detroit, Michigan on May 7–9, 2024.

It is intended to be run locally in the `RAILS_ENV=production` environment to demonstrate the performance characteristics of a Rails application using SQLite.

## Setup

After cloning the repository, run the `bin/setup` command to install the dependencies and set up the database. It is recommended to run all commands in the `production` environments to allow you to better simulate the application locally:

```sh
RAILS_ENV=production bin/setup
```

## Details

The application is a basic "Hacker News" style app with `User`s, `Post`s, and `Comment`s. The seeds file will create ~100 users, ~1,000 posts, and ~10 comments per post. Every user has the same password: `password`, so you can sign in as any user to test the app.

This application runs on Ruby 3.2.1, Rails `main`, and SQLite 3.45.3 (gem version 2.0.1).

It was created using the following command:

```
rails new railsconf-2024 \
  --main \
  --database=sqlite3 \
  --asset-pipeline=propshaft \
  --javascript=esbuild \
  --css=tailwind \
  --skip-jbuilder \
  --skip-action-mailbox \
  --skip-spring
```

So it uses [`propshaft`](https://github.com/rails/propshaft) for asset compilation, [`esbuild`](https://esbuild.github.io) for JavaScript bundling, and [`tailwind`](https://tailwindcss.com) for CSS.

To demonstrate how to control the actual compilation of SQLite, this application sets the `cflags` for the SQLite executable. The `sqlite3-ruby` gem allows us to control the compilation flags used to compile the SQLite executable. We can set the compilation flags via the `BUNDLE_BUILD__SQLITE3` environment variable set in the `.bundle/config` file. The [SQLite docs recommend 12 flags](https://www.sqlite.org/compile.html#recommended_compile_time_options) for a 5% improvement. The `sqlite3-ruby` gem needs some of the features recommended to be omitted, and some are useful for Rails apps. These 7 flags are my recommendation for a Rails app, and can be set using the following command:

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

Typically, the `.bundle/config` file is removed from source control, but we add it back to make this app more portable. Note, however, that this does restrict individual configuration of Bundler.

Finally, in order to ensure that SQLite is compiled from source, we need to specify in the `Gemfile` that the SQLite gem should use the `ruby` platform version.

## Load Testing

Load testing can be done using the [`oha` CLI utility](https://github.com/hatoo/oha), which can be installed on MacOS via [homebrew](https://brew.sh):

```sh
brew install oha
```

and on Windows via [winget](https://github.com/microsoft/winget-cli):

```sh
winget install hatoo.oha
```

or using their [precompiled binaries](https://github.com/hatoo/oha?tab=readme-ov-file#installation) on other platforms.

In order to perform the load testing, you will need to run the web server in the `production` environment. To do this from your laptop, there are a few environment variables you will need to set:

```sh
RELAX_SSL=true RAILS_LOG_LEVEL=warn SECRET_KEY_BASE=secret RAILS_ENV=production WEB_CONCURRENCY=10 RAILS_MAX_THREADS=5 bin/rails server
```

The `RELAX_SSL` environment variable is necessary to allow you to use `http://localhost`. The `RAILS_LOG_LEVEL` is set to `warn` to reduce the amount of logging output. The `SECRET_KEY_BASE` is a dummy value that is required for the app to start. Set `WEB_CONCURRENCY` to the number of cores you have on your laptop. I am on an M1 Macbook Pro with 10 cores, and thus I set the value to 10. The `RAILS_MAX_THREADS` controls the number of threads per worker. I left it at the default of 5, but you can tweak it to see how it affects performance.

With your server running in one terminal window, you can use the load testing utility to test the app in another terminal window. Here is the shape of the command you will use to test the app:

```sh
oha -c N -z 5s -m POST
    --latency-correction
    --disable-keepalive
    --redirect 0
    http://localhost:3000/benchmarking/PATH
```

`N` is the number of concurrent requests that `oha` will make. I recommend running a large variety of different scenarios with different values of `N`. Personally, I scale up from 1 to 256 concurrent requests, doubling the number of concurrent requests each time. In general, when `N` matches your `WEB_CONCURRENCY` number, this is mostly likely the sweet spot for this app.

`PATH` can be any of the benchmarking paths defined in the app. The app has a few different paths that you can test. From the `routes.rb` file:

```ruby
namespace :benchmarking do
  post "read_heavy"
  post "write_heavy"
  post "balanced"
  post "post_create"
  post "comment_create"
  post "post_destroy"
  post "comment_destroy"
  post "post_show"
  post "posts_index"
  post "user_show"
end
```

The `read_heavy`, `write_heavy`, and `balanced` paths are designed to test the performance of the app under a mix of scenarios. Each of those paths will randomly run one of the more precise actions, with the overall distribution defined in the controller to match the name. The rest of the paths are specific actions, which you can use if you want to see how a particular action handles concurrent load.

In general, I recommend running the `balanced` path with a variety of different values of `N` to see how the app performs under a variety of different scenarios.

For load testing the app in our different configurations, we will run the `post_create` benchmark with 20 concurrent requests (twice the number of Puma workers we spin up, to ensure contention) for 10 seconds:

```sh
oha -c 20 -z 10s -m POST \
    --latency-correction \
    --disable-keepalive \
    --redirect 0 \
    http://localhost:3000/benchmarking/post_create
```

And then the same setup with `posts_index`:

```sh
oha -c 20 -z 10s -m POST \
    --latency-correction \
    --disable-keepalive \
    --redirect 0 \
    http://localhost:3000/benchmarking/posts_index
```

## Results

Running this load test against our app, I get the following results on my laptop:

```
$ oha -c 20 -z 10s -m POST \
    --latency-correction \
    --disable-keepalive \
    --redirect 0 \
    http://localhost:3000/benchmarking/post_create

Summary:
  Success rate:	100.00%
  Total:	10.0025 secs
  Slowest:	5.2051 secs
  Fastest:	0.0038 secs
  Average:	0.0238 secs
  Requests/sec:	102.1747

  Total data:	1.16 MiB
  Size/request:	1.19 KiB
  Size/sec:	118.76 KiB

Response time histogram:
  0.004 [1]   |
  0.524 [999] |■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  1.044 [0]   |
  1.564 [0]   |
  2.084 [0]   |
  2.604 [0]   |
  3.125 [0]   |
  3.645 [0]   |
  4.165 [0]   |
  4.685 [0]   |
  5.205 [2]   |

Response time distribution:
  10.00% in 0.0076 secs
  25.00% in 0.0091 secs
  50.00% in 0.0110 secs
  75.00% in 0.0139 secs
  90.00% in 0.0204 secs
  95.00% in 0.0293 secs
  99.00% in 0.0643 secs
  99.90% in 5.1837 secs
  99.99% in 5.2051 secs


Details (average, fastest, slowest):
  DNS+dialup:	0.0004 secs, 0.0001 secs, 0.0033 secs
  DNS-lookup:	0.0000 secs, 0.0000 secs, 0.0004 secs

Status code distribution:
  [500] 744 responses
  [302] 258 responses

Error distribution:
  [20] aborted due to deadline
```

and

```
$ oha -c 20 -z 10s -m POST \
    --latency-correction \
    --disable-keepalive \
    --redirect 0 \
    http://localhost:3000/benchmarking/posts_index

Summary:
  Success rate:	100.00%
  Total:	10.0021 secs
  Slowest:	5.3826 secs
  Fastest:	0.0278 secs
  Average:	0.1672 secs
  Requests/sec:	121.0740

  Total data:	57.05 MiB
  Size/request:	49.05 KiB
  Size/sec:	5.70 MiB

Response time histogram:
  0.028 [1]    |
  0.563 [1170] |■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  1.099 [0]    |
  1.634 [0]    |
  2.170 [0]    |
  2.705 [0]    |
  3.241 [0]    |
  3.776 [0]    |
  4.312 [0]    |
  4.847 [0]    |
  5.383 [20]   |

Response time distribution:
  10.00% in 0.0614 secs
  25.00% in 0.0676 secs
  50.00% in 0.0750 secs
  75.00% in 0.0850 secs
  90.00% in 0.1082 secs
  95.00% in 0.1420 secs
  99.00% in 5.2617 secs
  99.90% in 5.3535 secs
  99.99% in 5.3826 secs


Details (average, fastest, slowest):
  DNS+dialup:	0.0007 secs, 0.0001 secs, 0.0095 secs
  DNS-lookup:	0.0000 secs, 0.0000 secs, 0.0047 secs

Status code distribution:
  [200] 1186 responses
  [500] 5 responses

Error distribution:
  [20] aborted due to deadline
```

I ran the command on a freshly seeded database. The single slowest request took 5.3826 seconds. When hitting the create endpoint, the average request time was 0.0238 seconds, while for the index endpoint it was 0.1672. The average requests per second was 121.0740 for index and 102.1747 for create. We see a notable difference in errored responses across the two though—0.004% errored for index, but 74% for create.

There are a few key details to pay attention to in the output:

1. There are *way too many* errored responses. Looking at the logs, you will see that all of these errors are `SQLite3::BusyException: database is locked` exceptions.
2. The slowest request took *200&times;* longer than the average request. This is a sign that the app is not handling the load well at all.
3. Even on our high-powered laptop over localhost, our server can only support ~100 requests per second. This is a low number, and should be higher.
4. The p99 response time is over 5 seconds. This is a very high number, and it is likely that users will not be happy with the performance of the app.

The goal of our work is to improve these metrics while simultaneously adding more features to the app.