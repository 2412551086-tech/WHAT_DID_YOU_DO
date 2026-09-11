import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import nodemailer = require('nodemailer');
import type { Transporter } from 'nodemailer';

type EmailDeliveryMode = 'LOG' | 'ALIYUN_DM';

@Injectable()
export class EmailDeliveryService {
  private readonly logger = new Logger(EmailDeliveryService.name);
  private readonly mode: EmailDeliveryMode;
  private readonly transporter?: Transporter;

  constructor() {
    this.mode = process.env.EMAIL_DELIVERY_MODE?.toUpperCase() === 'ALIYUN_DM'
      ? 'ALIYUN_DM'
      : 'LOG';
    if (process.env.NODE_ENV === 'production' && this.mode !== 'ALIYUN_DM') {
      throw new Error('EMAIL_DELIVERY_MODE must be ALIYUN_DM in production');
    }
    if (this.mode === 'ALIYUN_DM') {
      const port = this.smtpPort();
      this.transporter = nodemailer.createTransport({
        host: process.env.ALIYUN_DM_SMTP_HOST?.trim() || 'smtpdm.aliyun.com',
        port,
        secure: process.env.ALIYUN_DM_SMTP_SECURE !== 'false',
        connectionTimeout: 10_000,
        greetingTimeout: 10_000,
        socketTimeout: 15_000,
        auth: {
          user: this.required('ALIYUN_DM_SMTP_USER'),
          pass: this.required('ALIYUN_DM_SMTP_PASS'),
        },
      });
    }
  }

  async sendLoginCode(email: string, code: string, expiresInMinutes: number) {
    if (this.mode === 'LOG') {
      if (process.env.NODE_ENV !== 'test') {
        this.logger.log(`Development email OTP for ${this.mask(email)}: ${code}`);
      }
      return;
    }

    try {
      await this.transporter!.sendMail({
        from: {
          name: process.env.ALIYUN_DM_FROM_NAME?.trim() || '家庭保卫战',
          address: this.required('ALIYUN_DM_SMTP_USER'),
        },
        to: email,
        subject: '家庭保卫战登录验证码',
        text: `你的登录验证码是 ${code}，${expiresInMinutes} 分钟内有效。如非本人操作，请忽略这封邮件。`,
        html: [
          '<div style="font-family:-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif;color:#161616;line-height:1.6">',
          '<h2 style="margin:0 0 12px">家庭保卫战</h2>',
          '<p>你的登录验证码是：</p>',
          `<p style="font-size:32px;font-weight:700;letter-spacing:8px;margin:16px 0">${code}</p>`,
          `<p>${expiresInMinutes} 分钟内有效。如非本人操作，请忽略这封邮件。</p>`,
          '</div>',
        ].join(''),
      });
    } catch (error) {
      this.logger.error('Email OTP delivery failed', error instanceof Error ? error.stack : undefined);
      throw new ServiceUnavailableException('验证码邮件发送失败，请稍后重试');
    }
  }

  exposesDevelopmentCode() {
    return process.env.NODE_ENV !== 'production'
      && (process.env.EMAIL_OTP_EXPOSE_CODE === 'true' || this.mode === 'LOG');
  }

  private required(name: string) {
    const value = process.env[name]?.trim();
    if (!value) {
      throw new Error(`${name} is required`);
    }
    return value;
  }

  private smtpPort() {
    const port = Number(process.env.ALIYUN_DM_SMTP_PORT || '465');
    if (!Number.isInteger(port) || port < 1 || port > 65_535) {
      throw new Error('ALIYUN_DM_SMTP_PORT must be a valid TCP port');
    }
    return port;
  }

  private mask(email: string) {
    const [local, domain] = email.split('@');
    return `${local.slice(0, 2)}***@${domain}`;
  }
}
