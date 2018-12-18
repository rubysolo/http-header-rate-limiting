local singletons = require "kong.singletons"
local timestamp = require "kong.tools.timestamp"
local ngx_log = ngx.log
local shm = ngx.shared.kong_cache

local pairs = pairs
local fmt = string.format

local get_local_key = function(api_id, identifier, period_date, name)
  return fmt("httpheaderratelimiting:%s:%s:%s:%s", api_id, identifier, period_date, name)
end

local EXPIRATIONS = {
  second = 1,
  minute = 60,
  hour = 3600,
  day = 86400,
  month = 2592000,
  year = 31536000,
}

return {
  ["local"] = {
    increment = function(conf, limits, api_id, identifier, current_timestamp, value)
      local periods = timestamp.get_timestamps(current_timestamp)
      for period, period_date in pairs(periods) do
        if limits[period] then
          local cache_key = get_local_key(api_id, identifier, period_date, period)

          local newval, err = shm:incr(cache_key, value, 0)
          if not newval then
            ngx_log(ngx.ERR, "[http-header-rate-limiting] could not increment counter ",
                             "for period '", period, "': ", err)
            return nil, err
          end
        end
      end

      return true
    end,
    usage = function(conf, api_id, identifier, current_timestamp, name)
      local periods = timestamp.get_timestamps(current_timestamp)
      local cache_key = get_local_key(api_id, identifier, periods[name], name)
      local current_metric, err = shm:get(cache_key)
      if err then
        return nil, err
      end
      return current_metric and current_metric or 0
    end
  },
}