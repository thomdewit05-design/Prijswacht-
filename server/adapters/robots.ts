/** Kleine robots.txt-lezer: Allow/Disallow met * en $, langste regel wint. */
interface Rule {
  allow: boolean;
  pattern: string;
}

interface Group {
  agents: string[];
  rules: Rule[];
}

export class Robots {
  private groups: Group[];

  constructor(text: string) {
    this.groups = [];
    let current: Group | null = null;
    let lastWasAgent = false;
    for (const rawLine of text.split(/\r?\n/)) {
      const line = rawLine.replace(/#.*$/, "").trim();
      const separator = line.indexOf(":");
      if (separator < 0) continue;
      const field = line.slice(0, separator).trim().toLowerCase();
      const value = line.slice(separator + 1).trim();
      if (field === "user-agent") {
        if (current === null || !lastWasAgent) {
          current = { agents: [], rules: [] };
          this.groups.push(current);
        }
        current.agents.push(value.toLowerCase());
        lastWasAgent = true;
      } else if ((field === "allow" || field === "disallow") && current !== null) {
        // Een lege Disallow betekent: alles mag.
        if (value !== "") current.rules.push({ allow: field === "allow", pattern: value });
        lastWasAgent = false;
      } else {
        lastWasAgent = false;
      }
    }
  }

  /** Mag deze user-agent dit pad (met querystring) ophalen? */
  allows(userAgent: string, path: string): boolean {
    const agent = userAgent.toLowerCase();
    const specific = this.groups.filter((group) =>
      group.agents.some((name) => name !== "*" && agent.includes(name)),
    );
    const chosen = specific.length > 0 ? specific : this.groups.filter((group) => group.agents.includes("*"));

    let best: Rule | null = null;
    for (const rule of chosen.flatMap((group) => group.rules)) {
      if (!matches(rule.pattern, path)) continue;
      if (
        best === null ||
        rule.pattern.length > best.pattern.length ||
        (rule.pattern.length === best.pattern.length && rule.allow)
      ) {
        best = rule;
      }
    }
    return best === null ? true : best.allow;
  }
}

function matches(pattern: string, path: string): boolean {
  const anchored = pattern.endsWith("$");
  const body = anchored ? pattern.slice(0, -1) : pattern;
  const source = body
    .split("*")
    .map((part) => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
    .join(".*");
  return new RegExp(`^${source}${anchored ? "$" : ""}`).test(path);
}
