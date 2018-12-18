package = "http-header-rate-limiting"
version = "0.1.0-1"
source = {
   url = "https://github.com/rubysolo/http-header-rate-limiting"
}
description = {
   homepage = "https://github.com/rubysolo/http-header-rate-limiting",
   license = "MIT"
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.http-header-rate-limiting.handler"] = "kong/plugins/http-header-rate-limiting/handler.lua",
      ["kong.plugins.http-header-rate-limiting.policies"] = "kong/plugins/http-header-rate-limiting/policies.lua"
      ["kong.plugins.http-header-rate-limiting.schema"] = "kong/plugins/http-header-rate-limiting/schema.lua"
   }
}
