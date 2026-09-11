import { readFile, writeFile, mkdir, copyFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { reviewPages } from './review-content.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
const production = process.argv.includes('--production');
const output = path.join(root, production ? 'release' : 'review');
const config = JSON.parse(await readFile(path.join(root, 'site.config.json'), 'utf8'));
if (production && (config.policyApproved !== true || ['operator','icpNumber','supportEmail','effectiveDate','retentionStatement','backupStatement'].some(key=>!config[key]?.trim()))) throw new Error('Approved publication configuration is required');
const esc = v => String(v).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
await mkdir(path.join(output, 'assets'), {recursive:true});
await copyFile(path.join(root, 'review.css'), path.join(output,'assets/site.css'));
await copyFile(path.join(root, 'review-language.js'), path.join(output,'assets/language.js'));
const assets = path.join(root, '../apps/ios/Resources/Assets.xcassets');
await copyFile(path.join(assets,'AppIcon.appiconset/AppIcon-1024.png'),path.join(output,'assets/logo.png'));
await copyFile(path.join(assets,'subscription_teamwork.imageset/teamwork.png'),path.join(output,'assets/teamwork.png'));

for (const en of [false,true]) {
  const locale = en ? 'en' : 'zh-CN';
  const base = en ? '/en' : '';
  const app = `${base}/familyguard/`;
  const title = en ? 'Family Guard' : '家庭保卫战';
  const pages = reviewPages(config,en);
  const tr = (zh,eng) => en ? eng : zh;
  const pageLink = slug => app + slug + '/';
  const footer = `<footer class="footer"><div class="footer-top"><a href="${base}/">douxiaolang</a><a href="${pageLink('support')}">${tr('联系与支持','Contact & support')}</a></div><a class="icp" href="https://beian.miit.gov.cn/" rel="noopener noreferrer">${esc(config.icpNumber)}</a></footer>`;
  const layout = (route,heading,content,isApp=false) => `<!doctype html><html lang="${locale}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>${esc(heading)} · douxiaolang</title><link rel="stylesheet" href="/assets/site.css"><script defer src="/assets/language.js"></script></head><body data-route="${route}" id="top"><a class="skip" href="#main">${tr('跳转到正文','Skip to content')}</a><div class="shell"><header class="top"><a class="wordmark" href="${isApp?app:base+'/'}">${isApp?'<img src="/assets/logo.png" alt="">':''}${isApp?title:'douxiaolang'}</a><div class="tools"><a class="home-link" href="${base}/">${tr('个人主页','Personal site')}</a><label class="language"><span class="sr-only">${tr('语言','Language')}</span><select id="language"><option value="auto">${tr('跟随本机语言','Device language')}</option><option value="zh">简体中文</option><option value="en">English</option></select></label><noscript><a href="${en?'':'/en'}${route}">${en?'中文':'English'}</a></noscript></div></header><div class="notice">${tr('本地审阅版 · 尚未发布','Local review · Not published')}</div><main id="main">${content}</main>${footer}</div></body></html>`;
  async function save(route,html) {
    if (production) {
      html = html.replace('<meta name="robots" content="noindex,nofollow">','')
        .replace(`<div class="notice">${tr('本地审阅版 · 尚未发布','Local review · Not published')}</div>`,'')
        .replace(' · English translation for review','');
    }
    const directory = path.join(output,base+route);
    await mkdir(directory,{recursive:true});
    await writeFile(path.join(directory,'index.html'),html);
  }
  await save('/',layout('/','douxiaolang',`<section class="masthead"><p class="subtitle">${tr('个人主页','Personal site')}</p><h1>douxiaolang</h1><p class="intro">${tr('我的应用与作品。','My apps and projects.')}</p></section><section class="work"><div class="section-label"><h2>${tr('应用','Apps')}</h2><span>iOS</span></div><div class="work-title"><img class="app-icon" src="/assets/logo.png" alt="${title}"><div><h2>${title}</h2><p>${tr('记录家务，看见彼此的付出。','Record chores. Recognize each other’s effort.')}</p></div><a class="visit" href="${app}">${tr('查看应用','Explore the app')} ↗</a></div><a href="${app}" aria-label="${tr('查看家庭保卫战','Explore Family Guard')}"><img class="art" src="/assets/teamwork.png" alt="${tr('两位家庭成员完成家务后击掌','Two household members high-five after doing chores')}"></a><div class="work-note"><span>${tr('家务记录 · 家庭协作 · 成就与战报','Chores · Collaboration · Achievements & reports')}</span><a href="${pageLink('support')}">${tr('帮助与反馈','Help & feedback')}</a></div></section>`));
  const captions = en ? ['Your data and your choices.','A clear agreement for using the app.','Plans, benefits and renewal.','Answers and a way to reach us.'] : ['数据如何使用，由您如何管理。','关于使用这个 App 的约定。','价格、权益与续费规则。','常见问题，以及联系我的方式。'];
  await save('/familyguard/',layout('/familyguard/',title,`<section class="app-header"><img class="app-icon" src="/assets/logo.png" alt=""><div><h1>${title}</h1><p>${tr('记录家务，看见彼此的付出。','Record chores. Recognize each other’s effort.')}</p></div></section><img class="art app-art" src="/assets/teamwork.png" alt="${tr('一起完成家务的家庭成员','Household members doing chores together')}"><div class="work-note"><span>${tr('先在本机体验，需要家庭同步时再登录。','Try it locally. Sign in when you need household sync.')}</span><span>iOS</span></div><nav class="product-links" aria-label="${tr('应用说明','App information')}">${pages.map((p,i)=>`<a class="product-link" href="${pageLink(p.slug)}"><h2>${p.title}<span aria-hidden="true">↗</span></h2><p>${captions[i]}</p></a>`).join('')}</nav>`,true));
  for (const page of pages) {
    const sections = page.sections.map(([h,...ps],i) => `<section id="section-${i}"><h2>${esc(h)}</h2>${ps.map(p=>`<p>${p===config.supportEmail?`<a class="email" href="mailto:${esc(p)}">${esc(p)}</a>`:esc(p)}</p>`).join('')}</section>`).join('');
    const languageNote = page.slug === 'privacy' ? `<section><h2>${tr('网站语言偏好','Website language preference')}</h2><p>${tr('网站按浏览器语言选择默认显示，手动选择仅保存在本机浏览器，不发送到服务器，也不用于追踪。您可随时改回“跟随本机语言”。','The website uses your browser language by default. A manual choice is stored only in this browser, not sent to the server or used for tracking. You can switch back to Device language at any time.')}</p></section>` : '';
    await save(`/familyguard/${page.slug}/`,layout(`/familyguard/${page.slug}/`,page.title,`<div class="breadcrumb"><a href="${app}">${title}</a> / ${page.title}</div><header class="document-heading"><h1>${page.title}</h1><p class="intro">${page.intro}</p><p class="meta">${tr('更新日期','Updated')} ${esc(config.effectiveDate)}${en?' · English translation for review':''}</p></header><div class="reading"><aside class="toc"><h2>${tr('本页内容','On this page')}</h2><nav>${page.sections.map(([h],i)=>`<a href="#section-${i}">${esc(h)}</a>`).join('')}</nav></aside><article class="article">${sections}${languageNote}<a class="backtop" href="#top">${tr('回到顶部','Back to top')} ↑</a></article></div>`,true));
  }
}
// Old app links continue to reach the product-specific pages after a future migration.
for (const slug of ['privacy','terms','subscription','support']) {
  const html = `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=/familyguard/${slug}/"><title>家庭保卫战</title></head><body><a href="/familyguard/${slug}/">家庭保卫战</a></body></html>`;
  await mkdir(path.join(output,slug),{recursive:true});
  await writeFile(path.join(output,slug,'index.html'),html);
  await writeFile(path.join(output,`${slug}.html`),html);
}
console.log(`${production ? 'Production package' : 'Local review only'}: ${output}`);
