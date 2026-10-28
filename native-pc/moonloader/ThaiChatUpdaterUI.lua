script_name('ThaiChatBridge Updater UI')
script_description('Dedicated updater window; independent of the message core')
local ui
function onScriptTerminate(script)
    if script==thisScript()and ui then ui:close()end
end
function main()
    while not isSampAvailable()do wait(100)end
    ui=require('thaichat.updater_ui').new()
    sampRegisterChatCommand('thupdate',function(arg)
        if arg=='close'then ui:close()
        elseif arg=='cancel'or arg=='rollback'then ui:action(arg)
        else ui:open()end
    end)
    while true do wait(0);ui:tick()end
end
