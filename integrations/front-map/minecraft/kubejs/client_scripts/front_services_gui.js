var fsData={}, fsRole='',fsCallsign='',fsFlag=''
var fsText={
 ru:{mail:'ПОЧТА',profile:'РП-ПРОФИЛЬ',missions:'СПЕЦОПЕРАЦИИ',back:'Штаб',save:'Сохранить',role:'Должность (только РП)',callsign:'Позывной',flag:'Эмблема / символ',read:'Прочитано',refresh:'Обновить',cancel:'Отменить',mortar:'Миномётчик',depot:'Снабженец',headquarters:'Командир',empty:'Нет активной задачи',defence:'Последний учёт обороны',soldiers:'солдат',vehicles:'техника',advance:'Продвижение противника',liberated:'Зона освобождена',mission_mortar:'Миномётная поддержка ослаблена',mission_depot:'Пополнение задержано',mission_headquarters:'Наступление задержано'},
 uk:{mail:'ПОШТА',profile:'РП-ПРОФІЛЬ',missions:'СПЕЦОПЕРАЦІЇ',back:'Штаб',save:'Зберегти',role:'Посада (лише РП)',callsign:'Позивний',flag:'Емблема / символ',read:'Прочитано',refresh:'Оновити',cancel:'Скасувати',mortar:'Мінометник',depot:'Постачальник',headquarters:'Командир',empty:'Немає активного завдання',defence:'Останній облік оборони',soldiers:'солдатів',vehicles:'техніка',advance:'Просування противника',liberated:'Зону звільнено',mission_mortar:'Мінометну підтримку послаблено',mission_depot:'Поповнення затримано',mission_headquarters:'Наступ затримано'},
 en:{mail:'MAIL',profile:'RP PROFILE',missions:'OPERATIONS',back:'HQ',save:'Save',role:'Role (RP only)',callsign:'Callsign',flag:'Emblem / symbol',read:'Mark read',refresh:'Refresh',cancel:'Cancel',mortar:'Mortar operator',depot:'Supply unit',headquarters:'Commander',empty:'No active operation',defence:'Last defence census',soldiers:'soldiers',vehicles:'vehicles',advance:'Enemy advance',liberated:'Zone liberated',mission_mortar:'Mortar support reduced',mission_depot:'Reinforcements delayed',mission_headquarters:'Advance delayed'}
}
function fsRequest(action,tab){Client.player.sendData('front:services_request',{action:action,tab:tab || action})}
NetworkEvents.dataReceived('front:services_data',event=>{
 fsData=event.data;fsRole=String(fsData.role || '');fsCallsign=String(fsData.callsign || '');fsFlag=String(fsData.flag || '')
 GuiJS.open('front:services')
})
GUIEvents.createUI('front:services',event=>{
 var t=fsText[String(fsData.language)] || fsText.ru,tab=String(fsData.tab),w=320,h=246
 var x=(Client.window.guiScaledWidth-w)/2,y=(Client.window.guiScaledHeight-h)/2
 event.setBackground('minecraft:textures/gui/demo_background.png',x,y,w,h);event.pauseGame(false);event.background(true)
 event.button(t.mail,x+8,y+8,94,20).onClick(()=>fsRequest('mail'))
 event.button(t.profile,x+110,y+8,98,20).onClick(()=>fsRequest('profile'))
 event.button(t.missions,x+216,y+8,96,20).onClick(()=>fsRequest('missions'))
 if(tab==='profile') {
  event.label(String(fsData.state),x+12,y+38)
  event.label(t.role,x+12,y+60);event.textBox(x+12,y+74,290,18).setValue(fsRole).onTextChanged(v=>{fsRole=String(v)})
  event.label(t.callsign,x+12,y+100);event.textBox(x+12,y+114,290,18).setValue(fsCallsign).onTextChanged(v=>{fsCallsign=String(v)})
  event.label(t.flag,x+12,y+140);event.textBox(x+12,y+154,290,18).setValue(fsFlag).onTextChanged(v=>{fsFlag=String(v)})
  event.button(t.save,x+12,y+184,290,20).onClick(()=>Client.player.sendData('front:services_request',{action:'profile_save',role:fsRole,callsign:fsCallsign,flag:fsFlag}))
 } else if(tab==='missions') {
  var task=fsData.mission
  event.label(task && task.kind ? (t[String(task.kind)] || String(task.kind))+' | '+String(task.zone) : t.empty,x+12,y+42)
  if(task && task.kind) {
   event.label('X/Z: '+String(task.x)+' / '+String(task.z),x+12,y+60)
   event.label('~ '+Math.max(0,Math.ceil((Number(task.expires)-Number(fsData.now))/1200))+' min',x+12,y+76)
  }
  event.button(t.mortar,x+12,y+100,290,20).onClick(()=>Client.player.sendData('front:services_request',{action:'mission',kind:'mortar'}))
  event.button(t.depot,x+12,y+124,290,20).onClick(()=>Client.player.sendData('front:services_request',{action:'mission',kind:'depot'}))
  event.button(t.headquarters,x+12,y+148,290,20).onClick(()=>Client.player.sendData('front:services_request',{action:'mission',kind:'headquarters'}))
  event.button(t.cancel,x+12,y+176,290,20).onClick(()=>fsRequest('cancel'))
 } else {
  var list=fsData.mail || []
  for(var i=0;i<list.length && i<8;i++) {
   var m=list[i],age=Math.max(0,Math.floor((Number(fsData.now)-Number(m.tick))/1200))
   event.label((Number(m.tick)>Number(fsData.read)?'§e':'§7')+String(m.zone)+' '+(t[String(m.kind)] || String(m.kind))+' x'+String(m.count)+' ('+age+'m)',x+12,y+40+i*16)
  }
  var d=fsData.defence || {}
  event.label(t.defence+': '+String(fsData.zone),x+12,y+176)
  event.label(String(d.soldiers || 0)+' '+t.soldiers+' / '+String(d.vehicles || 0)+' '+t.vehicles,x+12,y+190)
  event.button(t.read,x+12,y+207,140,18).onClick(()=>fsRequest('read'))
  event.button(t.refresh,x+160,y+207,144,18).onClick(()=>fsRequest('mail'))
 }
 event.button(t.back,x+12,y+228,290,16).onClick(()=>Client.player.sendData('front:hq_request',{action:'refresh'}))
})
