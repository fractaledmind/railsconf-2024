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

- - -

The next step is to upgrade Ruby to continue fixing these performance issues. You will find that step's instructions when you checkout the `step-3` tag.

```sh
git checkout step-3
```

and then open the `workshop/03-upgrading-to-ruby-3-3.md` file to begin.

- - -

You can find the final solution for this step by checking out the `step-2-solution` tag

```sh
git checkout step-2-solution
```
