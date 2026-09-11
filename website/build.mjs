import { readFile, writeFile, mkdir, copyFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { pages } from './content.mjs';

const root = path.dirname(fileURLToPath(import.meta.url));
const preview = process.argv.includes('--preview');
const configPath = process.env.SITE_CONFIG_PATH || path.join(root, 'site.config.json');
const config = await readFile(configPath, 'utf8').then(JSON.parse).catch(error => {
  if (!preview || error.code !== 'ENOENT') throw error;
  return { operator: '待确认的运营主体', icpNumber: '', supportEmail: '待确认', effectiveDate: '2026-09-06',
    retentionStatement: '待确认：业务数据、验证码挑战、会话和日志的具体保留期限与清理机制。',
    backupStatement: '待确认：备份轮换期限、删除请求如何应用到备份及恢复后的再次删除。' };
});
const required = ['operator', 'icpNumber', 'supportEmail', 'effectiveDate', 'retentionStatement', 'backupStatement'];
if (!preview && (config.policyApproved !== true || required.some(key => typeof config[key] !== 'string' || !config[key].trim()))) {
  throw new Error('发布被阻止：请确认运营主体、备案号、客服邮箱、政策日期、保留与备份规则，并设置 policyApproved=true。');
}
if (!preview && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(config.supportEmail)) throw new Error('客服邮箱格式无效');
const escape = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const output = path.join(root, preview ? 'preview' : 'dist');
await mkdir(output, { recursive: true });
await copyFile(
  path.join(root, '..', 'apps', 'ios', 'Resources', 'Assets.xcassets', 'AppIcon.appiconset', 'AppIcon-1024.png'),
  path.join(output, 'logo.png'),
);
const documents = pages(config);
for (const page of documents) {
  const nav = documents.map(item => `<a href="${item.slug || 'index'}.html"${page.slug === item.slug ? ' aria-current="page"' : ''}>${escape(item.title)}</a>`).join('');
  const sections = page.sections.map(([title, ...paragraphs]) => `<section><h2>${escape(title)}</h2>${paragraphs.map(p => `<p>${escape(p)}</p>`).join('')}</section>`).join('');
  const html = `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">${preview ? '<meta name="robots" content="noindex,nofollow">' : ''}<title>${escape(page.title)} · 家庭保卫战</title><style>
  *{box-sizing:border-box}body{margin:0;background:#fff;color:#202323;font-family:-apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif;line-height:1.8;letter-spacing:0}a{color:#17684f;text-underline-offset:4px}header,main,footer{max-width:880px;margin:auto;padding:24px}header{border-bottom:1px solid #e4e8e6}.brand{display:flex;gap:12px;align-items:center;font-size:20px;font-weight:600;color:inherit;text-decoration:none}.brand img{width:44px;height:44px}nav{display:flex;flex-wrap:wrap;gap:8px 24px;margin-top:16px}nav a{padding:8px 0;font-size:14px}nav [aria-current]{font-weight:600}h1{font-size:32px;line-height:1.4;margin:24px 0 12px;font-weight:600}h2{font-size:20px;line-height:1.5;margin:32px 0 12px}p{margin:10px 0;overflow-wrap:anywhere}.meta{font-size:14px;color:#53605b}.draft{background:#fff2cb;padding:12px 16px;border-radius:4px}.intro{font-size:17px}footer{font-size:14px;border-top:1px solid #e4e8e6;color:#53605b}a:focus-visible{outline:2px solid #17684f;outline-offset:4px}@media(max-width:480px){header,main,footer{padding:20px}h1{font-size:28px}nav{gap:4px 18px}}
  </style></head><body><header><a class="brand" href="index.html"><img src="logo.png" alt=""><span>家庭保卫战</span></a><nav aria-label="网站导航">${nav}</nav></header><main>${preview ? '<p class="draft">审核草稿：未发布，运营信息和数据保留规则仍需确认。</p>' : ''}<h1>${escape(page.title)}</h1><p class="meta">版本日期：${escape(config.effectiveDate)}</p><p class="intro">${escape(page.intro)}</p>${sections}</main><footer><p>${escape(config.operator)}</p>${config.icpNumber ? `<a href="https://beian.miit.gov.cn/" rel="noopener noreferrer">${escape(config.icpNumber)}</a>` : ''}</footer></body></html>`;
  await writeFile(path.join(output, `${page.slug || 'index'}.html`), html);
}
console.log(`Generated ${documents.length} ${preview ? 'draft' : 'approved'} pages: ${output}`);
