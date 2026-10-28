-- Optional Codec Lab controller. Owns CEF controls, samples and test queue only.
-- Chat hooks, codec implementation and the live ASI poller belong to the engine.
local M={}
function M.new(deps)
    local Native,CodecOptions,live=deps.native,deps.options,deps.live
    local build,restore,randomPhrase=deps.build,deps.restore,deps.randomPhrase
    local Updater,UpdateError,liveApi=deps.updater,deps.updateError,deps.liveApi
    local PHRASES,PHRASE=deps.phrases,deps.phrase
    local log,info,hex,run=deps.log,deps.info,deps.hex,deps.run
local cases={{raw="\202\199\209\202\180\213\164\195\209\186\032\199\209\185\185\213\233\183\216\161\164\185\183\211\205\208\228\195\161\209\185\205\194\217\232",encoding=0},{raw="\195\205\205\194\217\232\203\185\233\210\184\185\210\164\210\195\185\208\164\195\209\186\032\205\213\161\203\233\210\185\210\183\213\224\168\205\161\209\185\032\072\101\108\108\111",encoding=0},{raw="\091\091\116\104\058\202\199\209\202\180\213\032\093\093\072\101\108\108\111\032\207\240\232\226\229\242\032\091\091\117\056\058\240\159\152\128\032\241\144\128\130\093\093",encoding=1},{raw="\161\162\164\167\168\169\170\171\173\174\175\176\177\178\179\180\181\182\183\184\185\186\187\188\189\190\191\192\193\194\195\197\199\200\201\202\203\204\205\206\161\162\164\167\168\169\170\171\173\174\175\176\177\178\179\180\181\182\183\184\185\186\187\188\189\190\191\192\193\194\195\197\199\200\201\202\203\204\205\206\161\162\164\167\168\169\170\171\173\174\175\176\177\178\179\180\181\182\183\184\185\186\187\188\189\190\191\192\193\194\195\197\199\200\201\202\203\204\205\206",encoding=0}}

-- Mixed script order, emoji sequences, item and unresolved slot ID probes.
cases[#cases+1]={raw="\072\101\108\108\111\032\091\091\116\104\058\228\167\032\093\093\207\240\232\226\229\242\032\091\091\117\056\058\240\159\152\128\032\241\144\128\131\032\093\093\091\091\116\104\058\228\183\194\032\093\093\111\107",encoding=1}
cases[#cases+1]={raw="\091\091\117\056\058\240\159\152\142\032\093\093\091\091\116\104\058\228\183\194\032\093\093\091\091\117\056\058\240\159\145\169\240\159\143\189\226\128\141\240\159\146\187\032\241\144\128\136\032\093\093\208\243\241\241\234\232\233\032\069\110\103\108\105\115\104",encoding=1}
cases[#cases+1]={raw="\091\091\116\104\058\228\183\194\032\093\093\065\032\091\091\116\104\058\228\183\194\032\093\093\193\032\091\091\116\104\058\228\183\194\032\093\093\091\091\117\056\058\240\159\153\130\032\241\144\128\138\093\093",encoding=1}
cases[#cases+1]={raw="\091\091\116\104\058\202\199\209\202\180\213\032\093\093\091\091\117\056\058\240\159\135\185\240\159\135\173\032\093\093\049\091\091\117\056\058\239\184\143\226\131\163\032\240\159\145\141\240\159\143\189\032\241\160\128\129\032\093\093\091\091\116\104\058\168\186\093\093",encoding=1}

-- Thai-focused LZW repetition probes, cases 9 and 10.
cases[#cases+1]={raw="\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032\202\199\209\202\180\213\164\195\209\186\032",encoding=0}
cases[#cases+1]={raw="\228\187\228\203\185\032\228\187\228\203\185\032\228\187\228\203\185\032\228\187\228\203\185\032\228\187\228\203\185\032\228\187\228\203\185\032\228\187\228\203\185\032\228\187\228\203\185\032",encoding=0}
local prefixes={normal='',s='/s ',me='/me ',b='/b '}
local limits=deps.limits or{normal=111,s=99,me=99,b=115}
local queue={}
local json=require 'dkjson'
local SenderEnabled=true
local Ui={visible=false,ready=false,caseId=2,channel='normal',channels={'normal'},last='',wasCursor=false,openedAt=0,ack=0}
local UiSession=tostring(os.time())..tostring(math.floor(os.clock()*1000000))
local CaseLabels={'Thai sentence','Thai + Hello','Thai / English / Russian / emoji / item',
    'Long Thai (capacity test)','Mixed languages, different order','Emoji ZWJ / skin / mixed',
    'Alternating Thai / Latin / Cyrillic','Flags / keycap / skin / slot','Repeated Thai sentence','Repeated Thai word'}
local UiControl
-- Optional tool view: failure must not disable the chat engine.
local View
local viewOk,viewModule=pcall(require,'thaichat.cef_view')
if viewOk then
    local ok,result=pcall(viewModule.new,{json=json,log=log,info=info,state=Ui})
    if ok then View=result else log('CEF_VIEW_INIT_ERROR '..tostring(result))end
else log('CEF_VIEW_LOAD_ERROR '..tostring(viewModule))end
local function cefEval(js)return View and View:eval(js)or false end
local function uiState()
    local c=cases[Ui.caseId]
    local budget=limits[Ui.channel]
    for _,channel in ipairs(Ui.channels)do budget=math.min(budget,limits[channel])end
    local wire,n,mode,e,stats=build(c.raw,c.encoding,budget)
    local utf8=Native.to_utf8(c.raw,c.encoding)or '[Invalid input]'
    local rows,caseList={},{}
    for id=0,9 do rows[#rows+1]={id=id,enabled=CodecOptions.enabled[id],bytes=stats[id]and stats[id].bytes or json.null}end
    for id=1,#cases do caseList[#caseList+1]={id=id,label=CaseLabels[id]or('Case '..id)}end
    local finite=n~=math.huge
    local canSend=#Ui.channels>0 and #c.raw>0 and wire~=nil and SenderEnabled and #queue==0 and getGameTimer()>=run.nextSend
    local remaining=math.ceil(math.max(0,run.nextSend-getGameTimer())/1000)
    local reason=#Ui.channels==0 and 'Select at least one channel' or not SenderEnabled and 'Test sending is OFF' or not finite and 'No enabled codec selected' or
        not wire and 'Over budget: this message will NOT be sent' or #queue>0 and 'A test is queued' or
        getGameTimer()<run.nextSend and ('Wait '..remaining..' seconds') or 'Fits the observed channel budget'
    return {version=deps.version or'PC 1.3 R24',update=Updater and Updater:state()or{phase='error',message=UpdateError or'Updater unavailable',canCheck=false},session=UiSession,ack=Ui.ack,master=SenderEnabled,caseId=Ui.caseId,channel=Ui.channel,channels=Ui.channels,force=CodecOptions.force,
        live=live.enabled,liveAvailable=liveApi~=nil,liveStatus=live.status,liveMs=live.ms,
        remaining=remaining,queued=#queue+(live.pending and 1 or 0),computeMs=deps.computeMs(),
        text=utf8,rows=rows,cases=caseList,budget=budget,bytes=finite and n or json.null,
        selectedMode=mode or json.null,canSend=canSend,reason=reason,last=Ui.last,wasCursor=Ui.wasCursor,phrases=PHRASES,phrase=PHRASE}
end
local function uiRefresh()
    if Ui.visible then cefEval('window.__thCodecUI&&window.__thCodecUI.receive('..json.encode(uiState())..');')end
end
local function uiClose()
    if View then View:close()end
end
local function uiOpen()
    if not View then info('CEF tool unavailable; chat remains active.');return end
    UiSession=tostring(os.time())..tostring(getGameTimer())..tostring(math.floor(os.clock()*1000000))
    Ui.visible=true;Ui.ready=false;Ui.ack=0;Ui.openedAt=getGameTimer()
    if not View:open()then Ui.visible=false;return end
    uiRefresh();log('CEF_UI_OPEN bridge=registry; awaiting local mailbox handshake')
end
UiControl=function(arg)
    local session,action,request,rest=arg:match('^(%S+)%s+(%S+)%s+(%d+)%s*(.*)$')
    if session~=UiSession or not Ui.visible then return end
    if tonumber(request)<=Ui.ack then return end
    Ui.ack=tonumber(request)
    if action=='ready'then Ui.ready=true;log('CEF_UI_READY bridge=registry request='..request);uiRefresh();return end
    if action=='close'then uiClose();return end
    if action=='update_check'and Updater then Updater:check()
    elseif action=='update_install'and Updater then Updater:install()
    elseif action=='update_rollback'and Updater then Updater:rollback()
    elseif action=='live'then live:set(rest=='1')
    elseif action=='toggle'then
        local id,value=rest:match('^(%d)%s+([01])$');id=tonumber(id)
        if id and id<=9 then CodecOptions.enabled[id]=value=='1';queue={}end
    elseif action=='all'and(rest=='0'or rest=='1')then
        for id=0,9 do CodecOptions.enabled[id]=rest=='1'end;queue={}
    elseif action=='master'and(rest=='0'or rest=='1')then SenderEnabled=rest=='1';queue={}
    elseif action=='force'then
        local id=tonumber(rest)
        if rest=='auto'then CodecOptions.force='auto';queue={}
        elseif id and id>=0 and id<=9 and id==math.floor(id)then CodecOptions.force=id;queue={}end
    elseif action=='source'then
        if #rest<=800 and #rest%2==0 and not rest:find('[^a-fA-F0-9]')then
            local text=rest:gsub('%x%x',function(pair)return string.char(tonumber(pair,16))end)
            local raw=Native.from_utf8(text,0);local encoding=0
            if not raw or Native.to_utf8(raw,0)~=text then raw=Native.from_utf8(text,1);encoding=1 end
            if raw and Native.to_utf8(raw,encoding)==text then cases[11]={raw=raw,encoding=encoding};CaseLabels[11]='Custom text';Ui.caseId=11 end
        end
    elseif action=='case'then local id=tonumber(rest);if id and cases[id]and id==math.floor(id)then Ui.caseId=id end
    elseif action=='channels'then
        local requested,valid={},true
        if rest~=''then
            if rest:sub(1,1)==','or rest:sub(-1)==','or rest:find(',,',1,true)then valid=false end
            for channel in rest:gmatch('[^,]+')do
                if not prefixes[channel]or requested[channel]then valid=false end
                requested[channel]=true
            end
        end
        if valid then
            Ui.channels={}
            for _,channel in ipairs({'normal','s','b','me'})do if requested[channel]then Ui.channels[#Ui.channels+1]=channel end end
            Ui.channel=Ui.channels[1]or'normal'
        end
    elseif action=='channel'and prefixes[rest]then Ui.channel=rest;Ui.channels={rest}
    elseif action=='stop'then queue={};live:cancel();Ui.last='Queue stopped'
    elseif action=='send'then
        if uiState().canSend then
            for _,channel in ipairs(Ui.channels)do queue[#queue+1]={channel=channel,case=cases[Ui.caseId],index=Ui.caseId}end
            Ui.last='Queued '..#queue..' channels (8 seconds apart)'
        end
    end
    log('CEF_UI_CONTROL action='..tostring(action)..' request='..request..' value='..tostring(rest))
    uiRefresh()
end

    local self={}
    function self:start()
    sampRegisterChatCommand('thcodecui',function(arg)
        if arg=='close'or Ui.visible then uiClose()else uiOpen()end
    end)
    sampRegisterChatCommand('thcodecctl',UiControl)
    sampRegisterChatCommand('thcodec',function(arg)
        if arg=='ui'then if Ui.visible then uiClose()else uiOpen()end;return end
        local channel,which=arg:match('^(%S+)%s*(%S*)$')
        channel=channel or 'normal';which=(not which or which=='')and 'all'or which
        if channel=='stop'then queue={};live:cancel();info('Stopped.');return end
        if not SenderEnabled then info('Test sending is OFF. Enable it in /thcodecui.');return end
        if not prefixes[channel]then info('Usage: /thcodec normal|s|me|b [1-10|thai|mixed|all]');return end
        if #queue>0 then info('Probe already queued.');return end
        for i,c in ipairs(cases)do
            if which=='all'or(which=='mixed'and i>=5 and i<=8)or(which=='thai'and(i==1 or i==2 or i>=9))or tonumber(which)==i then queue[#queue+1]={channel=channel,case=c,index=i}end
        end
        if #queue==0 then info('Choose case 1-10, thai, mixed or all.');return end
        info('Queued. Manual test only; sends 8 seconds apart.')
    end)
    end
    function self:command(command)
        local arg=command:match('^/thcodecctl%s+(.*)$')
        if arg then UiControl(arg);return false end
    end
    function self:close()if Ui.visible then uiClose()end end
    function self:queued()return #queue end
    function self:tick()
        if View then View:tick(UiControl,uiRefresh)end
        if #queue>0 and getGameTimer()>=run.nextSend then
            local test=table.remove(queue,1)
            local c=test.case
            local wire,n,mode,encoding=build(c.raw,c.encoding,limits[test.channel])
            if not SenderEnabled then wire=nil end
            if wire then
                wire=randomPhrase(wire,limits[test.channel]);n=#wire
                local restored,raw=restore(wire)
                if restored and raw==c.raw then
                    log('SEND case='..test.index..' channel='..test.channel..' bytes='..n..' mode='..mode..' encoding='..encoding..' raw_hex='..hex(c.raw)..' wire_hex='..hex(wire))
                    sampSendChat(prefixes[test.channel]..wire)
                    Ui.last='Sent case '..test.index..': '..n..' bytes, codec '..mode
                    info('Sent case '..test.index..': '..n..'/'..limits[test.channel]..' bytes.')
                else log('LOCAL_ROUNDTRIP_FAILED');info('Local verification failed; not sent.')end
            else
                log('BLOCKED case='..test.index..' bytes='..n..' budget='..limits[test.channel]..' raw_hex='..hex(c.raw))
                info('Case '..test.index..' does not fit ('..n..' bytes); NOT sent. Test text retained in script.')
                Ui.last='Not sent: case '..test.index..' exceeds budget or no codec enabled'
            end
            run.nextSend=getGameTimer()+8000
        end
    end
    return self
end
return M
