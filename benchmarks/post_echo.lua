wrk.method = "POST"
wrk.body   = '{"title":"benchmark","timestamp":1700000000,"payload":{"counter":123,"active":true,"tags":["perf","http","json"]}}'
wrk.headers["Content-Type"] = "application/json"
