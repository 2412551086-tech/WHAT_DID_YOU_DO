import { readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");

async function imageData(relativePath) {
  const bytes = await readFile(join(root, relativePath));
  return `data:image/png;base64,${bytes.toString("base64")}`;
}

const [
  styles,
  accentLeft,
  accentRight,
  battle,
  bottomLeft,
  bottomRight,
  phoneIcon,
  wechatIcon,
  appleIcon,
] = await Promise.all([
  readFile(join(root, "src/styles.css"), "utf8"),
  imageData("public/assets/accent-left.png"),
  imageData("public/assets/accent-right.png"),
  imageData("public/assets/housework-battle.png"),
  imageData("public/assets/bottom-left.png"),
  imageData("public/assets/bottom-right.png"),
  imageData("public/assets/standalone-icons/phone.png"),
  imageData("public/assets/standalone-icons/wechat.png"),
  imageData("public/assets/standalone-icons/apple.png"),
]);

const html = `<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="theme-color" content="#fff9e8" />
    <meta name="description" content="《你今天干啥啦》登录首页单文件 HTML" />
    <title>你今天干啥啦</title>
    <style>
${styles}
      .login-button__icon {
        object-fit: contain;
        border-radius: 4px;
      }
      .login-button--wechat .login-button__icon {
        width: 34px;
        height: 34px;
      }
    </style>
  </head>
  <body>
    <main class="stage" aria-label="你今天干啥啦登录页 HTML 还原">
      <section class="mobile-prototype">
        <img class="top-accent top-accent--left" src="${accentLeft}" alt="" />
        <img class="top-accent top-accent--right" src="${accentRight}" alt="" />

        <header class="hero-copy">
          <h1>你今天干啥啦</h1>
          <p>家务不是没人做，只是还没记上功劳簿。</p>
        </header>

        <img class="battle-illustration" src="${battle}" alt="两位家庭成员展开夸张幽默的家务大战" />

        <div class="login-actions" aria-label="登录方式">
          <button class="login-button login-button--phone" type="button" data-login="phone">
            <img class="login-button__icon" src="${phoneIcon}" alt="" />
            <span>手机号登录</span>
          </button>
          <button class="login-button login-button--wechat" type="button" data-login="wechat">
            <img class="login-button__icon" src="${wechatIcon}" alt="" />
            <span>微信登录</span>
          </button>
          <button class="login-button login-button--apple" type="button" data-login="apple">
            <img class="login-button__icon" src="${appleIcon}" alt="" />
            <span>Apple 登录</span>
          </button>
        </div>

        <label class="agreement">
          <input id="agreement" type="checkbox" />
          <span class="agreement__box" aria-hidden="true"></span>
          <span class="agreement__copy">
            我已阅读并同意
            <a href="#user-agreement">用户协议</a>
            和
            <a href="#privacy-policy">隐私政策</a>
          </span>
        </label>

        <img class="bottom-accent bottom-accent--left" src="${bottomLeft}" alt="" />
        <img class="bottom-accent bottom-accent--right" src="${bottomRight}" alt="" />
        <div class="notice" role="status" aria-live="polite"></div>
      </section>
    </main>

    <script>
      const agreement = document.querySelector("#agreement");
      const notice = document.querySelector(".notice");
      let noticeTimer;

      function showNotice(message) {
        window.clearTimeout(noticeTimer);
        notice.textContent = message;
        notice.classList.add("notice--visible");
        noticeTimer = window.setTimeout(() => {
          notice.classList.remove("notice--visible");
        }, 2200);
      }

      document.querySelectorAll("[data-login]").forEach((button) => {
        button.addEventListener("click", () => {
          if (!agreement.checked) {
            showNotice("请先阅读并同意用户协议与隐私政策");
            return;
          }

          showNotice(button.dataset.login === "phone" ? "手机号登录入口已开启" : "该登录方式即将支持");
        });
      });

      document.querySelectorAll(".agreement a").forEach((link) => {
        link.addEventListener("click", (event) => event.preventDefault());
      });
    </script>
  </body>
</html>
`;

const output = join(root, "你今天干啥啦-登录页.html");
await writeFile(output, html, "utf8");
console.log(output);
