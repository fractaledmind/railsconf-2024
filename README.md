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

