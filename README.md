# HTTP Header Rate Limiting

The stock rate limiting plugin from Kong assumes that Kong is handling authorization (with a fallback to IP address).  This custom plugin (modified from the stock plugin) is intended for installations where Kong is acting as the load balancer, but authorization is handled elsewhere.  It buckets users by the value of an HTTP header (e.g. Authorization) with a fallback to IP address.  To simplify the code for my use-case, this plugin only implements the `local` policy.

## Usage instructions

Assuming you are running Kong in docker, add the following to your `docker run` command:

```
-e "KONG_LUA_PACKAGE_PATH=/etc/?.lua" \
-e "KONG_CUSTOM_PLUGINS=http-header-rate-limiting" \
-v $(pwd)/kong/plugins/http-header-rate-limiting:/etc/kong/plugins/http-header-rate-limiting \
```