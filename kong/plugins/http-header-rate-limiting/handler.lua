local policies = require "kong.plugins.http-header-rate-limiting.policies"
local timestamp = require "kong.tools.timestamp"
local responses = require "kong.tools.responses"
local BasePlugin = require "kong.plugins.base_plugin"

local ngx_log = ngx.log
local pairs = pairs
local tostring = tostring
local ngx_timer_at = ngx.timer.at

local HttpHeaderRateLimitingHandler = BasePlugin:extend()

HttpHeaderRateLimitingHandler.PRIORITY = 902

local function get_identifier(conf)
  local identifier

  -- user is identified by (e.g.) Authorization HTTP header
  local header_name = conf.http_header 
  if header_name then
    header_name = string.gsub(string.lower('http_'..header_name), "-", "_")
    local header = ngx.var[header_name]
    identifier = header 
  end

  if not identifier then
    identifier = ngx.var.remote_addr
  end

  return identifier
end

local function get_usage(conf, api_id, identifier, current_timestamp, limits)
  local usage = {}
  local stop

  for name, limit in pairs(limits) do
    local current_usage, err = policies[conf.policy].usage(conf, api_id, identifier, current_timestamp, name)
    if err then
      return nil, nil, err
    end

    -- What is the current usage for the configured limit name?
    local remaining = limit - current_usage

    -- Recording usage
    usage[name] = {
      limit = limit,
      remaining = remaining
    }

    if remaining <= 0 then
      stop = name
    end
  end

  return usage, stop
end

function HttpHeaderRateLimitingHandler:new()
  HttpHeaderRateLimitingHandler.super.new(self, "http-header-rate-limit")
end

function HttpHeaderRateLimitingHandler:access(conf)
  HttpHeaderRateLimitingHandler.super.access(self)
  local current_timestamp = timestamp.get_utc()

  -- scope this request to a user
  local identifier = get_identifier(conf)
  local api_id = ngx.ctx.api.id
  local policy = conf.policy

  -- Load current metric for configured period
  local limits = {
    second = conf.second,
    minute = conf.minute,
    hour = conf.hour,
    day = conf.day,
    month = conf.month,
    year = conf.year
  }

  local usage, stop, err = get_usage(conf, api_id, identifier, current_timestamp, limits)
  if err then
    return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
  end

  if usage then
    -- If limit is exceeded, terminate the request
    if stop then
      return responses.send(429, "API rate limit exceeded")
    end
  end

  local incr = function(premature, conf, limits, api_id, identifier, current_timestamp, value)
    if premature then
      return
    end
    policies[policy].increment(conf, limits, api_id, identifier, current_timestamp, value)
  end

  -- Increment metrics for configured periods if the request goes through
  local ok, err = ngx_timer_at(0, incr, conf, limits, api_id, identifier, current_timestamp, 1)
  if not ok then
    ngx_log(ngx.ERR, "failed to create timer: ", err)
  end
end

return HttpHeaderRateLimitingHandler