import { Robots } from "./robots.ts";
import { AdapterError, type PageFetcher } from "./types.ts";

export interface PoliteFetcherOptions {
  /** Eerlijke User-Agent met contactadres, bijvoorbeeld
   *  "PrijswachtStudie/0.1 (+mailto:jij@voorbeeld.nl)". */
  userAgent: string;
  /** Minimale tijd tussen twee verzoeken aan dezelfde host. */
  minIntervalMs?: number;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
  now?: () => number;
  sleep?: (ms: number) => Promise<void>;
}

/**
 * Haalt pagina's netjes op: respecteert robots.txt, wacht minstens vijf
 * seconden tussen twee verzoeken aan dezelfde winkel en meldt zich met een
 * eerlijke User-Agent.
 */
export class PoliteFetcher implements PageFetcher {
  private options: Required<PoliteFetcherOptions>;
  private nextAllowed = new Map<string, number>();
  private robots = new Map<string, Promise<Robots | "geblokkeerd">>();

  constructor(options: PoliteFetcherOptions) {
    if (!/@|https?:\/\//.test(options.userAgent)) {
      throw new Error("De User-Agent moet een contactadres bevatten (e-mail of website).");
    }
    this.options = {
      minIntervalMs: 5000,
      timeoutMs: 20_000,
      fetchImpl: fetch,
      now: Date.now,
      sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
      ...options,
    };
  }

  async getHtml(url: string): Promise<string> {
    const target = new URL(url);
    if (target.protocol !== "https:" && target.protocol !== "http:") {
      throw new AdapterError("netwerk", "geen weblink");
    }
    const verdict = await this.robotsVerdict(target);
    if (verdict === "onbereikbaar") throw new AdapterError("netwerk", "robots.txt niet bereikbaar");
    if (verdict === "verboden") throw new AdapterError("robots-verbiedt", target.pathname);

    const response = await this.request(target, "text/html,application/xhtml+xml");
    if (!response.ok) throw new AdapterError("http-status", String(response.status));
    return await response.text();
  }

  /** Mag deze pagina volgens robots.txt worden opgehaald? */
  async isAllowed(target: URL): Promise<boolean> {
    return (await this.robotsVerdict(target)) === "toegestaan";
  }

  /** Zonder leesbare robots.txt halen we voor de zekerheid niets op. */
  private async robotsVerdict(target: URL): Promise<"toegestaan" | "verboden" | "onbereikbaar"> {
    let pending = this.robots.get(target.origin);
    if (pending === undefined) {
      pending = this.loadRobots(target.origin);
      this.robots.set(target.origin, pending);
    }
    const robots = await pending;
    if (robots === "geblokkeerd") return "onbereikbaar";
    return robots.allows(this.options.userAgent, target.pathname + target.search) ? "toegestaan" : "verboden";
  }

  private async loadRobots(origin: string): Promise<Robots | "geblokkeerd"> {
    try {
      const response = await this.request(new URL("/robots.txt", origin), "text/plain");
      if (response.ok) return new Robots(await response.text());
      // Geen robots.txt (4xx) betekent: geen beperkingen. Bij een serverfout
      // weten we het niet en halen we voor de zekerheid niets op.
      return response.status >= 400 && response.status < 500 && response.status !== 429
        ? new Robots("")
        : "geblokkeerd";
    } catch {
      return "geblokkeerd";
    }
  }

  private async request(target: URL, accept: string): Promise<Response> {
    await this.waitForTurn(target.host);
    try {
      return await this.options.fetchImpl(target, {
        headers: {
          "User-Agent": this.options.userAgent,
          Accept: accept,
          "Accept-Language": "nl-NL,nl;q=0.9",
        },
        redirect: "follow",
        signal: AbortSignal.timeout(this.options.timeoutMs),
      });
    } catch (error) {
      throw new AdapterError("netwerk", error instanceof Error ? error.message : String(error));
    }
  }

  private async waitForTurn(host: string): Promise<void> {
    const now = this.options.now();
    const start = Math.max(now, this.nextAllowed.get(host) ?? 0);
    this.nextAllowed.set(host, start + this.options.minIntervalMs);
    if (start > now) await this.options.sleep(start - now);
  }
}
