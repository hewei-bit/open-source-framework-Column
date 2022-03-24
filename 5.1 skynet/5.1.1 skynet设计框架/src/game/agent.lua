local skynet = require "skynet"
local socket = require "skynet.socket"

local tunpack = table.unpack

local clientfd, addr = ...
local client, heartbeat = {}, 0
local redis = setmetatable({0}, {
    __index = function (t, k)
        t[k] = function (red, ...)
            return skynet.call(red[1], "lua", k, ...)
        end
        return t[k]
    end
})

local CMD = {}
function CMD.login(name, password)
    print("cmd.login", name, password)
    if client.clientfd and client.clientfd == clientfd then
        socket.write(clientfd, "不能重复登录")
        return
    end
    if not name and not password then
        socket.write(clientfd, "没有设置用户名或者密码")
        skynet.fork(skynet.exit)
        return
    end
    local ok = redis:exists("role:"..name)
    if not ok then
        redis:hmset("role:"..name, tunpack({
            "name", name,
            "password", password,
        }))
        client.name = name
        client.password = password
        client.clientfd = clientfd
        client.addr = addr
    else
        local fields = redis:hgetall("role:"..name)
        for i=1, #fields, 2 do
            client[fields[i]] = fields[i+1]
        end
        client.clientfd = clientfd
        client.addr = addr
    end
    skynet.fork(function ()
        while true do
            skynet.sleep(1000) -- 10s
            if heartbeat == 0 then
                socket.close(clientfd)
                return
            end
            heartbeat = 0
        end
    end)
end

function CMD.heartbeat()
    print("receive client heartbeat", clientfd)
    heartbeat = heartbeat + 1
end

local function dispatch_message(data)
    local pms = {}
    for pm in string.gmatch(data, "%w+") do
        pms[#pms+1] = pm
    end
    if not next(pms) then
        socket.write(clientfd, "命令不能为空")
        return
    end
    local cmd = pms[1]
    if not CMD[cmd] then
        socket.write(clientfd, cmd.." 该命令不存在")
        return
    end
    skynet.fork(CMD[cmd], select(2, tunpack(pms)))
end

skynet.start(function ()
    clientfd = tonumber(clientfd)
    print("receive a client:", clientfd, addr, skynet.self())
    redis[1] = skynet.uniqueservice("redis")
    socket.start(clientfd)  -- fd  int clientfd = accept(listenfd, addr, sz);
    skynet.fork(function () -- \n
        while true do
            local data = socket.readline(clientfd) -- 协程   让出协程   等待网络数据  网络数据到达
            -- 协程消除回调的例子   zvnet   reactor  异步事件   同步非阻塞
            if not data then
                print("client closed:", clientfd)
                skynet.fork(skynet.exit)
                return
            end
            dispatch_message(data)
        end
    end)
end)
