// Minimale typen voor de Edge Functions, zodat tsc ze kan controleren.
declare const Deno: {
  serve(handler: (request: Request) => Response | Promise<Response>): void;
  env: { get(name: string): string | undefined };
};
