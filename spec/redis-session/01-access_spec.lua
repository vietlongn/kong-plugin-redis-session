local helpers = require "spec.helpers"

describe("Redis-Session: redisSession (access)", function()
  local client

  setup(function()
    local api1 = assert(helpers.dao.apis:insert { 
        name = "api-1", 
        hosts = { "test1.com" }, 
        upstream_url = "http://mockbin.com",
    })

    assert(helpers.dao.plugins:insert {
      api_id = api1.id,
      name = "redisSession",
    })

    -- start kong, while setting the config item `custom_plugins` to make sure our
    -- plugin gets loaded
    assert(helpers.start_kong {custom_plugins = "redisSession"})
  end)

  teardown(function()
    helpers.stop_kong()
  end)

  before_each(function()
    client = helpers.proxy_client()
  end)

  after_each(function()
    if client then client:close() end
  end)

  describe("request", function()
    it("Add Authorization Header (JWT)", function()
      local r = assert(client:send {
        method = "GET",
        path = "/request",  -- makes mockbin return the entire request
        headers = {
          host = "test1.com"
        }
      })
      -- validate that the request succeeded, response status 200
      assert.response(r).has.status(200)
      -- now check the request (as echoed by mockbin) to have the header
      local header_value = assert.request(r).has.header("Authorization")
      -- validate the value of that header
      assert.contains("Bearer", header_value)
    end)
  end)


end)