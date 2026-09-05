import { useEffect, useState } from "react";
import { FaApple, FaWeixin } from "react-icons/fa";
import { HiOutlineEnvelope } from "react-icons/hi2";

const loginOptions = [
  {
    id: "email",
    label: "邮箱验证码",
    className: "login-button--email",
    icon: HiOutlineEnvelope,
  },
  {
    id: "wechat",
    label: "微信登录",
    className: "login-button--wechat",
    icon: FaWeixin,
  },
  {
    id: "apple",
    label: "Apple 登录",
    className: "login-button--apple",
    icon: FaApple,
  },
];

export function App() {
  const [hasAgreed, setHasAgreed] = useState(false);
  const [notice, setNotice] = useState("");

  useEffect(() => {
    if (!notice) return undefined;

    const timer = window.setTimeout(() => setNotice(""), 2200);
    return () => window.clearTimeout(timer);
  }, [notice]);

  function handleLogin(type) {
    if (!hasAgreed) {
      setNotice("请先阅读并同意用户协议与隐私政策");
      return;
    }

    setNotice(type === "email" ? "邮箱验证码入口正在接入" : "该登录方式即将支持");
  }

  return (
    <main className="stage" aria-label="你今天干啥啦登录页 HTML 还原">
      <section className="mobile-prototype">
        <img className="top-accent top-accent--left" src="/assets/accent-left.png" alt="" />
        <img className="top-accent top-accent--right" src="/assets/accent-right.png" alt="" />

        <header className="hero-copy">
          <h1>你今天干啥啦</h1>
          <p>家务不是没人做，只是还没记上功劳簿。</p>
        </header>

        <img
          className="battle-illustration"
          src="/assets/housework-battle.png"
          alt="两位家庭成员拿着拖把和衣物展开一场夸张幽默的家务大战"
        />

        <div className="login-actions" aria-label="登录方式">
          {loginOptions.map(({ id, label, className, icon: Icon }) => (
            <button
              className={`login-button ${className}`}
              key={id}
              type="button"
              onClick={() => handleLogin(id)}
            >
              <Icon className="login-button__icon" aria-hidden="true" />
              <span>{label}</span>
            </button>
          ))}
        </div>

        <label className="agreement">
          <input
            type="checkbox"
            checked={hasAgreed}
            onChange={(event) => setHasAgreed(event.target.checked)}
          />
          <span className="agreement__box" aria-hidden="true" />
          <span className="agreement__copy">
            我已阅读并同意
            <a href="#user-agreement" onClick={(event) => event.preventDefault()}>用户协议</a>
            和
            <a href="#privacy-policy" onClick={(event) => event.preventDefault()}>隐私政策</a>
          </span>
        </label>

        <img className="bottom-accent bottom-accent--left" src="/assets/bottom-left.png" alt="" />
        <img className="bottom-accent bottom-accent--right" src="/assets/bottom-right.png" alt="" />

        <div className={`notice ${notice ? "notice--visible" : ""}`} role="status" aria-live="polite">
          {notice}
        </div>
      </section>
    </main>
  );
}
