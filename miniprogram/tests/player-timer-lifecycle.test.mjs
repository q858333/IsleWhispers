import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import { createSleepTimer } from '../services/sleep-timer.js';
import { fileURLToPath } from 'node:url';
const root=fileURLToPath(new URL('../', import.meta.url));
const timer=createSleepTimer({now:()=>0});
let player;
vm.runInNewContext(readFileSync(root+'pages/player/index.js','utf8').replace(/^import .*;\n/gm,''), {Page:p=>player=p,getApp:()=>({sleepTimer:timer}),sounds:[],clearInterval(){}});
for(const paused of [false,true]){
 timer.schedule(15);if(paused)timer.pause();
 player.onUnload();
 assert.equal(timer.remainingMs(),null,'退出播放页应清除运行中或暂停中的定时');
}
let home;
vm.runInNewContext(readFileSync(root+'pages/home/index.js','utf8').replace(/^import .*;\n/gm,''), {Page:p=>home=p,getApp:()=>({sleepTimer:timer}),sounds:[]});
home.data.timerChoice=15;home.setData=d=>Object.assign(home.data,d);home.render=()=>{};
home.onShow();assert.equal(home.data.timerChoice,0,'返回首页应显示不限时');
console.log('通过：播放页退出清除运行/暂停定时，首页重置为不限时');
