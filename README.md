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
