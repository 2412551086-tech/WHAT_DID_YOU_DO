const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');

(async()=>{
  const browser = await chromium.launch({headless:true,channel:'chrome'});
  const output = require('node:path').join(__dirname,'review','checks');
  await fs.mkdir(output,{recursive:true});
  let checked = 0;
  try {
    for (const [name,locale,width,height] of [['desktop','zh-CN',1440,1050],['mobile','en-US',390,844],['small','zh-CN',320,740],['small-en','en-US',320,740]]) {
      const context = await browser.newContext({locale,viewport:{width,height}});
      const page = await context.newPage();
      const errors=[];
      page.on('pageerror',e=>errors.push(e.message));
      for (const route of ['/','/familyguard/','/familyguard/privacy/','/familyguard/terms/','/familyguard/subscription/','/familyguard/support/']) {
        await page.goto('http://127.0.0.1:4318'+route);
        await page.waitForURL(locale==='en-US'?`**/en${route}`:`**${route}`);
        await page.locator('#language').waitFor();
        assert.equal(await page.locator('html').getAttribute('lang'),locale==='en-US'?'en':'zh-CN');
        assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true,`${name} overflow ${route}`);
        assert.equal(await page.locator('h1').count(),1);
        for (const image of await page.locator('img').all()) assert.equal(await image.evaluate(i=>i.complete&&i.naturalWidth>0),true);
        if (route==='/' || route==='/familyguard/' || route==='/familyguard/privacy/') {
          await page.screenshot({path:output+'/'+name+'-'+(route==='/'?'home':route.includes('privacy')?'privacy':'app')+'.png',fullPage:true});
        }
        checked++;
      }
      await page.goto('http://127.0.0.1:4318/familyguard/privacy/#section-4');
      await page.selectOption('#language','en');
      await page.waitForURL('**/en/familyguard/privacy/?lang=en#section-4');
      await page.reload();
      assert.equal(await page.locator('html').getAttribute('lang'),'en');
      await page.selectOption('#language','zh');
      await page.waitForURL('**/familyguard/privacy/?lang=zh#section-4');
      assert.equal(await page.locator('html').getAttribute('lang'),'zh-CN');
      await page.selectOption('#language','auto');
      await page.waitForURL(locale==='en-US'?'**/en/familyguard/privacy/#section-4':'**/familyguard/privacy/#section-4');
      assert.equal(await page.locator('html').getAttribute('lang'),locale==='en-US'?'en':'zh-CN');
      await page.goto('http://127.0.0.1:4318/privacy');
      await page.waitForURL(locale==='en-US'?'**/en/familyguard/privacy/':'**/familyguard/privacy/');
      assert.deepEqual(errors,[]);
      await context.close();
    }
    console.log(`PASS: ${checked} pages; device language, manual choice, persistence, reset, anchors, legacy links, images and overflow.`);
  } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exitCode=1;});
