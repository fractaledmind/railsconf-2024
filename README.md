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
