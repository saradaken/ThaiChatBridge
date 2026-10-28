script_name('ThaiChatBridge Tools')
script_description('Optional CEF tools for the standalone ThaiChatBridge ASI')
local tools
local events=require 'samp.events'
function events.onSendCommand(command)
    if command:match('^/thcodecctl%s')then if tools then tools:command(command)end;return false end
end
function onScriptTerminate(script)
    if script==thisScript()and tools then tools:close()end
end
function main()
    while not isSampAvailable()do wait(100)end
    local ok,api=pcall(function()return require('thaichat.native_tools').bind()end)
    if not ok then sampAddChatMessage('[ThaiChatTools] '..tostring(api),-1);return end
    if api.ready()~=1 or api.running()~=1 then sampAddChatMessage('[ThaiChatTools] Native core hooks are not ready. Check ThaiChatBridge.log.',-1);return end
    local created,result=pcall(require('thaichat.native_tools').new,api)
    if not created then sampAddChatMessage('[ThaiChatTools] '..tostring(result),-1);return end
    tools=result;tools:start()
    local font=type(renderCreateFont)=='function'and renderCreateFont('Arial',12,5)
    while true do
        wait(0)
        local remaining,queued=tools:tick()
        if font and(remaining>0 or queued>0)then renderFontDrawText(font,string.format('Codec: %d queued | wait %d s',queued,remaining),30,300,0xFFFFFFFF)end
    end
end
