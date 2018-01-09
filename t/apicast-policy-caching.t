use lib 't';
use Test::APIcast::Blackbox 'no_plan';

repeat_each(1);
run_tests();

__DATA__

=== TEST 1: Caching policy configured as resilient
When the cache is configured as 'resilient', cache entries are not deleted when
backend returns a 500 error. This means that if we get a 200, and then
backend fails and starts returning 500, we will still have the 200 cached
and we'll continue authorizing requests.
In order to test this, we configure our backend so the first request returns
200, and all the others 502.
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.caching",
            "configuration": { "caching_type": "resilient" }
          },
          {
            "name": "apicast.policy.apicast"
          }
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local test_counter = ngx.shared.test_counter or 0
      if test_counter == 0 then
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(200)
      else
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(502)
      end
    }
  }
--- upstream
  location / {
     echo 'yay, api backend';
  }
--- request eval
["GET /test?user_key=foo", "GET /foo?user_key=foo", "GET /?user_key=foo"]
--- response_body eval
["yay, api backend\x{0a}", "yay, api backend\x{0a}", "yay, api backend\x{0a}"]
--- error_code eval
[ 200, 200, 200 ]

=== TEST 2: Caching policy configured as strict
When the cache is configured as 'strict', entries are removed when backend
denies the authorization with a 4xx or when it fails with a 5xx.
In order to test this, we use a backend that returns 200 on the first call, and
502 on the rest. We need to test that the first call is authorized, the
second is too because it will be cached, and the third will not be authorized
because the cache was cleared in the second call.
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "policy_chain": [
          {
            "name": "apicast.policy.caching",
            "configuration": { "caching_type": "strict" }
          },
          {
            "name": "apicast.policy.apicast"
          }
        ],
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "error_auth_failed": "Authentication failed!",
        "error_status_auth_failed": 444,
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local test_counter = ngx.shared.test_counter or 0
      if test_counter == 0 then
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(200)
      else
        ngx.shared.test_counter = test_counter + 1
        ngx.exit(502)
      end
    }
  }
--- upstream
  location / {
     echo 'yay, api backend';
  }
--- request eval
["GET /test?user_key=foo", "GET /foo?user_key=foo", "GET /?user_key=foo"]
--- response_body eval
["yay, api backend\x{0a}", "yay, api backend\x{0a}", "Authentication failed!"]
--- error_code eval
[ 200, 200, 444 ]
