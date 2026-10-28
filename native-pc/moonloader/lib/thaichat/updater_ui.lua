-- Dedicated updater controller. No core, codec, chat send or automatic downloads.
local M={}
function M.new(deps)
    deps=deps or {}
    local json=deps.json or require 'dkjson'
    local info=deps.info or function(s)sampAddChatMessage('[ThaiChatUpdater] '..s,-1)end
    local log=deps.log or function(s)print('[ThaiChatUpdater] '..s)end
    local Ui={visible=false,ready=false,ack=0}
    local client,bindError,lastPhase
    local function bind()
        if client then return end
        local ok,result=pcall(deps.bind or function()return require('thaichat.updater_client').bind()end)
        if ok then client=result;bindError=nil else bindError=tostring(result)end
    end
    local view=(deps.view or require('thaichat.cef_view')).new{
        json=json,log=log,info=info,state=Ui,mailbox=deps.mailbox,
        config={api='__thUpdaterUI',host='thaichat-updater',mailbox='thaichat_updater',
            js='resource/thaichat-updater-ui.js',css='resource/thaichat-updater.css',command='thupdate'}
    }
    local self={}
    local function refresh()
        if not Ui.visible then return end
        bind()
        local ok,state=pcall(function()return client and client:state()end)
        if not ok or not state then state={phase='error',message=bindError or tostring(state),canCheck=false,canInstall=false,canRollback=false}end
        if state.phase~=lastPhase then log('STATE '..tostring(state.phase)..' '..tostring(state.message));lastPhase=state.phase end
        state.session=Ui.session;state.ack=Ui.ack;state.wasCursor=Ui.wasCursor
        view:eval('window.__thUpdaterUI&&window.__thUpdaterUI.receive('..json.encode(state)..');')
    end
    function self:close()if Ui.visible then view:close()end end
    function self:action(action)
        bind()
        if client and(action=='cancel'or action=='rollback')then
            local ok,result=pcall(client[action],client)
            log('COMMAND '..action..' accepted='..tostring(ok and result==true))
            info(ok and result and 'Request accepted. Open /thupdate to see status.'or 'Request was not accepted.')
        else info(bindError or 'Updater is not available.')end
    end
    function self:open()
        if Ui.visible then self:close();return end
        Ui.session=tostring(getGameTimer())..'-'..tostring(math.random(100000,999999))
        Ui.ack=0;Ui.ready=false;Ui.visible=true;Ui.openedAt=getGameTimer()
        log('OPEN /thupdate')
        if not view:open()then Ui.visible=false;return end
        refresh()
    end
    local function control(value)
        local session,action,serial=value:match('^(%S+) (%w+) (%d+)$')
        serial=tonumber(serial)
        if session~=Ui.session or not serial or serial<=Ui.ack then return end
        Ui.ack=serial
        if action=='close'then self:close();return end
        if action=='ready'then Ui.ready=true;log('CEF_READY')
        elseif client and(action=='check'or action=='install'or action=='rollback'or action=='cancel')then
            local ok,result=pcall(client[action],client)
            log('ACTION '..action..' accepted='..tostring(ok and result==true))
            if not ok or not result then info('Request was not accepted; refresh the updater status.')end
        end
        refresh()
    end
    function self:tick()view:tick(control,refresh)end
    return self
end
return M
