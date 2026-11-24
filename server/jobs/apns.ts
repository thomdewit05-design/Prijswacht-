import { createPrivateKey, sign, type KeyObject } from "node:crypto";
import { connect } from "node:http2";
import type { PushMessage, PushSender } from "./store.ts";

export interface ApnsConfig {
  /** Inhoud van het .p8-bestand uit het Apple Developer-account. */
  privateKey: string;
  keyId: string;
  teamId: string;
  /** Bundle-id van de app. */
  topic: string;
  production: boolean;
}

const base64url = (data: Buffer | string): string => Buffer.from(data).toString("base64url");

/** JWT voor APNs (ES256). Een uur geldig; we maken er elke 50 minuten een. */
export function apnsToken(config: Pick<ApnsConfig, "keyId" | "teamId">, key: KeyObject, nowSeconds: number): string {
  const header = base64url(JSON.stringify({ alg: "ES256", kid: config.keyId }));
  const claims = base64url(JSON.stringify({ iss: config.teamId, iat: nowSeconds }));
  const signature = sign("sha256", Buffer.from(`${header}.${claims}`), { key, dsaEncoding: "ieee-p1363" });
  return `${header}.${claims}.${base64url(signature)}`;
}

export function apnsPayload(message: PushMessage): string {
  return JSON.stringify({
    aps: { alert: { title: message.title, body: message.body }, sound: "default" },
    purchaseID: message.purchaseId,
  });
}

/** Stuurt pushmeldingen via APNs. Nog niet tegen Apple getest. */
export class ApnsSender implements PushSender {
  private config: ApnsConfig;
  private key: KeyObject;
  private cached: { token: string; madeAt: number } | null = null;

  constructor(config: ApnsConfig) {
    this.config = config;
    this.key = createPrivateKey(config.privateKey);
  }

  private token(): string {
    const now = Math.floor(Date.now() / 1000);
    if (this.cached === null || now - this.cached.madeAt > 50 * 60) {
      this.cached = { token: apnsToken(this.config, this.key, now), madeAt: now };
    }
    return this.cached.token;
  }

  send(deviceToken: string, message: PushMessage): Promise<void> {
    const host = this.config.production ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";
    return new Promise((resolve, reject) => {
      const session = connect(host);
      session.on("error", reject);
      const request = session.request({
        ":method": "POST",
        ":path": `/3/device/${deviceToken}`,
        authorization: `bearer ${this.token()}`,
        "apns-topic": this.config.topic,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "content-type": "application/json",
      });
      let status = 0;
      let body = "";
      request.on("response", (headers) => {
        status = Number(headers[":status"]);
      });
      request.on("data", (chunk) => {
        body += String(chunk);
      });
      request.on("end", () => {
        session.close();
        if (status === 200) resolve();
        else reject(new Error(`APNs ${status}: ${body}`));
      });
      request.on("error", reject);
      request.end(apnsPayload(message));
    });
  }
}

/** Voor als er nog geen APNs-sleutel is: alleen loggen. */
export class LogSender implements PushSender {
  async send(deviceToken: string, message: PushMessage): Promise<void> {
    console.log(`[push naar ${deviceToken.slice(0, 8)}…] ${message.title} — ${message.body}`);
  }
}
