# README

This is an app built for demonstration purposes for the [RailsConf 2024 conference](https://railsconf.org) held in Detroit, Michigan on May 7–9, 2024.

The application is a basic "Hacker News" style app with `User`s, `Post`s, and `Comment`s. The seeds file will create ~100 users, ~1,000 posts, and ~10 comments per post. Every user has the same password: `password`, so you can sign in as any user to test the app.

## Setup

First you need to clone the repository to your local machine:

```sh
git clone git@github.com:fractaledmind/railsconf-2024.git
cd railsconf-2024
```

After cloning the repository, run the `bin/setup` command to install the dependencies and set up the database:

```sh
bin/setup
```

## Details

This application runs on Ruby 3.2.4, Rails `main`, and SQLite 3.45.3 (gem version 2.0.1).

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

## Setup Load Testing

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
RELAX_SSL=true RAILS_LOG_LEVEL=warn RAILS_ENV=production WEB_CONCURRENCY=10 RAILS_MAX_THREADS=5 bin/rails server
```

The `RELAX_SSL` environment variable is necessary to allow you to use `http://localhost`. The `RAILS_LOG_LEVEL` is set to `warn` to reduce the amount of logging output. Set `WEB_CONCURRENCY` to the number of cores you have on your laptop. I am on an M1 Macbook Pro with 10 cores, and thus I set the value to 10. The `RAILS_MAX_THREADS` controls the number of threads per worker. I left it at the default of 5, but you can tweak it to see how it affects performance.

With your server running in one terminal window, you can use the load testing utility to test the app in another terminal window. Here is the shape of the command you will use to test the app:

```sh
oha -c N -z 10s -m POST http://localhost:3000/benchmarking/PATH
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

## Run Baseline Load Tests

Before we start, let's establish a baseline. This is the starting point from which we will measure our progress. It's important to have a clear understanding of where we are now, so we can see how far we've come.

We will run two load tests to assess the current state of the application's performance; one for the `post_create` action and one for the `posts_index` action. We will run each test with 20 concurrent requests for 10 seconds.

We will run the read operation first since it can't have any effect on the write operation performance (while the inverse cannot be said). But first, it is often worth checking that the endpoint is responding as expected _before_ running a load test. So, let's make a single `curl` request first.

In one terminal window, start the Rails server:

```sh
RELAX_SSL=true RAILS_LOG_LEVEL=warn RAILS_ENV=production WEB_CONCURRENCY=10 RAILS_MAX_THREADS=5 bin/rails server
```

In another, make a single `curl` request to the `posts_index` endpoint:

```sh
curl -X POST http://localhost:3000/benchmarking/posts_index
```

You should see an HTML response with a footer near the bottom of the page:

```
<footer class="mt-auto text-sm text-center">
  <p class="py-4">
    Made with &heartsuit; by <a href="https://twitter.com/fractaledmind" class="underline focus:outline-none focus:ring focus:ring-offset-2 focus:ring-blue-500">@fractaledmind</a> for <a href="https://railsconf.org" class="underline focus:outline-none focus:ring focus:ring-offset-2 focus:ring-blue-500">RailsConf 2024</a>
  </p>
</footer>
```

If you see that response, everything is working as expected. If you don't, you may need to troubleshoot the issue before proceeding.

Once we have verified that our Rails application is responding to the `benchmarking/posts_index` route as expected, we can run the load test and record the results.

As stated earlier, we will use the `oha` tool to run the load test. We will send waves of 20 concurrent requests, which is twice the number of Puma workers that our application has spun up. We will run the test for 10 seconds. The command to run the load test is as follows:

```sh
oha -c 20 -z 10s -m POST http://localhost:3000/benchmarking/posts_index
```

Running this on my 2021 M1 MacBook Pro (32 GB of RAM running MacOS 12.5.1), I get the following results:

```
Summary:
  Success rate:	100.00%
  Total:	10.0063 secs
  Slowest:	5.2124 secs
  Fastest:	0.0224 secs
  Average:	0.1081 secs
  Requests/sec:	40.8744

  Total data:	22.08 MiB
  Size/request:	58.13 KiB
  Size/sec:	2.21 MiB

Response time histogram:
  0.022 [1]   |
  0.541 [387] |■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  1.060 [0]   |
  1.579 [0]   |
  2.098 [0]   |
  2.617 [0]   |
  3.136 [0]   |
  3.655 [0]   |
  4.174 [0]   |
  4.693 [0]   |
  5.212 [1]   |

Response time distribution:
  10.00% in 0.0446 secs
  25.00% in 0.0697 secs
  50.00% in 0.0875 secs
  75.00% in 0.1035 secs
  90.00% in 0.1463 secs
  95.00% in 0.1963 secs
  99.00% in 0.2991 secs
  99.90% in 5.2124 secs
  99.99% in 5.2124 secs


Details (average, fastest, slowest):
  DNS+dialup:	0.0018 secs, 0.0012 secs, 0.0022 secs
  DNS-lookup:	0.0002 secs, 0.0000 secs, 0.0006 secs

Status code distribution:
  [200] 379 responses
  [500] 10 responses

Error distribution:
  [20] aborted due to deadline
```

A quick analysis of the results shows that the average response time is 108 ms, with the slowest response taking **over 5 seconds**! This means that the slowest request is _~50× slower_ than the average. Then, even on my high-powered laptop over localhost, our server can only support ~40 requests per second; this is a low number, and should be higher. Plus, we see 7 responses returning a 500 status code, which is not what we want.

Now that we have the baseline for the `posts_index` action, we can move on to the `post_create` action. We will follow the same steps as above, but this time we will run the load test on the `post_create` endpoint.

With the Rails server still running in one terminal window, we can make a single `curl` request to the `post_create` endpoint in another:

```sh
curl -X POST http://localhost:3000/benchmarking/post_create
```

Again, you should see the `<footer>` in the response. If you don't, you may need to troubleshoot the issue before proceeding.

Once we have verified that our Rails application is responding to the `benchmarking/post_create` route as expected, we can run the load test and record the results.

```sh
oha -c 20 -z 10s -m POST http://localhost:3000/benchmarking/post_create
```

Running this on my 2021 M1 MacBook Pro (32 GB of RAM running MacOS 12.5.1), I get the following results:

```
Summary:
  Success rate:	100.00%
  Total:	10.0051 secs
  Slowest:	5.4778 secs
  Fastest:	0.0033 secs
  Average:	0.0468 secs
  Requests/sec:	379.2079

  Total data:	9.92 MiB
  Size/request:	2.69 KiB
  Size/sec:	1015.39 KiB

Response time histogram:
  0.003 [1]    |
  0.551 [3747] |■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  1.098 [6]    |
  1.646 [0]    |
  2.193 [0]    |
  2.741 [0]    |
  3.288 [0]    |
  3.835 [0]    |
  4.383 [0]    |
  4.930 [0]    |
  5.478 [20]   |

Response time distribution:
  10.00% in 0.0068 secs
  25.00% in 0.0091 secs
  50.00% in 0.0124 secs
  75.00% in 0.0189 secs
  90.00% in 0.0312 secs
  95.00% in 0.0501 secs
  99.00% in 0.1784 secs
  99.90% in 5.3393 secs
  99.99% in 5.4778 secs


Details (average, fastest, slowest):
  DNS+dialup:	0.0016 secs, 0.0013 secs, 0.0021 secs
  DNS-lookup:	0.0001 secs, 0.0000 secs, 0.0004 secs

Status code distribution:
  [500] 2925 responses
  [200] 849 responses

Error distribution:
  [20] aborted due to deadline
```

Immediately, it should jump out just how many `500` responses we are seeing. **77%** of the responses are returning an error status code. Suffice it to say, this is not at all what we want from our application. We still see some requests taking over 5 seconds to complete, which is aweful. But at least for a single resource write request we are seeing a healthier ~380 requests per second.

Our first challenge is to fix these performance issues.

## Adding the Enhanced Adapter

As of today, a SQLite on Rails application will struggle with concurrency. Although Rails, since version 7.1.0, ensures that your SQLite databases are running in [WAL mode](https://www.sqlite.org/wal.html), this is insufficient to ensure quality performance for web applications under concurrent load.

The first major issue are all of the `500` error responses that we saw in our baseline load tests. These are caused by Rails not opening transactions in what SQLite calls ["immediate mode"](https://www.sqlite.org/lang_transaction.html#deferred_immediate_and_exclusive_transactions). In order to ensure only one write operation occurs at a time, SQLite uses a write lock on the database. Only one connection can hold the write lock at a time. By default, SQLite interprets the `BEGIN TRANSACTION` command as initiating a _deferred_ transaction. This means that SQLite will not attempt to acquire the database write lock until a write operation is made inside that transaction. In contrast, an _immediate_ transaction will attempt to acquire the write lock immediately upon the `BEGIN IMMEDIATE TRANSACTION` command being issued.

Opening deferred transactions in a web application with multiple connections open to the database _nearly guarantees_ that you will see a large number of `SQLite3::BusyException` errors. This is because SQLite is unable to retry the write operation within the deferred transaction if the write lock is already held by another connection because any retry would risk the transaction operating against a different snapshot of the database state.

Opening _immediate_ transactions, on the other hand, is safer in a multi-connection environment because SQLite can safely retry the transaction opening command until the write lock is available, since the transaction won't grab a snapshot until the write lock is acquired.

The second major issue are the 5+ second responses. This issue is due to the nature of SQLite being an _embedded_ database. SQLite runs _within_ your Rails application's process; not in a separate process. This is a major reason why SQLite is so fast. But, in Ruby, this also means that we need to be careful to ensure that long-running SQLite IO does not block the Ruby process from handling other requests.

Luckily, we can address both of these pain points by bringing into our project the [`activerecord-enhancedsqlite3-adapter` gem](https://github.com/fractaledmind/activerecord-enhancedsqlite3-adapter). This gem is a zero-configuration drop-in enhancement for the `sqlite3` adapter that comes with Rails. It will automatically open transactions in immediate mode, and it will also ensure that whenever SQLite is waiting for a query to acquire the write lock that other Puma workers can continue to process requests. In addition, it will back port some nice ActiveRecord features that aren't yet in a point release, like deferred foreign key constraints, custom return columns, and generated columns.

To add the `activerecord-enhancedsqlite3-adapter` gem to your project, simply run the following command:

```sh
bundle add activerecord-enhancedsqlite3-adapter
```

Simply by adding the gem to your `Gemfile` you automatically get all of the gem's goodies. You don't need to configure anything.

Let's rerun our load tests and see how things have improved. We run the `posts_index` load test first:

```sh
oha -c 20 -z 10s -m POST http://localhost:3000/benchmarking/posts_index
```

which gave me these results:

```
Summary:
  Success rate:	100.00%
  Total:	10.0034 secs
  Slowest:	0.3261 secs
  Fastest:	0.0062 secs
  Average:	0.0867 secs
  Requests/sec:	231.1223

  Total data:	136.32 MiB
  Size/request:	60.91 KiB
  Size/sec:	13.63 MiB

Response time histogram:
  0.006 [1]   |
  0.038 [136] |■■■■
  0.070 [603] |■■■■■■■■■■■■■■■■■■■
  0.102 [981] |■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.134 [335] |■■■■■■■■■■
  0.166 [130] |■■■■
  0.198 [60]  |■
  0.230 [27]  |
  0.262 [11]  |
  0.294 [4]   |
  0.326 [4]   |

Response time distribution:
  10.00% in 0.0422 secs
  25.00% in 0.0630 secs
  50.00% in 0.0802 secs
  75.00% in 0.1020 secs
  90.00% in 0.1354 secs
  95.00% in 0.1639 secs
  99.00% in 0.2229 secs
  99.90% in 0.3119 secs
  99.99% in 0.3261 secs


Details (average, fastest, slowest):
  DNS+dialup:	0.0020 secs, 0.0014 secs, 0.0024 secs
  DNS-lookup:	0.0002 secs, 0.0000 secs, 0.0004 secs

Status code distribution:
  [200] 2292 responses

Error distribution:
  [20] aborted due to deadline
```

This is a huge improvement! We are now seeing an average response time of 0.0867 seconds, and we are seeing a much healthier 231 requests per second. We are seeing no `500` error responses, and we are seeing no responses taking over 400 milliseconds to complete.

To directly compare this to our baseline, the slowest response dropped from 5.2124 seconds to 0.3261 seconds (16× better), the fastest response dropped from 0.0224 seconds to 0.0062 seconds (4× better), the average response time dropped from 0.1081 seconds to 0.0867 seconds (25% better), and the requests per second increased from 40.8744 to 231.1223 (6× better).

Let's now run the `posts_create` load test and compare:

```sh
oha -c 20 -z 10s -m POST http://localhost:3000/benchmarking/post_create
```

which gave me these results:

```
Summary:
  Success rate:	100.00%
  Total:	10.0021 secs
  Slowest:	0.2113 secs
  Fastest:	0.0040 secs
  Average:	0.0320 secs
  Requests/sec:	624.2716

  Total data:	39.30 MiB
  Size/request:	6.46 KiB
  Size/sec:	3.93 MiB

Response time histogram:
  0.004 [1]    |
  0.025 [2914] |■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.045 [1940] |■■■■■■■■■■■■■■■■■■■■■
  0.066 [858]  |■■■■■■■■■
  0.087 [347]  |■■■
  0.108 [108]  |■
  0.128 [37]   |
  0.149 [12]   |
  0.170 [4]    |
  0.191 [2]    |
  0.211 [1]    |

Response time distribution:
  10.00% in 0.0097 secs
  25.00% in 0.0157 secs
  50.00% in 0.0263 secs
  75.00% in 0.0428 secs
  90.00% in 0.0624 secs
  95.00% in 0.0750 secs
  99.00% in 0.1059 secs
  99.90% in 0.1521 secs
  99.99% in 0.2113 secs


Details (average, fastest, slowest):
  DNS+dialup:	0.0025 secs, 0.0015 secs, 0.0038 secs
  DNS-lookup:	0.0003 secs, 0.0000 secs, 0.0008 secs

Status code distribution:
  [200] 6224 responses

Error distribution:
  [20] aborted due to deadline
```

Another huge improvement! Instead of 70+% of responses returning an error, every single request is successfully processed. And the performance once again is markedly improved. The slowest response dropped from 5.4778 seconds to 0.2113 seconds (26× better), the fastest response dropped from 0.0033 seconds to 0.0040 seconds (20% better), the average response time dropped from 0.0468 seconds to 0.0320 seconds (32% better), and the requests per second increased from 379.2079 to 624.2716 (60% better).

If you want to learn more about the details of how the enhanced adapter gem improves the performance of SQLite on Rails applications, I have a [blog post](https://fractaledmind.github.io/2024/04/15/sqlite-on-rails-the-how-and-why-of-optimal-performance/) with lots of graphics and benchmarks and detailed explanations. For now though, let's just enjoy the easy win.

## Upgrading Ruby to 3.3

There is another quick win we have available to us. Ruby 3.3 was released in December 2023, and it has a number of performance improvements over Ruby 3.2. Let's upgrade our Ruby version to 3.3 and see how it affects our performance.

Upgrading is as simple as updating the value in the `.ruby-version` file in the root of our project. If you don't yet have Ruby 3.3.1 installed on your machine, you can install it with whatever mechanism you use to manage Ruby versions (e.g. `rbenv install 3.3.1` or `asdf install ruby 3.3.1`). Once you have Ruby 3.3.1 installed, run `bundle install` to download the necessary gems for the new Ruby version.

Once ready, restart your Rails server process in your first terminal window, and then run the `posts_index` and `posts_create` load tests in your second terminal window.

When I ran

```sh
oha -c 20 -z 10s -m POST http://localhost:3000/benchmarking/posts_index
```

I got these results:

```
Summary:
  Success rate:	100.00%
  Total:	10.0078 secs
  Slowest:	0.5737 secs
  Fastest:	0.0044 secs
  Average:	0.0475 secs
  Requests/sec:	421.4724

  Total data:	250.85 MiB
  Size/request:	61.19 KiB
  Size/sec:	25.07 MiB

Response time histogram:
  0.004 [1]    |
  0.061 [3460] |■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.118 [665]  |■■■■■■
  0.175 [44]   |
  0.232 [8]    |
  0.289 [1]    |
  0.346 [0]    |
  0.403 [3]    |
  0.460 [4]    |
  0.517 [5]    |
  0.574 [7]    |

Response time distribution:
  10.00% in 0.0219 secs
  25.00% in 0.0315 secs
  50.00% in 0.0418 secs
  75.00% in 0.0540 secs
  90.00% in 0.0722 secs
  95.00% in 0.0877 secs
  99.00% in 0.1523 secs
  99.90% in 0.5476 secs
  99.99% in 0.5737 secs


Details (average, fastest, slowest):
  DNS+dialup:	0.0019 secs, 0.0017 secs, 0.0022 secs
  DNS-lookup:	0.0001 secs, 0.0000 secs, 0.0003 secs

Status code distribution:
  [200] 4198 responses

Error distribution:
  [20] aborted due to deadline
```

Compared to the previous results, the slowest response time dropped from 0.3261 seconds to 0.5737 seconds (43% worse), the fastest response time dropped from 0.0062 seconds to 0.0044 seconds (29% better), the average response time increased from 0.0867 seconds to 0.0475 seconds (45% better), and the requests per second increased from 231.1223 to 421.4724 (82% better). All in all, a solid improvement.

Then, when I ran

```sh
oha -c 20 -z 10s -m POST http://localhost:3000/benchmarking/post_create
```

I got these results:

```
Summary:
  Success rate:	100.00%
  Total:	10.0036 secs
  Slowest:	0.2302 secs
  Fastest:	0.0028 secs
  Average:	0.0238 secs
  Requests/sec:	839.2937

  Total data:	52.85 MiB
  Size/request:	6.46 KiB
  Size/sec:	5.28 MiB

Response time histogram:
  0.003 [1]    |
  0.025 [5357] |■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.048 [2360] |■■■■■■■■■■■■■■
  0.071 [520]  |■■■
  0.094 [100]  |
  0.116 [18]   |
  0.139 [5]    |
  0.162 [8]    |
  0.185 [4]    |
  0.207 [2]    |
  0.230 [1]    |

Response time distribution:
  10.00% in 0.0073 secs
  25.00% in 0.0118 secs
  50.00% in 0.0197 secs
  75.00% in 0.0316 secs
  90.00% in 0.0451 secs
  95.00% in 0.0544 secs
  99.00% in 0.0790 secs
  99.90% in 0.1547 secs
  99.99% in 0.2302 secs


Details (average, fastest, slowest):
  DNS+dialup:	0.0028 secs, 0.0023 secs, 0.0034 secs
  DNS-lookup:	0.0002 secs, 0.0000 secs, 0.0006 secs

Status code distribution:
  [200] 8376 responses

Error distribution:
  [20] aborted due to deadline
```

We see similar improvements for the write operation. The slowest response time dropped from 0.2113 seconds to 0.2302 seconds (9% worse), the fastest response time dropped from 0.0040 seconds to 0.0028 seconds (30% better), the average response time increased from 0.0320 seconds to 0.0238 seconds (34% better), and the requests per second increased from 624.2716 to 839.2937 (35% better).

Without any complicated code changes or mind-cracking debugging, we were able to completely eliminate all of our `500` error responses, notably improve our throughput for read operation (from ~40 RPS to ~400), and massively improve our p99.99 latency (from ~5 seconds to ~50 milliseconds). All of this by installing one gem and bumping to the latest Ruby version. I love quick wins!

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
