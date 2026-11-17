// ============================================================
// Clash Verge Rev · 全局扩展脚本（修正版）
// 把「FlClash 那套代理组」复刻到 Verge：国内流量 / 国外流量 / 全部节点
// + 地区组 + 国外媒体 + 服务组，并自带 rule-providers 与规则
// （否则订阅自带规则会指向已被删掉的组，配置直接报错）
// 用法：设置 → 扩展脚本 → 全局扩展脚本 → 粘贴保存 → 重新应用配置
//
// 本版修复：
//   1. buildGroups 里 tailnet 组写在 var groups/var exists 之前（必崩）+ 重复声明
//   2. providers 先用后声明
//   3. PROVIDERS 定义了却从未写进 config["rule-providers"]（RULE-SET 找不到）
//   4. ENTRY_FOREIGN 里的 "Tailnet" 与组名 "🔒 Tailnet" 不一致，被静默丢弃
//   5. TSNET_RE 认不出 Tailscale 命名
//   6. 规则里硬编码组名 → 统一用 @TSNET 占位符
//   7. safeRules 原地改写全局 RULES → 改为生成新数组
//   8. 纯 proxy-providers 模式下「其他」组逻辑失效
//   9. select 组上无意义的 tolerance/lazy
// ============================================================

var TSNET_GROUP      = "🔒 Tailnet";
var TSNET_IN_ALL     = false;                 // tailnet 节点是否也放进「全部节点」
var TSNET_RE         = /(tailnet|tailscale|tail7a372|ts\.net|\bts[-_ ])/i;  // 认订阅里的 tailnet 节点名
var TSNET_FILTER_SRC = "(?i)(tailnet|tailscale|tail7a372|ts\\.net|\\bts[-_ ])"; // mihomo 正则（不是 JS）
var MAGICDNS         = "100.100.100.100";

var REPLACE_RULES    = true;                  // 必须 true，否则订阅规则指向不存在的组
var DROP_OLD_GROUPS  = true;                  // 丢掉订阅自带的代理组
var TEST_URL         = "https://www.gstatic.com/generate_204";
var FALLBACK         = "国外流量";             // 规则指向不存在的组时改投这里

// 机场塞进节点列表的「剩余流量 / 套餐到期」类信息节点
var JUNK     = /套餐|到期|剩余|流量|重置|官网|文档|下载|使用说明|通知|电报|\bTG\b|客服|群组|频道|网址|备用|距离下次|过期|防失联|续费|购买|折扣|优惠|订阅|失效|无效|expire/i;
var JUNK_SRC = "套餐|到期|剩余|流量|重置|官网|文档|下载|使用说明|通知|电报|TG|客服|群组|频道|网址|备用|距离下次|过期|防失联|续费|购买|折扣|优惠|订阅|失效|无效|expire";

// ---------------- 入口组固定顺序（@TSNET 运行时替换成 TSNET_GROUP） ----------------
var ENTRY_DOMESTIC = ["DIRECT", "全部节点", "其他", "香港", "日本", "新加坡", "台湾", "美国", "法国", "德国", "加拿大", "英国", "印度", "韩国", "俄罗斯", "土耳其", "马来西亚", "巴西"];
var ENTRY_FOREIGN  = ["全部节点", "香港", "日本", "新加坡", "台湾", "美国", "其他", "法国", "德国", "加拿大", "英国", "印度", "韩国", "俄罗斯", "土耳其", "马来西亚", "巴西", "@TSNET", "DIRECT"];

// ---------------- 地区自动筛选组 ----------------
var REGIONS = [
  { name: "其他",     type: "url-test", tolerance: 100, filter: "泰国|越南|菲律宾|迪拜|柬埔寨|阿根廷|印尼|印度尼西亚|Indonesia|Thailand|Vietnam|Philippines|Dubai|Cambodia|Argentina|🇹🇭|🇻🇳|🇵🇭|🇦🇪|🇰🇭|🇦🇷|🇮🇩|th_|vn_|ph_|ae_|kh_|ar_|id_", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载" },
  { name: "香港",     type: "url-test", tolerance: 100, filter: "香港|Hong\\s*Kong|\\bHK\\b|🇭🇰", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载|日本|新加坡|台湾|美国|Korea|Japan" },
  { name: "日本",     type: "url-test", tolerance: 100, filter: "日本|东京|大阪|Japan|\\bJP\\b|🇯🇵", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载|香港|新加坡|台湾|美国" },
  { name: "新加坡",   type: "url-test", tolerance: 100, filter: "新加坡|狮城|Singapore|\\bSG\\b|🇸🇬", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载|香港|日本|台湾|美国" },
  { name: "台湾",     type: "url-test", tolerance: 100, filter: "台湾|臺灣|Taiwan|\\bTW\\b|🇹🇼", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载|香港|日本|新加坡|美国" },
  { name: "美国",     type: "select",   tolerance: 0,   filter: "美国|美國|United\\s*States|\\bUSA\\b|\\bUS\\b|🇺🇸", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载|香港|日本|新加坡|台湾" },
  { name: "法国",     type: "url-test", tolerance: 100, filter: "法国|法國|France|\\bFR\\b|🇫🇷", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载" },
  { name: "德国",     type: "url-test", tolerance: 100, filter: "德国|德國|Germany|\\bDE\\b|🇩🇪", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载" },
  { name: "加拿大",   type: "url-test", tolerance: 100, filter: "加拿大|Canada|\\bCA\\b|🇨🇦", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载" },
  { name: "英国",     type: "url-test", tolerance: 100, filter: "英国|英國|United\\s*Kingdom|\\bUK\\b|\\bGB\\b|🇬🇧", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载" },
  { name: "印度",     type: "url-test", tolerance: 100, filter: "印度|India|🇮🇳", exclude: "印度尼西亚|Indonesia|印尼|套餐|到期|剩余|流量|重置|官网|文档|下载" },
  { name: "韩国",     type: "url-test", tolerance: 100, filter: "韩国|韓國|Korea|\\bKR\\b|🇰🇷", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载" },
  { name: "俄罗斯",   type: "url-test", tolerance: 100, filter: "俄罗斯|俄羅斯|Russia|\\bRU\\b|🇷🇺", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载" },
  { name: "土耳其",   type: "url-test", tolerance: 100, filter: "土耳其|Turkey|Türkiye|\\bTR\\b|🇹🇷", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载" },
  { name: "马来西亚", type: "url-test", tolerance: 100, filter: "马来西亚|馬來西亞|Malaysia|\\bMY\\b|🇲🇾", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载" },
  { name: "巴西",     type: "url-test", tolerance: 100, filter: "巴西|Brazil|\\bBR\\b|🇧🇷", exclude: "套餐|到期|剩余|流量|重置|官网|文档|下载" }
];

// ---------------- 服务组 ----------------
var SERVICES = [
  { name: "YouTube",    proxies: ["国外媒体", "国外流量", "DIRECT"] },
  { name: "Spotify",    proxies: ["国外媒体", "国外流量", "DIRECT"] },
  { name: "Google",     proxies: ["国外流量", "DIRECT"] },
  { name: "openAi",     proxies: ["全部节点", "日本", "新加坡", "美国", "国外流量", "DIRECT"] },
  { name: "Netflix",    proxies: ["国外媒体", "国外流量", "DIRECT"] },
  { name: "Twitter",    proxies: ["国外流量", "DIRECT"] },
  { name: "TikTok",     proxies: ["国外媒体", "国外流量", "DIRECT"] },
  { name: "Facebook",   proxies: ["国外流量", "DIRECT"] },
  { name: "Discord",    proxies: ["国外流量", "DIRECT"] },
  { name: "广告拦截",   proxies: ["REJECT", "DIRECT", "国外流量"] },
  { name: "GitHub",     proxies: ["DIRECT", "国外流量"] },
  { name: "OneDrive",   proxies: ["DIRECT", "国外流量"] },
  { name: "Microsoft",  proxies: ["DIRECT", "国外流量"] },
  { name: "Steam",      proxies: ["DIRECT", "国外流量"] },
  { name: "Cloudflare", proxies: ["DIRECT", "国外流量"] }
];

// ---------------- 规则（@TSNET → TSNET_GROUP；100.100.100.100 已含在 100.64/10 内，删掉冗余条） ----------------
var RULES = [
  "IP-CIDR,100.64.0.0/10,@TSNET,no-resolve",
  "IP-CIDR6,fd7a:115c:a1e0::/48,@TSNET,no-resolve",
  "DOMAIN-SUFFIX,ts.net,@TSNET",

  "DOMAIN,new-api.aberrrrrrr.space,国外流量",
  "DOMAIN-KEYWORD,cityu,DIRECT",
  "PROCESS-NAME,sonora,国外流量",
  "DOMAIN-KEYWORD,spotify,Spotify",
  "DOMAIN-KEYWORD,notion,国外流量",
  "DOMAIN-SUFFIX,re0.me,国外流量",
  "DOMAIN-SUFFIX,1molchuan.top,DIRECT",
  "DOMAIN-SUFFIX,linux.do,国外流量",
  "DOMAIN-KEYWORD,sonobus,DIRECT",
  "DOMAIN-KEYWORD,claude,美国",
  "DOMAIN-SUFFIX,network-auth.com,DIRECT",
  "DOMAIN-SUFFIX,wifi-cloud.jp,DIRECT",
  "DOMAIN-SUFFIX,ne.jp,DIRECT",
  "DOMAIN-SUFFIX,v2ex.com,国外流量",
  "DOMAIN-SUFFIX,nodeseek.com,国外流量",
  "DOMAIN-SUFFIX,mnapi.com,DIRECT",
  "DOMAIN-SUFFIX,ieee.org,DIRECT",
  "DOMAIN-SUFFIX,anrunnetwork.com,DIRECT",
  "DOMAIN-SUFFIX,apifox.com,DIRECT",
  "DOMAIN-SUFFIX,crond.dev,DIRECT",
  "IP-CIDR,223.113.52.0/22,DIRECT,no-resolve",
  "IP-CIDR,43.130.34.76/24,DIRECT,no-resolve",
  "DOMAIN-SUFFIX,clivia.fun,DIRECT",
  "DOMAIN-SUFFIX,hqu.edu.cn,DIRECT",
  "DOMAIN-SUFFIX,digit77.com,DIRECT",
  "DOMAIN-SUFFIX,czzy77.com,DIRECT",
  "DOMAIN-SUFFIX,hdhive.com,国外流量",
  "DOMAIN-SUFFIX,jdbstatic.com,香港",
  "DOMAIN-SUFFIX,javdb.com,香港",
  "DOMAIN-KEYWORD,jable,新加坡",
  "DOMAIN-SUFFIX,muyuan.do,香港",

  "RULE-SET,广告拦截-rule,广告拦截",
  "RULE-SET,GitHub-rule,GitHub",
  "RULE-SET,YouTube-rule,YouTube",
  "RULE-SET,YouTube-rule-1,YouTube",
  "RULE-SET,Spotify-rule,Spotify",
  "RULE-SET,Google-rule,Google",
  "RULE-SET,openAi-rule,openAi",
  "RULE-SET,Netflix-rule,Netflix",
  "RULE-SET,Twitter-rule,Twitter",
  "RULE-SET,TikTok-rule,TikTok",
  "RULE-SET,Facebook-rule,Facebook",
  "RULE-SET,OneDrive-rule,OneDrive",
  "RULE-SET,Microsoft-rule,Microsoft",
  "RULE-SET,Steam-rule,Steam",
  "RULE-SET,Cloudflare-rule,Cloudflare",
  "RULE-SET,Discord-rule,Discord",
  "RULE-SET,reject,广告拦截",
  "RULE-SET,cncidr,DIRECT,no-resolve",
  "RULE-SET,direct,DIRECT",

  "GEOSITE,gfw,国外流量",
  "GEOIP,CN,国内流量",
  "MATCH,国外流量"
];

// ---------------- rule-providers（blackmatrix7 + Loyalsoldier） ----------------
var PROVIDERS = {
  "广告拦截-rule":  { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/广告拦截-rule.yaml",  url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/AdvertisingLite/AdvertisingLite_Classical.yaml" },
  "GitHub-rule":    { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/GitHub-rule.yaml",    url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/GitHub/GitHub.yaml" },
  "YouTube-rule":   { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/YouTube-rule.yaml",   url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/YouTube/YouTube.yaml" },
  "YouTube-rule-1": { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/YouTube-rule-1.yaml", url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/YouTubeMusic/YouTubeMusic.yaml" },
  "Spotify-rule":   { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/Spotify-rule.yaml",   url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/Spotify/Spotify.yaml" },
  "Google-rule":    { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/Google-rule.yaml",    url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/Google/Google_No_Resolve.yaml" },
  "openAi-rule":    { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/openAi-rule.yaml",    url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/OpenAI/OpenAI_No_Resolve.yaml" },
  "Netflix-rule":   { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/Netflix-rule.yaml",   url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/Netflix/Netflix_No_Resolve.yaml" },
  "Twitter-rule":   { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/Twitter-rule.yaml",   url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/Twitter/Twitter_No_Resolve.yaml" },
  "TikTok-rule":    { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/TikTok-rule.yaml",    url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/TikTok/TikTok_No_Resolve.yaml" },
  "Facebook-rule":  { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/Facebook-rule.yaml",  url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/Facebook/Facebook_No_Resolve.yaml" },
  "OneDrive-rule":  { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/OneDrive-rule.yaml",  url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/OneDrive/OneDrive_No_Resolve.yaml" },
  "Microsoft-rule": { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/Microsoft-rule.yaml", url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/Microsoft/Microsoft_No_Resolve.yaml" },
  "Steam-rule":     { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/Steam-rule.yaml",     url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@release/rule/Clash/Steam/Steam_No_Resolve.yaml" },
  "Cloudflare-rule":{ type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/Cloudflare-rule.yaml",url: "https://cdn.jsdelivr.net/gh/blackmatrix7/ios_rule_script@master/rule/Clash/Cloudflare/Cloudflare_No_Resolve.yaml" },
  // 这条是 Z-Siqi 的 Clash 格式，behavior classical 能对上；若报格式错，换成 blackmatrix7 的 Discord
  "Discord-rule":   { type: "http", behavior: "classical", format: "yaml", interval: 86400, path: "./providers/Discord-rule.yaml",   url: "https://raw.githubusercontent.com/Z-Siqi/Clash-for-Windows_Rule/main/Rule/Discord" },
  "reject":         { type: "http", behavior: "domain",    format: "yaml", interval: 86400, path: "./providers/reject.yaml",         url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/reject.txt" },
  "cncidr":         { type: "http", behavior: "ipcidr",    format: "yaml", interval: 86400, path: "./providers/cncidr.yaml",         url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/cncidr.txt" },
  "direct":         { type: "http", behavior: "domain",    format: "yaml", interval: 86400, path: "./providers/direct.yaml",         url: "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release/direct.txt" }
};

// ============================================================
// 以下为实现，一般不用改
// ============================================================
function rx(src) { return new RegExp(src, "i"); }

function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }

function mergeObj(a, b) {
  var out = {}, k;
  a = a || {}; b = b || {};
  for (k in a) { if (has(a, k)) { out[k] = a[k]; } }
  for (k in b) { if (has(b, k)) { out[k] = b[k]; } }
  return out;
}

function providerNames(config) {
  var pp = config["proxy-providers"] || {}, out = [], k;
  for (k in pp) { if (has(pp, k)) { out.push(k); } }
  return out;
}

// 有内联节点就在 JS 里筛；只有 provider 就退回 mihomo 原生 use + filter
function members(config, nodes, filterSrc, excludeSrc) {
  if (nodes.length > 0) {
    var inc = filterSrc ? rx(filterSrc) : null;
    var exc = excludeSrc ? rx(excludeSrc) : null;
    var out = [];
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i];
      if (inc && !inc.test(n)) { continue; }
      if (exc && exc.test(n)) { continue; }
      out.push(n);
    }
    return { proxies: out };
  }
  var use = providerNames(config);
  if (use.length === 0) { return { proxies: [] }; }
  var g = { use: use };
  if (filterSrc) { g.filter = filterSrc; }
  if (excludeSrc) { g["exclude-filter"] = excludeSrc; }
  return g;
}

// 组名集合（入口 4 + 地区 + 服务 + tailnet）
function groupNameSet() {
  var set = { "国内流量": true, "国外流量": true, "全部节点": true, "国外媒体": true };
  set[TSNET_GROUP] = true;
  var i;
  for (i = 0; i < REGIONS.length; i++) { set[REGIONS[i].name] = true; }
  for (i = 0; i < SERVICES.length; i++) { set[SERVICES[i].name] = true; }
  return set;
}

// 机场偶尔有节点就叫「韩国」「美国」——和我们建的地区组同名，
// mihomo 会判成 self-loop：loop is detected in ProxyGroup: [韩国]。
// 统一改名成「韩国 ·节点」：节点留着，名字不撞。
function renameCollidingNodes(config, reserved) {
  var ps = config.proxies || [], seen = {}, i;
  for (i = 0; i < ps.length; i++) { if (ps[i] && ps[i].name) { seen[ps[i].name] = true; } }
  for (i = 0; i < ps.length; i++) {
    var p = ps[i];
    if (!p || typeof p.name !== "string" || !reserved[p.name]) { continue; }
    var base = p.name + " ·节点", nm = base, n = 1;
    while (seen[nm] || reserved[nm]) { n++; nm = base + n; }
    seen[nm] = true;
    p.name = nm;
  }
}

function splitNodes(config) {
  var plain = [], tn = [], ps = config.proxies || [], i;
  for (i = 0; i < ps.length; i++) {
    var n = ps[i] && ps[i].name;
    if (typeof n !== "string" || n.length === 0) { continue; }
    if (JUNK.test(n)) { continue; }
    if (TSNET_RE.test(n)) { tn.push(n); } else { plain.push(n); }
  }
  return { nodes: plain, tn: tn };
}

function buildGroups(config, sp) {
  // ↓ 所有声明必须在最前面（上一版就是栽在这里）
  var groups = [];
  var exists = { "DIRECT": true, "REJECT": true, "PASS": true };
  var providers = providerNames(config);
  var nodes = sp.nodes;
  var providerOnly = (nodes.length === 0 && providers.length > 0);
  var i, j;

  // ---- 1) Tailnet 组（规则第一条就指向它，必须最先建）----
  if (sp.tn.length > 0) {
    groups.push({ name: TSNET_GROUP, type: "select", proxies: sp.tn.concat(["DIRECT"]) });
    exists[TSNET_GROUP] = true;
  } else if (providerOnly) {
    // 纯 provider 模式看不到节点名，只能退回 mihomo 原生 filter
    groups.push({
      name: TSNET_GROUP, type: "select", use: providers,
      filter: TSNET_FILTER_SRC, proxies: ["DIRECT"]
    });
    exists[TSNET_GROUP] = true;
  }

  // ---- 2) 地区组 ----
  var RESIDUAL = "其他";
  var matched = {};
  var results = [];

  for (i = 0; i < REGIONS.length; i++) {
    var r = REGIONS[i];
    if (r.name === RESIDUAL) { results.push(null); continue; }
    var m = members(config, nodes, r.filter, r.exclude);
    results.push(m);
    if (m.proxies) {
      for (j = 0; j < m.proxies.length; j++) { matched[m.proxies[j]] = true; }
    }
  }

  var regionGroups = [];
  for (i = 0; i < REGIONS.length; i++) {
    var reg = REGIONS[i];
    var mm = results[i];
    var g = { name: reg.name, type: reg.type, url: TEST_URL, interval: 300, lazy: true };
    if (reg.type !== "select") { g.tolerance = reg.tolerance || 100; }

    if (reg.name === RESIDUAL) {
      if (providerOnly) { continue; }              // provider 模式算不出「没被别的组吃掉」的节点
      var rest = [];
      for (j = 0; j < nodes.length; j++) { if (!matched[nodes[j]]) { rest.push(nodes[j]); } }
      if (rest.length === 0) { continue; }
      g.proxies = rest;
    } else if (mm && mm.use) {
      g.use = mm.use;
      if (mm.filter) { g.filter = mm.filter; }
      if (mm["exclude-filter"]) { g["exclude-filter"] = mm["exclude-filter"]; }
    } else {
      var list = (mm && mm.proxies) ? mm.proxies : [];
      if (list.length === 0) { continue; }         // 该机场没有这个地区 → 不生成空组
      g.proxies = list;
    }
    exists[reg.name] = true;
    regionGroups.push(g);
  }

  // ---- 3) 全部节点 ----
  var allGroup = null;
  if (nodes.length > 0) {
    allGroup = { name: "全部节点", type: "select", proxies: TSNET_IN_ALL ? nodes.concat(sp.tn) : nodes.slice() };
  } else if (providerOnly) {
    allGroup = { name: "全部节点", type: "select", use: providers, "exclude-filter": JUNK_SRC };
  }
  if (allGroup) { exists["全部节点"] = true; }

  // 只保留真实存在的成员，避免指向被跳过的组
  function keep(list) {
    var out = [], x, n;
    for (x = 0; x < list.length; x++) {
      n = (list[x] === "@TSNET") ? TSNET_GROUP : list[x];
      if (exists[n] && out.indexOf(n) < 0) { out.push(n); }
    }
    return out;
  }

  var domestic = keep(ENTRY_DOMESTIC);
  var foreign = keep(ENTRY_FOREIGN);
  if (domestic.length === 0) { domestic = ["DIRECT"]; }
  if (foreign.length === 0) { foreign = ["DIRECT"]; }

  // ---- 4) 入口组 ----
  groups.push({ name: "国内流量", type: "select", url: "https://www.baidu.com/favicon.ico", proxies: domestic });
  groups.push({ name: "国外流量", type: "select", url: "https://www.bing.com/favicon.ico", proxies: foreign });
  exists["国内流量"] = true;
  exists["国外流量"] = true;

  if (allGroup) { groups.push(allGroup); }
  for (i = 0; i < regionGroups.length; i++) { groups.push(regionGroups[i]); }

  // ---- 5) 国外媒体：所有流媒体共用一个口子 ----
  var mediaOrder = ["国外流量", "全部节点"];
  for (i = 0; i < regionGroups.length; i++) { mediaOrder.push(regionGroups[i].name); }
  mediaOrder.push("DIRECT");
  var mediaMembers = [];
  for (i = 0; i < mediaOrder.length; i++) {
    if (exists[mediaOrder[i]] && mediaMembers.indexOf(mediaOrder[i]) < 0) { mediaMembers.push(mediaOrder[i]); }
  }
  groups.push({ name: "国外媒体", type: "select", url: TEST_URL, proxies: mediaMembers });
  exists["国外媒体"] = true;

  // ---- 6) 服务组 ----
  for (i = 0; i < SERVICES.length; i++) {
    var svc = SERVICES[i];
    var mem = keep(svc.proxies);
    if (mem.length === 0) { mem = [exists["国外流量"] ? "国外流量" : "DIRECT"]; }
    groups.push({ name: svc.name, type: "select", url: TEST_URL, proxies: mem });
  }

  return { groups: groups, exists: exists };
}

// 规则兜底：指向不存在的组就改投 fallback；@TSNET 组不存在就整条丢掉
function safeRules(rules, groups, proxyNames, fallback) {
  var valid = { "DIRECT": true, "REJECT": true, "PASS": true };
  var i, out = [];
  for (i = 0; i < groups.length; i++) { valid[groups[i].name] = true; }
  for (i = 0; i < proxyNames.length; i++) { valid[proxyNames[i]] = true; }

  for (i = 0; i < rules.length; i++) {
    var line = String(rules[i]).replace(/@TSNET/g, TSNET_GROUP);   // 生成新字符串，不动全局 RULES
    var parts = line.split(",");
    var idx = (parts[0] === "MATCH") ? 1 : 2;
    var t = parts[idx];
    if (t === TSNET_GROUP && !valid[TSNET_GROUP]) { continue; }
    if (t !== undefined && !valid[t]) {
      parts[idx] = fallback;
      line = parts.join(",");
    }
    out.push(line);
  }
  return out;
}

function main(config, profileName) {
  renameCollidingNodes(config, groupNameSet());

  var sp = splitNodes(config);
  var built = buildGroups(config, sp);

  // ---- 代理组 ----
  var oldGroups = config["proxy-groups"] || [];
  if (DROP_OLD_GROUPS) {
    config["proxy-groups"] = built.groups;
  } else {
    var used = {}, extra = [], i;
    for (i = 0; i < built.groups.length; i++) { used[built.groups[i].name] = true; }
    for (i = 0; i < oldGroups.length; i++) {
      if (oldGroups[i] && !used[oldGroups[i].name]) { extra.push(oldGroups[i]); }
    }
    config["proxy-groups"] = built.groups.concat(extra);
  }

  // ---- 规则 + rule-providers（上一版漏了这两行的联动）----
  if (REPLACE_RULES) {
    config["rule-providers"] = mergeObj(config["rule-providers"], PROVIDERS);
    var proxyNames = [], ps = config.proxies || [];
    for (var k = 0; k < ps.length; k++) { if (ps[k] && ps[k].name) { proxyNames.push(ps[k].name); } }
    config.rules = safeRules(RULES, built.groups, proxyNames,
      built.exists[FALLBACK] ? FALLBACK : "DIRECT");
  }

  // ---- MagicDNS：只有 tailnet 组真的建出来了才接管 ts.net 的解析 ----
  if (built.exists[TSNET_GROUP]) {
    config.dns = config.dns || {};
    config.dns["nameserver-policy"] = config.dns["nameserver-policy"] || {};
    config.dns["nameserver-policy"]["+.ts.net"] = MAGICDNS + "#" + TSNET_GROUP;
  }

  return config;
}