(function () {
  'use strict';
  if (window.__thCodecUI) { window.__thCodecUI.destroy(); }
  var host = document.createElement('div');
  host.id = 'thaichat-codec-lab';
  host.style.cssText = 'position:fixed;inset:0;z-index:2147483646;pointer-events:none';
  document.body.appendChild(host);
  var shadow = host.attachShadow({mode:'open'});
  shadow.innerHTML = `
  <style>
:host{all:initial;color-scheme:dark}*{box-sizing:border-box}[hidden]{display:none!important}.shade{position:fixed;inset:0;display:grid;place-items:center;pointer-events:auto;font:14px/1.45 Segoe UI,Tahoma,sans-serif;color:#eaf0fc}.panel{display:flex;flex-direction:column;overflow:hidden}header{display:flex;justify-content:space-between;align-items:center}h1{margin:0}small,.muted{color:#a4b1c9}header small{display:block}header,.status{flex-shrink:0}button{font:inherit;color:inherit;border:1px solid;padding:8px 12px;cursor:pointer}button:disabled{opacity:.4;cursor:not-allowed}.close{font-size:20px}.body{min-height:0}.toolbar{display:flex;align-items:center;flex-wrap:wrap;margin-bottom:12px}.spacer{flex:1}label{display:flex;align-items:center;gap:8px}input[type=checkbox]{width:17px;height:17px;accent-color:#78e2c3}.switch{padding:8px 12px}.field{display:grid;gap:5px;flex:1;min-width:180px}.field>span{font-size:12px;color:#a4b1c9}.picker{position:relative}.picker>button{text-align:left;width:100%}.picker>button:after{content:' ▾';float:right}.menu{position:absolute;left:0;right:0;top:calc(100% + 5px);z-index:10;max-height:245px;overflow:auto;border:1px solid;border-radius:8px;padding:4px}.menu button{display:block;width:100%;border:0;text-align:left;background:transparent}.preview{margin:12px 0;border:1px solid}.preview p{white-space:pre-wrap;overflow-wrap:anywhere}.grid{display:grid}table{border-collapse:collapse;width:100%;font-size:12px}th{text-align:left;color:#a4b1c9}td,th{border-bottom:1px solid}.num{text-align:right;font-variant-numeric:tabular-nums}td button{font-size:11px;padding:4px 7px}.badge{font-size:10px;padding:2px 5px;border-radius:4px;margin-left:5px}.aside{border:1px solid;padding:17px;height:fit-content}.aside h2{font-size:13px}.aside p{font-size:12px;color:#acbbd3}.bytes{font-size:30px;margin:9px 0}.bytes small{font-size:13px}.good{color:#8ce4bd}.bad{color:#ffbd8d}.actions{display:grid;gap:9px;margin-top:16px}.status{display:flex;gap:10px;align-items:center;font-size:11px}.dot{width:7px;height:7px;background:#d9ad61;border-radius:100%;display:inline-block}.dot.ready{background:#72d6ac}.notice{font-size:11px;color:#a4b1c9}#error{color:#ffb9a5;display:none}
  </style>
  <div class="shade"><section class="panel" role="dialog" aria-modal="true" aria-label="ThaiChatBridge Codec Lab">
    <header><div><h1>ThaiChatBridge <span class="muted">/ Control Center</span></h1><small>YOUR WORDS. YOUR LANGUAGE.</small></div><button class="close" id="close" aria-label="ปิด">×</button></header>
    <div class="body">
      <div class="toolbar"><label class="switch"><input id="live" type="checkbox">ใช้กับการพิมพ์จริง</label><label class="switch"><input id="master" type="checkbox" checked>เปิดการส่งทดสอบ</label><button id="auto">Auto · เลือกตัวเล็กสุด</button><span id="modeLabel" class="muted"></span><span class="spacer"></span><button id="allOn">เปิดทุกตัว</button><button id="allOff">ปิดทุกตัว</button></div>
      <div class="toolbar"><div class="field"><span>ข้อความตัวอย่าง</span><div class="picker"><button id="case" role="combobox" aria-label="ข้อความตัวอย่าง" aria-haspopup="listbox" aria-expanded="false" aria-controls="case-options">กำลังโหลด…</button><div id="case-options" class="menu" role="listbox" aria-label="รายการข้อความตัวอย่าง" hidden></div></div></div><div class="field"><span>ช่องที่ใช้ส่ง</span><div class="picker"><button id="channel" role="combobox" aria-label="ช่องที่ใช้ส่ง" aria-haspopup="listbox" aria-expanded="false" aria-controls="channel-options">แชตปกติ · 111 bytes</button><div id="channel-options" class="menu" role="listbox" aria-label="รายการช่องส่ง" hidden></div></div></div></div>
      <div class="preview"><small>ต้นฉบับที่ใช้เปรียบเทียบ</small><p id="text">กำลังเชื่อมกับ Lua…</p></div>
      <div class="grid"><div><table><thead><tr><th>อนุญาตให้ส่ง</th><th>วิธีบีบอัด</th><th class="num">รวม bytes</th><th>เลือกวิธีเดียว</th></tr></thead><tbody id="rows"></tbody></table><p class="notice">ขนาดรวมข้อความแทนและ carrier แล้ว · การเปลี่ยนตัวเลือกไม่ส่งข้อความ · ปุ่ม “บังคับ” จะไม่เปลี่ยนไปใช้วิธีอื่นหากเกินเพดาน</p></div>
      <aside class="aside"><div><h2>ผลที่จะส่ง</h2><strong id="selected">กำลังคำนวณ…</strong><div class="bytes" id="bytes">—</div><div id="fit" class="muted">รอสถานะจาก Lua</div><p>เครื่องที่ไม่มีตัวถอดจะเห็น<br><strong id="phrase">สุ่มประโยคตามงบ</strong></p></div><div><div class="actions"><button id="send" class="primary" disabled>ส่งกรณีนี้ 1 ครั้ง</button><button id="stop">หยุดคิวทดสอบ</button></div><p id="metrics"></p><p id="liveStatus"></p><p id="last">ยังไม่ได้ส่ง</p><p id="error"></p></div></aside></div>
    </div><footer class="status"><span class="dot" id="dot"></span><span id="connection">กำลังเชื่อม CEF ↔ Lua…</span><span class="spacer"></span><span>Esc ปิด · /thcodecui เปิดอีกครั้ง</span></footer>
  </section></div>`;
  var $ = function(id){return shadow.getElementById(id);};
  // Presentation only: existing mailbox actions and codec state remain authoritative.
  function icon(name){
    var paths={chat:'<path d="M20 11a8 8 0 0 1-8 8H5l-4 3V11a10 10 0 0 1 19 0Z"/><path d="M6 9h8M6 13h5"/>',settings:'<path d="M4 6h16M4 12h16M4 18h16"/><circle cx="9" cy="6" r="2"/><circle cx="15" cy="12" r="2"/><circle cx="8" cy="18" r="2"/>',lab:'<path d="m8 3 0 7-5 8a2 2 0 0 0 2 3h14a2 2 0 0 0 2-3l-5-8V3M6 3h12M7 15h10"/>',log:'<path d="M6 3h12a2 2 0 0 1 2 2v16H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2ZM8 8h8M8 12h8M8 16h5"/>',check:'<path d="m5 12 4 4L19 6"/>',bolt:'<path d="m14 2-10 12h7l-1 8 10-13h-7Z"/>',update:'<path d="M20 7a9 9 0 1 0 1 9M20 2v6h-6"/>'};
    return '<svg class="icon" viewBox="0 0 24 24" aria-hidden="true">'+(paths[name]||paths.chat)+'</svg>';
  }
  var panel=shadow.querySelector('.panel'),body=shadow.querySelector('.body');
  panel.setAttribute('aria-label','ThaiChatBridge Control Center');
  var workspace=document.createElement('div');workspace.className='workspace';panel.insertBefore(workspace,body);
  var sidebar=document.createElement('nav');sidebar.className='sidebar';sidebar.setAttribute('aria-label','เมนู ThaiChatBridge');
  sidebar.innerHTML='<div class="brandmark">'+icon('chat')+'</div><button class="nav active" data-page="home" aria-current="page">'+icon('settings')+'<span>ตั้งค่าทั่วไป</span></button><button class="nav" data-page="lab">'+icon('lab')+'<span>Codec Lab</span></button><button class="nav" data-page="activity">'+icon('log')+'<span>เหตุการณ์</span></button><div class="sidebar-note"><b>ThaiChatBridge PC</b>Local control center<br><span id="buildVersion">รอเวอร์ชันจาก Lua</span></div>';
  workspace.appendChild(sidebar);workspace.appendChild(body);
  var lab=document.createElement('section');lab.dataset.page='lab';lab.hidden=true;
  while(body.firstChild)lab.appendChild(body.firstChild);
  lab.insertAdjacentHTML('afterbegin','<div class="eyebrow">DEVELOPER TOOLS</div><h2 class="page-title">Codec Lab</h2><p class="lead">เปรียบเทียบขนาดจริงและทดสอบส่งทีละข้อความ</p>');body.appendChild(lab);
  var home=document.createElement('section');home.dataset.page='home';
  home.innerHTML='<div class="eyebrow">CONTROL CENTER</div><h2 class="page-title">ให้ทุกคำเป็นตัวคุณ</h2><p class="lead">ตั้งค่าภาษาไทย และดูสถานะการทำงานในที่เดียว</p><div class="home-grid"><div class="card hero"><span class="pill"><span class="dot" id="homeDot"></span><span id="homeConnection">กำลังเชื่อมต่อ</span></span><h2>คุยไทย ผ่านแชตเดิม</h2><p>เปิดการทำงานกับช่องพิมพ์จริง เลือกวิธีบีบอัดจากขนาดที่คำนวณได้ และคืนข้อความต้นฉบับให้เครื่องที่มีตัวถอด</p><div class="home-controls" id="homeControls"></div></div><div class="card"><div class="card-top">'+icon('bolt')+'<h3>การบีบอัดข้อความ</h3></div><div class="home-value" id="homeMode">—</div><p>Auto เลือกขนาดรวมที่น้อยที่สุดจากวิธีที่เปิดไว้</p><span class="mini" id="homeEnabled">รอสถานะ codec</span></div><div class="card"><div class="card-top">'+icon('chat')+'<h3>ตัวอย่างที่เลือกใน Lab</h3></div><div class="home-value" id="homeBytes">—</div><div class="meter" role="progressbar" aria-label="ขนาดข้อความตัวอย่าง" aria-valuemin="0" aria-valuemax="100" id="budgetMeter"><div id="budgetFill"></div></div><span class="mini" id="homeTiming">รอข้อมูล</span></div></div><div class="card update-card"><div><div class="card-top">'+icon('update')+'<h3>อัปเดตจาก GitHub</h3></div><p id="updateInfo">รอสถานะตัวอัปเดต</p><small id="updateNotes"></small></div><div class="update-actions"><button id="updateCheck">ตรวจเวอร์ชัน</button><button id="updateInstall" hidden>ติดตั้งและโหลดใหม่</button><button id="updateRollback" hidden>ย้อนรุ่นก่อน</button></div></div>';
  body.insertBefore(home,lab);
  $('homeControls').appendChild($('live').parentNode);$('homeControls').appendChild($('auto'));
  var activity=document.createElement('section');activity.dataset.page='activity';activity.hidden=true;
  activity.innerHTML='<div class="eyebrow">SESSION ACTIVITY</div><h2 class="page-title">เหตุการณ์ล่าสุด</h2><p class="lead">สถานะและการตั้งค่าในหน้าต่างรอบนี้ · ไม่ใช่ log เกมทั้งหมด และไม่เก็บบทสนทนา</p><div class="event-tools"><span class="mini" id="eventCount">0 เหตุการณ์</span><button id="clearEvents">ล้างรายการ</button></div><div class="event-list" id="eventList" role="log" aria-live="polite"><div class="empty">เหตุการณ์จะแสดงเมื่อเชื่อมต่อกับ Lua</div></div>';
  body.appendChild(activity);
  var toasts=document.createElement('div');toasts.className='toast-stack';toasts.setAttribute('aria-live','polite');toasts.setAttribute('role','status');panel.appendChild(toasts);
  var activityItems=[],toastTimers=[],actionPending=null,previousLiveStatus='',updatePhase='';
  function notify(message,warn){
    var toast=document.createElement('div');toast.className='toast'+(warn?' warn':'');toast.innerHTML=icon(warn?'log':'check');var text=document.createElement('span');text.textContent=message;toast.appendChild(text);toasts.appendChild(toast);
    while(toasts.children.length>3)toasts.removeChild(toasts.firstChild);
    toastTimers.push(setTimeout(function(){toast.classList.add('fade');toastTimers.push(setTimeout(function(){toast.remove();},260));},3600));
  }
  function record(message){
    activityItems.unshift({time:new Date().toLocaleTimeString(),text:message});activityItems=activityItems.slice(0,80);$('eventList').textContent='';
    activityItems.forEach(function(item){var row=document.createElement('div');row.className='event-row';var time=document.createElement('span');time.className='event-time';time.textContent=item.time;var text=document.createElement('span');text.className='event-text';text.textContent=item.text;row.appendChild(time);row.appendChild(text);$('eventList').appendChild(row);});$('eventCount').textContent=activityItems.length+' เหตุการณ์';
  }
  sidebar.querySelectorAll('.nav').forEach(function(button){button.onclick=function(){
    closeMenus();var name=button.dataset.page;
    [home,lab,activity].forEach(function(page){page.hidden=page.dataset.page!==name;});
    sidebar.querySelectorAll('.nav').forEach(function(tab){tab.classList.toggle('active',tab===button);if(tab===button)tab.setAttribute('aria-current','page');else tab.removeAttribute('aria-current');});body.scrollTop=0;
  };});
  $('clearEvents').onclick=function(){activityItems=[];$('eventList').innerHTML='<div class="empty">ล้างรายการแล้ว</div>';$('eventCount').textContent='0 เหตุการณ์';notify('ล้างเหตุการณ์ในหน้าต่างแล้ว');};
  var session='', state=null, browserId=0, destroyed=false, wasCursor=false, pending=false, nextRequest=0;
  var openMenu=null;
  function closeMenus(){
    ['case','channel'].forEach(function(id){$(id+'-options').hidden=true;$(id).setAttribute('aria-expanded','false');});openMenu=null;
  }
  function createPicker(id,choices){
    var menu=$(id+'-options');menu.textContent='';
    choices.forEach(function(choice){
      var option=document.createElement('button');option.type='button';option.setAttribute('role','option');option.dataset.value=String(choice.id);option.textContent=choice.label;
      option.onclick=function(){closeMenus();command(id,String(choice.id));};menu.appendChild(option);
    });
    $(id).onclick=function(){var opening=openMenu!==id;closeMenus();if(opening){menu.hidden=false;openMenu=id;this.setAttribute('aria-expanded','true');}};
  }
  function updatePicker(id,value){
    $(id+'-options').querySelectorAll('button').forEach(function(option){
      var selected=option.dataset.value===String(value);option.setAttribute('aria-selected',String(selected));if(selected)$(id).textContent=option.textContent;
    });
  }
  shadow.addEventListener('click',function(e){if(!e.target.closest('.picker'))closeMenus();});
  var labels=['Raw / ไม่บีบอัด','Arithmetic Order-0','LZW','Static Dictionary','Unishox2 · default','Unishox2 · dictionary','Unishox2 · no dictionary','Thai Dictionary · V1','Thai Dictionary · V2','Thai Dictionary · Wide'];
  function invoke(action,args){
    if(!session||!window.cef||typeof window.cef.RegWrite2!=='function'){
      $('error').textContent='ไม่พบสะพาน CEF สำหรับสั่ง Lua · ปิดหน้าต่างด้วย /thcodecui close';$('error').style.display='block';notify('ยังไม่เชื่อมกับ Lua กรุณาเปิดหน้าต่างใหม่',true);return false;
    }
    var id=String(++nextRequest), message=session+' '+action+' '+id+(args?' '+args:'');
    pending=true;actionPending={action:action,args:args};
    shadow.querySelectorAll('button,input,select').forEach(function(el){if(el.id!=='close')el.disabled=true;});
    window.cef.RegWrite2('thaichat_codec_lab','mailbox',message,false);
    return true;
  }
  function command(action,args){if(pending)return;$('connection').textContent='กำลังรอ Lua ยืนยัน…';if(!invoke(action,args))pending=false;}
  function remove(){
    if(destroyed)return;destroyed=true;
    toastTimers.forEach(clearTimeout);
    document.removeEventListener('keydown',onKey,true);
    try{if(window.cef&&window.cef.ToggleCursor&&!wasCursor)window.cef.ToggleCursor(browserId,false,true);}catch(e){}
    host.remove();if(window.__thCodecUI===api)delete window.__thCodecUI;
  }
  function close(){invoke('close','');remove();}
  function onKey(e){
    if(e.key==='Escape'){e.preventDefault();e.stopImmediatePropagation();if(openMenu){var id=openMenu;closeMenus();$(id).focus();}else close();return;}
    if(shadow.activeElement)e.stopPropagation();
  }
  document.addEventListener('keydown',onKey,true);
  ['mousedown','mouseup','click','wheel','keyup'].forEach(function(name){host.addEventListener(name,function(e){e.stopPropagation();});});
  $('close').onclick=close;
  $('live').onchange=function(){command('live',this.checked?'1':'0');};
  $('master').onchange=function(){command('master',this.checked?'1':'0');};
  $('auto').onclick=function(){command('force','auto');};
  $('allOn').onclick=function(){command('all','1');};
  $('allOff').onclick=function(){command('all','0');};
  $('send').onclick=function(){if(!pending&&state&&state.canSend){command('send','');this.disabled=true;}};
  $('stop').onclick=function(){command('stop','');};
  $('updateCheck').onclick=function(){command('update_check','');};
  $('updateInstall').onclick=function(){command('update_install','');};
  $('updateRollback').onclick=function(){command('update_rollback','');};
  function receive(s){
    if(destroyed)return;
    if(pending&&Number(s.ack||0)<nextRequest)return;
    var first=!session,confirmed=actionPending;session=s.session;state=s;pending=false;actionPending=null;wasCursor=!!s.wasCursor;
    shadow.querySelectorAll('button,input,select').forEach(function(el){el.disabled=false;});
    if(first){
      createPicker('case',(s.cases||[]).map(function(c){return{id:c.id,label:c.id+' · '+c.label};}));
      createPicker('channel',[{id:'normal',label:'แชตปกติ · 111 bytes'},{id:'s',label:'/s · 99 bytes'},{id:'me',label:'/me · 99 bytes'},{id:'b',label:'/b · 115 bytes'}]);
      try{if(window.cef&&window.cef.ToggleCursor)window.cef.ToggleCursor(browserId,true,true);}catch(e){}
    }
    $('live').checked=!!s.live;$('live').disabled=!s.liveAvailable;
    $('metrics').textContent='คำนวณ '+Number(s.computeMs||0).toFixed(2)+' ms · คิว '+(s.queued||0)+' · รอ '+(s.remaining||0)+' วินาที';
    $('liveStatus').textContent=(s.liveStatus||'Real chat unavailable')+' · '+Number(s.liveMs||0).toFixed(2)+' ms';
    $('master').checked=s.master;updatePicker('case',s.caseId);updatePicker('channel',s.channel);
    $('modeLabel').textContent=s.force==='auto'?'Auto':('บังคับ: '+labels[s.force]);
    $('phrase').textContent='สุ่ม '+(s.phrases||[]).length+' ประโยคที่พอดี · ตารางใช้ประโยคสั้นสุด';
    $('text').textContent=s.text;$('rows').textContent='';
    (s.rows||[]).forEach(function(row){
      var tr=document.createElement('tr');tr.className=(row.id===s.selectedMode?'selected ':'')+(!row.enabled?'off':'');
      var td=document.createElement('td'),check=document.createElement('input');check.type='checkbox';check.checked=row.enabled;check.setAttribute('aria-label','เปิด '+labels[row.id]);check.onchange=function(){command('toggle',row.id+' '+(this.checked?'1':'0'));};td.appendChild(check);tr.appendChild(td);
      td=document.createElement('td');td.textContent=labels[row.id];if(row.id===s.selectedMode){var badge=document.createElement('span');badge.className='badge';badge.textContent='เลือกอยู่';td.appendChild(badge);}tr.appendChild(td);
      td=document.createElement('td');td.className='num';td.textContent=row.bytes==null?'—':String(row.bytes);if(row.bytes>s.budget)td.classList.add('bad');tr.appendChild(td);
      td=document.createElement('td');var button=document.createElement('button');button.textContent=s.force===row.id?'บังคับอยู่':'บังคับ';button.disabled=!row.enabled||row.bytes==null;button.onclick=function(){command('force',String(row.id));};td.appendChild(button);tr.appendChild(td);$('rows').appendChild(tr);
    });
    $('selected').textContent=s.selectedMode==null?'ไม่มีวิธีที่เลือกได้':labels[s.selectedMode];
    $('bytes').textContent=s.bytes==null?'—':String(s.bytes);var small=document.createElement('small');small.textContent=' / '+s.budget+' bytes';$('bytes').appendChild(small);
    $('fit').textContent=s.reason;$('fit').className=s.canSend?'good':'bad';$('send').disabled=!s.canSend;
    $('last').textContent=s.last||'ยังไม่ได้ส่ง';$('dot').className='dot ready';$('connection').textContent='เชื่อมกับ Lua แล้ว · เปลี่ยนตัวเลือกได้';
    $('error').style.display='none';
    $('homeConnection').textContent=s.live?'พร้อมใช้กับการพิมพ์จริง':'ปิดการพิมพ์จริง';$('homeDot').className='dot'+(s.live?' ready':'');
    $('homeMode').textContent=s.force==='auto'?'Auto · ขนาดน้อยที่สุด':labels[s.force];
    $('homeEnabled').textContent=(s.rows||[]).filter(function(row){return row.enabled;}).length+' / '+(s.rows||[]).length+' วิธีเปิดใช้งาน';
    $('homeBytes').textContent=(s.bytes==null?'—':s.bytes)+' / '+s.budget+' bytes';
    var ratio=s.bytes==null?0:Math.min(100,Math.round(s.bytes/s.budget*100));$('budgetFill').style.width=ratio+'%';$('budgetFill').style.background=s.bytes>s.budget?'#edb27d':'#76e1c1';$('budgetMeter').setAttribute('aria-valuenow',String(ratio));
    $('homeTiming').textContent=Number(s.computeMs||0).toFixed(2)+' ms · '+(s.remaining?'รอ '+s.remaining+' วินาที':'พร้อมคำนวณ');
    $('buildVersion').textContent=s.version||'PC · เวอร์ชันยังไม่ส่งจาก Lua';
    var u=s.update||{phase:'error',message:'Updater unavailable'};
    $('updateInfo').textContent=(u.current||'')+(u.latest&&u.latest!==u.current?' → '+u.latest:'')+' · '+u.message+(u.busy?' '+(u.progress||0)+'%':'');
    $('updateNotes').textContent=u.notes||'';
    $('updateCheck').disabled=!u.canCheck;$('updateInstall').hidden=!u.canInstall;$('updateInstall').disabled=!u.canInstall;
    $('updateRollback').hidden=!u.canRollback;$('updateRollback').disabled=!u.canRollback;
    if(updatePhase!==u.phase){updatePhase=u.phase;record(u.message);if(!first&&/^(error|available|current|installed|rolled-back)$/.test(u.phase))notify(u.message,u.phase==='error');}
    if(first){record('เชื่อมต่อ CEF ↔ Lua แล้ว');notify('เชื่อมต่อ ThaiChatBridge แล้ว');}
    else if(confirmed&&confirmed.action!=='ready'){
      var titles={live:s.live?'เปิดการพิมพ์จริงแล้ว':'ปิดการพิมพ์จริงแล้ว',force:s.force==='auto'?'ใช้ Auto เลือกขนาดน้อยที่สุดแล้ว':'เลือก '+labels[s.force],toggle:'อัปเดตวิธีบีบอัดแล้ว',all:'อัปเดตรายการ codec แล้ว',master:s.master?'เปิดการส่งทดสอบแล้ว':'ปิดการส่งทดสอบแล้ว',send:s.last||'อัปเดตคิวทดสอบแล้ว',stop:'หยุดคิวแล้ว',case:'เปลี่ยนข้อความตัวอย่างแล้ว',channel:'เปลี่ยนช่องทดสอบเป็น '+s.channel};
      var message=titles[confirmed.action];if(message){record(message);notify(message);}
    }
    if(s.liveStatus&&s.liveStatus!==previousLiveStatus){
      record(s.liveStatus);if(/^Not sent|unavailable|Invalid/.test(s.liveStatus))notify(s.liveStatus,true);previousLiveStatus=s.liveStatus;
    }
    if(first)invoke('ready','');
  }
  var api=window.__thCodecUI={receive:receive,destroy:remove};
})();
