local skynet = require "skynet"
local socket = require "skynet.socket"

skynet.start(function ()
    skynet.uniqueservice("redis")
    local listenfd = socket.listen("0.0.0.0", 8888)
    socket.start(listenfd, function (clientfd, addr)
        skynet.newservice("agent", clientfd, addr)
    end)
end)
