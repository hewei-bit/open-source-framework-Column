local skynet = require "skynet"

local redis = require "skynet.db.redis"

skynet.start(function ()
    local rds = redis.connect({
        host = "127.0.0.1",
        port = 6379,
        db = 0, -- select db
    })
    skynet.dispatch("lua", function (_, _, cmd, ...)
        skynet.retpack( rds[cmd](rds, ...))
    end)
end)

