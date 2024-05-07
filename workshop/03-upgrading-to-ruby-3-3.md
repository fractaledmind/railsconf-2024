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

- - -

With core performance issues resolved, the next step is to ensure that the application's data is resilient. You will find that step's instructions when you checkout the `step-4` tag.

```sh
git checkout step-4
```

and then open the `workshop/04-data-resilience.md` file to begin.

- - -

You can find the final solution for this step by checking out the `step-3-solution` tag

```sh
git checkout step-3-solution
```
