// HQ localisation: language is selected per player, enemy name is shared by the world.
var frontHqData = {}
var frontHqNameInput = ''
var frontEnemyInput = ''
var frontTexts = {
 ru: {hq:'ШТАБ',sector:'Сектор',control:'Контроль',tro:'ТрО',deploy:'Разместить ТрО (2)',upgrade:'Улучшить ТрО (3/4)',commando:'Коммандос (4)',refresh:'Обновить',map:'Метки Xaero',state:'Название государства',enemy:'Название противника',save:'Сохранить',outside:'Вне театра войны',safe:'Безопасная зона',front:'Линия фронта',free:'Свободный сектор',enemyZone:'Территория противника'},
 uk: {hq:'ШТАБ',sector:'Сектор',control:'Контроль',tro:'ТрО',deploy:'Розмістити ТрО (2)',upgrade:'Покращити ТрО (3/4)',commando:'Командос (4)',refresh:'Оновити',map:'Мітки Xaero',state:'Назва держави',enemy:'Назва противника',save:'Зберегти',outside:'Поза театром війни',safe:'Безпечна зона',front:'Лінія фронту',free:'Вільний сектор',enemyZone:'Територія противника'},
 en: {hq:'HEADQUARTERS',sector:'Sector',control:'Control',tro:'Territorial defence',deploy:'Deploy defence (2)',upgrade:'Upgrade defence (3/4)',commando:'Commandos (4)',refresh:'Refresh',map:'Xaero waypoints',state:'State name',enemy:'Enemy name',save:'Save',outside:'Outside war area',safe:'Safe zone',front:'Frontline',free:'Free sector',enemyZone:'Enemy territory'}
}
function frontHqSend(action) { Client.player.sendData('front:hq_request', {action:action}) }
NetworkEvents.dataReceived('front:hq_data', event => {
 frontHqData = event.data
 frontHqNameInput = String(frontHqData.stateName)
 frontEnemyInput = String(frontHqData.enemyName)
 GuiJS.open('front:headquarters')
})
GUIEvents.createUI('front:headquarters', event => {
 var t = frontTexts[String(frontHqData.language)] || frontTexts.ru
 var w = 300
 var h = frontHqData.canEdit ? 254 : 212
 var x = (Client.window.guiScaledWidth-w)/2
 var y = (Client.window.guiScaledHeight-h)/2
 event.setBackground('minecraft:textures/gui/demo_background.png',x,y,w,h)
 event.pauseGame(false)
 event.background(true)
 event.label('§l'+t.hq,x+12,y+10)
 event.label(String(frontHqData.stateName),x+12,y+24)
 event.label(t.sector+': '+String(frontHqData.sector),x+12,y+38)
 var zone = String(frontHqData.zoneCode)
 event.label(zone === 'enemy' ? t.enemyZone : (t[zone] || ''),x+12,y+50)
 event.label(String(frontHqData.enemyName)+' — '+t.control+': '+String(frontHqData.control)+'%',x+12,y+62)
 event.label(t.tro+': '+String(frontHqData.garrisonStrength)+'/'+String(frontHqData.garrisonMax),x+12,y+74)
 event.button(t.deploy,x+12,y+90,134,20).onClick(()=>frontHqSend('garrison'))
 event.button(t.upgrade,x+154,y+90,134,20).onClick(()=>frontHqSend('upgrade'))
 event.button(t.map,x+12,y+114,134,20).onClick(()=>frontHqSend('map'))
 event.button('HQ+',x+154,y+114,134,20).onClick(()=>Client.player.sendData('front:services_request',{action:'mail'}))
 event.button(t.refresh,x+12,y+138,90,20).onClick(()=>frontHqSend('refresh'))
 event.button('RU',x+112,y+138,54,20).onClick(()=>Client.player.sendData('front:hq_request',{action:'language',language:'ru'}))
 event.button('UK',x+170,y+138,54,20).onClick(()=>Client.player.sendData('front:hq_request',{action:'language',language:'uk'}))
 event.button('EN',x+228,y+138,54,20).onClick(()=>Client.player.sendData('front:hq_request',{action:'language',language:'en'}))
 event.label(t.state,x+12,y+166)
 event.textBox(x+12,y+180,190,18).setValue(frontHqNameInput).onTextChanged(text=>{frontHqNameInput=String(text)})
 event.button(t.save,x+210,y+179,78,20).onClick(()=>{
  Client.player.sendData('front:hq_request',{action:'state_name',name:frontHqNameInput})
 })
 if (frontHqData.canEdit) {
  event.label(t.enemy,x+12,y+208)
  event.textBox(x+12,y+222,190,18).setValue(frontEnemyInput).onTextChanged(text=>{frontEnemyInput=String(text)})
  event.button(t.save,x+210,y+221,78,20).onClick(()=>{
   Client.player.sendData('front:hq_request',{action:'enemy_name',name:frontEnemyInput})
  })
 }
})
