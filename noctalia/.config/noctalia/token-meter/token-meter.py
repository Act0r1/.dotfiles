#!/usr/bin/env python3
import argparse
import datetime as dt
import fcntl
import hashlib
import hmac
import json
import math
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from collections import defaultdict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


HOST = "127.0.0.1"
PORT = 41739
BASE_URL = f"http://{HOST}:{PORT}"
CACHE_DIR = Path.home() / ".cache" / "token-meter"
CACHE_FILE = CACHE_DIR / "usage-cache.json"
LOCK_FILE = CACHE_DIR / "usage-cache.lock"
SECRET_FILE = CACHE_DIR / "local-secret"
ICONS_DIR = Path(__file__).resolve().parent / "icons"
CACHE_VERSION = 9
SOURCE_PATTERNS = {
    "Pi": Path.home() / ".pi" / "agent" / "sessions",
    "Codex": Path.home() / ".codex" / "sessions",
    "Claude": Path.home() / ".claude" / "projects",
}
ICON_NAMES = {"ai", "claude", "deepseek", "gemini", "grok", "kimi", "meta", "mistral", "ollama", "openai", "perplexity", "qwen", "zai"}
PRICING_CATALOG = None
LOCAL_SECRET = None
OPENAI_PRICING = {
    "gpt-6-astra": {"input": 10, "output": 50, "cacheRead": 1, "cacheWrite": 12.5, "tiers": [{"inputTokensAbove": 272000, "input": 20, "output": 75, "cacheRead": 2, "cacheWrite": 25}]},
    "gpt-5.6-luna": {"input": 0.2, "output": 1.2, "cacheRead": 0.02, "cacheWrite": 0.25, "tiers": [{"inputTokensAbove": 272000, "input": 0.4, "output": 1.8, "cacheRead": 0.04, "cacheWrite": 0.5}]},
    "gpt-5.6-terra": {"input": 2, "output": 12, "cacheRead": 0.2, "cacheWrite": 2.5, "tiers": [{"inputTokensAbove": 272000, "input": 4, "output": 18, "cacheRead": 0.4, "cacheWrite": 5}]},
    "gpt-5.6-sol": {"input": 4, "output": 20, "cacheRead": 0.4, "cacheWrite": 5, "tiers": [{"inputTokensAbove": 272000, "input": 8, "output": 30, "cacheRead": 0.8, "cacheWrite": 10}]},
}
FALLBACK_PRICING = {
    **OPENAI_PRICING,
    "claude-fable-5": {"input": 10, "output": 50, "cacheRead": 1, "cacheWrite": 12.5},
    "claude-opus-5": {"input": 5, "output": 25, "cacheRead": 0.5, "cacheWrite": 6.25},
    "claude-sonnet-5": {"input": 2, "output": 10, "cacheRead": 0.2, "cacheWrite": 2.5},
    "claude-opus-4-8": {"input": 5, "output": 25, "cacheRead": 0.5, "cacheWrite": 6.25},
    "claude-sonnet-4-6": {"input": 3, "output": 15, "cacheRead": 0.3, "cacheWrite": 3.75},
    "claude-haiku-4-5": {"input": 1, "output": 5, "cacheRead": 0.1, "cacheWrite": 1.25},
    "glm-5.2": {"input": 1.4, "output": 4.4, "cacheRead": 0.26, "cacheWrite": 0},
}
TOKEN_FIELDS = ("input", "output", "cacheRead", "cacheWrite", "reasoning", "totalTokens")
CODEX_FIELDS = (
    "input_tokens",
    "cached_input_tokens",
    "cache_write_input_tokens",
    "output_tokens",
    "reasoning_output_tokens",
    "total_tokens",
)
PROCESS_LOCK = threading.Lock()


DASHBOARD = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="color-scheme" content="dark">
<title>Token Meter</title>
<style>
:root{--bg:#080b14;--panel:rgba(18,23,40,.68);--panel2:rgba(25,31,52,.82);--line:rgba(255,255,255,.09);--text:#f4f7ff;--muted:#98a2bd;--violet:#a78bfa;--blue:#58b7ff;--cyan:#4ee7ca;--pink:#fa76b7;--amber:#f8c56a;--shadow:0 24px 70px rgba(0,0,0,.32)}
*{box-sizing:border-box}
html{background:var(--bg);min-height:100%}
body{margin:0;min-height:100vh;color:var(--text);font:14px/1.5 Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;background:radial-gradient(circle at 15% -10%,rgba(111,78,255,.27),transparent 35%),radial-gradient(circle at 90% 10%,rgba(53,190,255,.18),transparent 32%),linear-gradient(150deg,#080b14 0%,#0b1020 48%,#090c15 100%);overflow-x:hidden}
body:before{content:"";position:fixed;inset:0;pointer-events:none;opacity:.2;background-image:linear-gradient(rgba(255,255,255,.025) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.025) 1px,transparent 1px);background-size:42px 42px;mask-image:linear-gradient(to bottom,black,transparent 80%)}
.shell{width:min(1480px,calc(100% - 40px));margin:0 auto;padding:34px 0 54px;position:relative}
.topbar{display:flex;align-items:center;justify-content:space-between;gap:18px;margin-bottom:28px}
.brand{display:flex;align-items:center;gap:13px}.mark{width:42px;height:42px;border-radius:14px;display:grid;place-items:center;background:linear-gradient(140deg,var(--violet),var(--blue));box-shadow:0 12px 35px rgba(112,94,246,.35);position:relative}.mark:after{content:"";width:18px;height:18px;border:3px solid white;border-left-color:transparent;border-radius:50%;transform:rotate(-25deg)}
.brand h1{font-size:20px;line-height:1.1;margin:0;letter-spacing:-.025em}.brand p{margin:4px 0 0;color:var(--muted);font-size:12px}
.actions{display:flex;align-items:center;gap:10px}.periods{display:flex;padding:4px;border:1px solid var(--line);border-radius:14px;background:rgba(9,12,23,.6);backdrop-filter:blur(18px)}
button{font:inherit;color:inherit}.period{border:0;background:transparent;color:var(--muted);padding:8px 13px;border-radius:10px;cursor:pointer;transition:.2s}.period:hover{color:var(--text)}.period.active{color:white;background:linear-gradient(135deg,rgba(167,139,250,.35),rgba(88,183,255,.23));box-shadow:inset 0 0 0 1px rgba(255,255,255,.08)}
.refresh{height:42px;border-radius:13px;border:1px solid var(--line);background:var(--panel);padding:0 14px;display:flex;gap:8px;align-items:center;cursor:pointer;backdrop-filter:blur(18px);transition:.2s;text-decoration:none}.refresh:hover{border-color:rgba(167,139,250,.48);transform:translateY(-1px)}.refresh svg{width:16px;height:16px}.refresh.busy svg{animation:spin .8s linear infinite}@keyframes spin{to{transform:rotate(360deg)}}
.grid{display:grid;grid-template-columns:repeat(12,1fr);gap:16px}.glass{background:linear-gradient(145deg,rgba(27,33,55,.78),rgba(13,17,30,.68));border:1px solid var(--line);border-radius:22px;box-shadow:var(--shadow);backdrop-filter:blur(22px)}
.overview{grid-column:span 12;display:grid;grid-template-columns:repeat(6,1fr);overflow:hidden}.metric{padding:22px 20px;min-width:0;position:relative}.metric+.metric{border-left:1px solid var(--line)}.metric .label{color:var(--muted);font-size:12px;margin-bottom:8px}.metric .value{font-size:25px;line-height:1.15;font-weight:720;letter-spacing:-.04em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.metric .hint{font-size:11px;color:#6f7890;margin-top:7px}.accent{color:var(--cyan)}
.chart-card{grid-column:span 8;padding:23px}.composition{grid-column:span 4;padding:23px}.section-head{display:flex;align-items:flex-start;justify-content:space-between;gap:12px;margin-bottom:18px}.section-head h2{font-size:15px;margin:0;letter-spacing:-.01em}.section-head p{font-size:12px;color:var(--muted);margin:3px 0 0}.badge{font-size:11px;padding:5px 9px;border-radius:20px;color:#cbd3e8;border:1px solid var(--line);background:rgba(255,255,255,.035)}
.chart-wrap{height:260px;position:relative}.chart-wrap canvas{display:block;width:100%;height:100%}.chart-empty{position:absolute;inset:0;display:none;place-items:center;color:var(--muted)}
.composition-body{display:flex;gap:22px;align-items:center;min-height:260px}.donut{width:148px;aspect-ratio:1;border-radius:50%;position:relative;flex:none;background:conic-gradient(var(--violet) 0 25%,var(--blue) 25% 50%,var(--cyan) 50% 75%,var(--pink) 75%)}.donut:after{content:"";position:absolute;inset:24px;border-radius:50%;background:#111629;box-shadow:inset 0 0 0 1px var(--line)}.donut-center{position:absolute;inset:0;z-index:1;display:grid;place-content:center;text-align:center}.donut-center strong{font-size:21px;letter-spacing:-.04em}.donut-center span{font-size:10px;color:var(--muted)}
.legend{display:grid;gap:11px;min-width:0;flex:1}.legend-row{display:grid;grid-template-columns:auto 1fr auto;align-items:center;gap:8px;color:var(--muted);font-size:12px}.dot{width:8px;height:8px;border-radius:50%}.legend-row b{font-weight:600;color:#e7ebf7;font-variant-numeric:tabular-nums}
.models{grid-column:span 8;padding:23px}.breakdowns{grid-column:span 4;display:grid;gap:16px}.breakdown{padding:23px}.table-wrap{overflow:auto}.model-table{border-collapse:collapse;width:100%;min-width:610px}.model-table th{text-align:left;color:#77819b;font-size:10px;text-transform:uppercase;letter-spacing:.08em;font-weight:600;padding:0 12px 11px}.model-table th:first-child,.model-table td:first-child{padding-left:0}.model-table th:not(:first-child),.model-table td:not(:first-child){text-align:right}.model-table td{padding:13px 12px;border-top:1px solid var(--line);font-size:12px;font-variant-numeric:tabular-nums}.model-name{display:flex;align-items:center;gap:10px;text-align:left}.model-orb{width:30px;height:30px;border-radius:9px;background:rgba(255,255,255,.06);display:grid;place-items:center;overflow:hidden;border:1px solid var(--line);padding:6px}.model-orb img{display:block;width:100%;height:100%;object-fit:contain}.model-title{max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.provider{color:var(--muted);font-size:10px}.cache-good{color:var(--cyan)}
.bars{display:grid;gap:14px}.bar-row{display:grid;gap:6px}.bar-meta{display:flex;justify-content:space-between;gap:10px;font-size:12px}.bar-meta span:first-child{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.bar-meta span:last-child{color:var(--muted);font-variant-numeric:tabular-nums}.track{height:5px;border-radius:99px;background:rgba(255,255,255,.055);overflow:hidden}.fill{height:100%;border-radius:inherit;background:linear-gradient(90deg,var(--violet),var(--blue));box-shadow:0 0 14px rgba(112,163,255,.35)}
.status{display:flex;justify-content:space-between;gap:16px;align-items:center;margin-top:18px;color:#6f7890;font-size:11px}.live{display:flex;align-items:center;gap:7px}.live:before{content:"";width:6px;height:6px;border-radius:50%;background:var(--cyan);box-shadow:0 0 10px var(--cyan)}
.skeleton{color:transparent!important;border-radius:8px;background:linear-gradient(90deg,rgba(255,255,255,.04),rgba(255,255,255,.09),rgba(255,255,255,.04));background-size:200% 100%;animation:shimmer 1.3s infinite}@keyframes shimmer{to{background-position:-200% 0}}
.error{display:none;margin-bottom:16px;padding:12px 15px;border:1px solid rgba(250,118,183,.3);background:rgba(250,118,183,.08);color:#ffb4d7;border-radius:14px}
@media(max-width:1050px){.overview{grid-template-columns:repeat(3,1fr)}.metric:nth-child(4){border-left:0}.metric:nth-child(n+4){border-top:1px solid var(--line)}.chart-card,.composition,.models,.breakdowns{grid-column:span 12}.breakdowns{grid-template-columns:1fr 1fr}.composition-body{justify-content:center}}
@media(max-width:680px){.shell{width:min(100% - 22px,1480px);padding-top:18px}.topbar{align-items:flex-start;flex-direction:column}.actions{width:100%;justify-content:space-between}.period{padding:8px 10px}button.refresh span{display:none}.overview{grid-template-columns:repeat(2,1fr)}.metric{padding:18px 16px}.metric:nth-child(odd){border-left:0}.metric:nth-child(even){border-left:1px solid var(--line)}.metric:nth-child(n+3){border-top:1px solid var(--line)}.metric .value{font-size:22px}.chart-card,.composition,.models,.breakdown{padding:18px}.chart-wrap{height:220px}.composition-body{min-height:0;flex-direction:column;align-items:stretch}.donut{align-self:center}.breakdowns{grid-template-columns:1fr}.status{align-items:flex-start;flex-direction:column}.brand p{max-width:260px}}
</style>
</head>
<body>
<main class="shell">
<header class="topbar">
<div class="brand"><div class="mark"></div><div><h1>Token Meter</h1><p>Local AI usage, clearly measured</p></div></div>
<div class="actions">
<div class="periods" role="group" aria-label="Period">
<button class="period active" data-period="today">24h</button><button class="period" data-period="week">7d</button><button class="period" data-period="month">30d</button><button class="period" data-period="all">All</button>
</div>
<a class="refresh" href="/advanced" aria-label="Advanced statistics"><span>Advanced stats</span></a>
<button class="refresh" id="refresh" aria-label="Refresh"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M20 6v5h-5M4 18v-5h5"/><path d="M18.5 9A7 7 0 0 0 6 6.5L4 9m2 6a7 7 0 0 0 12 2.5L20 15"/></svg><span>Refresh</span></button>
</div>
</header>
<div class="error" id="error"></div>
<section class="grid">
<div class="glass overview">
<div class="metric"><div class="label">Processed tokens</div><div class="value skeleton" id="totalTokens">Loading</div><div class="hint" id="totalHint">Includes repeated cache reads</div></div>
<div class="metric"><div class="label">Uncached input</div><div class="value skeleton" id="input">Loading</div><div class="hint">New context</div></div>
<div class="metric"><div class="label">Output</div><div class="value skeleton" id="output">Loading</div><div class="hint" id="outputHint">Generated tokens</div></div>
<div class="metric"><div class="label">Cache read</div><div class="value skeleton accent" id="cacheRead">Loading</div><div class="hint" id="cacheHint">Input traffic</div></div>
<div class="metric"><div class="label">API cost</div><div class="value skeleton" id="cost">Loading</div><div class="hint">Equivalent public API pricing</div></div>
<div class="metric"><div class="label">Requests</div><div class="value skeleton" id="requests">Loading</div><div class="hint" id="sessionHint">Across sessions</div></div>
</div>
<article class="glass chart-card">
<div class="section-head"><div><h2>Usage activity</h2><p id="chartSubtitle">Token volume over time</p></div><span class="badge" id="chartBadge">90 days</span></div>
<div class="chart-wrap"><canvas id="chart"></canvas><div class="chart-empty" id="chartEmpty">No usage in this period</div></div>
</article>
<article class="glass composition">
<div class="section-head"><div><h2>Token composition</h2><p>How context was processed</p></div></div>
<div class="composition-body"><div class="donut" id="donut"><div class="donut-center"><strong id="donutTotal">0</strong><span>tokens</span></div></div><div class="legend" id="legend"></div></div>
</article>
<article class="glass models">
<div class="section-head"><div><h2>Models</h2><p>Usage, requests and API-equivalent cost</p></div><span class="badge" id="modelCount">0 models</span></div>
<div class="table-wrap"><table class="model-table"><thead><tr><th>Model</th><th>Tokens</th><th>Requests</th><th>Cache reuse</th><th>Cost</th></tr></thead><tbody id="models"></tbody></table></div>
</article>
<div class="breakdowns">
<article class="glass breakdown"><div class="section-head"><div><h2>Sources</h2><p>Pi, Codex and Claude Code activity</p></div></div><div class="bars" id="sources"></div></article>
<article class="glass breakdown"><div class="section-head"><div><h2>Projects</h2><p>Usage by working directory</p></div></div><div class="bars" id="projects"></div></article>
</div>
</section>
<footer class="status"><div class="live">Loopback only · local data</div><div id="updated">Waiting for data</div></footer>
</main>
<script>
const state={data:null,period:'today'};
const colors=['#a78bfa','#58b7ff','#4ee7ca','#fa76b7','#f8c56a'];
const $=id=>document.getElementById(id);
const compact=new Intl.NumberFormat('en',{notation:'compact',maximumFractionDigits:1});
const integer=new Intl.NumberFormat('en');
const fmt=n=>compact.format(Number(n)||0);
const money=n=>{const v=Number(n)||0;return v===0?'$0':v<.01?'$'+v.toFixed(4):'$'+v.toFixed(2)};
const percent=n=>Math.round((Number(n)||0)*100)+'%';
const escapeHtml=value=>String(value).replace(/[&<>"]/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[ch]));
function selected(){return state.data.periods[state.period]}
function setText(id,value){const node=$(id);node.textContent=value;node.classList.remove('skeleton')}
function renderOverview(data){setText('totalTokens',fmt(data.totalTokens));setText('input',fmt(data.input));setText('output',fmt(data.output));setText('cacheRead',fmt(data.cacheRead));setText('cost',money(data.cost));setText('requests',integer.format(data.requests));setText('outputHint','Generated · '+fmt(data.reasoning)+' reasoning');setText('cacheHint',percent(data.cacheRate)+' of input traffic');setText('sessionHint',integer.format(data.sessions)+' sessions')}
function renderComposition(data){const parts=[['Input',data.input],['Output',data.output],['Cache read',data.cacheRead],['Cache write',data.cacheWrite]];const sum=parts.reduce((a,p)=>a+p[1],0);let offset=0;const stops=[];parts.forEach((part,i)=>{const start=offset;offset+=sum?part[1]/sum*100:0;stops.push(`${colors[i]} ${start}% ${offset}%`)});$('donut').style.background=sum?`conic-gradient(${stops.join(',')})`:'rgba(255,255,255,.06)';$('donutTotal').textContent=fmt(sum);$('legend').innerHTML=parts.map((part,i)=>`<div class="legend-row"><span class="dot" style="background:${colors[i]}"></span><span>${part[0]}</span><b>${fmt(part[1])}</b></div>`).join('')}
function renderModels(data){$('modelCount').textContent=`${data.models.length} model${data.models.length===1?'':'s'}`;$('models').innerHTML=data.models.length?data.models.map(m=>{const icon=String(m.icon||'ai').replace(/[^a-z0-9-]/g,'')||'ai';return `<tr><td><div class="model-name"><span class="model-orb"><img src="/icons/${icon}.svg" alt=""></span><span><div class="model-title" title="${escapeHtml(m.name)} · ${escapeHtml(m.source)}">${escapeHtml(m.name)} · ${escapeHtml(m.source)}</div><div class="provider">${escapeHtml(m.provider)}</div></span></div></td><td>${fmt(m.totalTokens)}</td><td>${integer.format(m.requests)}</td><td class="cache-good">${percent(m.cacheRate)} reused</td><td>${money(m.cost)}</td></tr>`}).join(''):'<tr><td colspan="5" style="text-align:center;color:var(--muted);padding:30px">No model usage in this period</td></tr>'}
function renderBars(id,items,limit){const shown=items.slice(0,limit);const max=Math.max(1,...shown.map(x=>x.totalTokens));$(id).innerHTML=shown.length?shown.map(item=>`<div class="bar-row"><div class="bar-meta"><span title="${escapeHtml(item.name)}">${escapeHtml(item.name)}</span><span>${fmt(item.totalTokens)}</span></div><div class="track"><div class="fill" style="width:${Math.max(2,item.totalTokens/max*100)}%"></div></div></div>`).join(''):'<div style="color:var(--muted);font-size:12px">No usage in this period</div>'}
function timeline(){const all=state.data.timeline;if(state.period==='today')return state.data.timeline24h||[];if(state.period==='week')return all.slice(-7);if(state.period==='month')return all.slice(-30);return all}
function drawChart(){if(!state.data)return;const canvas=$('chart');const box=canvas.getBoundingClientRect();const dpr=Math.min(devicePixelRatio||1,2);canvas.width=Math.max(1,Math.round(box.width*dpr));canvas.height=Math.max(1,Math.round(box.height*dpr));const ctx=canvas.getContext('2d');ctx.scale(dpr,dpr);const w=box.width,h=box.height,p={l:10,r:12,t:16,b:28};const rows=timeline();const values=rows.map(x=>x.totalTokens);const max=Math.max(0,...values);$('chartEmpty').style.display=max?'none':'grid';ctx.clearRect(0,0,w,h);ctx.font='10px system-ui';ctx.fillStyle='#77819b';ctx.strokeStyle='rgba(255,255,255,.07)';ctx.lineWidth=1;for(let i=0;i<4;i++){const y=p.t+(h-p.t-p.b)*i/3;ctx.beginPath();ctx.moveTo(p.l,y+.5);ctx.lineTo(w-p.r,y+.5);ctx.stroke();ctx.fillText(fmt(max*(3-i)/3),p.l,y-6)}if(!max)return;const x=i=>rows.length===1?(p.l+w-p.r)/2:p.l+(w-p.l-p.r)*i/(rows.length-1);const y=v=>p.t+(h-p.t-p.b)*(1-v/max);const grad=ctx.createLinearGradient(0,p.t,0,h-p.b);grad.addColorStop(0,'rgba(167,139,250,.36)');grad.addColorStop(1,'rgba(88,183,255,0)');ctx.beginPath();ctx.moveTo(x(0),h-p.b);values.forEach((v,i)=>ctx.lineTo(x(i),y(v)));ctx.lineTo(x(values.length-1),h-p.b);ctx.closePath();ctx.fillStyle=grad;ctx.fill();const line=ctx.createLinearGradient(p.l,0,w-p.r,0);line.addColorStop(0,'#a78bfa');line.addColorStop(1,'#58b7ff');ctx.beginPath();values.forEach((v,i)=>i?ctx.lineTo(x(i),y(v)):ctx.moveTo(x(i),y(v)));ctx.strokeStyle=line;ctx.lineWidth=2;ctx.lineJoin='round';ctx.stroke();if(rows.length===1){ctx.beginPath();ctx.arc(x(0),y(values[0]),4,0,Math.PI*2);ctx.fillStyle='#a78bfa';ctx.fill()}const labels=rows.length<8?rows.map((_,i)=>i):[0,Math.floor((rows.length-1)/2),rows.length-1];ctx.fillStyle='#77819b';labels.forEach((idx,n)=>{const hourly=rows[idx].date.includes('T');const date=new Date(hourly?rows[idx].date:rows[idx].date+'T00:00:00');const text=hourly?date.toLocaleTimeString(undefined,{hour:'2-digit',minute:'2-digit'}):date.toLocaleDateString(undefined,{month:'short',day:'numeric'});ctx.textAlign=n===0?'left':n===labels.length-1?'right':'center';ctx.fillText(text,x(idx),h-7)});ctx.textAlign='left'}
function render(){if(!state.data)return;const data=selected();renderOverview(data);renderComposition(data);renderModels(data);renderBars('sources',data.sources,5);renderBars('projects',data.projects,7);const days=state.period==='today'?1:state.period==='week'?7:state.period==='month'?30:90;$('chartBadge').textContent=days===1?'Last 24 hours':days+' days';$('chartSubtitle').textContent=state.period==='all'?'Last 90 days of token volume':'Token volume for the selected period';drawChart();const when=new Date(state.data.updatedAt);$('updated').textContent=`Updated ${when.toLocaleString()} · ${integer.format(state.data.discovered.files)} files discovered`}
async function load(){const button=$('refresh');button.classList.add('busy');button.disabled=true;$('error').style.display='none';try{const response=await fetch('/api/stats',{cache:'no-store'});if(!response.ok)throw new Error('Stats request failed');state.data=await response.json();render()}catch(error){$('error').textContent='Could not refresh local usage data. The server may still be scanning logs.';$('error').style.display='block'}finally{button.classList.remove('busy');button.disabled=false}}
document.querySelectorAll('.period').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('.period').forEach(x=>x.classList.remove('active'));button.classList.add('active');state.period=button.dataset.period;render()}));
$('refresh').addEventListener('click',load);
addEventListener('resize',()=>requestAnimationFrame(drawChart));
load();
</script>
</body>
</html>'''


ADVANCED_DASHBOARD = r'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="dark">
<title>Token Meter · Advanced</title>
<style>
:root{--bg:#080b14;--card:rgba(20,25,43,.76);--card2:rgba(28,34,56,.72);--line:rgba(255,255,255,.09);--text:#f4f7ff;--muted:#98a2bd;--violet:#a78bfa;--blue:#58b7ff;--cyan:#4ee7ca;--pink:#fa76b7;--amber:#f8c56a;--green:#9eea57}*{box-sizing:border-box}body{margin:0;min-height:100vh;color:var(--text);font:14px/1.45 Inter,ui-sans-serif,system-ui,sans-serif;background:radial-gradient(circle at 12% -8%,rgba(111,78,255,.28),transparent 35%),radial-gradient(circle at 92% 5%,rgba(53,190,255,.17),transparent 34%),linear-gradient(150deg,#080b14,#0b1020 52%,#090c15)}body:before{content:"";position:fixed;inset:0;pointer-events:none;opacity:.18;background-image:linear-gradient(rgba(255,255,255,.025) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.025) 1px,transparent 1px);background-size:42px 42px}.shell{width:min(1540px,calc(100% - 40px));margin:auto;padding:30px 0 55px;position:relative}.top{display:flex;align-items:center;justify-content:space-between;gap:18px;margin-bottom:22px}.brand{display:flex;align-items:center;gap:13px}.mark{width:43px;height:43px;border-radius:14px;display:grid;place-items:center;background:linear-gradient(140deg,var(--violet),var(--blue));font-size:20px;font-weight:800}.brand h1{font-size:21px;margin:0}.brand p{margin:3px 0 0;color:var(--muted);font-size:12px}.actions{display:flex;align-items:center;gap:10px}.periods{display:flex;padding:4px;border:1px solid var(--line);border-radius:14px;background:rgba(9,12,23,.65)}button,a{font:inherit;color:inherit}.period,.back,.refresh{border:0;text-decoration:none;background:transparent;color:var(--muted);padding:8px 12px;border-radius:10px;cursor:pointer}.period.active{color:white;background:linear-gradient(135deg,rgba(167,139,250,.36),rgba(88,183,255,.22))}.back,.refresh{height:42px;display:flex;align-items:center;border:1px solid var(--line);background:var(--card);color:var(--text)}.refresh.busy{color:var(--cyan)}.grid{display:grid;grid-template-columns:repeat(12,1fr);gap:15px}.glass{background:linear-gradient(145deg,var(--card2),var(--card));border:1px solid var(--line);border-radius:20px;box-shadow:0 20px 65px rgba(0,0,0,.27);backdrop-filter:blur(20px)}.metrics{grid-column:span 12;display:grid;grid-template-columns:repeat(6,1fr);overflow:hidden}.metric{padding:20px;min-width:0}.metric+.metric{border-left:1px solid var(--line)}.label{font-size:11px;color:var(--muted);text-transform:uppercase;letter-spacing:.055em}.value{font-size:24px;font-weight:750;letter-spacing:-.04em;margin-top:8px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.hint{font-size:10px;color:#6f7890;margin-top:6px}.wide{grid-column:span 8}.side{grid-column:span 4}.half{grid-column:span 6}.card{padding:21px}.head{display:flex;justify-content:space-between;gap:12px;align-items:flex-start;margin-bottom:16px}.head h2{font-size:15px;margin:0}.head p{font-size:11px;color:var(--muted);margin:3px 0 0}.badge{border:1px solid var(--line);border-radius:99px;padding:5px 9px;font-size:10px;color:var(--muted)}.composition{display:grid;grid-template-columns:repeat(4,1fr);gap:9px}.part{padding:13px;border-radius:13px;background:rgba(255,255,255,.035)}.part b{display:block;font-size:18px;margin-top:5px}.part:nth-child(1){border-top:2px solid var(--violet)}.part:nth-child(2){border-top:2px solid var(--blue)}.part:nth-child(3){border-top:2px solid var(--cyan)}.part:nth-child(4){border-top:2px solid var(--pink)}.forecast{display:grid;gap:13px}.forecast strong{font-size:32px;letter-spacing:-.05em}.forecast-row{display:flex;justify-content:space-between;color:var(--muted)}.forecast-row b{color:var(--text)}.bars{display:grid;gap:13px}.bar{display:grid;gap:6px}.bar-meta{display:flex;justify-content:space-between;gap:12px;font-size:12px}.bar-meta span:first-child{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.bar-meta span:last-child{color:var(--muted);white-space:nowrap}.track{height:6px;border-radius:99px;background:rgba(255,255,255,.055);overflow:hidden}.fill{height:100%;border-radius:inherit;background:linear-gradient(90deg,var(--violet),var(--blue))}.table-wrap{overflow:auto}.table{width:100%;border-collapse:collapse;min-width:680px}.table th{font-size:10px;color:#77819b;text-transform:uppercase;letter-spacing:.07em;text-align:left;padding:0 10px 10px}.table td{border-top:1px solid var(--line);padding:11px 10px;font-size:12px}.table th:not(:first-child),.table td:not(:first-child){text-align:right}.who{display:flex;align-items:center;gap:9px;text-align:left}.icon{width:27px;height:27px;border-radius:8px;padding:5px;background:rgba(255,255,255,.06);border:1px solid var(--line)}.icon img{width:100%;height:100%;object-fit:contain}.sub{display:block;font-size:10px;color:var(--muted)}.good{color:var(--cyan)}.hot{color:var(--pink)}.anomalies{display:grid;gap:10px}.anomaly{display:grid;grid-template-columns:1fr auto;gap:12px;padding:12px;border-radius:13px;background:rgba(250,118,183,.055);border:1px solid rgba(250,118,183,.12)}.anomaly small{color:var(--muted)}.empty{color:var(--muted);display:grid;place-items:center;min-height:100px;text-align:center}.status{margin-top:16px;display:flex;justify-content:space-between;color:#6f7890;font-size:11px}.error{display:none;padding:13px;margin-bottom:15px;border-radius:13px;color:#ffb4d7;background:rgba(250,118,183,.08);border:1px solid rgba(250,118,183,.25)}
@media(max-width:1100px){.metrics{grid-template-columns:repeat(3,1fr)}.metric:nth-child(4){border-left:0}.metric:nth-child(n+4){border-top:1px solid var(--line)}.wide,.side,.half{grid-column:span 12}.side-grid{display:grid;grid-template-columns:1fr 1fr;gap:15px}}
@media(max-width:700px){.shell{width:calc(100% - 22px);padding-top:18px}.top{align-items:flex-start;flex-direction:column}.actions{width:100%;flex-wrap:wrap}.metrics{grid-template-columns:repeat(2,1fr)}.metric:nth-child(odd){border-left:0}.metric:nth-child(even){border-left:1px solid var(--line)}.metric:nth-child(n+3){border-top:1px solid var(--line)}.composition{grid-template-columns:1fr 1fr}.side-grid{grid-template-columns:1fr}.card{padding:17px}.status{flex-direction:column;gap:5px}}
</style>
</head>
<body>
<main class="shell">
<header class="top"><div class="brand"><div class="mark">↗</div><div><h1>Advanced token analytics</h1><p>Where context, tokens and API-equivalent cost are concentrated</p></div></div><div class="actions"><a class="back" href="/">← Overview</a><div class="periods"><button class="period active" data-period="today">24h</button><button class="period" data-period="week">7d</button><button class="period" data-period="month">30d</button><button class="period" data-period="all">All</button></div><button class="refresh" id="refresh">Refresh</button></div></header>
<div class="error" id="error"></div>
<section class="grid">
<div class="glass metrics">
<div class="metric"><div class="label">API-equivalent estimate</div><div class="value" id="cost">—</div><div class="hint" id="costHint">Current public list pricing</div></div>
<div class="metric"><div class="label">New + output tokens</div><div class="value" id="useful">—</div><div class="hint" id="usefulHint">Excludes cache reads</div></div>
<div class="metric"><div class="label">Cache reused</div><div class="value good" id="cache">—</div><div class="hint" id="cacheHint">Input traffic served from cache</div></div>
<div class="metric"><div class="label">Context amplification</div><div class="value" id="amplification">—</div><div class="hint">Processed context ÷ new context</div></div>
<div class="metric"><div class="label">P95 context/request</div><div class="value" id="p95">—</div><div class="hint" id="maxContext">Peak request context</div></div>
<div class="metric"><div class="label">Requests</div><div class="value" id="requests">—</div><div class="hint" id="sessions">Across local sessions</div></div>
</div>
<article class="glass card wide"><div class="head"><div><h2>Token destination</h2><p>New context, generated output and cache traffic</p></div><span class="badge" id="processed">— processed</span></div><div class="composition" id="composition"></div></article>
<article class="glass card side"><div class="head"><div><h2>30-day projection</h2><p>Run-rate from the selected rolling period</p></div></div><div class="forecast"><strong id="forecastCost">—</strong><div class="forecast-row"><span>Processed tokens</span><b id="forecastTokens">—</b></div><div class="forecast-row"><span>Daily API cost</span><b id="dailyCost">—</b></div><div class="forecast-row"><span>Observed span</span><b id="observed">—</b></div></div></article>
<article class="glass card half"><div class="head"><div><h2>Top projects</h2><p>Repositories and working directories driving usage</p></div></div><div class="bars" id="projects"></div></article>
<article class="glass card half"><div class="head"><div><h2>Top sessions</h2><p>Anonymized sessions ranked by processed tokens</p></div></div><div class="bars" id="sessionBars"></div></article>
<article class="glass card wide"><div class="head"><div><h2>Models and applications</h2><p>Cost and context concentration by model/source pair</p></div></div><div class="table-wrap"><table class="table"><thead><tr><th>Model</th><th>Tokens</th><th>Requests</th><th>Cache reuse</th><th>API cost</th><th>Share</th></tr></thead><tbody id="models"></tbody></table></div></article>
<article class="glass card side"><div class="head"><div><h2>Sources</h2><p>Pi, Codex and Claude Code attribution</p></div></div><div class="bars" id="sources"></div></article>
<article class="glass card wide"><div class="head"><div><h2>Largest requests</h2><p>Metadata only; prompt and response content is never collected</p></div><span class="badge">Top 20</span></div><div class="table-wrap"><table class="table"><thead><tr><th>Request</th><th>Context</th><th>Output</th><th>Total</th><th>API cost</th><th>Time</th></tr></thead><tbody id="requestsTable"></tbody></table></div></article>
<article class="glass card side"><div class="head"><div><h2>Unusual spikes</h2><p>Hourly or daily buckets above the normal range</p></div></div><div class="anomalies" id="anomalies"></div></article>
</section>
<footer class="status"><span>Local metadata only · session identifiers are hashed</span><span id="updated">Waiting for data</span></footer>
</main>
<script>
const state={period:'today'};const $=id=>document.getElementById(id);const compact=new Intl.NumberFormat('en',{notation:'compact',maximumFractionDigits:2});const integer=new Intl.NumberFormat('en');const fmt=n=>compact.format(Number(n)||0);const money=n=>{const v=Number(n)||0;return v&&v<.01?'$'+v.toFixed(4):'$'+v.toFixed(2)};const pct=n=>Math.round((Number(n)||0)*100)+'%';const esc=v=>String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function bars(id,rows,extra){const max=Math.max(1,...rows.map(x=>x.totalTokens));$(id).innerHTML=rows.length?rows.map(x=>`<div class="bar"><div class="bar-meta"><span title="${esc(x.name)}">${esc(x.name)}</span><span>${fmt(x.totalTokens)} · ${money(x.cost)}${extra?` · ${integer.format(x.requests)} req`:''}</span></div><div class="track"><div class="fill" style="width:${Math.max(1,x.totalTokens/max*100)}%"></div></div></div>`).join(''):'<div class="empty">No activity in this period</div>'}
function render(d){const m=d.metrics;set('cost',money(m.cost));set('costHint',pct(m.pricedTokens/Math.max(1,m.totalTokens))+' token coverage · current public pricing');set('useful',fmt(m.newTokens));set('cache',fmt(m.cacheRead));set('amplification',(m.contextAmplification||0).toFixed(1)+'×');set('p95',fmt(m.contextP95));set('requests',integer.format(m.requests));set('usefulHint',pct(m.newTokenRate)+' of processed volume');set('cacheHint',pct(m.cacheRate)+' of input traffic');set('maxContext','Maximum '+fmt(m.contextMax));set('sessions',integer.format(m.sessions)+' sessions');set('processed',fmt(m.totalTokens)+' processed');set('forecastCost',money(d.forecast.cost30d));set('forecastTokens',fmt(d.forecast.tokens30d));set('dailyCost',money(d.forecast.dailyCost));set('observed',d.forecast.observedDays.toFixed(1)+' days · '+d.forecast.confidence+' confidence');const parts=[['Uncached input',m.input],['Generated output',m.output],['Cache read',m.cacheRead],['Cache write',m.cacheWrite]];$('composition').innerHTML=parts.map(x=>`<div class="part"><span class="label">${x[0]}</span><b>${fmt(x[1])}</b><span class="sub">${pct(x[1]/Math.max(1,m.totalTokens))}</span></div>`).join('');bars('projects',d.projects,false);bars('sessionBars',d.sessions,true);bars('sources',d.sources,true);$('models').innerHTML=d.models.length?d.models.map(x=>{const icon=String(x.icon||'ai').replace(/[^a-z0-9-]/g,'')||'ai';return `<tr><td><div class="who"><span class="icon"><img src="/icons/${icon}.svg" alt=""></span><span>${esc(x.name)} · ${esc(x.source)}<span class="sub">${esc(x.provider)}</span></span></div></td><td>${fmt(x.totalTokens)}</td><td>${integer.format(x.requests)}</td><td class="good">${pct(x.cacheRate)}</td><td>${money(x.cost)}</td><td>${pct(x.share)}</td></tr>`}).join(''):'<tr><td colspan="6"><div class="empty">No models in this period</div></td></tr>';$('requestsTable').innerHTML=d.requests.length?d.requests.map(x=>`<tr><td><div class="who"><span>${esc(x.model)} · ${esc(x.source)}<span class="sub">${esc(x.project)} · ${esc(x.session)}</span></span></div></td><td>${fmt(x.contextTokens)}</td><td>${fmt(x.output)}</td><td>${fmt(x.totalTokens)}</td><td>${money(x.cost)}</td><td>${new Date(x.timestamp*1000).toLocaleString()}</td></tr>`).join(''):'<tr><td colspan="6"><div class="empty">No requests in this period</div></td></tr>';$('anomalies').innerHTML=d.anomalies.length?d.anomalies.map(x=>`<div class="anomaly"><span><b>${new Date(x.timestamp*1000).toLocaleString()}</b><small>${x.bucketHours}h bucket · ${x.ratio.toFixed(1)}× normal</small></span><b class="hot">${fmt(x.totalTokens)}</b></div>`).join(''):'<div class="empty">No statistically unusual spikes detected</div>';set('updated','Updated '+new Date(d.updatedAt).toLocaleString()+' · '+integer.format(d.files)+' files scanned')}
function set(id,value){$(id).textContent=value}async function load(){const b=$('refresh');b.classList.add('busy');b.disabled=true;$('error').style.display='none';try{const r=await fetch('/api/advanced?period='+encodeURIComponent(state.period),{cache:'no-store'});if(!r.ok)throw Error();render(await r.json())}catch(e){$('error').textContent='Advanced statistics could not be calculated.';$('error').style.display='block'}finally{b.classList.remove('busy');b.disabled=false}}
document.querySelectorAll('.period').forEach(b=>b.addEventListener('click',()=>{document.querySelectorAll('.period').forEach(x=>x.classList.remove('active'));b.classList.add('active');state.period=b.dataset.period;load()}));$('refresh').addEventListener('click',load);load();
</script>
</body>
</html>'''


def number(value):
    if isinstance(value, bool):
        return 0
    if isinstance(value, (int, float)) and math.isfinite(value):
        return value
    try:
        parsed = float(value)
        return parsed if math.isfinite(parsed) else 0
    except (TypeError, ValueError):
        return 0


def token_number(value):
    return max(0, int(number(value)))


def event_timestamp(value):
    parsed = None
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        stamp = float(value)
        if stamp > 10_000_000_000:
            stamp /= 1000
        try:
            parsed = dt.datetime.fromtimestamp(stamp, tz=dt.timezone.utc)
        except (OSError, OverflowError, ValueError):
            parsed = None
    elif isinstance(value, str) and value:
        try:
            parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            parsed = None
    if parsed is None:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.datetime.now().astimezone().tzinfo)
    return parsed.timestamp()


def local_date(value):
    stamp = event_timestamp(value)
    if stamp is None:
        return None
    return dt.datetime.fromtimestamp(stamp, tz=dt.datetime.now().astimezone().tzinfo).date().isoformat()


def project_name(cwd):
    if not isinstance(cwd, str) or not cwd.strip():
        return "Unknown"
    cleaned = cwd.rstrip(os.sep)
    return os.path.basename(cleaned) or os.sep


def safe_label(value, fallback="Unknown"):
    if value is None:
        return fallback
    label = str(value).strip()
    return label if label else fallback


def local_secret():
    global LOCAL_SECRET
    if LOCAL_SECRET is not None:
        return LOCAL_SECRET
    CACHE_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(CACHE_DIR, 0o700)
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    try:
        descriptor = os.open(SECRET_FILE, flags)
    except FileNotFoundError:
        create_flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
        try:
            descriptor = os.open(SECRET_FILE, create_flags, 0o600)
        except FileExistsError:
            descriptor = None
        if descriptor is not None:
            try:
                os.write(descriptor, os.urandom(32))
                os.fsync(descriptor)
            finally:
                os.close(descriptor)
        descriptor = os.open(SECRET_FILE, flags)
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.getuid():
            raise RuntimeError("Invalid token meter secret")
        value = os.read(descriptor, 64)
    finally:
        os.close(descriptor)
    if len(value) != 32:
        raise RuntimeError("Invalid token meter secret")
    os.chmod(SECRET_FILE, 0o600)
    LOCAL_SECRET = value
    return value


def private_id(value, namespace):
    payload = (namespace + "\0" + safe_label(value)).encode("utf-8")
    return namespace + "_" + hmac.new(local_secret(), payload, hashlib.sha256).hexdigest()


def load_pricing_catalog():
    catalog = {}
    executable = shutil.which("pi")
    candidates = []
    if executable:
        for package in Path(executable).resolve().parents:
            if (package / "package.json").is_file():
                candidates.append(package / "node_modules" / "@earendil-works" / "pi-ai" / "dist" / "providers" / "data")
                break
    for root in candidates:
        if not root.is_dir():
            continue
        for path in root.glob("*.json"):
            try:
                payload = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            if not isinstance(payload, dict):
                continue
            for models in payload.values():
                if not isinstance(models, dict):
                    continue
                for model_id, model in models.items():
                    if not isinstance(model, dict) or not isinstance(model.get("cost"), dict):
                        continue
                    provider = safe_label(model.get("provider"), path.stem).casefold()
                    catalog.setdefault((provider, str(model_id).casefold()), model["cost"])
                    catalog.setdefault((path.stem.casefold(), str(model_id).casefold()), model["cost"])
    return catalog


def model_variants(model):
    value = safe_label(model).casefold().split("[", 1)[0]
    variants = [value]
    if value.startswith("~"):
        variants.append(value[1:])
    if "/" in value:
        variants.append(value.rsplit("/", 1)[-1])
    variants.extend(item.replace(".", "-") for item in list(variants))
    return list(dict.fromkeys(variants))


def pricing_for(source, provider, model):
    global PRICING_CATALOG
    if PRICING_CATALOG is None:
        PRICING_CATALOG = load_pricing_catalog()
    providers = [safe_label(provider).casefold()]
    if source == "Codex":
        providers = ["openai-codex", "openai", *providers]
    elif source == "Claude":
        providers.extend(("opencode", "anthropic", "openrouter"))
    variants = model_variants(model)
    if source == "Codex" or safe_label(provider).casefold() in ("openai", "openai-codex"):
        for model_id in variants:
            if model_id in OPENAI_PRICING:
                return OPENAI_PRICING[model_id]
    expanded = list(variants)
    if source == "Claude":
        expanded.extend("anthropic/" + item for item in variants if "/" not in item)
    for provider_name in dict.fromkeys(providers):
        for model_id in dict.fromkeys(expanded):
            rates = PRICING_CATALOG.get((provider_name, model_id))
            if rates and any(number(rates.get(field)) > 0 for field in ("input", "output", "cacheRead", "cacheWrite")):
                return rates
    for model_id in variants:
        rates = FALLBACK_PRICING.get(model_id)
        if rates:
            return rates
    return None


def calculate_api_cost(source, model, provider, usage):
    rates = pricing_for(source, provider, model)
    if not rates:
        return None
    input_tokens = token_number(usage.get("input"))
    output_tokens = token_number(usage.get("output"))
    cache_read = token_number(usage.get("cacheRead"))
    cache_write = token_number(usage.get("cacheWrite"))
    selected = rates
    threshold = -1
    for tier in rates.get("tiers", []):
        current = token_number(tier.get("inputTokensAbove"))
        if input_tokens + cache_read + cache_write > current > threshold:
            selected = tier
            threshold = current
    long_write = min(cache_write, token_number(usage.get("cacheWrite1h")))
    short_write = cache_write - long_write
    total = (
        number(selected.get("input")) * input_tokens
        + number(selected.get("output")) * output_tokens
        + number(selected.get("cacheRead")) * cache_read
        + number(selected.get("cacheWrite")) * short_write
        + number(selected.get("input")) * 2 * long_write
    ) / 1_000_000
    return max(0.0, total)


def inferred_provider(model):
    value = safe_label(model).casefold()
    if "claude" in value:
        return "Anthropic"
    if "gpt" in value or "openai" in value:
        return "OpenAI"
    if "kimi" in value or "moonshot" in value:
        return "Moonshot AI"
    if "gemini" in value:
        return "Google"
    if "deepseek" in value:
        return "DeepSeek"
    if "qwen" in value:
        return "Alibaba"
    if "grok" in value:
        return "xAI"
    if "mistral" in value or "mixtral" in value:
        return "Mistral AI"
    return "Claude Code"


def model_icon(model, source, provider):
    value = " ".join((safe_label(model), safe_label(source), safe_label(provider))).casefold()
    if source == "Claude" or "claude" in value or "anthropic" in value:
        return "claude"
    if "kimi" in value or "moonshot" in value:
        return "kimi"
    if "gemini" in value or "google" in value:
        return "gemini"
    if "deepseek" in value:
        return "deepseek"
    if "qwen" in value or "alibaba" in value:
        return "qwen"
    if "glm" in value or "zai" in value or "z.ai" in value:
        return "zai"
    if "grok" in value or "xai" in value:
        return "grok"
    if "mistral" in value or "mixtral" in value:
        return "mistral"
    if "perplexity" in value:
        return "perplexity"
    if "ollama" in value:
        return "ollama"
    if "llama" in value or "meta" in value:
        return "meta"
    if source == "Codex" or "gpt" in value or "openai" in value or "codex" in value:
        return "openai"
    return "ai"


def record(source, model, provider, date, project, usage, logged_cost, session, timestamp=None):
    values = {field: token_number(usage.get(field)) for field in TOKEN_FIELDS}
    if not values["totalTokens"]:
        values["totalTokens"] = values["input"] + values["output"] + values["cacheRead"] + values["cacheWrite"]
    recorded_cost = max(0.0, float(number(logged_cost)))
    calculated_cost = calculate_api_cost(source, model, provider, usage)
    cost = calculated_cost if calculated_cost is not None else recorded_cost
    return {
        "source": source,
        "model": safe_label(model),
        "provider": safe_label(provider),
        "date": date,
        "timestamp": max(0.0, float(number(timestamp))),
        "project": safe_label(project),
        **values,
        "cacheWrite1h": token_number(usage.get("cacheWrite1h")),
        "cost": cost,
        "recordedCost": recorded_cost,
        "pricingKnown": calculated_cost is not None or recorded_cost > 0,
        "session": session,
    }


def json_lines(path, size):
    try:
        with path.open("rb") as stream:
            payload = stream.read(size)
    except OSError:
        return
    if payload and not payload.endswith((b"\n", b"\r")):
        payload = payload.rsplit(b"\n", 1)[0] if b"\n" in payload else b""
    for raw in payload.splitlines():
        try:
            item = json.loads(raw)
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
        if isinstance(item, dict):
            yield item


def parse_pi(path, size):
    records = []
    project = "Unknown"
    session = private_id(str(path), "session")
    for item in json_lines(path, size):
        if item.get("type") == "session":
            project = project_name(item.get("cwd"))
            continue
        if item.get("type") != "message":
            continue
        message = item.get("message")
        if not isinstance(message, dict) or message.get("role") != "assistant":
            continue
        usage = message.get("usage")
        if not isinstance(usage, dict):
            continue
        cost = usage.get("cost")
        total_cost = cost.get("total") if isinstance(cost, dict) else 0
        timestamp_value = message.get("timestamp") or item.get("timestamp")
        date = local_date(timestamp_value)
        if not date:
            continue
        records.append(
            record(
                "Pi",
                message.get("model"),
                message.get("provider"),
                date,
                project,
                {
                    "input": usage.get("input"),
                    "output": usage.get("output"),
                    "cacheRead": usage.get("cacheRead"),
                    "cacheWrite": usage.get("cacheWrite"),
                    "reasoning": usage.get("reasoning"),
                    "totalTokens": usage.get("totalTokens"),
                },
                total_cost,
                session,
                event_timestamp(timestamp_value),
            )
        )
    return records


def codex_tuple(usage):
    return tuple(token_number(usage.get(field)) for field in CODEX_FIELDS)


def codex_session_is_fork(payload):
    if isinstance(payload.get("forked_from_id"), str):
        return True
    source = payload.get("source")
    if not isinstance(source, dict):
        return False
    subagent = source.get("subagent")
    if not isinstance(subagent, dict):
        return False
    spawn = subagent.get("thread_spawn")
    return isinstance(spawn, dict) and isinstance(spawn.get("parent_thread_id"), str)


def parse_codex(path, size):
    records = []
    model = "Unknown"
    project = "Unknown"
    previous_cumulative = None
    pending_native_usage = None
    seen_responses = set()
    session_id = None
    saw_session_meta = False
    suppressing_fork_copies = False
    fork_copy_anchor = 0.0
    session = private_id(str(path), "session")
    for item in json_lines(path, size):
        payload = item.get("payload")
        if not isinstance(payload, dict):
            continue
        if item.get("type") == "session_meta":
            if not saw_session_meta:
                saw_session_meta = True
                session_id = payload.get("id") or payload.get("session_id")
                if isinstance(session_id, str):
                    session = private_id(session_id, "session")
                model = safe_label(payload.get("model"), model)
                project = project_name(payload.get("cwd")) if payload.get("cwd") else project
                timestamp = event_timestamp(item.get("timestamp"))
                if timestamp is not None and codex_session_is_fork(payload):
                    suppressing_fork_copies = True
                    fork_copy_anchor = timestamp
            continue
        if item.get("type") == "turn_context":
            model = safe_label(payload.get("model"), model)
            project = project_name(payload.get("cwd")) if payload.get("cwd") else project
            continue
        event_id = None
        if item.get("type") == "token_usage_record":
            if session_id and payload.get("thread_id") != session_id:
                continue
            last = payload.get("usage")
            response_id = payload.get("response_id")
            if not isinstance(last, dict) or not isinstance(response_id, str) or not response_id:
                continue
            pending_native_usage = codex_tuple(last)
            if response_id in seen_responses:
                continue
            seen_responses.add(response_id)
            event_id = private_id(response_id, "codex-response")
            suppressing_fork_copies = False
        elif item.get("type") == "event_msg" and payload.get("type") == "token_count":
            info = payload.get("info")
            if not isinstance(info, dict):
                continue
            last = info.get("last_token_usage")
            total = info.get("total_token_usage")
            if not isinstance(last, dict) or not isinstance(total, dict):
                continue
            cumulative = codex_tuple(total)
            if not any(cumulative) or cumulative == previous_cumulative:
                continue
            previous_cumulative = cumulative
            matches_native = pending_native_usage == codex_tuple(last)
            pending_native_usage = None
            if matches_native:
                continue
        else:
            continue
        timestamp_value = item.get("timestamp")
        timestamp = event_timestamp(timestamp_value)
        if timestamp is None:
            continue
        if suppressing_fork_copies:
            if timestamp - fork_copy_anchor < 1:
                fork_copy_anchor = timestamp
                continue
            suppressing_fork_copies = False
        date = local_date(timestamp_value)
        if not date:
            continue
        raw_input = token_number(last.get("input_tokens"))
        if not raw_input and not token_number(last.get("output_tokens")):
            continue
        cache_read = token_number(last.get("cached_input_tokens"))
        cache_write = token_number(last.get("cache_write_input_tokens"))
        records.append(
            record(
                "Codex",
                model,
                "OpenAI",
                date,
                project,
                {
                    "input": max(0, raw_input - cache_read - cache_write),
                    "output": last.get("output_tokens"),
                    "cacheRead": cache_read,
                    "cacheWrite": cache_write,
                    "reasoning": last.get("reasoning_output_tokens"),
                    "totalTokens": last.get("total_tokens"),
                },
                0,
                session,
                timestamp,
            )
        )
        if event_id:
            records[-1]["eventId"] = event_id
    if model != "Unknown":
        for item in records:
            if item.get("model") == "Unknown":
                item["model"] = model
    return records


def parse_claude(path, size):
    candidates = {}
    for item in json_lines(path, size):
        if item.get("type") != "assistant":
            continue
        message = item.get("message")
        if not isinstance(message, dict) or message.get("role") != "assistant":
            continue
        usage = message.get("usage")
        if not isinstance(usage, dict):
            continue
        model = safe_label(message.get("model"))
        if model == "<synthetic>":
            continue
        timestamp_value = item.get("timestamp") or message.get("timestamp")
        date = local_date(timestamp_value)
        if not date:
            continue
        cache_creation = usage.get("cache_creation")
        if not isinstance(cache_creation, dict):
            cache_creation = {}
        normalized = {
            "input": usage.get("input_tokens"),
            "output": usage.get("output_tokens"),
            "cacheRead": usage.get("cache_read_input_tokens"),
            "cacheWrite": usage.get("cache_creation_input_tokens"),
            "cacheWrite1h": cache_creation.get("ephemeral_1h_input_tokens"),
        }
        if not any(token_number(value) for value in normalized.values()):
            continue
        session = private_id(item.get("sessionId") or str(path), "session")
        current = record(
            "Claude",
            model,
            inferred_provider(model),
            date,
            project_name(item.get("cwd")),
            normalized,
            item.get("costUSD"),
            session,
            event_timestamp(timestamp_value),
        )
        request_id = item.get("requestId") or message.get("id") or item.get("uuid")
        key = safe_label(request_id, session + ":" + str(len(candidates)))
        current["eventId"] = private_id(session + ":" + key, "event")
        previous = candidates.get(key)
        if previous is None or current["totalTokens"] >= previous["totalTokens"]:
            candidates[key] = current
    return list(candidates.values())


def discover_files():
    found = []
    counts = {}
    for source, root in SOURCE_PATTERNS.items():
        roots = [root]
        if source == "Codex":
            roots.append(root.parent / "archived_sessions")
        paths = sorted({path for directory in roots if directory.is_dir() for path in directory.rglob("*.jsonl") if path.is_file()})
        counts[source] = len(paths)
        found.extend((source, path) for path in paths)
    return found, counts


def load_cache():
    try:
        with CACHE_FILE.open(encoding="utf-8") as stream:
            cache = json.load(stream)
    except (OSError, json.JSONDecodeError):
        return {"version": CACHE_VERSION, "entries": {}}
    if not isinstance(cache, dict) or cache.get("version") != CACHE_VERSION or not isinstance(cache.get("entries"), dict):
        return {"version": CACHE_VERSION, "entries": {}}
    return cache


def write_cache(cache):
    descriptor, temporary = tempfile.mkstemp(prefix="usage-cache.", suffix=".tmp", dir=CACHE_DIR)
    try:
        os.fchmod(descriptor, 0o600)
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            json.dump(cache, stream, ensure_ascii=False, separators=(",", ":"))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, CACHE_FILE)
        directory = os.open(CACHE_DIR, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def scan_records(rebuild=False):
    CACHE_DIR.mkdir(mode=0o700, parents=True, exist_ok=True)
    with PROCESS_LOCK:
        with LOCK_FILE.open("a+") as lock:
            os.chmod(LOCK_FILE, 0o600)
            fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
            if rebuild:
                try:
                    CACHE_FILE.unlink()
                except FileNotFoundError:
                    pass
                cache = {"version": CACHE_VERSION, "entries": {}}
            else:
                cache = load_cache()
            old_entries = cache["entries"]
            new_entries = {}
            records = []
            files, counts = discover_files()
            for source, path in files:
                try:
                    stat = path.stat()
                except OSError:
                    continue
                key = private_id(str(path), "file")
                signature = [stat.st_mtime_ns, stat.st_size]
                cached = old_entries.get(key)
                if isinstance(cached, dict) and cached.get("signature") == signature and cached.get("source") == source and isinstance(cached.get("records"), list) and all(isinstance(item, dict) for item in cached["records"]):
                    parsed = cached["records"]
                else:
                    if source == "Pi":
                        parsed = parse_pi(path, stat.st_size)
                    elif source == "Codex":
                        parsed = parse_codex(path, stat.st_size)
                    else:
                        parsed = parse_claude(path, stat.st_size)
                new_entries[key] = {"signature": signature, "source": source, "records": parsed}
                records.extend(parsed)
            updated = {"version": CACHE_VERSION, "entries": new_entries}
            if rebuild or new_entries != old_entries:
                write_cache(updated)
            current_records = []
            seen_events = set()
            for cached_record in records:
                item = dict(cached_record)
                event_id = item.get("eventId")
                if event_id and event_id in seen_events:
                    continue
                if event_id:
                    seen_events.add(event_id)
                calculated = calculate_api_cost(item.get("source"), item.get("model"), item.get("provider"), item)
                recorded_cost = max(0.0, float(number(item.get("recordedCost"))))
                item["cost"] = calculated if calculated is not None else recorded_cost
                item["pricingKnown"] = calculated is not None or recorded_cost > 0
                current_records.append(item)
            return current_records, counts


def base_aggregate(records):
    result = {field: 0 for field in TOKEN_FIELDS}
    result.update({"cost": 0.0, "recordedCost": 0.0, "pricedTokens": 0, "unpricedTokens": 0, "requests": 0, "sessions": 0, "cacheRate": 0.0})
    sessions = set()
    for item in records:
        for field in TOKEN_FIELDS:
            result[field] += token_number(item.get(field))
        result["cost"] += max(0.0, float(number(item.get("cost"))))
        result["recordedCost"] += max(0.0, float(number(item.get("recordedCost"))))
        pricing_field = "pricedTokens" if item.get("pricingKnown") else "unpricedTokens"
        result[pricing_field] += token_number(item.get("totalTokens"))
        result["requests"] += 1
        sessions.add(item.get("session"))
    result["sessions"] = len(sessions)
    cache_base = result["input"] + result["cacheRead"] + result["cacheWrite"]
    result["cacheRate"] = round(result["cacheRead"] / cache_base, 6) if cache_base else 0.0
    result["cost"] = round(result["cost"], 10)
    result["recordedCost"] = round(result["recordedCost"], 10)
    return result


def grouped(records, key):
    buckets = defaultdict(list)
    for item in records:
        buckets[item.get(key)].append(item)
    rows = []
    for group_key, items in buckets.items():
        row = {"name": safe_label(group_key)}
        row.update(base_aggregate(items))
        rows.append(row)
    rows.sort(key=lambda item: (-item["totalTokens"], item["name"].casefold()))
    return rows


def grouped_models(records):
    buckets = defaultdict(list)
    for item in records:
        key = (item.get("model"), item.get("source"), item.get("provider"))
        buckets[key].append(item)
    rows = []
    for (name, source, provider), items in buckets.items():
        row = {
            "name": safe_label(name),
            "source": safe_label(source),
            "provider": safe_label(provider),
            "icon": model_icon(name, source, provider),
        }
        row.update(base_aggregate(items))
        rows.append(row)
    rows.sort(key=lambda item: (-item["totalTokens"], item["name"].casefold(), item["source"].casefold()))
    return rows


def aggregate(records, breakdowns=True):
    result = base_aggregate(records)
    if breakdowns:
        result["models"] = grouped_models(records)
        result["sources"] = grouped(records, "source")
        result["projects"] = grouped(records, "project")
    return result


PERIOD_DAYS = {"today": 1, "week": 7, "month": 30}


def records_for_period(records, period, now=None):
    current = time.time() if now is None else now
    if period == "all":
        return [item for item in records if 0 < number(item.get("timestamp")) <= current + 300]
    days = PERIOD_DAYS.get(period, 1)
    cutoff = current - days * 86400
    return [item for item in records if cutoff <= number(item.get("timestamp")) <= current + 300]


def percentile(values, ratio):
    if not values:
        return 0
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, math.ceil(len(ordered) * ratio) - 1))
    return ordered[index]


def median(values):
    if not values:
        return 0
    ordered = sorted(values)
    middle = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[middle]
    return (ordered[middle - 1] + ordered[middle]) / 2


def rows_with_share(rows, total):
    output = []
    for row in rows:
        item = dict(row)
        item["share"] = round(item.get("totalTokens", 0) / total, 8) if total else 0
        output.append(item)
    return output


def advanced_sessions(records, total):
    buckets = defaultdict(list)
    for item in records:
        buckets[item.get("session")].append(item)
    rows = []
    for session, items in buckets.items():
        summary = base_aggregate(items)
        digest = hashlib.sha256(safe_label(session).encode("utf-8")).hexdigest()[:8]
        projects = sorted({safe_label(item.get("project")) for item in items})
        sources = sorted({safe_label(item.get("source")) for item in items})
        models = sorted({safe_label(item.get("model")) for item in items})
        timestamps = [number(item.get("timestamp")) for item in items if number(item.get("timestamp")) > 0]
        row = {
            "name": f"{projects[0] if projects else 'Unknown'} · {'+'.join(sources)} · #{digest}",
            "id": digest,
            "projects": projects,
            "sources": sources,
            "models": models,
            "startedAt": min(timestamps) if timestamps else 0,
            "endedAt": max(timestamps) if timestamps else 0,
            **summary,
        }
        row["share"] = round(row["totalTokens"] / total, 8) if total else 0
        rows.append(row)
    rows.sort(key=lambda item: (-item["totalTokens"], -item["cost"]))
    return rows


def advanced_anomalies(records, period, now):
    bucket_hours = 1 if period == "today" else 24
    bucket_seconds = bucket_hours * 3600
    timestamps = [number(item.get("timestamp")) for item in records if number(item.get("timestamp")) > 0]
    if not timestamps:
        return []
    start = min(timestamps) if period == "all" else now - PERIOD_DAYS.get(period, 1) * 86400
    first = math.floor(start / bucket_seconds) * bucket_seconds
    last_complete = math.floor(now / bucket_seconds) * bucket_seconds - bucket_seconds
    values = defaultdict(int)
    for item in records:
        stamp = number(item.get("timestamp"))
        bucket = math.floor(stamp / bucket_seconds) * bucket_seconds
        values[bucket] += token_number(item.get("totalTokens"))
    buckets = []
    cursor = first
    while cursor <= last_complete and len(buckets) < 4000:
        buckets.append((cursor, values.get(cursor, 0)))
        cursor += bucket_seconds
    anomalies = []
    for index, (stamp, value) in enumerate(buckets):
        history = [volume for _, volume in buckets[:index] if volume > 0]
        if len(history) < 6 or value <= 0:
            continue
        baseline = median(history)
        deviation = median([abs(volume - baseline) for volume in history])
        scale = 1.4826 * deviation
        score = (value - baseline) / scale if scale > 0 else 0
        ratio = value / baseline if baseline > 0 else 0
        threshold = max(100_000, baseline * 2)
        unusual = score > 4.5 if scale > 0 else value > threshold
        if unusual and value > threshold:
            anomalies.append({
                "timestamp": stamp,
                "bucketHours": bucket_hours,
                "totalTokens": value,
                "ratio": round(ratio, 4),
                "score": round(score, 4) if scale > 0 else None,
            })
    anomalies.sort(key=lambda item: (-item["totalTokens"], -item["timestamp"]))
    return anomalies[:12]


def advanced_data(period):
    records, counts = scan_records()
    current = time.time()
    selected = records_for_period(records, period, current)
    metrics = base_aggregate(selected)
    contexts = [token_number(item.get("input")) + token_number(item.get("cacheRead")) + token_number(item.get("cacheWrite")) for item in selected]
    new_tokens = metrics["input"] + metrics["cacheWrite"] + metrics["output"]
    new_context = metrics["input"] + metrics["cacheWrite"]
    metrics.update({
        "newTokens": new_tokens,
        "newTokenRate": round(new_tokens / metrics["totalTokens"], 8) if metrics["totalTokens"] else 0,
        "contextAmplification": round((metrics["input"] + metrics["cacheRead"] + metrics["cacheWrite"]) / new_context, 6) if new_context else 0,
        "contextAverage": round(sum(contexts) / len(contexts), 2) if contexts else 0,
        "contextP50": percentile(contexts, 0.5),
        "contextP95": percentile(contexts, 0.95),
        "contextMax": max(contexts, default=0),
    })
    total = metrics["totalTokens"]
    projects = rows_with_share(grouped(selected, "project"), total)[:15]
    sources = rows_with_share(grouped(selected, "source"), total)[:10]
    models = rows_with_share(grouped_models(selected), total)[:25]
    sessions = advanced_sessions(selected, total)[:20]
    request_rows = []
    for item in selected:
        context_tokens = token_number(item.get("input")) + token_number(item.get("cacheRead")) + token_number(item.get("cacheWrite"))
        digest = hashlib.sha256(safe_label(item.get("session")).encode("utf-8")).hexdigest()[:8]
        request_rows.append({
            "timestamp": math.floor(number(item.get("timestamp")) / 3600) * 3600,
            "session": "#" + digest,
            "source": safe_label(item.get("source")),
            "model": safe_label(item.get("model")),
            "provider": safe_label(item.get("provider")),
            "project": safe_label(item.get("project")),
            "input": token_number(item.get("input")),
            "output": token_number(item.get("output")),
            "cacheRead": token_number(item.get("cacheRead")),
            "cacheWrite": token_number(item.get("cacheWrite")),
            "contextTokens": context_tokens,
            "totalTokens": token_number(item.get("totalTokens")),
            "cost": round(max(0.0, float(number(item.get("cost")))), 10),
        })
    request_rows.sort(key=lambda item: (-item["totalTokens"], -item["cost"]))
    all_timestamps = [number(item.get("timestamp")) for item in records if 0 < number(item.get("timestamp")) <= current + 300]
    if period == "all":
        boundary_start = min(all_timestamps) if all_timestamps else current
        target_days = max((current - boundary_start) / 86400, 1 / 24)
    else:
        target_days = float(PERIOD_DAYS.get(period, 1))
        requested_start = current - target_days * 86400
        boundary_start = max(requested_start, min(all_timestamps)) if all_timestamps else current
    observed_days = max((current - boundary_start) / 86400, 1 / 24)
    coverage_ratio = min(1.0, observed_days / target_days) if target_days else 0
    confidence = "high" if coverage_ratio >= 0.8 and metrics["requests"] >= 20 else "medium" if coverage_ratio >= 0.5 and metrics["requests"] >= 5 else "low"
    daily_cost = metrics["cost"] / observed_days
    daily_tokens = total / observed_days
    monthly_days = 30.4375
    return {
        "updatedAt": dt.datetime.fromtimestamp(current, tz=dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "asOf": current,
        "boundaryStart": boundary_start,
        "boundaryEnd": current,
        "period": period,
        "files": sum(counts.values()),
        "metrics": metrics,
        "forecast": {
            "observedDays": round(observed_days, 4),
            "coverageRatio": round(coverage_ratio, 6),
            "confidence": confidence,
            "dailyCost": round(daily_cost, 10),
            "cost30d": round(daily_cost * monthly_days, 10),
            "tokens30d": round(daily_tokens * monthly_days),
        },
        "projects": projects,
        "sources": sources,
        "models": models,
        "sessions": sessions,
        "requests": request_rows[:20],
        "anomalies": advanced_anomalies(selected, period, current),
    }


def snapshot_data(rebuild=False):
    records, counts = scan_records(rebuild)
    now = time.time()
    today = dt.datetime.now().astimezone().date()

    periods = {
        "today": aggregate(records_for_period(records, "today", now)),
        "week": aggregate(records_for_period(records, "week", now)),
        "month": aggregate(records_for_period(records, "month", now)),
        "all": aggregate(records_for_period(records, "all", now)),
    }
    by_date = defaultdict(list)
    for item in records:
        by_date[item.get("date")].append(item)
    timeline = []
    for offset in range(89, -1, -1):
        date = (today - dt.timedelta(days=offset)).isoformat()
        timeline.append({"date": date, **aggregate(by_date.get(date, []), False)})
    recent_records = records_for_period(records, "today", now)
    timeline24h = []
    for offset in range(23, -1, -1):
        start = now - (offset + 1) * 3600
        end = now - offset * 3600
        bucket = [item for item in recent_records if start <= number(item.get("timestamp")) < end]
        label = dt.datetime.fromtimestamp(end, tz=dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
        timeline24h.append({"date": label, **aggregate(bucket, False)})
    discovered_sources = [{"name": source, "files": counts.get(source, 0)} for source in SOURCE_PATTERNS]
    return {
        "updatedAt": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
        "periods": periods,
        "timeline": timeline,
        "timeline24h": timeline24h,
        "discovered": {"files": sum(counts.values()), "sources": discovered_sources},
    }


def compact_json(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


class TokenMeterServer(ThreadingHTTPServer):
    allow_reuse_address = True
    daemon_threads = True


class Handler(BaseHTTPRequestHandler):
    server_version = "TokenMeter"
    sys_version = ""

    def common_headers(self, content_type, length):
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(length))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        self.send_header("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=(), usb=()")
        self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'")

    def respond(self, status, body, content_type):
        payload = body.encode("utf-8")
        self.send_response(status)
        self.common_headers(content_type, len(payload))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(payload)

    def do_GET(self):
        host = self.headers.get("Host", "")
        if host not in (f"{HOST}:{PORT}", f"localhost:{PORT}"):
            self.respond(421, compact_json({"error": "Invalid host"}), "application/json; charset=utf-8")
            return
        origin = self.headers.get("Origin")
        if origin and origin not in (BASE_URL, f"http://localhost:{PORT}"):
            self.respond(403, compact_json({"error": "Invalid origin"}), "application/json; charset=utf-8")
            return
        parsed_url = urllib.parse.urlsplit(self.path)
        path = parsed_url.path
        if path == "/":
            self.respond(200, DASHBOARD, "text/html; charset=utf-8")
            return
        if path == "/advanced":
            self.respond(200, ADVANCED_DASHBOARD, "text/html; charset=utf-8")
            return
        if path == "/health":
            self.respond(200, "OK", "text/plain; charset=utf-8")
            return
        if path == "/api/stats":
            try:
                body = compact_json(snapshot_data())
            except Exception:
                self.respond(500, compact_json({"error": "Unable to build local stats"}), "application/json; charset=utf-8")
                return
            self.respond(200, body, "application/json; charset=utf-8")
            return
        if path == "/api/advanced":
            query = urllib.parse.parse_qs(parsed_url.query)
            period = query.get("period", ["today"])[0]
            if period not in ("today", "week", "month", "all"):
                self.respond(400, compact_json({"error": "Invalid period"}), "application/json; charset=utf-8")
                return
            try:
                body = compact_json(advanced_data(period))
            except Exception:
                self.respond(500, compact_json({"error": "Unable to build advanced stats"}), "application/json; charset=utf-8")
                return
            self.respond(200, body, "application/json; charset=utf-8")
            return
        if path.startswith("/icons/") and path.endswith(".svg"):
            name = path.removeprefix("/icons/").removesuffix(".svg")
            if name in ICON_NAMES:
                try:
                    body = (ICONS_DIR / f"{name}.svg").read_text(encoding="utf-8")
                except OSError:
                    pass
                else:
                    self.respond(200, body, "image/svg+xml; charset=utf-8")
                    return
        self.respond(404, compact_json({"error": "Not found"}), "application/json; charset=utf-8")

    def do_HEAD(self):
        self.do_GET()

    def log_message(self, format, *args):
        return


def serve():
    server = TokenMeterServer((HOST, PORT), Handler)
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


def server_healthy(timeout=0.35):
    try:
        with urllib.request.urlopen(f"{BASE_URL}/health", timeout=timeout) as response:
            return response.status == 200 and response.read(2) == b"OK"
    except (OSError, urllib.error.URLError):
        return False


def open_dashboard():
    if not server_healthy():
        subprocess.Popen(
            [sys.executable, str(Path(__file__).resolve()), "serve"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            close_fds=True,
            start_new_session=True,
            cwd=os.sep,
        )
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline and not server_healthy():
            time.sleep(0.1)
        if not server_healthy():
            raise RuntimeError(f"Token Meter did not start on {BASE_URL}")
    if not webbrowser.open(BASE_URL, new=2):
        raise RuntimeError(f"Could not open the default browser; visit {BASE_URL}")


def main():
    parser = argparse.ArgumentParser(prog="token-meter.py")
    parser.add_argument("command", choices=("snapshot", "serve", "open", "rebuild"))
    args = parser.parse_args()
    if args.command == "snapshot":
        print(compact_json(snapshot_data()))
    elif args.command == "rebuild":
        print(compact_json(snapshot_data(True)))
    elif args.command == "serve":
        serve()
    else:
        open_dashboard()


if __name__ == "__main__":
    main()
